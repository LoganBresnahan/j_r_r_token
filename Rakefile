# frozen_string_literal: true

# require "rspec/core/rake_task"

# RSpec::Core::RakeTask.new(:spec)

require "bundler/gem_tasks"
require "rake/clean"
require "rake/extensiontask"

# This is the task for local development and for CI runners
# that build natively (like macOS).
Rake::ExtensionTask.new("ru_token") do |ext|
  ext.lib_dir = "lib/ru_token"
end

# This block defines the cross-compilation tasks in a more robust way.
begin
  require "rake_compiler_dock"

  Rake::CompilerDock.new("ru_token") do |t|
    # Set the platforms to build for.
    t.platforms = [
      "x86_64-linux",
      "aarch64-linux",
      "x64-mingw-ucrt"
    ]
  end

  # Define a simple alias task for the workflow to call.
  # This makes the workflow file cleaner.
  task "cross-compile" => "cross:ru_token"
rescue LoadError
  puts "rake-compiler-dock not installed. Cross-compilation tasks will not be available."
end


# This helper task is used by rake-compiler-dock.
task :native do
  Rake::Task["compile:ru_token"].invoke
end

# The default task remains a standard local compile.
task default: %w[compile]
