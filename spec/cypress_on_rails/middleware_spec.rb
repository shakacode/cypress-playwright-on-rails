require 'cypress_on_rails/middleware'

RSpec.describe CypressOnRails::Middleware do
  subject { described_class.new(app, command_executor, file) }

  let(:app) { ->(env) { [200, {}, ["app did #{env['PATH_INFO']}"]] } }
  let(:env) { {} }
  let(:response) { subject.call(env) }
  let(:command_executor) { class_double(CypressOnRails::CommandExecutor) }
  let(:file) { class_double(File) }

  def rack_input(json_value)
    StringIO.new(JSON.generate(json_value))
  end

  context '/__e2e__/command' do
    before do
      allow(command_executor).to receive(:perform).and_return({ id: 1, title: 'some result' })
      allow(file).to receive(:exist?)
      env['PATH_INFO'] = '/__e2e__/command'
    end

    it 'command file exist' do
      allow(command_executor).to receive(:perform).and_return({ id: 1, title: 'some result' })
      env['rack.input'] = rack_input(name: 'seed')
      allow(file).to receive(:exist?).with('spec/e2e/app_commands/seed.rb').and_return(true)

      aggregate_failures do
        expect(response).to eq([201,
                                { 'Content-Type' => 'application/json' },
                                ['[{"id":1,"title":"some result"}]']])
        expect(command_executor).to have_received(:perform).with('spec/e2e/app_commands/seed.rb', nil)
      end
    end

    it 'command file exist with options' do
      env['rack.input'] = rack_input(name: 'seed', options: ['my_options'])
      allow(file).to receive(:exist?).with('spec/e2e/app_commands/seed.rb').and_return(true)

      aggregate_failures do
        expect(response).to eq([201,
                                { 'Content-Type' => 'application/json' },
                                ['[{"id":1,"title":"some result"}]']])
        expect(command_executor).to have_received(:perform).with('spec/e2e/app_commands/seed.rb', ['my_options'])
      end
    end

    it 'command file does not exist' do
      object = BasicObject.new
      allow(command_executor).to receive(:perform).and_return(object)
      env['rack.input'] = rack_input(name: 'seed')
      allow(file).to receive(:exist?).with('spec/e2e/app_commands/seed.rb').and_return(true)

      aggregate_failures do
        expect(response).to eq([201,
                                { 'Content-Type' => 'application/json' },
                                ['{"message":"Cannot convert to json"}']])
        expect(command_executor).to have_received(:perform).with('spec/e2e/app_commands/seed.rb', nil)
      end
    end

    it 'command result does not respond to to_json' do
      env['rack.input'] = rack_input(name: 'seed')
      allow(file).to receive(:exist?).with('spec/e2e/app_commands/seed.rb').and_return(true)

      aggregate_failures do
        expect(response).to eq([201,
                                { 'Content-Type' => 'application/json' },
                                ['[{"id":1,"title":"some result"}]']])
        expect(command_executor).to have_received(:perform).with('spec/e2e/app_commands/seed.rb', nil)
      end
    end

    it 'running multiple commands' do
      env['rack.input'] = rack_input([{ name: 'load_user' },
                                      { name: 'load_sample', options: { 'all' => 'true' } }])
      allow(file).to receive(:exist?).with('spec/e2e/app_commands/load_user.rb').and_return(true)
      allow(file).to receive(:exist?).with('spec/e2e/app_commands/load_sample.rb').and_return(true)

      aggregate_failures do
        expect(response).to eq([201,
                                { 'Content-Type' => 'application/json' },
                                ['[{"id":1,"title":"some result"},{"id":1,"title":"some result"}]']])
        expect(command_executor).to have_received(:perform).with('spec/e2e/app_commands/load_user.rb', nil)
        expect(command_executor).to have_received(:perform).with('spec/e2e/app_commands/load_sample.rb', { 'all' => 'true' })
      end
    end

    it 'running multiple commands but one missing' do
      env['rack.input'] = rack_input([{ name: 'load_user' }, { name: 'load_sample' }])
      allow(file).to receive(:exist?).with('spec/e2e/app_commands/load_user.rb').and_return(true)
      allow(file).to receive(:exist?).with('spec/e2e/app_commands/load_sample.rb').and_return(false)

      aggregate_failures do
        expect(response).to eq([404,
                                { 'Content-Type' => 'application/json' },
                                ['{"message":"could not find command file: spec/e2e/app_commands/load_sample.rb"}']])
        expect(command_executor).not_to have_received(:perform)
      end
    end
  end

  context '"Other paths"' do
    it 'runs app' do
      aggregate_failures do
        %w[/ /__e2e__/login command /e2e_command /].each do |path|
          env['PATH_INFO'] = path

          response = subject.call(env)

          expect(response).to eq([200, {}, ["app did #{path}"]])
        end
      end
    end
  end

  context 'without stubs' do
    subject { described_class.new(app) }

    it 'runs' do
      env['PATH_INFO'] = '/test'

      response = subject.call(env)

      expect(response).to eq([200, {}, ['app did /test']])
    end
  end
end
