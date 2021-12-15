require 'rack'
require 'cypress_on_rails/configuration'

module CypressOnRails
  class VCRWrapper

    def initialize(app:, env:)
      @app = app
      @env = env
      @request = Rack::Request.new(env)
    end

    def run_with_cassette
      VCR.use_cassette(cassette_name, { :record => configuration.vcr_record_mode }) do
        logger.info "Handle request with cassette name: #{cassette_name}"
        @app.call(@env)
      end
    end

    private

    def configuration
      CypressOnRails.configuration
    end

    def logger
      configuration.logger
    end

    def cassette_name
      if @request.path.start_with?('/graphql') && @request.params.key?('operation')
        "#{@request.path}/#{@request.params['operation']}"
      else
        @request.path
      end
    end
  end
end
