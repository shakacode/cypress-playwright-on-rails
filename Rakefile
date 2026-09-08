require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = 'spec/cypress_on_rails/*_spec.rb'
end

# Local convenience task: the union of what CI runs, in one command.
#
# CI deliberately splits this work rather than calling `rake ci` directly:
#   - .github/workflows/lint.yml runs `rake lint` + `rake check_newlines` once.
#   - .github/workflows/ruby.yml runs `rake` (the default :spec task) three
#     times, once per Rails/Ruby pairing.
#
# Having the lint job call `rake ci` would re-run the specs a fourth time, and
# having the Rails jobs call it would require RuboCop to resolve on every Ruby
# in the matrix -- including the 3.0.7 minimum, which the linter does not
# target. So `default` stays specs-only and this task exists for humans.
desc 'Run every check CI runs, in one command (specs, linting, newlines)'
task ci: %i[spec lint check_newlines]

task default: :spec
