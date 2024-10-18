require_relative 'middleware_helpers'

module CypressOnRails
  module Vcr
    # Middleware to handle vcr with use_cassette
    class UseCassetteMiddleware
      include MiddlewareHelpers

      def initialize(app, vcr = nil)
        @app = app
        @vcr = vcr
      end

      def call(env)
        return @app.call(env) if should_not_use_vcr?

        initialize_vcr
        handle_request_with_vcr(env)
      end

      private

      def vcr_defined?
        defined?(VCR) != nil
      end

      def should_not_use_vcr?
        vcr_defined? &&
          VCR.configuration.cassette_library_dir.present? &&
          VCR.configuration.cassette_library_dir != cassette_library_dir
      end

      def initialize_vcr
        WebMock.enable! if defined?(WebMock)
        vcr.turn_on!
      end

      def handle_request_with_vcr(env)
        request = Rack::Request.new(env)
        cassette_name = fetch_request_cassette(request)
        vcr.use_cassette(cassette_name, { record: configuration.vcr_record_mode }) do
          logger.info "Handle request with cassette name: #{cassette_name}"
          @app.call(env)
        end
      end

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
