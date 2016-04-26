# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.
#
require File.expand_path('../config/application', __FILE__)
#
Rails.application.load_tasks

require 'rake/testtask'
require 'pathname'

task :default => :test

namespace :test do
  task :isolated do
    Dir.glob("test/**/*_test.rb").all? do |file|
      sh(Gem.ruby, '-w', '-Ilib:test', file)
    end or raise "Failures"
  end
end