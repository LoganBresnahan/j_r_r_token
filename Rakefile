# frozen_string_literal: true

# This line ensures all gems from your Gemfile are loaded and available.
require "bundler/setup"
require "rake/clean"
require "rake/extensiontask"

# Load the gemspec file to pass it to the extension task.
spec = Gem::Specification.load("ru_token.gemspec")

# Define the extension task and store it in a variable.
ext_task = Rake::ExtensionTask.new("ru_token", spec) do |ext|
  ext.lib_dir = "lib/ru_token"
  ext.cross_compile = true
  ext.cross_platform = [
    "x86_64-linux",
    # "aarch64-linux",   # Temporarily disabled
    # "x64-mingw-ucrt",  # Temporarily disabled
    # "x64-mingw32",     # Temporarily disabled
    # "x86_64-darwin"
  ]
end

# This block defines how to run the cross-compilation using rake-compiler-dock.
begin
  require "rake_compiler_dock"

  task "cross-compile" do
    ext_task.cross_platform.each do |platform|
      script = <<-SCRIPT
        set -e
        echo "----> Installing build dependencies for #{platform}"
        # For all platforms, we need libclang-dev for the rb-sys gem.
        sudo apt-get update -y && sudo apt-get install -y --no-install-recommends build-essential libclang-dev

        echo "----> Installing Rust"
        curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

        echo "----> Sourcing Rust environment"
        source "$HOME/.cargo/env"

        echo "----> Installing gems"
        bundle install

        echo "----> Compiling native extension for #{platform}"
        bundle exec rake native:#{platform}
      SCRIPT

      RakeCompilerDock.sh script, platform: platform
    end
  end
rescue LoadError
  puts "rake-compiler-dock not installed. Cross-compilation tasks will not be available."
end

# The default task remains a standard local compile.
task default: %w[compile]
