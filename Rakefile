# frozen_string_literal: true

require "bundler/setup"
require "rake/clean"
require "rake/extensiontask"
require "rspec/core/rake_task"

spec = Gem::Specification.load("ru_token.gemspec")

Rake::ExtensionTask.new("ru_token", spec) do |ext|
  ext.lib_dir = "lib/ru_token"
end

# Define a task to run your specs
RSpec::Core::RakeTask.new(:spec)

# Make the 'spec' task depend on the 'compile' task
task spec: :compile

# Set the default task to run specs
task default: :spec
