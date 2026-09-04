require 'cypress_on_rails/middleware'

RSpec.describe CypressOnRails::Middleware do
  let(:app) { ->(env) { [200, {}, ["app did #{env['PATH_INFO']}"]] } }
  let(:command_executor) { class_double(CypressOnRails::CommandExecutor) }
  let(:file) { class_double(File) }
  subject { described_class.new(app, command_executor, file) }

  let(:env) { {} }

  let(:response) { subject.call(env) }

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
                                {"Content-Type"=>"application/json"},
                                ["[{\"id\":1,\"title\":\"some result\"}]"]])
        expect(command_executor).to have_received(:perform).with('spec/e2e/app_commands/seed.rb', nil)
      end
    end

    it 'command file exist with options' do
      env['rack.input'] = rack_input(name: 'seed', options: ['my_options'])
      allow(file).to receive(:exist?).with('spec/e2e/app_commands/seed.rb').and_return(true)

      aggregate_failures do
        expect(response).to eq([201,
                                {"Content-Type"=>"application/json"},
                                ["[{\"id\":1,\"title\":\"some result\"}]"]])
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
                                {"Content-Type"=>"application/json"},
                                ["{\"message\":\"Cannot convert to json\"}"]])
        expect(command_executor).to have_received(:perform).with('spec/e2e/app_commands/seed.rb', nil)
      end
    end

    it 'command result does not respond to to_json' do
      env['rack.input'] = rack_input(name: 'seed')
      allow(file).to receive(:exist?).with('spec/e2e/app_commands/seed.rb').and_return(true)

      aggregate_failures do
        expect(response).to eq([201,
                                {"Content-Type"=>"application/json"},
                                ["[{\"id\":1,\"title\":\"some result\"}]"]])
        expect(command_executor).to have_received(:perform).with('spec/e2e/app_commands/seed.rb', nil)
      end
    end

    it 'running multiple commands' do
      env['rack.input'] = rack_input([{name: 'load_user'},
                                      {name: 'load_sample', options: {'all' => 'true'}}])
      allow(file).to receive(:exist?).with('spec/e2e/app_commands/load_user.rb').and_return(true)
      allow(file).to receive(:exist?).with('spec/e2e/app_commands/load_sample.rb').and_return(true)

      aggregate_failures do
        expect(response).to eq([201,
                                {"Content-Type"=>"application/json"},
                                ["[{\"id\":1,\"title\":\"some result\"},{\"id\":1,\"title\":\"some result\"}]"]])
        expect(command_executor).to have_received(:perform).with('spec/e2e/app_commands/load_user.rb', nil)
        expect(command_executor).to have_received(:perform).with('spec/e2e/app_commands/load_sample.rb', {'all' => 'true'})
      end
    end

    it 'running multiple commands but one missing' do
      env['rack.input'] = rack_input([{name: 'load_user'}, {name: 'load_sample'}])
      allow(file).to receive(:exist?).with('spec/e2e/app_commands/load_user.rb').and_return(true)
      allow(file).to receive(:exist?).with('spec/e2e/app_commands/load_sample.rb').and_return(false)

      aggregate_failures do
        expect(response).to eq([404,
                                {"Content-Type"=>"application/json"},
                                ["{\"message\":\"could not find command file: spec/e2e/app_commands/load_sample.rb\"}"]])
        expect(command_executor).to_not have_received(:perform)
      end
    end
  end

  context '"Other paths"' do
    it 'runs app' do
      aggregate_failures do
        %w(/ /__e2e__/login command /e2e_command /).each do |path|
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

      expect(response).to eq([200, {}, ["app did /test"]])
    end
  end

  context 'with a middleware_token configured' do
    let(:token) { 'super-secret-token' }
    let(:forbidden) do
      [403, { 'Content-Type' => 'application/json' }, ['{"message":"invalid or missing token"}']]
    end

    before do
      CypressOnRails.configure { |config| config.middleware_token = token }
      allow(command_executor).to receive(:perform).and_return({ id: 1 })
      allow(file).to receive(:exist?).and_return(true)
      env['PATH_INFO'] = '/__e2e__/command'
      env['rack.input'] = rack_input(name: 'seed')
    end

    it 'rejects a request without the token header' do
      aggregate_failures do
        expect(response).to eq(forbidden)
        expect(command_executor).to_not have_received(:perform)
      end
    end

    it 'rejects a request with the wrong token' do
      env['HTTP_X_CYPRESS_ON_RAILS_TOKEN'] = 'not-the-token'

      aggregate_failures do
        expect(response).to eq(forbidden)
        expect(command_executor).to_not have_received(:perform)
      end
    end

    it 'rejects the request before before_request runs' do
      before_request_calls = 0
      CypressOnRails.configure do |config|
        config.before_request = ->(_request) { before_request_calls += 1 }
      end

      aggregate_failures do
        expect(response).to eq(forbidden)
        expect(before_request_calls).to eq(0)
      end
    end

    it 'runs the command when the token matches' do
      env['HTTP_X_CYPRESS_ON_RAILS_TOKEN'] = token

      aggregate_failures do
        expect(response).to eq([201,
                                { 'Content-Type' => 'application/json' },
                                ['[{"id":1}]']])
        expect(command_executor).to have_received(:perform).with('spec/e2e/app_commands/seed.rb', nil)
      end
    end

    it 'does not interfere with other paths' do
      env['PATH_INFO'] = '/'

      expect(subject.call(env)).to eq([200, {}, ['app did /']])
    end
  end

  context 'without a middleware_token configured' do
    before do
      allow(command_executor).to receive(:perform).and_return({ id: 1 })
      allow(file).to receive(:exist?).and_return(true)
      env['PATH_INFO'] = '/__e2e__/command'
      env['rack.input'] = rack_input(name: 'seed')
    end

    it 'runs the command without any token header' do
      expect(response).to eq([201,
                              { 'Content-Type' => 'application/json' },
                              ['[{"id":1}]']])
    end

    it 'ignores a token header that is sent anyway' do
      env['HTTP_X_CYPRESS_ON_RAILS_TOKEN'] = 'ignored'

      expect(response).to eq([201,
                              { 'Content-Type' => 'application/json' },
                              ['[{"id":1}]']])
    end
  end
end
