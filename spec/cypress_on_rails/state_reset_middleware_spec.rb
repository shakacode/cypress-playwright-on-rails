require 'cypress_on_rails/state_reset_middleware'

RSpec.describe CypressOnRails::StateResetMiddleware do
  let(:app) { ->(_env) { [200, {}, ['downstream']] } }
  let(:middleware) { described_class.new(app) }
  let(:cleared) { [] }

  before do
    stub_const('Rails', double('Rails', cache: double('cache', clear: nil)))
  end

  # Stands in for ActiveSupport::Dependencies across Rails versions: Rails >= 7
  # exposes .autoloader (nil whenever reloading is disabled) and its .clear
  # calls .autoloader.reload, so clearing without an autoloader raises exactly
  # as it does in a real app. Older versions do not expose .autoloader at all.
  def stub_dependencies(with_autoloader:, autoloader_value: nil)
    recorder = cleared
    value = autoloader_value
    autoloader_exposed = with_autoloader
    dependencies = Module.new do
      define_singleton_method(:clear) do
        raise NoMethodError, "undefined method 'reload' for nil" if autoloader_exposed && value.nil?

        recorder << :cleared
      end
      define_singleton_method(:autoloader) { value } if with_autoloader
    end
    stub_const('ActiveSupport::Dependencies', dependencies)
  end

  def reset_state
    middleware.call('PATH_INFO' => '/cypress_rails_reset_state')
  end

  it 'passes unrelated requests through to the app' do
    expect(middleware.call('PATH_INFO' => '/posts')).to eq([200, {}, ['downstream']])
  end

  ['/cypress_rails_reset_state', '/__cypress__/reset_state'].each do |path|
    it "resets state for #{path}" do
      stub_dependencies(with_autoloader: true, autoloader_value: nil)

      status, _headers, body = middleware.call('PATH_INFO' => path)

      expect(status).to eq(200)
      expect(body).to eq(['State reset completed'])
    end
  end

  describe 'clearing autoloaded constants' do
    it 'skips the clear when reloading is disabled and there is no autoloader' do
      stub_dependencies(with_autoloader: true, autoloader_value: nil)

      status, _headers, _body = reset_state

      expect(status).to eq(200)
      expect(cleared).to be_empty
    end

    it 'clears when an autoloader is present' do
      stub_dependencies(with_autoloader: true, autoloader_value: double('autoloader'))

      reset_state

      expect(cleared).to eq([:cleared])
    end

    it 'clears on Rails versions that do not expose an autoloader' do
      stub_dependencies(with_autoloader: false)

      reset_state

      expect(cleared).to eq([:cleared])
    end
  end

  describe 'the after_state_reset hook' do
    before { stub_dependencies(with_autoloader: true, autoloader_value: nil) }

    it 'runs the configured hook' do
      events = []
      CypressOnRails.configuration.after_state_reset = -> { events << :hook }

      reset_state

      expect(events).to eq([:hook])
    end

    it 'tolerates no configured hook' do
      CypressOnRails.configuration.after_state_reset = nil

      expect { reset_state }.not_to raise_error
    end
  end
end
