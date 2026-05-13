use magnus::{define_module, exception, function, Error};
use tiktoken_rs::{
    cl100k_base, o200k_base, o200k_harmony, p50k_base, p50k_edit, r50k_base,
    tokenizer::{get_tokenizer, Tokenizer},
    CoreBPE,
};

// Resolves a model name (or bare encoding name) to a CoreBPE instance.
// Model -> tokenizer dispatch is delegated to `tiktoken_rs::tokenizer::get_tokenizer`,
// which is kept in sync with upstream OpenAI tiktoken. It handles `ft:` prefix
// stripping, GPT-5/4.5/4.1/4o families, o1/o3/o4 reasoning models, gpt-oss
// (harmony), codex-mini, and all legacy aliases.
fn get_bpe_from_model(model: &str) -> Result<CoreBPE, Error> {
    let tokenizer_result = match model {
        // Bare encoding names — callers may pass these directly.
        "o200k_harmony" => o200k_harmony(),
        "o200k_base" => o200k_base(),
        "cl100k_base" => cl100k_base(),
        "p50k_base" => p50k_base(),
        "p50k_edit" => p50k_edit(),
        "r50k_base" => r50k_base(),
        _ => match get_tokenizer(model) {
            Some(Tokenizer::O200kHarmony) => o200k_harmony(),
            Some(Tokenizer::O200kBase) => o200k_base(),
            Some(Tokenizer::Cl100kBase) => cl100k_base(),
            Some(Tokenizer::P50kBase) => p50k_base(),
            Some(Tokenizer::P50kEdit) => p50k_edit(),
            Some(Tokenizer::R50kBase) | Some(Tokenizer::Gpt2) => r50k_base(),
            None => {
                return Err(Error::new(
                    exception::arg_error(),
                    format!("Model '{}' not supported.", model),
                ));
            }
        },
    };
    tokenizer_result.map_err(|e| Error::new(exception::runtime_error(), e.to_string()))
}

// This function is exposed to Ruby.
fn count_tokens(model: String, text: String) -> Result<usize, Error> {
    let bpe = get_bpe_from_model(&model)?;
    let tokens = bpe.encode_with_special_tokens(&text);
    Ok(tokens.len())
}

#[magnus::init]
fn init() -> Result<(), Error> {
    let module = define_module("JRRToken")?;
    module.define_module_function("count_tokens", function!(count_tokens, 2))?;
    Ok(())
}
