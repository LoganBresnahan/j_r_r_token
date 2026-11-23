use std::{collections::HashSet, sync::OnceLock};

use magnus::{function, method, prelude::*, Error, RString, Ruby};
use regex::Regex;
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
    SETS[cache_slot(tokenizer)].get_or_init(|| bpe.special_tokens())
}

// Matches any of the encoding's special tokens, for `special_tokens: :raise`. Built once
// per encoding. Longest tokens come first so an overlapping match reports the full token.
// (The regex crate compiles a literal alternation like this to an Aho-Corasick search.)
fn special_token_regex(tokenizer: Tokenizer, bpe: &'static CoreBPE) -> &'static Regex {
    static REGEXES: [OnceLock<Regex>; 6] = [const { OnceLock::new() }; 6];
    REGEXES[cache_slot(tokenizer)].get_or_init(|| {
        let mut tokens: Vec<&str> = allowed_special(tokenizer, bpe).iter().copied().collect();
        tokens.sort_by(|a, b| b.len().cmp(&a.len()).then(a.cmp(b)));
        let pattern = tokens
            .iter()
            .map(|token| regex::escape(token))
            .collect::<Vec<_>>()
            .join("|");
        Regex::new(&pattern).expect("special token alternation is a valid regex")
    })
}

// Per-encoding cache index. Gpt2 resolves to the same r50k_base singleton.
fn cache_slot(tokenizer: Tokenizer) -> usize {
    match tokenizer {
        Tokenizer::O200kHarmony => 0,
        Tokenizer::O200kBase => 1,
        Tokenizer::Cl100kBase => 2,
        Tokenizer::P50kBase => 3,
        Tokenizer::P50kEdit => 4,
        Tokenizer::R50kBase | Tokenizer::Gpt2 => 5,
    }
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

    // Encodes `text`. With `allow_special`, special-token strings (e.g. "<|endoftext|>")
    // become their special token ids; otherwise they're encoded as ordinary text.
    //
    // Both paths use the fallible `CoreBPE::encode` (with an empty allowed set for plain
    // text) rather than `encode_with_special_tokens` / `encode_ordinary`, which unwrap
    // tokenizer regex failures and would panic (Ruby `fatal`) on pathological input.
    fn encode_ranks(&self, ruby: &Ruby, text: &str, allow_special: bool) -> Result<Vec<u32>, Error> {
        let bpe = self.bpe(ruby)?;
        let none = HashSet::new();
        let allowed = if allow_special {
            allowed_special(self.tokenizer, bpe)
        } else {
            &none
        };
        bpe.encode(text, allowed)
            .map(|(tokens, _)| tokens)
            .map_err(|e| Error::new(ruby.exception_runtime_error(), e.to_string()))
    }

    // `Tokenizer#_count(text, allow_special)`
    fn count(ruby: &Ruby, rb_self: &Self, text: String, allow_special: bool) -> Result<usize, Error> {
        rb_self.encode_ranks(ruby, &text, allow_special).map(|tokens| tokens.len())
    }

    // `Tokenizer#_encode(text, allow_special)`
    fn encode(
        ruby: &Ruby,
        rb_self: &Self,
        text: String,
        allow_special: bool,
    ) -> Result<Vec<u32>, Error> {
        rb_self.encode_ranks(ruby, &text, allow_special)
    }

    // `Tokenizer#_split(text, allow_special)`: the text of each token, 1:1 with `encode`.
    // Bytes of a multi-byte character split across tokens (common for emoji and CJK) can't
    // be shown on their own, so they become U+FFFD; use encode + decode_bytes for exact
    // bytes.
    fn split(
        ruby: &Ruby,
        rb_self: &Self,
        text: String,
        allow_special: bool,
    ) -> Result<Vec<String>, Error> {
        let tokens = rb_self.encode_ranks(ruby, &text, allow_special)?;
        tokens
            .iter()
            .map(|token| {
                rb_self
                    .decode_to_bytes(ruby, std::slice::from_ref(token))
                    .map(|bytes| String::from_utf8_lossy(&bytes).into_owned())
            })
            .collect()
    }

    // `Tokenizer#_find_special(text)`: the first special-token string in `text`, or nil.
    fn find_special(ruby: &Ruby, rb_self: &Self, text: String) -> Result<Option<String>, Error> {
        let bpe = rb_self.bpe(ruby)?;
        Ok(special_token_regex(rb_self.tokenizer, bpe)
            .find(&text)
            .map(|m| m.as_str().to_owned()))
    }

    // `Tokenizer#_truncate(text, max_tokens, allow_special)`: `text` cut at a token
    // boundary, i.e. the text of the first `max_tokens` tokens of its encoding (the
    // `decode(encode(text)[..n])` idiom). This is not necessarily the longest prefix that
    // fits: a slightly longer prefix can sometimes re-encode within budget, but finding it
    // would need a character-level search (token count isn't monotonic in prefix length).
    // Cost is one full encode of `text`, plus a re-encode of the result.
    //
    // Decoding the first `max_tokens` tokens yields a byte prefix of `text`; if the cut
    // lands inside a multi-byte character, the partial character is dropped so the result
    // is valid UTF-8. BPE boundaries can shift when a prefix is re-encoded, so the result
    // is re-counted and shortened one token at a time until it fits; this guarantees
    // `count(result) <= max_tokens`. It's almost always a single pass.
    fn truncate(
        ruby: &Ruby,
        rb_self: &Self,
        text: String,
        max_tokens: usize,
        allow_special: bool,
    ) -> Result<String, Error> {
        let tokens = rb_self.encode_ranks(ruby, &text, allow_special)?;
        if tokens.len() <= max_tokens {
            return Ok(text);
        }
        let mut keep = max_tokens;
        loop {
            let bytes = rb_self.decode_to_bytes(ruby, &tokens[..keep])?;
            let valid_len = match std::str::from_utf8(&bytes) {
                Ok(_) => bytes.len(),
                Err(e) => e.valid_up_to(),
            };
            // A prefix of the decoded token bytes is a prefix of `text` (tokens concatenate
            // to the original bytes), so slicing `text` keeps the caller's exact characters.
            let prefix = text.get(..valid_len).ok_or_else(|| {
                Error::new(
                    ruby.exception_runtime_error(),
                    "truncate: decoded tokens are not a prefix of the input text",
                )
            })?;
            if keep == 0 || rb_self.encode_ranks(ruby, prefix, allow_special)?.len() <= max_tokens {
                return Ok(prefix.to_owned());
            }
            keep -= 1;
        }
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

// `JRRToken.context_size(model)`: the model's context window in tokens, from tiktoken-rs's
// model table, or nil if the model isn't in it. Accepts `ft:` fine-tune names.
fn context_size(model: String) -> Option<usize> {
    tiktoken_rs::model::get_context_size(&model)
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
    module.define_singleton_method("context_size", function!(context_size, 1))?;
    let class = module.define_class("Tokenizer", ruby.class_object())?;
    // Instances are only created through `_build` (and handed out by `for_model`).
    class.undef_default_alloc_func();
    class.define_singleton_method("_build", function!(RbTokenizer::build, 1))?;
    class.define_singleton_method("_encoding_for", function!(encoding_for, 1))?;
    class.define_private_method("_count", method!(RbTokenizer::count, 2))?;
    class.define_private_method("_encode", method!(RbTokenizer::encode, 2))?;
    class.define_private_method("_find_special", method!(RbTokenizer::find_special, 1))?;
    class.define_private_method("_truncate", method!(RbTokenizer::truncate, 3))?;
    class.define_private_method("_split", method!(RbTokenizer::split, 2))?;
    class.define_private_method("_decode", method!(RbTokenizer::decode, 1))?;
    class.define_private_method("_decode_bytes", method!(RbTokenizer::decode_bytes, 1))?;
    Ok(())
}
