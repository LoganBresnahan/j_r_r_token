use magnus::{function, Error, Ruby};
use tiktoken_rs::{
    bpe_for_tokenizer,
    tokenizer::{get_tokenizer, Tokenizer},
};

// Resolves a model name (or bare encoding name) to a tokenizer.
// Model -> tokenizer dispatch is delegated to `tiktoken_rs::tokenizer::get_tokenizer`,
// which is kept in sync with upstream OpenAI tiktoken. It handles `ft:` prefix
// stripping, GPT-5/4.5/4.1/4o families, o1/o3/o4 reasoning models, gpt-oss
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

    Ok(bpe.count_with_special_tokens(&text))
}

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let module = ruby.define_module("JRRToken")?;
    module.define_module_function("count_tokens", function!(count_tokens, 2))?;
    Ok(())
}
