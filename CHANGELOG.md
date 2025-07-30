# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
