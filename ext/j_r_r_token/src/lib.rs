use std::{collections::HashSet, sync::OnceLock};

use magnus::{function, method, prelude::*, Error, RString, Ruby};
use tiktoken_rs::{
    bpe_for_tokenizer,
    tokenizer::{get_tokenizer, Tokenizer},
    CoreBPE,
};

// Resolves a model name (or bare encoding name) to a tokenizer.
// Model -> tokenizer dispatch is delegated to `tiktoken_rs::tokenizer::get_tokenizer`,
// which is kept in sync with upstream OpenAI tiktoken. It handles `ft:` prefix
// stripping, GPT-5/4.5/4.1/4o families, o1/o3/o4-mini reasoning models, gpt-oss
// (harmony), codex-mini, and all legacy aliases.
fn tokenizer_for(model: &str) -> Option<Tokenizer> {
    match model {
        // Bare encoding names — callers may pass these directly.
        "o200k_harmony" => Some(Tokenizer::O200kHarmony),
        "o200k_base" => Some(Tokenizer::O200kBase),
        "cl100k_base" => Some(Tokenizer::Cl100kBase),
        "p50k_base" => Some(Tokenizer::P50kBase),
        "p50k_edit" => Some(Tokenizer::P50kEdit),
        "r50k_base" => Some(Tokenizer::R50kBase),
        _ => get_tokenizer(model),
    }
}

// Canonical encoding name. `Gpt2` is an alias tiktoken-rs keeps for r50k_base.
fn encoding_name(tokenizer: Tokenizer) -> &'static str {
    match tokenizer {
        Tokenizer::O200kHarmony => "o200k_harmony",
        Tokenizer::O200kBase => "o200k_base",
        Tokenizer::Cl100kBase => "cl100k_base",
        Tokenizer::P50kBase => "p50k_base",
        Tokenizer::P50kEdit => "p50k_edit",
        Tokenizer::R50kBase | Tokenizer::Gpt2 => "r50k_base",
    }
}

fn unsupported_model(ruby: &Ruby, model: &str) -> Error {
    Error::new(
        ruby.exception_arg_error(),
        format!("Model '{}' not supported.", model),
    )
}

// Returns the special tokens allowed when encoding (all of the encoding's special
// tokens, matching `encode_with_special_tokens`). The set is built once per encoding
// and cached: `CoreBPE::special_tokens()` allocates a fresh set on every call, which
// is noticeable for o200k_harmony (~1,100 special tokens).
fn allowed_special(tokenizer: Tokenizer, bpe: &'static CoreBPE) -> &'static HashSet<&'static str> {
    static SETS: [OnceLock<HashSet<&'static str>>; 6] = [const { OnceLock::new() }; 6];
    let index = match tokenizer {
        Tokenizer::O200kHarmony => 0,
        Tokenizer::O200kBase => 1,
        Tokenizer::Cl100kBase => 2,
        Tokenizer::P50kBase => 3,
        Tokenizer::P50kEdit => 4,
        // Gpt2 resolves to the same r50k_base singleton.
        Tokenizer::R50kBase | Tokenizer::Gpt2 => 5,
    };
    SETS[index].get_or_init(|| bpe.special_tokens())
}

/// A tokenizer for one encoding, exposed to Ruby as `JRRToken::Tokenizer`.
///
/// Instances only hold the encoding; the heavy `CoreBPE` is the process-wide singleton
/// from `bpe_for_tokenizer`, so instances are cheap. The Ruby side builds one frozen
/// instance per encoding and hands those out from `Tokenizer.for_model`.
#[magnus::wrap(class = "JRRToken::Tokenizer", free_immediately, size)]
struct RbTokenizer {
    tokenizer: Tokenizer,
}

impl RbTokenizer {
    // Private constructor, `Tokenizer._build(encoding_name)`.
    fn build(ruby: &Ruby, encoding: String) -> Result<Self, Error> {
        let tokenizer = match encoding.as_str() {
            "o200k_harmony" | "o200k_base" | "cl100k_base" | "p50k_base" | "p50k_edit"
            | "r50k_base" => tokenizer_for(&encoding),
            _ => None,
        }
        .ok_or_else(|| {
            Error::new(
                ruby.exception_arg_error(),
                format!("Unknown encoding '{}'.", encoding),
            )
        })?;
        Ok(Self { tokenizer })
    }

    fn bpe(&self, ruby: &Ruby) -> Result<&'static CoreBPE, Error> {
        // `bpe_for_tokenizer` returns a process-wide `&'static CoreBPE` singleton, so the
        // vocabulary is decoded and the regexes are compiled once per encoding, not on
        // every call. It currently never returns `Err` (a failed build panics inside
        // tiktoken-rs's lazy static); the `map_err` only guards against future changes.
        bpe_for_tokenizer(self.tokenizer)
            .map_err(|e| Error::new(ruby.exception_runtime_error(), e.to_string()))
    }

    fn encoding(&self) -> &'static str {
        encoding_name(self.tokenizer)
    }

    fn encode_ranks(&self, ruby: &Ruby, text: &str) -> Result<Vec<u32>, Error> {
        let bpe = self.bpe(ruby)?;
        // `encode` (unlike `encode_with_special_tokens`) reports tokenizer regex failures
        // as an error instead of panicking, so Ruby gets a RuntimeError rather than `fatal`.
        bpe.encode(text, allowed_special(self.tokenizer, bpe))
            .map(|(tokens, _)| tokens)
            .map_err(|e| Error::new(ruby.exception_runtime_error(), e.to_string()))
    }

    // `Tokenizer#_count(text)`
    fn count(ruby: &Ruby, rb_self: &Self, text: String) -> Result<usize, Error> {
        rb_self.encode_ranks(ruby, &text).map(|tokens| tokens.len())
    }

    // `Tokenizer#_encode(text)`
    fn encode(ruby: &Ruby, rb_self: &Self, text: String) -> Result<Vec<u32>, Error> {
        rb_self.encode_ranks(ruby, &text)
    }

    fn decode_to_bytes(&self, ruby: &Ruby, tokens: &[u32]) -> Result<Vec<u8>, Error> {
        let bpe = self.bpe(ruby)?;
        bpe.decode_bytes(tokens).map_err(|e| {
            Error::new(
                ruby.exception_arg_error(),
                format!("Invalid token {} for {}.", e.token, self.encoding()),
            )
        })
    }

    // `Tokenizer#_decode(tokens)`. Bytes that aren't valid UTF-8 (a token slice that cuts
    // a multi-byte character) become U+FFFD, matching Python tiktoken's default
    // `errors="replace"`. Unknown token ids raise ArgumentError.
    fn decode(ruby: &Ruby, rb_self: &Self, tokens: Vec<u32>) -> Result<String, Error> {
        let bytes = rb_self.decode_to_bytes(ruby, &tokens)?;
        Ok(String::from_utf8_lossy(&bytes).into_owned())
    }

    // `Tokenizer#_decode_bytes(tokens)`: the exact bytes as a binary (ASCII-8BIT) String.
    fn decode_bytes(ruby: &Ruby, rb_self: &Self, tokens: Vec<u32>) -> Result<RString, Error> {
        let bytes = rb_self.decode_to_bytes(ruby, &tokens)?;
        Ok(ruby.str_from_slice(&bytes))
    }
}

// `Tokenizer._encoding_for(model)`: resolves a model or encoding name to the canonical
// encoding name, raising ArgumentError for unsupported models.
fn encoding_for(ruby: &Ruby, model: String) -> Result<&'static str, Error> {
    tokenizer_for(&model)
        .map(encoding_name)
        .ok_or_else(|| unsupported_model(ruby, &model))
}

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let module = ruby.define_module("JRRToken")?;
    let class = module.define_class("Tokenizer", ruby.class_object())?;
    // Instances are only created through `_build` (and handed out by `for_model`).
    class.undef_default_alloc_func();
    class.define_singleton_method("_build", function!(RbTokenizer::build, 1))?;
    class.define_singleton_method("_encoding_for", function!(encoding_for, 1))?;
    class.define_private_method("_count", method!(RbTokenizer::count, 1))?;
    class.define_private_method("_encode", method!(RbTokenizer::encode, 1))?;
    class.define_private_method("_decode", method!(RbTokenizer::decode, 1))?;
    class.define_private_method("_decode_bytes", method!(RbTokenizer::decode_bytes, 1))?;
    Ok(())
}
