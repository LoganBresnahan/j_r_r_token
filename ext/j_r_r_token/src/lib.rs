use std::{collections::HashSet, sync::OnceLock};

use magnus::{function, Error, Ruby};
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

// Returns the special tokens allowed when counting (all of the encoding's special
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

// This function is exposed to Ruby.
fn count_tokens(ruby: &Ruby, model: String, text: String) -> Result<usize, Error> {
    let tokenizer = tokenizer_for(&model).ok_or_else(|| {
        Error::new(
            ruby.exception_arg_error(),
            format!("Model '{}' not supported.", model),
        )
    })?;

    // `bpe_for_tokenizer` returns a process-wide `&'static CoreBPE` singleton, so the
    // vocabulary is decoded and the regexes are compiled once per encoding, not on
    // every call. It currently never returns `Err` (a failed build panics inside
    // tiktoken-rs's lazy static); the `map_err` only guards against future changes.
    let bpe = bpe_for_tokenizer(tokenizer)
        .map_err(|e| Error::new(ruby.exception_runtime_error(), e.to_string()))?;

    // `count` (unlike `count_with_special_tokens`) reports tokenizer regex failures as an
    // error instead of panicking, so Ruby gets a RuntimeError rather than `fatal`.
    bpe.count(&text, allowed_special(tokenizer, bpe))
        .map_err(|e| Error::new(ruby.exception_runtime_error(), e.to_string()))
}

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let module = ruby.define_module("JRRToken")?;
    module.define_module_function("count_tokens", function!(count_tokens, 2))?;
    Ok(())
}
