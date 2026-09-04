require 'logger'

module CypressOnRails
  class Configuration
    attr_accessor :api_prefix
    attr_accessor :install_folder
    attr_accessor :use_middleware
    attr_accessor :use_vcr_middleware
    attr_accessor :use_vcr_use_cassette_middleware
    attr_accessor :before_request
    # Optional shared secret. When set, every middleware that executes
    # commands or resets state requires a matching X-Cypress-On-Rails-Token
    # header. Defaults to ENV['CYPRESS_ON_RAILS_TOKEN'].
    attr_accessor :middleware_token
    attr_accessor :logger
    attr_accessor :vcr_options
    
    # Server hooks for managing test lifecycle
    attr_accessor :before_server_start
    attr_accessor :after_server_start
    attr_accessor :after_transaction_start
    attr_accessor :after_state_reset
    attr_accessor :before_server_stop
    
    # Server configuration
    attr_accessor :server_host
    attr_accessor :server_port
    attr_accessor :transactional_server
    # HTTP path to check for server readiness (default: '/')
    # Can be set via CYPRESS_RAILS_READINESS_PATH environment variable
    attr_accessor :server_readiness_path
    # Timeout in seconds for individual HTTP readiness checks (default: 5)
    # Can be set via CYPRESS_RAILS_READINESS_TIMEOUT environment variable
    attr_accessor :server_readiness_timeout

    # Attributes for backwards compatibility
    def cypress_folder
      warn "cypress_folder is deprecated, please use install_folder"
      install_folder
    end
    def cypress_folder=(v)
      warn "cypress_folder= is deprecated, please use install_folder"
      self.install_folder = v
    end

    def initialize
      reset
    end

    alias :use_vcr_middleware? :use_vcr_middleware
    alias :use_vcr_use_cassette_middleware? :use_vcr_use_cassette_middleware

    # The middleware can execute arbitrary ruby code, so it must never be
    # mounted in production. When `use_middleware` was never assigned we
    # resolve the default lazily: enabled everywhere except Rails production.
    # An explicit assignment (true or false) always wins.
    def use_middleware?
      return use_middleware unless use_middleware.nil?

      !rails_production?
    end

    def reset
      self.api_prefix = ''
      self.install_folder = 'spec/e2e'
      self.use_middleware = nil # nil means "decide from the environment", see #use_middleware?
      self.use_vcr_middleware = false
      self.use_vcr_use_cassette_middleware = false
      self.before_request = -> (request) {}
      self.middleware_token = ENV.fetch('CYPRESS_ON_RAILS_TOKEN', nil)
      self.logger = Logger.new(STDOUT)
      self.vcr_options = {}
      
      # Server hooks
      self.before_server_start = nil
      self.after_server_start = nil
      self.after_transaction_start = nil
      self.after_state_reset = nil
      self.before_server_stop = nil
      
      # Server configuration
      self.server_host = ENV.fetch('CYPRESS_RAILS_HOST', 'localhost')
      self.server_port = ENV.fetch('CYPRESS_RAILS_PORT', nil)
      self.transactional_server = true
      self.server_readiness_path = ENV.fetch('CYPRESS_RAILS_READINESS_PATH', '/')
      self.server_readiness_timeout = ENV.fetch('CYPRESS_RAILS_READINESS_TIMEOUT', '5').to_i
    end

    def tagged_logged
      if logger.respond_to?(:tagged)
        logger.tagged('CY_DEV') { yield }
      else
        yield
      end
    end

    private

    # Works whether or not Rails is loaded, and whether `Rails.env` is an
    # ActiveSupport::StringInquirer, a plain String or not set up yet.
    def rails_production?
      return false unless defined?(Rails) && Rails.respond_to?(:env)

      Rails.env.to_s == 'production'
    end
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield configuration if block_given?
  end
end
