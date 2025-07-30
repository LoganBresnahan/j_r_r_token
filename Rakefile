# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/extensiontask"

Rake::ExtensionTask.new("ru_token") do |ext|
  ext.lib_dir = "lib/ru_token"
  ext.ext_dir = "ext/ru_token"
end

require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task spec: :compile

task default: :spec
