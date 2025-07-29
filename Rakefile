# frozen_string_literal: true

# This line ensures all gems from your Gemfile are loaded and available.
require "bundler/setup"

require "bundler/gem_tasks"
require "rake/clean"
require "rake/extensiontask"

# Define the extension task and store it in a variable.
ext_task = Rake::ExtensionTask.new("ru_token") do |ext|
  ext.lib_dir = "lib/ru_token"
  ext.cross_compile = true
  ext.cross_platform = [
    "x86_64-linux",
    "aarch64-linux",
    "x64-mingw-ucrt",
    "x64-mingw32",
    "x86_64-darwin"
  ]
end

# This block defines how to run the cross-compilation using rake-compiler-dock.
begin
  require "rake_compiler_dock"

  task "cross-compile" do
    ext_task.cross_platform.each do |platform|
      # This command now does three things inside the container:
      # 1. Installs the Rust toolchain non-interactively.
      # 2. Sources the environment to add `cargo` to the PATH.
      # 3. Runs the original build command.
      command = "bash -c 'curl --proto \"=https\" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && source \"$HOME/.cargo/env\" && bundle install && bundle exec rake native:#{platform}'"
      RakeCompilerDock.sh command, platform: platform
    end
  end
rescue LoadError
  puts "rake-compiler-dock not installed. Cross-compilation tasks will not be available."
end

# The default task remains a standard local compile.
task default: %w[compile]
