require 'json'
require 'rack'
require 'cypress_on_rails/middleware_config'

module CypressOnRails
  module Vcr
    # Base abstract Middleware
    class BaseMiddleware
      include MiddlewareConfig

      def initialize(_app, _vcr = nil)
        raise_not_implemented
      end

      def call(_env)
        raise_not_implemented
      end

      def vcr
        @vcr ||= configure_vcr
      end

      private

      def configure_vcr
        require 'vcr'
        VCR.configure do |config|
          config.cassette_library_dir = "#{configuration.install_folder}/fixtures/vcr_cassettes"
        end
        VCR
      end

      def raise_not_implemented
        raise NotImplementedError,
              'BaseMiddleware can not be initialized directly, use InsertEjectMiddleware or UseCassetteMiddleware'
      end
    end
  end
end
