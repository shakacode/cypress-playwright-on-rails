require 'cypress_on_rails/configuration'
require_relative 'base_middleware'

module CypressOnRails
  module Vcr
    # Middleware to handle vcr with use_cassette
    class UseCassetteMiddleware < BaseMiddleware
      def initialize(app, vcr = nil)
        @app = app
        @vcr = vcr
      end

      def call(env)
        WebMock.enable! if defined?(WebMock)
        vcr.turn_on!
        request = Rack::Request.new(env)
        cassette_name = fetch_request_cassette(request)
        vcr.use_cassette(cassette_name, { record: configuration.vcr_use_cassette_mode }) do
          logger.info "Handle request with cassette name: #{cassette_name}"
          @app.call(env)
        end
      end

      private

      def fetch_request_cassette(request)
        if request.path.start_with?('/graphql') && request.params.key?('operation')
          "#{request.path}/#{request.params['operation']}"
        else
          request.path
        end
      end
    end
  end
end
