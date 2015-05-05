require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task default: [:spec]

task :integration do
  ENV['INTEGRATION'] = 'true'
  Rake::Task['spec'].execute
end
