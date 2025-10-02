require 'cypress_on_rails/railtie'

module Rails
  def self.env; end
end

RSpec.describe CypressOnRails::Railtie do
  let(:rails_env) { double }
  let(:middleware) { double('Middleware', use: true) }
  let(:rails_app) { double('RailsApp', middleware: middleware) }

  before do
    allow(Rails).to receive(:env).and_return(rails_env)
  end

  it 'runs the middleware in test mode' do
    CypressOnRails::Railtie.initializers.each do |initializer|
      initializer.run(rails_app)
    end
  end
end
