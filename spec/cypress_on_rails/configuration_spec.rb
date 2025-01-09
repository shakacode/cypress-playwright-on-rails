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
    end
    expect(CypressOnRails.configuration.api_prefix).to eq('/api')
    expect(CypressOnRails.configuration.install_folder).to eq('my/path')
    expect(CypressOnRails.configuration.use_middleware?).to eq(false)
    expect(CypressOnRails.configuration.logger).to eq(my_logger)
    expect(CypressOnRails.configuration.before_request).to eq(before_request_lambda)
    expect(CypressOnRails.configuration.vcr_options).to eq(hook_into: :webmock)
  end
end
