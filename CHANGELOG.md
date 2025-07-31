# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
