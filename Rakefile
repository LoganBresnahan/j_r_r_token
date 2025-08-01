# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/extensiontask"
require "rb_sys/extensiontask"

GEMSPEC = Gem::Specification.load("j_r_r_token.gemspec")

RbSys::ExtensionTask.new("j_r_r_token", GEMSPEC) do |ext|
  ext.lib_dir = "lib/j_r_r_token"
end

# Only require rspec if it's available
begin
  require "rspec/core/rake_task"
  RSpec::Core::RakeTask.new(:spec)
  task default: %i[compile spec]
rescue LoadError
  puts "RSpec not available"
  task default: :compile
end

task :native, [:platform] do |_t, platform:|
  sh "bundle", "exec", "rb-sys-dock", "--platform", platform, "--build"
end

task build: :compile
