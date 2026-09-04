require 'json'
require 'rack'
require 'cypress_on_rails/configuration'

module CypressOnRails
  # Optional shared secret check for the middlewares that can execute commands
  # or reset application state.
  #
  # It is disabled unless `CypressOnRails.configuration.middleware_token` is
  # set (it defaults to ENV['CYPRESS_ON_RAILS_TOKEN']), so behaviour is
  # unchanged for anyone who does not opt in. It is deliberately thin sugar
  # over the same code path as `before_request`, which remains the general
  # purpose hook for custom authentication.
  module TokenAuthentication
    # Header the generated cypress/playwright helpers send.
    TOKEN_HEADER = 'X-Cypress-On-Rails-Token'.freeze
    # The same header, as rack exposes it in the request env.
    TOKEN_ENV_KEY = "HTTP_#{TOKEN_HEADER.upcase.tr('-', '_')}".freeze

    protected

    # @param env [Hash] the rack env of the incoming request
    # @return [Array, nil] a rack response when the request must be rejected,
    #   nil when the request may continue
    def invalid_middleware_token_response(env)
      expected = CypressOnRails.configuration.middleware_token.to_s
      return nil if expected.empty?
      return nil if middleware_token_matches?(env[TOKEN_ENV_KEY], expected)

      [403,
       { 'Content-Type' => 'application/json' },
       [{ 'message' => 'invalid or missing token' }.to_json]]
    end

    private

    def middleware_token_matches?(provided, expected)
      return false if provided.nil?

      secure_token_compare(provided.to_s, expected)
    end

    # Rack only code paths cannot assume ActiveSupport is loaded.
    def secure_token_compare(left, right)
      if defined?(ActiveSupport::SecurityUtils) &&
         ActiveSupport::SecurityUtils.respond_to?(:secure_compare)
        ActiveSupport::SecurityUtils.secure_compare(left, right)
      else
        Rack::Utils.secure_compare(left, right)
      end
    end
  end
end
