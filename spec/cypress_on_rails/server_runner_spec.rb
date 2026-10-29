require 'cypress_on_rails/server'
require 'tmpdir'
require 'fileutils'
require 'rbconfig'
require 'json'

RSpec.describe CypressOnRails::Server do
  let(:recording) { File.expand_path('runner.json') }
  let(:wrapper) { File.expand_path('custom runner') }

  around do |example|
    previous_path = ENV.fetch('PATH')
    previous_url = ENV.fetch('BASE_URL', nil)
    Dir.mktmpdir do |directory|
      FileUtils.mkdir_p(File.join(directory, 'spec'))
      Dir.chdir(directory) do
        ENV['PATH'] = directory + File::PATH_SEPARATOR + previous_path
        ENV['BASE_URL'] = 'parent-shell-value'
        example.run
      end
    end
  ensure
    ENV['PATH'] = previous_path
    ENV['BASE_URL'] = previous_url
  end

  before do
    allow($stdout).to receive(:write)
    script = "#!#{RbConfig.ruby}\nrequire 'json'\n" \
             "File.write(#{recording.dump}, JSON.generate(args: ARGV, base_url: ENV['BASE_URL']))\n"
    File.write('npx', script)
    File.chmod(0o700, 'npx')
    FileUtils.cp('npx', wrapper)
  end

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
    server
  end

  def invoke(server, action)
    if action == :run
      expect { server.run }.to raise_error(SystemExit) { |error| expect(error.status).to eq(0) }
    else
      expect(server.open).to be(true)
    end
    JSON.parse(File.read(recording))
  end

  %i[run open].each do |action|
    describe "##{action}" do
      let(:arguments) { ['playwright', 'test'] }
      let(:ui_arguments) { action == :open ? ['--ui'] : [] }
      let(:managed_url) { 'http://127.0.0.1:5432' }

      it 'selects the generated config and passes the final managed port' do
        create_config('e2e')
        server = runner

        result = invoke(server, action)

        expect(result).to eq('args' => [*arguments, '--config', 'e2e', *ui_arguments], 'base_url' => managed_url)
        expect(ENV.fetch('BASE_URL')).to eq('parent-shell-value')
      end

      it 'supports an absolute custom install folder containing spaces' do
        directory = File.join(Dir.pwd, 'system tests')
        create_config(directory, 'ts')
        server = runner(install_folder: directory)

        result = invoke(server, action)

        expect(result).to eq('args' => [*arguments, '--config', directory, *ui_arguments], 'base_url' => managed_url)
      end

      it 'preserves a config already discoverable in the Rails root' do
        create_config('.', 'mjs')
        create_config('e2e')
        server = runner

        result = invoke(server, action)

        expect(result).to eq('args' => [*arguments, *ui_arguments], 'base_url' => managed_url)
      end

      it 'preserves default discovery when neither directory has a config' do
        server = runner

        result = invoke(server, action)

        expect(result).to eq('args' => [*arguments, *ui_arguments], 'base_url' => managed_url)
      end

      it 'keeps Cypress arguments and environment unchanged' do
        server = runner(framework: :cypress)

        result = invoke(server, action)

        expect(result).to eq('args' => ['cypress', action.to_s, '--project', 'e2e', '--config',
                                        'baseUrl=http://127.0.0.1:5432'], 'base_url' => 'parent-shell-value')
      end

      it 'keeps custom arguments without appending a discovered config' do
        create_config('e2e')
        CypressOnRails.configuration.playwright_command = %("#{wrapper}" --config "chosen config.ts")

        result = invoke(runner, action)

        expect(result).to eq('args' => ['--config', 'chosen config.ts', *ui_arguments], 'base_url' => managed_url)
        expect(ENV.fetch('BASE_URL')).to eq('parent-shell-value')
      end
    end
  end
end
