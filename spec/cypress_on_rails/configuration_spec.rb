require 'cypress_on_rails/configuration'

RSpec.describe CypressOnRails::Configuration do
  it 'has defaults' do
    CypressOnRails.configure { |config| config.reset }

    expect(CypressOnRails.configuration.api_prefix).to eq('')
    expect(CypressOnRails.configuration.install_folder).to eq('spec/e2e')
    expect(CypressOnRails.configuration.use_middleware?).to eq(true)
    expect(CypressOnRails.configuration.logger).to_not be_nil
    expect(CypressOnRails.configuration.before_request).to_not be_nil
    expect(CypressOnRails.configuration.vcr_options).to eq({})
    expect(CypressOnRails.configuration.server_readiness_path).to eq('/')
    expect(CypressOnRails.configuration.server_readiness_timeout).to eq(5)
    expect(CypressOnRails.configuration.server_shutdown_timeout).to eq(10)
  end

  it 'can be configured' do
    my_logger = Logger.new(STDOUT)
    before_request_lambda = ->(_) { return [200, {}, ['hello world']] }
    CypressOnRails.configure do |config|
      config.api_prefix = '/api'
      config.install_folder = 'my/path'
      config.use_middleware = false
      config.logger = my_logger
      config.before_request = before_request_lambda
      config.vcr_options = { hook_into: :webmock }
      config.server_readiness_path = '/health'
      config.server_readiness_timeout = 10
      config.server_shutdown_timeout = 30
    end
    expect(CypressOnRails.configuration.api_prefix).to eq('/api')
    expect(CypressOnRails.configuration.install_folder).to eq('my/path')
    expect(CypressOnRails.configuration.use_middleware?).to eq(false)
    expect(CypressOnRails.configuration.logger).to eq(my_logger)
    expect(CypressOnRails.configuration.before_request).to eq(before_request_lambda)
    expect(CypressOnRails.configuration.vcr_options).to eq(hook_into: :webmock)
    expect(CypressOnRails.configuration.server_readiness_path).to eq('/health')
    expect(CypressOnRails.configuration.server_readiness_timeout).to eq(10)
    expect(CypressOnRails.configuration.server_shutdown_timeout).to eq(30)
  end

  describe 'hook validation' do
    let(:configuration) { described_class.new }

    it 'covers every lifecycle hook' do
      expect(described_class::HOOKS).to contain_exactly(
        :before_request,
        :before_server_start,
        :after_server_start,
        :after_transaction_start,
        :after_state_reset,
        :before_server_stop
      )
    end

    described_class::HOOKS.each do |hook_name|
      it "accepts a callable for #{hook_name}" do
        hook = -> {}

        configuration.public_send("#{hook_name}=", hook)

        expect(configuration.public_send(hook_name)).to eq(hook)
      end

      it "accepts an arbitrary object responding to :call for #{hook_name}" do
        callable = Class.new { def call; end }.new

        configuration.public_send("#{hook_name}=", callable)

        expect(configuration.public_send(hook_name)).to eq(callable)
      end

      it "accepts nil for #{hook_name}" do
        configuration.public_send("#{hook_name}=", nil)

        expect(configuration.public_send(hook_name)).to be_nil
      end

      it "rejects a non-callable for #{hook_name}" do
        expect { configuration.public_send("#{hook_name}=", 'DatabaseCleaner.clean') }
          .to raise_error(
            ArgumentError,
            "#{hook_name} must respond to :call (for example a lambda or proc) or be nil, " \
            'got "DatabaseCleaner.clean"'
          )
      end
    end

    it 'leaves the previous hook in place when an invalid value is rejected' do
      hook = -> {}
      configuration.before_server_start = hook

      expect { configuration.before_server_start = :not_callable }.to raise_error(ArgumentError)
      expect(configuration.before_server_start).to eq(hook)
    end
  end

  describe '#server_shutdown_timeout=' do
    let(:configuration) { described_class.new }

    it 'accepts a numeric string' do
      configuration.server_shutdown_timeout = '2.5'

      expect(configuration.server_shutdown_timeout).to eq(2.5)
    end

    [nil, 0, -1, 'soon', '', true, Float::NAN, Float::INFINITY, -Float::INFINITY,
     'Infinity', 'NaN', '1e10000', '-1e10000'].each do |value|
      it "rejects #{value.inspect}" do
        expect { configuration.server_shutdown_timeout = value }
          .to raise_error(ArgumentError, /server_shutdown_timeout must be a finite number of seconds greater than 0/)
      end
    end

    # An infinite timeout makes the shutdown deadline unreachable, so
    # stop_server would wait on TERM forever and never escalate to KILL.
    it 'reports an overflowing string by its original value' do
      expect { configuration.server_shutdown_timeout = '1e10000' }
        .to raise_error(ArgumentError, /got "1e10000"/)
    end

    # Integer#finite? is true at any magnitude, but the deadline is computed in
    # floats, so a big enough Integer still yields an unreachable deadline.
    it 'rejects an integer too large to survive the float deadline arithmetic' do
      expect { configuration.server_shutdown_timeout = 10**10_000 }
        .to raise_error(ArgumentError, /server_shutdown_timeout must be a finite number of seconds greater than 0/)
    end

    it 'only ever stores a finite timeout' do
      configuration.server_shutdown_timeout = '2.5'

      expect(configuration.server_shutdown_timeout).to be_finite
    end

    it 'reports the rejected value in the error message' do
      expect { configuration.server_shutdown_timeout = 'soon' }
        .to raise_error(ArgumentError, /got "soon"/)
    end

    it 'reads the default from CYPRESS_RAILS_SHUTDOWN_TIMEOUT' do
      begin
        ENV['CYPRESS_RAILS_SHUTDOWN_TIMEOUT'] = '3'

        expect(described_class.new.server_shutdown_timeout).to eq(3)
      ensure
        ENV.delete('CYPRESS_RAILS_SHUTDOWN_TIMEOUT')
      end
    end
  end

  describe '#middleware_token' do
    it 'is not set when the environment variable is missing' do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('CYPRESS_ON_RAILS_TOKEN', nil).and_return(nil)

      CypressOnRails.configure { |config| config.reset }

      expect(CypressOnRails.configuration.middleware_token).to be_nil
    end

    it 'defaults to the CYPRESS_ON_RAILS_TOKEN environment variable' do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('CYPRESS_ON_RAILS_TOKEN', nil).and_return('token-from-env')

      CypressOnRails.configure { |config| config.reset }

      expect(CypressOnRails.configuration.middleware_token).to eq('token-from-env')
    end

    it 'can be configured' do
      CypressOnRails.configure { |config| config.middleware_token = 'my-token' }

      expect(CypressOnRails.configuration.middleware_token).to eq('my-token')
    end

    it 'treats false as not configured' do
      CypressOnRails.configure { |config| config.middleware_token = false }

      expect(CypressOnRails.configuration.middleware_token).to be_nil
    end

    it 'treats a blank string as not configured' do
      CypressOnRails.configure { |config| config.middleware_token = '' }

      expect(CypressOnRails.configuration.middleware_token).to be_nil
    end

    it 'treats a blank environment variable as not configured' do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('CYPRESS_ON_RAILS_TOKEN', nil).and_return('')

      CypressOnRails.configure { |config| config.reset }

      expect(CypressOnRails.configuration.middleware_token).to be_nil
    end

    it 'stores other values as strings' do
      CypressOnRails.configure { |config| config.middleware_token = 12_345 }

      expect(CypressOnRails.configuration.middleware_token).to eq('12345')
    end

    it 'rejects true instead of requiring the literal secret "true"' do
      expect {
        CypressOnRails.configure { |config| config.middleware_token = true }
      }.to raise_error(ArgumentError, /must be a secret string/)
    end
  end

  describe '#use_middleware?' do
    let(:configuration) { CypressOnRails.configuration }

    context 'when left at the default' do
      it 'is not assigned, so the environment decides' do
        expect(configuration.use_middleware).to be_nil
      end

      it 'is enabled when Rails is not loaded' do
        hide_const('Rails')

        expect(configuration.use_middleware?).to eq(true)
      end

      it 'is enabled when Rails is loaded but has no environment yet' do
        stub_const('Rails', Module.new)

        expect(configuration.use_middleware?).to eq(true)
      end

      it 'is enabled outside of production' do
        stub_const('Rails', double('Rails', env: 'development'))

        expect(configuration.use_middleware?).to eq(true)
      end

      it 'is disabled in production' do
        stub_const('Rails', double('Rails', env: 'production'))

        expect(configuration.use_middleware?).to eq(false)
      end
    end

    context 'when explicitly assigned' do
      it 'stays enabled in production' do
        stub_const('Rails', double('Rails', env: 'production'))
        CypressOnRails.configure { |config| config.use_middleware = true }

        expect(configuration.use_middleware?).to eq(true)
      end

      it 'stays disabled outside of production' do
        stub_const('Rails', double('Rails', env: 'development'))
        CypressOnRails.configure { |config| config.use_middleware = false }

        expect(configuration.use_middleware?).to eq(false)
      end
    end
  end
end
