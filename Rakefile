# frozen_string_literal: true

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = 'spec/cypress_on_rails/*_spec.rb'
end

desc 'Run all CI checks (specs, linting, newlines)'
task ci: %i[spec lint check_newlines]

task default: :ci
