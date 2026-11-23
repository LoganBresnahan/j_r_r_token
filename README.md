<p align="center">
  <img src="https://github.com/LoganBresnahan/j_r_r_token/raw/main/.github/assets/rings.png" height="120px" alt="JRRToken" />
</p>

<h1 align="center">JRRToken</h1>
<h2 align="center">v1.3.0</h2>

<p align="center">(Just Ruby, Rust, &amp; Tokens)</p>

---

JRRToken provides a high-performance, native Ruby interface for counting tokens using the powerful [tiktoken-rs](https://github.com/zurawiki/tiktoken-rs) library. It leverages the speed of Rust to offer a fast and efficient way to calculate token counts for various OpenAI models.

The gem ships with pre-compiled native extensions for Linux and macOS, so your end-users don't need a Rust toolchain installed. On other platforms the gem builds from source, which requires Rust >= 1.85.

Supports Ruby >= 3.0.0

Extensive Model Support: Includes tokenizers for all modern and legacy OpenAI models, recognizing dozens of model aliases automatically.

[https://rubygems.org/gems/j_r_r_token](https://rubygems.org/gems/j_r_r_token)

## Install

#### Gemfile
`gem 'j_r_r_token', '~> 1.3'`

#### Command Line
`gem install j_r_r_token -v '~> 1.3'`

## Use

### Count tokens for a specific model (the model keyword is required)
```Ruby
count = JRRToken::Tokenizer.count("hello world!", model: "gpt-5.4")
```

### The gem recognizes many aliases, including older models
```Ruby
count = JRRToken::Tokenizer.count("hello world!", model: "text-davinci-003")
```

### The count method calls .to_s on the argument if it is not a string
```Ruby
count = JRRToken::Tokenizer.count(1234, model: "o200k_base")
```

### Errors
- An unsupported model name raises `ArgumentError`.
- A model that isn't a String (e.g. `nil` or a Symbol) raises `TypeError`.
- If the tokenizer itself fails on pathological input (for example, a whitespace run of roughly a million characters followed by text), the gem raises `RuntimeError`. When counting untrusted input, rescue it or cap the input size.

## Supported Models
The gem automatically maps dozens of model names and prefixes to the correct underlying tokenizer. You don't need to know the tokenizer's base name (e.g., cl100k_base); just use the model name you're working with. Model resolution is delegated to [`tiktoken-rs`](https://github.com/zurawiki/tiktoken-rs), so the alias list stays in sync with upstream.

- o200k_harmony Models (e.g., gpt-oss-20b, gpt-oss-120b)
- o200k_base Models (e.g., gpt-5.4, gpt-5-mini, gpt-4.5, gpt-4.1, gpt-4o, o1, o3, o4-mini, codex-mini)
- cl100k_base Models (e.g., gpt-4, gpt-3.5-turbo, text-embedding-3-small)
- p50k_base Models (e.g., text-davinci-003)
- r50k_base Models (e.g., gpt-2)
- p50k_edit Models

Fine-tuned models (`ft:<base>:org:name:id`) are automatically resolved to the same tokenizer as their base model.

## Performance and Memory
Each tokenizer is built the first time you use it (roughly 15–85 ms, depending on the encoding) and then cached for the life of the process, so later calls are fast. A cached tokenizer stays in memory: roughly 45 MB for `o200k_base` and `o200k_harmony`, 24 MB for `cl100k_base`, and 10 MB each for the older encodings. Only the encodings you actually use are loaded.

To keep that one-time cost out of your first request, warm up the encodings you use at boot:

```Ruby
# e.g. config/initializers/j_r_r_token.rb
JRRToken::Tokenizer.count("", model: "gpt-4o")
```

With a preforking server (Puma with `preload_app!`, Unicorn with `preload_app true`), warming up before the fork lets the workers share the tokenizer memory copy-on-write instead of each building its own.

## Developing JRRToken Locally

### Install Ruby and Rust dependencies
Ruby >= 3.0.0

RubyGems >= 3.0.0

Rust >= 1.85

### Compile the Rust extension and run tests
Compile:
`bundle exec rake compile`

Specs:
`bundle exec rake spec`

Both:
`bundle exec rake`

Interactive console for experimentation: `bin/console`

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/LoganBresnahan/j_r_r_token.

## License

The gem is available as open source under the terms of the MIT License.
