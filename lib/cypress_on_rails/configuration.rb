require 'logger'

module CypressOnRails
  class Configuration
    attr_accessor :api_prefix, :install_folder, :use_middleware, :use_vcr_middleware, :use_vcr_use_cassette_middleware,
                  :before_request, :logger, :vcr_options, :after_server_start, :after_transaction_start, :after_state_reset, :before_server_stop, :server_port, :transactional_server

    # Server hooks for managing test lifecycle
    attr_accessor :before_server_start

    # Server configuration
    attr_accessor :server_host

    # Attributes for backwards compatibility
    def cypress_folder
      warn 'cypress_folder is deprecated, please use install_folder'
      install_folder
    end

    def cypress_folder=(v)
      warn 'cypress_folder= is deprecated, please use install_folder'
      self.install_folder = v
    end

    def initialize
      reset
    end

    alias use_middleware? use_middleware
    alias use_vcr_middleware? use_vcr_middleware
    alias use_vcr_use_cassette_middleware? use_vcr_use_cassette_middleware

    def reset
      self.api_prefix = ''
      self.install_folder = 'spec/e2e'
      self.use_middleware = true
      self.use_vcr_middleware = false
      self.use_vcr_use_cassette_middleware = false
      self.before_request = ->(request) {}
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
    end

    def tagged_logged(&block)
      if logger.respond_to?(:tagged)
        logger.tagged('CY_DEV', &block)
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
