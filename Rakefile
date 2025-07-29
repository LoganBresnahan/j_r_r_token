# frozen_string_literal: true

# This line ensures all gems from your Gemfile are loaded and available.
require "bundler/setup"

require "bundler/gem_tasks"
require "rake/clean"
require "rake/extensiontask"

# Define the extension task and store it in a variable.
# This is the standard way to configure a cross-compiled gem.
ext_task = Rake::ExtensionTask.new("ru_token") do |ext|
  ext.lib_dir = "lib/ru_token"

  # Tell rake-compiler that this extension can be cross-compiled.
  ext.cross_compile = true

  # Define all the platforms you want to build for.
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

  # This task will now run the cross-compilation using rake-compiler's built-in tasks.
  task "cross-compile" do
    # Use the `ext_task` variable to access the list of platforms.
    ext_task.cross_platform.each do |platform|
      # The command now runs the standard 'native' task provided by rake-compiler.
      # This is the documented and correct way to do this.
      RakeCompilerDock.sh "bundle install && bundle exec rake native:#{platform}", platform: platform
    end
  end
rescue LoadError
  # This message will be shown if rake-compiler-dock is not installed.
  puts "rake-compiler-dock not installed. Cross-compilation tasks will not be available."
end

# The default task remains a standard local compile.
# 'compile' is an alias for 'compile:local', which is the native build.
task default: %w[compile]
