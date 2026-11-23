# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Breaking Change
- Removed the undocumented `JRRToken.count_tokens(model, text)` native entry point. Use `JRRToken::Tokenizer.count(text, model:)` or `JRRToken::Tokenizer.for_model(model).count(text)`.
- `JRRToken::Tokenizer` is now a native class whose instances are built only by `for_model`; `Tokenizer.new` and `Tokenizer.allocate` are private.
- Special-token strings in input text (e.g. `"<|endoftext|>"`) are now treated as **ordinary text by default** (`special_tokens: :text`), so untrusted input can't be counted as control tokens. In 1.x, `count` encoded them as single special tokens (`"<|endoftext|>"` on gpt-4o: 1 token in 1.x, 7 now). Pass `special_tokens: :allow` for the old behavior, or `:raise` to reject such input (Python tiktoken's default).

### New Functionality
- `JRRToken::Tokenizer.for_model(model)` returns a tokenizer instance for a model name or bare encoding name. Models that share an encoding return the same frozen instance (one per encoding), so instances are cheap to fetch and safe to share across threads.
- Instance methods: `#encoding` (e.g. `"o200k_base"`), `#count(text)`, `#encode(text)` (token ids) and `#decode(tokens)`. `decode` replaces bytes that don't form valid UTF-8 (a token slice cutting a multi-byte character) with U+FFFD, matching Python tiktoken's default, and raises `ArgumentError` for token ids not in the encoding.
- `special_tokens:` option on `count`, `encode` and `truncate` (and their class-level shortcuts): `:text` (default, plain text), `:allow` (encode as special tokens) or `:raise` (raise `JRRToken::SpecialTokenError`, a subclass of `ArgumentError`, naming the token found). All three modes use the error-reporting encode path, so the pathological-input case still raises `RuntimeError` rather than crashing.
- `#truncate(text, max_tokens:)` cuts `text` at a token boundary: the text of its first `max_tokens` tokens (fewer if needed to stay within budget), dropping a trailing character the cut would split. The result is always a prefix of the input, valid UTF-8, and `count(result)` (with the same `special_tokens:`) is guaranteed to be at most `max_tokens`. Like tiktoken's `decode(encode(text)[:n])` idiom, it is not necessarily the longest prefix that fits. Class shortcut: `Tokenizer.truncate(text, max_tokens:, model:)`.
- `#split(text)` returns the text of each token (e.g. `"hello world"` -> `["hello", " world"]`), honoring `special_tokens:`. A token's incomplete multi-byte character bytes are shown as U+FFFD, so joining the pieces doesn't always reproduce the text. Class shortcut: `Tokenizer.split(text, model:)`.
- `JRRToken.context_size(model)` returns the model's context window in tokens (e.g. `128_000` for `"gpt-4o"`), or `nil` if the model isn't in tiktoken-rs's table. Fine-tuned names resolve to their base model. Values come from tiktoken-rs's prefix-matched table as-is, so they can be stale or loose (e.g. bare `gpt-4-turbo` reports 8,192, `davinci-002` 2,049), and a name can have a context size without having a tokenizer (e.g. `gpt-6`, `o4`).
- `#decode_bytes(tokens)` returns the exact bytes as a binary (ASCII-8BIT) String, with nothing replaced, for callers that need byte-exact output or join several token slices before converting to UTF-8.
- Token ids passed to `decode` / `decode_bytes` must be Integers; other numerics (e.g. `1.5`) raise `TypeError`.
- Class-level shortcuts for the new methods: `Tokenizer.encode(text, model:)`, `Tokenizer.decode(tokens, model:)` and `Tokenizer.decode_bytes(tokens, model:)`, alongside the existing `Tokenizer.count(text, model:)`.

### Change
- If the native extension can't be loaded, `require "j_r_r_token"` now raises `LoadError` (with the underlying reason) instead of printing a warning and failing later with a confusing error.

---
## [1.3.0] - 2026-11-22
### Breaking Change
- Model mapping now matches OpenAI's tiktoken 0.14.0 exactly (via `tiktoken-rs` 0.12.1). `tiktoken-rs` 0.11 carried its own extra `o4` / `o4-*` mappings that OpenAI's tiktoken never had (it only maps `o4-mini`); 0.12 dropped them, so bare `o4` and `o4-pro` (any `o4-*` other than `o4-mini*`) now raise `ArgumentError`, as do fine-tunes of them (e.g. `ft:o4`). Use `o4-mini` or pass `o200k_base` directly.

### Fix
- A whitespace run of ~1M+ characters followed by text previously killed the process with an uncatchable `fatal` (a Rust panic). It now raises a regular `RuntimeError` ("Could not encode string: ..."), so apps counting untrusted input can rescue it.

### Change
- Bumped `tiktoken-rs` from 0.11.0 to 0.12.1, which vendors OpenAI's tiktoken 0.14.0 core.
- Following OpenAI's tiktoken 0.14.0, any model name beginning with `gpt-5` now resolves to `o200k_base` (previously only `gpt-5`, `gpt-5-*` and `gpt-5.*`).
- Long repetitive input no longer hits a quadratic slowdown: upstream's large-piece BPE merge brings 200 KB of `"a"` from ~15 s to well under a second. Counts are unchanged (verified against 0.11.0 across all encodings).
- The allowed special-token set is now built once per encoding instead of on every call; repeat `gpt-oss` (`o200k_harmony`, ~1,100 special tokens) counts are now on par with the other encodings.
- Building from source (the generic gem or `rake compile`) now requires Rust 1.85 or newer. Precompiled platform gems are unaffected.
- Tokenizers are now built once per process and cached (via `tiktoken_rs::bpe_for_tokenizer`) instead of being rebuilt on every `count` call. Previously each call decoded the full vocabulary and compiled the tokenizer regexes, costing ~20–120 ms per call depending on the encoding; repeat calls are now sub-millisecond for short text. The first call for each encoding still pays the one-time build cost.
- Memory tradeoff: each encoding, once used, now stays resident for the life of the process. Approximate RSS per encoding: `o200k_base` ~45 MB, `o200k_harmony` ~47 MB, `cl100k_base` ~24 MB, `p50k_base` / `p50k_edit` / `r50k_base` ~10 MB each. Only encodings you actually call are loaded.
- Bumped `magnus` from 0.8.2 to 0.8.5 (patch fixes). Staying on the 0.8 series, the last to support Ruby 3.0.
- Migrated the extension off magnus's deprecated "old-api" (global `define_module` / `exception::*`) to the `&Ruby` handle API and dropped the `old-api` feature flag. No behavior change.
- Bumped `rb_sys` (gem and crate) from 0.9.128 to 0.9.130. It still pins `rake-compiler-dock` 1.12.0, so Ruby 3.0 platform gems are unaffected.
- README: documented the `RuntimeError` case, the one-time build cost and memory per encoding (with a boot-time warm-up tip for preforking servers), and the Rust >= 1.85 requirement for source builds.
- Gemspec description now lists `o200k_harmony`; added RBS signatures for `JRRToken::Tokenizer.count`.
- CI: the cross-gem matrix is now an explicit allowlist of the seven platforms this gem ships (`aarch64-linux`, `aarch64-linux-musl`, `arm-linux`, `arm64-darwin`, `x86_64-darwin`, `x86_64-linux`, `x86_64-linux-musl`) instead of an exclude list. The platform list comes from rb-sys `main` at release time, so new rb-sys targets (e.g. `arm-linux-musl`, added in 0.9.130) previously slipped into the release matrix; adding a platform is now a deliberate edit.
- CI: test jobs pin `ubuntu-24.04` instead of `ubuntu-latest`. Ruby 3.2.11's ubuntu-26.04 build (from ruby/ruby-builder, compiled with GCC 15 in C23 mode) lacks `HAVE_STDBOOL_H` in its `config.h`, so rb-sys's bindgen step fails with "unknown type name 'bool'". Other Ruby versions on that image, and Ruby 3.2 on the ARM Linux and macOS runners, were unaffected.

---
## [1.2.1] - 2026-05-13
### Breaking Change
- Minimum Ruby version raised from 2.7.0 to 3.0.0. Ruby 2.7 has been EOL since March 2023 and is no longer supported by upstream `rake-compiler-dock` (1.11.0+) which `rb_sys` uses for cross-compiling native gems. Production environments on Ruby 3.0+ are unaffected.

### New Functionality
- Added `o200k_harmony` tokenizer with support for `gpt-oss-20b` and `gpt-oss-120b`.
- Added support for additional model aliases now recognized by `tiktoken-rs` 0.11: `gpt-5-mini`, `gpt-5-nano`, `gpt-5.x` decimal variants (e.g. `gpt-5.4`, `gpt-5.4-pro`, `gpt-5.2-codex`), `gpt-4.5-*`, `o1`, `o3`, `o4-mini`, `codex-mini`, `codex-mini-latest`, and `ft:gpt-5` fine-tunes.
- Fine-tuned model resolution (`ft:` prefix) is now handled natively by the upstream `get_tokenizer` mapping, so any future ft: bases are picked up automatically.

### Change
- Bumped `tiktoken-rs` from 0.7 to 0.11.
- Bumped `magnus` from 0.6 to 0.8 (with the `old-api` feature enabled to preserve current bindings). Still supports Ruby >= 3.0.
- Refactored Rust model dispatch to delegate to `tiktoken_rs::tokenizer::get_tokenizer` instead of maintaining a parallel alias list. The gem now stays in sync with upstream OpenAI tiktoken automatically on each `tiktoken-rs` bump.
- CI matrix trimmed: dropped deprecated `macos-13`; consolidated to `ubuntu-latest`, `ubuntu-24.04-arm`, `macos-latest`, `macos-15-intel`. Added Ruby 4.0 to both test and cross-gem builds.

---
## [1.2.0] - 2026-05-13
### Note
- Partial release. The `arm-linux` cross-compile leg failed because upstream `rake-compiler-dock` 1.11.0+ dropped Ruby 2.7, so the published artifact set is incomplete. Please use 1.2.1 instead, which drops Ruby 2.7 from the support matrix and ships a complete set of platform gems.

---
## [1.1.0] - 2025-08-26
### New Functionality
- Added support for the `gpt-5` model name, which maps to the `o200k_base` tokenizer model.

#### New contributors
- [8edaf40](https://github.com/LoganBresnahan/j_r_r_token/commit/8edaf4021dae4ae41dcfa53fa5fb0fe61d9b0b9c) by [jordanmoore753](https://github.com/jordanmoore753)
- [a9738c7](https://github.com/LoganBresnahan/j_r_r_token/commit/a9738c7f0d4e7e691af8b8219e89d09b4a3367c0) by [lsysophia](https://github.com/lsysophia)

---
## [1.0.4] - 2025-08-01
### Change
- Bump version for RubyGems.

---
## [1.0.3] - 2025-08-01
### Fix
- Add Cargo files back to the gemspec.
### Change
- Adjust specs.

---
## [1.0.2] - 2025-08-01
### Change
- Refine Model Prefix Matching so 4 and 4* match to the correct Core BPE.

---
## [1.0.1] - 2025-08-01
### Change
- Slim down gem by removing unnecessary files defined in the gemspec.
- Refine Model Prefix Matching so 4 and 4* match to the correct Core BPE.

---
## [1.0.0] - 2025-08-01
### Breaking Change
- Rename Gem from ru_token (RuToken) to j_r_r_token (JRRToken).
- The ru_token gem will be patched with a deprecation notice.
- Bumping the version to 1.0.0 to symbolize the gem is now in a stable state.

---
## [0.1.20] - 2025-07-31
### Change
- Remove x64-mingw32 from Gemfile.lock
- Update README

---
## [0.1.19] - 2025-07-31
### No Change
- Bumping to retry RubyGems deploy

---
## [0.1.18] - 2025-07-31
### Change
- Update README

---
## [0.1.17] - 2025-07-31
### Change
- Update gemspec license entry
- Remove platform x64-mingw-ucrt from Gemfile.lock

---
## [0.1.16] - 2025-07-31
### Change
- Update license to MIT

---
## [0.1.15] - 2025-07-31
### Fix
- Stable ruby version build syntax
- Add ruby versions manual list for build

---
## [0.1.14] - 2025-07-31
### Fix
- Stable ruby version build syntax

---
## [0.1.13] - 2025-07-31
### Fix
- Stable ruby version build syntax

---
## [0.1.12] - 2025-07-31
### Fix
- Set stable ruby versions manually.
- Test macos-14 and macos-15

---
## [0.1.11] - 2025-07-31
### Fix
- Set stable ruby versions to default in build.

---
## [0.1.10] - 2025-07-31
### Fix
- Add stable ruby versions to ci data step in build.

---
## [0.1.9] - 2025-07-31
### Fix
- Add required ruby version to build and deploy.

---
## [0.1.8] - 2025-07-30
### Fix
- Correct loading paths for native gem versions.

---
## [0.1.7] - 2025-07-30
### Changed
- Add Generic Gem Build.

---
## [0.1.6] - 2025-07-30
### Changed
- Change build process to rely on Oxidize.

---
## [0.1.5] - 2025-07-30
### Changed
- Update Deploy Process for PKG gem names.

---
## [0.1.4] - 2025-07-30
### Changed
- Removed test runners from release process.

---
## [0.1.3] - 2025-07-30
### Changed
- Update release process to properly pre-compile native gems.

---
## [0.1.2] - 2025-07-30

### Changed
- Revamped the Linux publishing workflow to use the `oxidize-rb/actions/cross-gem` action. This produces highly portable "fat" gems for Linux, resulting in several key improvements:
  - Pre-compiled gems are now provided for both `glibc` (standard Linux) and `musl` (Alpine Linux) systems.
  - Both Intel (`x86_64`) and ARM (`aarch64`) architectures are now supported for both `glibc` and `musl`.
  - Linux gems are now compatible with a much wider range of distributions, including older enterprise versions.

---
## [0.1.1] - 2025-07-30

### Added
- Comprehensive RSpec test suite to validate token counts across all supported models.
- GitHub Actions workflow for continuous integration to automatically test against multiple Ruby versions and operating systems.
- Standard `rake release` task for simplified and automated gem publishing.

### Changed
- Updated README with accurate usage examples and a complete, collapsible list of supported model aliases.
- Improved the default `rake` task to automatically compile the extension and run tests.

### Fixed
- Corrected expected token counts in tests to match the `tiktoken-rs` library's actual output.

---
## [0.1.0] - 2025-07-29

### Added
- Initial release of the `RuToken` gem.
- Core functionality to count tokens for OpenAI models using a native Rust extension.
