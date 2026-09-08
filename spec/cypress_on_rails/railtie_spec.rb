require 'cypress_on_rails/railtie'

module Rails
  def self.env
  end
end

RSpec.describe CypressOnRails::Railtie do
  let(:rails_env) { double }
  let(:middleware) { double('Middleware', use: true) }
  let(:rails_app) { double('RailsApp', middleware: middleware) }

  before do
    allow(Rails).to receive(:env).and_return(rails_env)
  end

  def run_initializers
    CypressOnRails::Railtie.initializers.each do |initializer|
      initializer.run(rails_app)
    end
  end

  it 'runs the middleware in test mode' do
    run_initializers
  end

  context 'with the default configuration' do
    it 'mounts the middlewares outside of production' do
      allow(Rails).to receive(:env).and_return('development')

      run_initializers

      aggregate_failures do
        expect(middleware).to have_received(:use).with(CypressOnRails::Middleware)
        expect(middleware).to have_received(:use).with(CypressOnRails::StateResetMiddleware)
      end
    end

    it 'does not mount the middlewares in production' do
      allow(Rails).to receive(:env).and_return('production')

      run_initializers

      expect(middleware).to_not have_received(:use)
    end
  end

  it 'mounts the middlewares in production when explicitly configured' do
    allow(Rails).to receive(:env).and_return('production')
    CypressOnRails.configure { |config| config.use_middleware = true }

    run_initializers

    expect(middleware).to have_received(:use).with(CypressOnRails::Middleware)
  end
end
