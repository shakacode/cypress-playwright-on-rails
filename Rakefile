require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = 'spec/cypress_on_rails/*_spec.rb'
end

# Manually define build task (normally provided by bundler/gem_tasks)
# We don't use bundler/gem_tasks because it conflicts with our custom release task
desc "Build gem into pkg directory"
task :build do
  require_relative 'lib/cypress_on_rails/version'
  sh "gem build cypress-on-rails.gemspec"
  sh "mkdir -p pkg"
  sh "mv cypress-on-rails-#{CypressOnRails::VERSION}.gem pkg/"
end

task default: %w[spec build]
