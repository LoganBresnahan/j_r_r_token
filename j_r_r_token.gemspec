# frozen_string_literal: true

require_relative "lib/j_r_r_token/version"

Gem::Specification.new do |spec|
  spec.name = "j_r_r_token"
  spec.version = JRRToken::VERSION
  spec.authors = ["Logan Bresnahan"]
  spec.email = ["loganbbres@gmail.com"]

  spec.summary = "Ruby wrapper for the tiktoken Rust library, providing fast tokenization for OpenAI models."
  spec.description = "JRRToken is a Ruby gem that wraps the tiktoken Rust library, enabling fast and efficient tokenization for OpenAI models. It supports multiple models including o200k_base, cl100k_base, p50k_base, p50k_edit, and r50k_base."
  spec.homepage = "https://github.com/LoganBresnahan/j_r_r_token"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"
  spec.required_rubygems_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.extensions = ["ext/j_r_r_token/Cargo.toml"]

  # Development dependencies are managed here for the gem.
  spec.add_development_dependency "bundler", ">= 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rake-compiler"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
