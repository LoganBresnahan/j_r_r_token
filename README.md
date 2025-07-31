# RuToken 🦕
RuToken provides a high-performance, native Ruby interface for counting tokens using the powerful [tiktoken-rs](https://github.com/zurawiki/tiktoken-rs) library. It leverages the speed of Rust to offer a fast and efficient way to calculate token counts for various OpenAI models.

The gem ships with pre-compiled native extensions for Linux and macOS, so your end-users don't need a Rust toolchain installed.

Supports Ruby >= 2.7.0

Features
High Performance ⚡️: Uses a native Rust implementation for blazing-fast tokenization.

Simple API: A clean and straightforward interface for counting tokens.

Extensive Model Support: Includes tokenizers for all modern and legacy OpenAI models, recognizing dozens of model aliases automatically.

### Count tokens for a specific model (the model keyword is required)
```Ruby
count = RuToken::Tokenizer.count("hello world!", model: "gpt-4.1")
```

### The gem recognizes many aliases, including older models
```Ruby
count = RuToken::Tokenizer.count(1234, model: "text-davinci-003")
```

### The count method calls .to_s on the argument if it is not a string
```Ruby
count = RuToken::Tokenizer.count(1234, model: "o200k_base")
```

If you provide an unsupported model name, the gem will raise an ArgumentError.

## Supported Models
The gem automatically maps dozens of model names and prefixes to the correct underlying tokenizer. You don't need to know the tokenizer's base name (e.g., cl100k_base); just use the model name you're working with.

- o200k_base Models (e.g., GPT-4o)
- cl100k_base Models (e.g., GPT-4, GPT-3.5)
- p50k_base Models (e.g., text-davinci-003)
- r50k_base Models (e.g., GPT-2)
- p50k_edit Models

## Developing RuToken Locally

### Install Ruby and Rust dependencies
Ruby >= 2.7.0

RubyGems >= 3.0.0

Rust edtion 2021

### Compile the Rust extension and run tests
Compile:
`bundle exec rake compile`

Specs:
`bundle exec rake spec`

Both:
`bundle exec rake`

You can open an interactive console for experimentation with bin/console.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/LoganBresnahan/ru_token.

## License

The gem is available as open source under the terms of the MIT License.
