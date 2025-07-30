# frozen_string_literal: true

# This line ensures all gems from your Gemfile are loaded and available.
require "bundler/setup"
require "rake/clean"
require "rake/extensiontask"

# Load the gemspec file to pass it to the extension task.
# This is the standard practice and provides more context to rake-compiler.
spec = Gem::Specification.load("ru_token.gemspec")

# This is the only task needed now. It defines how to compile the
# native extension on whatever machine is currently running the build.
Rake::ExtensionTask.new("ru_token", spec) do |ext|
  ext.lib_dir = "lib/ru_token"
end

# The default task remains a standard local compile.
task default: %w[compile]
