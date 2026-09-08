require 'cypress_on_rails/state_reset_middleware'

RSpec.describe CypressOnRails::StateResetMiddleware do
  let(:app) { ->(_env) { [200, {}, ['downstream']] } }
  let(:middleware) { described_class.new(app) }
  let(:cleared) { [] }

  before do
    stub_rails(reloading: true)
    stub_dependencies(autoloader: double('autoloader'))
  end

  # Rails asks the application config whether reloading is on. Rails 7.1+ names
  # it reloading_enabled?; 6.1 and 7.0 only expose cache_classes.
  def stub_rails(reloading:, config_style: :modern)
    config = if config_style == :modern
               double('config', reloading_enabled?: reloading)
             else
               double('config', cache_classes: !reloading)
             end
    stub_const('Rails', double('Rails',
                               application: double('application', config: config),
                               cache: double('cache', clear: nil)))
  end

  # Stands in for ActiveSupport::Dependencies across Rails versions. Pass
  # autoloader: :absent for the Rails 6.1 shape, which has no such accessor and
  # instead raises from .clear when reloading is off.
  def stub_dependencies(autoloader: :absent, raises: nil)
    recorder = cleared
    error = raises
    value = autoloader
    exposes_autoloader = autoloader != :absent
    dependencies = Module.new do
      define_singleton_method(:clear) do
        raise error if error

        recorder << :cleared
      end
      define_singleton_method(:autoloader) { value } if exposes_autoloader
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
      status, _headers, body = middleware.call('PATH_INFO' => path)

      expect(status).to eq(200)
      expect(body).to eq(['State reset completed'])
    end
  end

  describe 'clearing autoloaded constants' do
    context 'on Rails 7.0+, which leaves the autoloader nil when reloading is off' do
      it 'skips the clear rather than raising NoMethodError after truncating' do
        stub_rails(reloading: false)
        stub_dependencies(autoloader: nil, raises: NoMethodError.new("undefined method 'reload' for nil"))

        status, _headers, body = reset_state

        expect(status).to eq(200)
        expect(body).to eq(['State reset completed'])
        expect(cleared).to be_empty
      end

      it 'clears when reloading is enabled' do
        stub_rails(reloading: true)
        stub_dependencies(autoloader: double('autoloader'))

        reset_state

        expect(cleared).to eq([:cleared])
      end
    end

    context 'on Rails 6.1, which has no autoloader accessor' do
      it 'skips the clear rather than raising when cache_classes is true' do
        stub_rails(reloading: false, config_style: :legacy)
        stub_dependencies(
          autoloader: :absent,
          raises: RuntimeError.new('reloading is disabled because config.cache_classes is true')
        )

        status, _headers, body = reset_state

        expect(status).to eq(200)
        expect(body).to eq(['State reset completed'])
        expect(cleared).to be_empty
      end

      it 'clears when reloading is enabled' do
        stub_rails(reloading: true, config_style: :legacy)
        stub_dependencies(autoloader: :absent)

        reset_state

        expect(cleared).to eq([:cleared])
      end
    end

    it 'clears when there is no Rails application to ask' do
      stub_const('Rails', double('Rails', cache: double('cache', clear: nil)))
      stub_dependencies(autoloader: :absent)

      reset_state

      expect(cleared).to eq([:cleared])
    end
  end

  describe 'the after_state_reset hook' do
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
