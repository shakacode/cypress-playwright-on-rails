# frozen_string_literal: true

require "spec_helper"
require "rake"
require "rspec/core/rake_task"

RSpec.describe Rake do
  def discovered_default_spec_files
    original_application = Rake.application
    Rake.application = Rake::Application.new
    rake_task = nil
    allow(RSpec::Core::RakeTask).to receive(:new).and_wrap_original do |constructor, *args, &block|
      rake_task = constructor.call(*args, &block)
    end
    load File.expand_path("../../Rakefile", __dir__)

    discovered_files = nil
    allow(rake_task).to receive(:run_task) do |_verbose|
      configuration = RSpec::Core::Configuration.new
      configuration.pattern = rake_task.pattern
      discovered_files = configuration.files_to_run
    end

    Rake::Task[:default].invoke
    discovered_files
  ensure
    Rake.application = original_application
  end

  it "discovers core, nested VCR, and generator specs" do
    expected_files = %w[
      spec/cypress_on_rails/configuration_spec.rb
      spec/cypress_on_rails/vcr/insert_eject_middleware_spec.rb
      spec/generators/install_generator_spec.rb
    ].map { |path| File.expand_path("../../#{path}", __dir__) }
    expect(discovered_default_spec_files).to include(*expected_files)
  end
end
