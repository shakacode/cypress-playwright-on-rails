require 'cypress_on_rails/command_executor'

RSpec.describe CypressOnRails::CommandExecutor do
  describe '.perform' do
    subject { described_class }

    let(:folder) { "#{__dir__}/command_executor" }

    def executor_perform(*values)
      subject.perform(*values)
    end

    before do
      CypressOnRails.configuration.install_folder = folder
      DummyTest.values.clear if defined?(DummyTest)
    end

    it 'runs test command' do
      executor_perform("#{folder}/test_command.rb")
      expect(DummyTest.values).to eq(%w[hello])
    end

    it 'runs test command twice' do
      executor_perform("#{folder}/test_command.rb")
      executor_perform("#{folder}/test_command.rb")
      expect(DummyTest.values).to eq(%w[hello hello])
    end

    it 'runs command with options' do
      executor_perform("#{folder}/test_command_with_options.rb", 'my_string')
      expect(DummyTest.values).to eq(%w[my_string])
    end
  end
end
