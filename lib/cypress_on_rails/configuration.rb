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
    attr_accessor :vcr_record_mode

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
      self.vcr_record_mode = :new_episodes
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
