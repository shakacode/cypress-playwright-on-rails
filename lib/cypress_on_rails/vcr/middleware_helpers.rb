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
        configuration.vcr_options&.fetch(:cassette_library_dir) do
          "#{configuration.install_folder}/fixtures/vcr_cassettes"
        end
      end

      private

      def configure_vcr
        require 'vcr'
        VCR.configure do |config|
          config.cassette_library_dir = cassette_library_dir
          apply_vcr_options(config) if configuration.vcr_options.present?
        end
        VCR
      end

      def apply_vcr_options(config)
        configuration.vcr_options.each do |option, value|
          next if option.to_sym == :cassette_library_dir

          apply_vcr_option(config, option, value)
        end
      end

      def apply_vcr_option(config, option, value)
        return unless config.respond_to?(option) || config.respond_to?("#{option}=")

        if config.respond_to?("#{option}=")
          config.send("#{option}=", value)
        elsif value.is_a?(Array)
          config.send(option, *value)
        else
          config.send(option, value)
        end
      end
    end
  end
end
