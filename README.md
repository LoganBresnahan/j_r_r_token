<p align="center">
  <img src="https://github.com/LoganBresnahan/j_r_r_token/raw/main/.github/assets/rings.png" height="120px" alt="JRRToken" />
</p>

<h1 align="center">JRRToken</h1>
<h2 align="center">v2.0.0</h2>

<p align="center">(Just Ruby, Rust, &amp; Tokens)</p>

---

JRRToken provides a high-performance, native Ruby interface to OpenAI's tokenizers using the powerful [tiktoken-rs](https://github.com/zurawiki/tiktoken-rs) library. Count, encode, decode, split and truncate text, and estimate chat prompt sizes, for all modern and legacy OpenAI models, with the speed of Rust.

The gem ships with pre-compiled native extensions for Linux and macOS, so your end-users don't need a Rust toolchain installed. On other platforms the gem builds from source, which requires Rust >= 1.85.

Supports Ruby >= 3.0.0

Extensive Model Support: Includes tokenizers for all modern and legacy OpenAI models, recognizing dozens of model aliases automatically.

[https://rubygems.org/gems/j_r_r_token](https://rubygems.org/gems/j_r_r_token)

## Install

#### Gemfile
`gem 'j_r_r_token', '~> 2.0'`

#### Command Line
`gem install j_r_r_token -v '~> 2.0'`

Upgrading from 1.x? See [Upgrading to 2.0](#upgrading-to-20).

## Use

### Count tokens (the model keyword is required)
```Ruby
JRRToken::Tokenizer.count("hello world!", model: "gpt-5.4")  # => 3
```

### Get a tokenizer for a model
`for_model` accepts a model name (including fine-tunes like `ft:gpt-4o:org:name:id`) or a bare encoding name like `"o200k_base"`. Models that share an encoding return the same frozen instance, which is cheap to fetch and safe to share across threads.

```Ruby
tok = JRRToken::Tokenizer.for_model("gpt-4o")  # => #<JRRToken::Tokenizer o200k_base>
tok.encoding                                   # => "o200k_base"
tok.count("hello world!")                      # => 3
tok.encode("hello world!")                     # => [24912, 2375, 0]
tok.decode([24912, 2375, 0])                   # => "hello world!"
tok.split("hello world!")                      # => ["hello", " world", "!"]
tok.truncate("The quick brown fox jumps over the lazy dog.", max_tokens: 5)
# => "The quick brown fox jumps"
```

Every instance method also has a class-level shortcut that takes `model:`, e.g. `JRRToken::Tokenizer.encode("hello", model: "gpt-4o")`.

- `decode` replaces bytes that don't form valid UTF-8 (a token slice that cuts a character in half) with U+FFFD, like Python tiktoken. `decode_bytes` returns the exact bytes as a binary String instead.
- `split` returns the text of each token, 1:1 with `encode`. Pieces of a character split across tokens (common for emoji and CJK) show as U+FFFD.
- `truncate` cuts at a token boundary: the result is always a prefix of the input, valid UTF-8, and at most `max_tokens` tokens. Like tiktoken's `decode(encode(text)[:n])`, it isn't necessarily the longest prefix that fits.

### Special tokens
Encodings reserve strings like `<|endoftext|>` as control tokens. `count`, `encode`, `truncate` and `split` take `special_tokens:` to decide what happens when they appear in your text:

| Mode | Behavior |
| --- | --- |
| `:text` (default) | Treat them as ordinary text. Right for user-supplied input. |
| `:allow` | Encode them as single special tokens. |
| `:raise` | Raise `JRRToken::SpecialTokenError` (an `ArgumentError`), naming the token. Python tiktoken's default. |

```Ruby
tok.count("<|endoftext|>")                          # => 7
tok.count("<|endoftext|>", special_tokens: :allow)  # => 1
```

### Count tokens in a chat conversation
`count_messages` estimates the prompt tokens for a list of chat messages, including the framing tokens each message adds, using OpenAI's cookbook formula (the same as tiktoken-rs's `num_tokens_from_messages`). Messages are OpenAI-shaped Hashes with String or Symbol keys.

```Ruby
messages = [
  { role: "system", content: "You are a helpful assistant." },
  { role: "user", content: "What is the capital of France?" }
]
JRRToken.count_messages(messages, model: "gpt-4o")  # => 24
```

It's an estimate: tool definitions and image, audio and file content aren't counted. Only chat-model encodings (`o200k_base`, `o200k_harmony`, `cl100k_base`) are supported.

### Context window sizes
```Ruby
JRRToken.context_size("gpt-4o")   # => 128000
JRRToken.context_size("unknown")  # => nil
```

Values come from tiktoken-rs's model table as-is, so they can be stale for some models.

### Text input
Text is converted with `to_s`, so `JRRToken::Tokenizer.count(1234, model: "o200k_base")` works. Binary (ASCII-8BIT) strings, such as those from `File.binread` or HTTP bodies, and US-ASCII strings holding non-ASCII bytes (what `File.read` returns when no locale is set, e.g. in a Docker image without `LANG`), are read as UTF-8 when their bytes are valid UTF-8. Other encodings are transcoded. Returned strings are UTF-8.

### Errors
- An unsupported model name raises `ArgumentError`, and a model that isn't a String raises `TypeError`.
- Text that isn't valid in its encoding raises `ArgumentError`.
- `special_tokens: :raise` raises `JRRToken::SpecialTokenError` when the text contains a special token.
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

## Upgrading to 2.0
- **Special tokens are plain text by default.** In 1.x, `count` encoded strings like `<|endoftext|>` as single special tokens. They now count as ordinary text (`<|endoftext|>` on gpt-4o: 1 token in 1.x, 7 in 2.0). Pass `special_tokens: :allow` to keep the 1.x behavior. Counts only change for text that contains special-token strings.
- **`JRRToken.count_tokens(model, text)` was removed.** Use `JRRToken::Tokenizer.count(text, model:)`.
- **`JRRToken::Tokenizer.new` is private.** Use `JRRToken::Tokenizer.for_model(model)`.
- **Invalid text raises `ArgumentError`** (1.x raised `EncodingError`), and binary or US-ASCII-labeled strings holding valid UTF-8 are now accepted.
- **A missing native extension raises `LoadError`** from `require "j_r_r_token"`. 1.x printed a warning and failed later.

`JRRToken::Tokenizer.count(text, model:)` otherwise works exactly as before.

## Performance and Memory
Each tokenizer is built the first time you use it (roughly 15–85 ms, depending on the encoding) and then cached for the life of the process, so later calls are fast. A cached tokenizer stays in memory: roughly 45 MB for `o200k_base` and `o200k_harmony`, 24 MB for `cl100k_base`, and 10 MB each for the older encodings. Only the encodings you actually use are loaded.

To keep that one-time cost out of your first request, warm up the encodings you use at boot:

```Ruby
# e.g. config/initializers/j_r_r_token.rb
JRRToken::Tokenizer.for_model("gpt-4o").count("")
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
