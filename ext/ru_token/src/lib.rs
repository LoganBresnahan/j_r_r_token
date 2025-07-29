use magnus::{define_module, exception, function, Error};
use tiktoken_rs::{cl100k_base, o200k_base, p50k_base, r50k_base, CoreBPE};

// This function now takes a model name and the text to encode.
fn count_tokens(model: String, text: String) -> Result<usize, Error> {
    // Select the tokenizer based on the model string.
    // We must map the error type for each arm to ensure they are all compatible.
    let bpe_result: Result<CoreBPE, Box<dyn std::error::Error>> = match model.as_str() {
        "o200k_base" => o200k_base().map_err(|e| e.into()),
        "cl100k_base" => cl100k_base().map_err(|e| e.into()),
        "p50k_base" => p50k_base().map_err(|e| e.into()),
        "r50k_base" => r50k_base().map_err(|e| e.into()),
        _ => {
            // If the model is not found, return a Ruby ArgumentError.
            let err_msg = format!("Model '{}' not supported.", model);
            return Err(Error::new(exception::arg_error(), err_msg));
        }
    };

    // Handle any potential errors from creating the tokenizer.
    let bpe = bpe_result.map_err(|e| Error::new(exception::runtime_error(), e.to_string()))?;

    let tokens = bpe.encode_with_special_tokens(&text);
    Ok(tokens.len())
}

#[magnus::init]
fn init() -> Result<(), Error> {
    let module = define_module("RuToken")?;
    // Update the function definition to reflect the new arity (2 arguments).
    module.define_module_function("count_tokens", function!(count_tokens, 2))?;
    Ok(())
}
