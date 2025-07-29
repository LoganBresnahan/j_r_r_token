# frozen_string_literal: true

# This line ensures all gems from your Gemfile are loaded and available.
require "bundler/setup"

require "bundler/gem_tasks"
require "rake/clean"
require "rake/extensiontask"

# This is the task for local development and for CI runners
# that build natively (like macOS).
Rake::ExtensionTask.new("ru_token") do |ext|
  ext.lib_dir = "lib/ru_token"
end

# This block defines the cross-compilation tasks.
begin
  require "rake_compiler_dock"

  # This is the main cross-compilation task for CI runners
  # that use Docker.
  task "cross-compile" do
    platforms = [
      "x86_64-linux",
      "aarch64-linux",
      "x64-mingw-ucrt", # For Ruby 3.1+ on Windows
      "x64-mingw32",    # For Ruby 2.7-3.0 on Windows
      "x86_64-darwin"
    ]

    platforms.each do |platform|
      # This command now runs the build inside a bash subshell to ensure the PATH is set correctly for all commands.
      command = "bash -c 'export PATH=\"$HOME/.cargo/bin:$PATH\" && bundle install && bundle exec rake compile:#{platform}'"
      RakeCompilerDock.sh command, platform: platform
    end
  end
rescue LoadError
  # This message will be shown if rake-compiler-dock is not installed.
  puts "rake-compiler-dock not installed. Cross-compilation tasks will not be available."
end


# This helper task is used by rake-compiler-dock.
task :native do
  Rake::Task["compile:ru_token"].invoke
end

# The default task remains a standard local compile.
task default: %w[compile]
