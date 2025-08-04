use magnus::{define_module, exception, function, Error};
use tiktoken_rs::{cl100k_base, o200k_base, p50k_base, p50k_edit, r50k_base, CoreBPE};

// Helper function to get the correct tokenizer based on the model name.
// This logic is adapted from the tiktoken-rs library.
fn get_bpe_from_model(model: &str) -> Result<CoreBPE, Error> {
    let tokenizer = match model {
        // --- O200k Base Models ---
        "o200k_base" | "gpt-4.1" | "chatgpt-4o-latest" | "gpt-4o" => o200k_base(),
        // --- Cl100k Base Models ---
        "cl100k_base" | "gpt-4" | "gpt-3.5-turbo" | "gpt-3.5" | "gpt-35-turbo"
        | "davinci-002" | "babbage-002" | "text-embedding-ada-002"
        | "text-embedding-3-small" | "text-embedding-3-large" => cl100k_base(),
        // --- P50k Base Models ---
        "p50k_base" | "text-davinci-003" | "text-davinci-002" | "code-davinci-002"
        | "code-davinci-001" | "code-cushman-002" | "code-cushman-001"
        | "davinci-codex" | "cushman-codex" => p50k_base(),
        // --- R50k Base (GPT-2) Models ---
        "r50k_base" | "gpt2" | "gpt-2" | "text-davinci-001" | "text-curie-001"
        | "text-babbage-001" | "text-ada-001" | "davinci" | "curie" | "babbage" | "ada"
        | "text-similarity-davinci-001" | "text-similarity-curie-001"
        | "text-similarity-babbage-001" | "text-similarity-ada-001"
        | "text-search-davinci-doc-001" | "text-search-curie-doc-001"
        | "text-search-babbage-doc-001" | "text-search-ada-doc-001"
        | "code-search-babbage-code-001" | "code-search-ada-code-001" => r50k_base(),
        // --- P50k Edit Models ---
        "p50k_edit" | "text-davinci-edit-001" | "code-davinci-edit-001" => p50k_edit(),
        // --- Fallback for Prefixes ---
        _ => {
            let o200k_prefixes = [
                "o1-", "o3-", "o4-", "gpt-4.1-", "chatgpt-4o-", "gpt-4o-", "ft:gpt-4o"
            ];

            let cl100k_prefixes = [
                "gpt-4-", "gpt-3.5-turbo-", "gpt-35-turbo-", "ft:gpt-4:",
                "ft:gpt-4-", "ft:gpt-3.5-turbo", "ft:davinci-002", "ft:babbage-002",
            ];

            let cl100k_exacts = [
                "ft:gpt-4"
            ];

            if o200k_prefixes.iter().any(|prefix| model.starts_with(prefix)) {
                o200k_base()
            } else if cl100k_prefixes.iter().any(|prefix| model.starts_with(prefix)) || cl100k_exacts.iter().any(|exact| model == *exact) {
                cl100k_base()
            } else {
                let err_msg = format!("Model '{}' not supported.", model);
                return Err(Error::new(exception::arg_error(), err_msg));
            }
        }
    };
    tokenizer.map_err(|e| Error::new(exception::runtime_error(), e.to_string()))
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
