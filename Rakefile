# frozen_string_literal: true

require "bundler/gem_tasks"
# require "rspec/core/rake_task"

# RSpec::Core::RakeTask.new(:spec)

require "rake/clean"
require "rake_compiler_dock"

# This line loads the necessary task definition for native extensions.
require "rake/extensiontask"

# This is the task for local development and for CI runners
# that build natively (like macOS).
Rake::ExtensionTask.new("ru_token") do |ext|
  ext.lib_dir = "lib/ru_token"
end

# This is the main cross-compilation task for CI runners
# that use Docker (Linux and Windows).
task "cross-compile" do
  # These platforms will be built using rake-compiler-dock
  platforms = [
    "x86_64-linux",
    "aarch64-linux",
    "x64-mingw-ucrt"
  ]

  platforms.each do |platform|
    Rake::Task["cross:#{platform}"].invoke
  end
end

# This helper task is used by rake-compiler-dock.
task :native do
  Rake::Task["compile:ru_token"].invoke
end

# The default task remains a standard local compile.
task default: %w[compile]
