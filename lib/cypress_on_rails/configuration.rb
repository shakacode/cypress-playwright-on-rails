require 'logger'

module CypressOnRails
  class Configuration
    attr_accessor :api_prefix
    attr_accessor :install_folder
    attr_accessor :use_middleware
    attr_accessor :use_vcr_middleware
    attr_accessor :use_vcr_use_cassette_middleware
    attr_accessor :before_request
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
    attr_accessor :server_readiness_path

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

    alias :use_middleware? :use_middleware
    alias :use_vcr_middleware? :use_vcr_middleware
    alias :use_vcr_use_cassette_middleware? :use_vcr_use_cassette_middleware

    def reset
      self.api_prefix = ''
      self.install_folder = 'spec/e2e'
      self.use_middleware = true
      self.use_vcr_middleware = false
      self.use_vcr_use_cassette_middleware = false
      self.before_request = -> (request) {}
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
    end

    def tagged_logged
      if logger.respond_to?(:tagged)
        logger.tagged('CY_DEV') { yield }
      else
        yield
      end
    end
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield configuration if block_given?
  end
end
