require 'cypress_on_rails/middleware_config'

module CypressOnRails
  module Vcr
    # Provides helper methods for VCR middlewares
    module MiddlewareHelpers
      include MiddlewareConfig

      def vcr
        @vcr ||= configure_vcr
      end

      def cassette_library_dir
        "#{configuration.install_folder}/fixtures/vcr_cassettes"
      end

      private

      def configure_vcr
        require 'vcr'
        VCR.configure do |config|
          config.cassette_library_dir = cassette_library_dir
        end
        VCR
      end
    end
  end
end
