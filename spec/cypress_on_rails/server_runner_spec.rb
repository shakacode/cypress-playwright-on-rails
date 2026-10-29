require 'cypress_on_rails/server'
require 'tmpdir'
require 'fileutils'

RSpec.describe CypressOnRails::Server do
  around do |example|
    Dir.mktmpdir do |directory|
      FileUtils.mkdir_p(File.join(directory, 'spec'))
      Dir.chdir(directory) { example.run }
    end
  end

  before { allow($stdout).to receive(:write) }

  def create_config(directory, extension = 'js')
    FileUtils.mkdir_p(directory)
    File.write(File.join(directory, "playwright.config.#{extension}"), 'module.exports = {}')
  end

  def runner(framework: :playwright, install_folder: 'e2e')
    server = described_class.new(framework: framework, host: '127.0.0.1', port: 4321,
                                 install_folder: install_folder)
    allow(server).to receive(:start_server) do |&block|
      # Startup can reselect the port after a bind race.
      server.instance_variable_set(:@port, 5432)
      block.call
    end
    allow(server).to receive(:command_exists?).with('yarn').and_return(false)
    allow(server).to receive(:command_exists?).with('npx').and_return(true)
    allow(server).to receive(:system).and_return(true)
    server
  end

  def invoke(server, action)
    if action == :run
      expect { server.run }.to raise_error(SystemExit) { |error| expect(error.status).to eq(0) }
    else
      server.open
    end
  end

  %i[run open].each do |action|
    describe "##{action}" do
      let(:arguments) { ['npx', 'playwright', 'test'] }
      let(:ui_arguments) { action == :open ? ['--ui'] : [] }
      let(:environment) { { 'BASE_URL' => 'http://127.0.0.1:5432' } }

      it 'selects the generated config and passes the final managed port' do
        create_config('e2e')
        server = runner

        invoke(server, action)

        expect(server).to have_received(:system).with(environment, *arguments, '--config', 'e2e', *ui_arguments)
      end

      it 'supports an absolute custom install folder containing spaces' do
        directory = File.join(Dir.pwd, 'system tests')
        create_config(directory, 'ts')
        server = runner(install_folder: directory)

        invoke(server, action)

        expect(server).to have_received(:system).with(environment, *arguments, '--config', directory, *ui_arguments)
      end

      it 'preserves a config already discoverable in the Rails root' do
        create_config('.', 'mjs')
        create_config('e2e')
        server = runner

        invoke(server, action)

        expect(server).to have_received(:system).with(environment, *arguments, *ui_arguments)
      end

      it 'preserves default discovery when neither directory has a config' do
        server = runner

        invoke(server, action)

        expect(server).to have_received(:system).with(environment, *arguments, *ui_arguments)
      end

      it 'keeps Cypress arguments and environment unchanged' do
        server = runner(framework: :cypress)

        invoke(server, action)

        expect(server).to have_received(:system)
          .with({}, 'npx', 'cypress', action.to_s, '--project', 'e2e', '--config',
                'baseUrl=http://127.0.0.1:5432')
      end
    end
  end
end
