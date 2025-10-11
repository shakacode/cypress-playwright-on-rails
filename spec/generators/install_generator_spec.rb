require 'spec_helper'
require 'rails/generators'
require 'generators/cypress_on_rails/install_generator'
require 'tmpdir'
require 'fileutils'

RSpec.describe CypressOnRails::InstallGenerator, type: :generator do
  let(:destination_root) { Dir.mktmpdir }

  before do
    # Set up a minimal Rails app structure
    FileUtils.mkdir_p(File.join(destination_root, 'config', 'initializers'))
    FileUtils.mkdir_p(File.join(destination_root, 'bin'))

    # Mock the generator's destination_root
    allow(Dir).to receive(:pwd).and_return(destination_root)

    # Prevent actual npm/yarn installation in tests
    allow_any_instance_of(CypressOnRails::InstallGenerator).to receive(:system).and_return(true)
  end

  after do
    FileUtils.rm_rf(destination_root)
  end

  describe 'with default options (cypress framework, e2e folder)' do
    let(:args) { [] }
    let(:options) { {} }

    before do
      run_generator(args, options)
    end

    it 'creates the initializer with correct install_folder path' do
      initializer_path = File.join(destination_root, 'config', 'initializers', 'cypress_on_rails.rb')
      expect(File).to exist(initializer_path)

      content = File.read(initializer_path)
      # Should point to e2e, not e2e/cypress
      expect(content).to include('c.install_folder = File.expand_path("#{__dir__}/../../e2e")')
    end

    it 'creates cypress config at install_folder root' do
      config_path = File.join(destination_root, 'e2e', 'cypress.config.js')
      expect(File).to exist(config_path)
    end

    it 'creates e2e_helper.rb at install_folder root' do
      helper_path = File.join(destination_root, 'e2e', 'e2e_helper.rb')
      expect(File).to exist(helper_path)
    end

    it 'creates app_commands directory at install_folder root' do
      commands_path = File.join(destination_root, 'e2e', 'app_commands')
      expect(File).to be_directory(commands_path)
    end

    it 'creates cypress support files in framework subdirectory' do
      support_path = File.join(destination_root, 'e2e', 'cypress', 'support', 'index.js')
      expect(File).to exist(support_path)
    end

    it 'creates cypress examples in framework subdirectory' do
      examples_path = File.join(destination_root, 'e2e', 'cypress', 'e2e', 'rails_examples')
      expect(File).to be_directory(examples_path)
    end
  end

  describe 'with playwright framework' do
    let(:args) { [] }
    let(:options) { { framework: 'playwright' } }

    before do
      run_generator(args, options)
    end

    it 'creates the initializer with correct install_folder path' do
      initializer_path = File.join(destination_root, 'config', 'initializers', 'cypress_on_rails.rb')
      expect(File).to exist(initializer_path)

      content = File.read(initializer_path)
      # Should point to e2e, not e2e/playwright
      expect(content).to include('c.install_folder = File.expand_path("#{__dir__}/../../e2e")')
    end

    it 'creates playwright config at install_folder root' do
      config_path = File.join(destination_root, 'e2e', 'playwright.config.js')
      expect(File).to exist(config_path)
    end

    it 'creates e2e_helper.rb at install_folder root' do
      helper_path = File.join(destination_root, 'e2e', 'e2e_helper.rb')
      expect(File).to exist(helper_path)
    end

    it 'creates app_commands directory at install_folder root' do
      commands_path = File.join(destination_root, 'e2e', 'app_commands')
      expect(File).to be_directory(commands_path)
    end

    it 'creates playwright support files in framework subdirectory' do
      support_path = File.join(destination_root, 'e2e', 'playwright', 'support', 'index.js')
      expect(File).to exist(support_path)
    end
  end

  describe 'with custom install_folder' do
    let(:args) { [] }
    let(:options) { { install_folder: 'spec/system' } }

    before do
      run_generator(args, options)
    end

    it 'creates files in the custom folder' do
      helper_path = File.join(destination_root, 'spec', 'system', 'e2e_helper.rb')
      expect(File).to exist(helper_path)

      commands_path = File.join(destination_root, 'spec', 'system', 'app_commands')
      expect(File).to be_directory(commands_path)
    end

    it 'sets the correct install_folder in the initializer' do
      initializer_path = File.join(destination_root, 'config', 'initializers', 'cypress_on_rails.rb')
      content = File.read(initializer_path)
      expect(content).to include('c.install_folder = File.expand_path("#{__dir__}/../../spec/system")')
    end
  end

  describe 'file structure ensures middleware and framework compatibility' do
    let(:args) { [] }
    let(:options) { {} }

    before do
      run_generator(args, options)
    end

    it 'places e2e_helper.rb where middleware expects it (install_folder/e2e_helper.rb)' do
      # Middleware looks for #{install_folder}/e2e_helper.rb
      helper_path = File.join(destination_root, 'e2e', 'e2e_helper.rb')
      expect(File).to exist(helper_path)
      expect(File.read(helper_path)).to include('CypressOnRails')
    end

    it 'places app_commands where middleware expects it (install_folder/app_commands)' do
      # Middleware looks for #{install_folder}/app_commands/#{command}.rb
      commands_path = File.join(destination_root, 'e2e', 'app_commands')
      expect(File).to be_directory(commands_path)

      # Check that command files exist
      clean_cmd = File.join(commands_path, 'clean.rb')
      expect(File).to exist(clean_cmd)
    end

    it 'places cypress.config.js where cypress --project flag expects it' do
      # Cypress runs with --project install_folder, expects config at that level
      config_path = File.join(destination_root, 'e2e', 'cypress.config.js')
      expect(File).to exist(config_path)

      # Verify the config references the correct relative path for support files
      content = File.read(config_path)
      expect(content).to include('cypress/support/index.js')
    end

    it 'creates a valid directory structure' do
      # The expected structure:
      # e2e/
      #   cypress.config.js       <- Config at root of install_folder
      #   e2e_helper.rb           <- Helper at root of install_folder
      #   app_commands/           <- Commands at root of install_folder
      #   cypress/                <- Framework-specific subdirectory
      #     support/
      #     e2e/

      expect(File).to exist(File.join(destination_root, 'e2e', 'cypress.config.js'))
      expect(File).to exist(File.join(destination_root, 'e2e', 'e2e_helper.rb'))
      expect(File).to be_directory(File.join(destination_root, 'e2e', 'app_commands'))
      expect(File).to be_directory(File.join(destination_root, 'e2e', 'cypress'))
      expect(File).to be_directory(File.join(destination_root, 'e2e', 'cypress', 'support'))
      expect(File).to be_directory(File.join(destination_root, 'e2e', 'cypress', 'e2e'))
    end
  end

  def run_generator(args, options)
    generator_options = []
    options.each do |key, value|
      generator_options << "--#{key}=#{value}"
    end

    CypressOnRails::InstallGenerator.start(
      args + generator_options,
      {
        destination_root: destination_root,
        shell: Thor::Shell::Basic.new,
        behavior: :invoke
      }
    )
  end
end
