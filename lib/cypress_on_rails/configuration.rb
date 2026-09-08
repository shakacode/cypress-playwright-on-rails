require 'logger'

module CypressOnRails
  class Configuration
    DEFAULT_SERVER_SHUTDOWN_TIMEOUT = 10

    attr_accessor :api_prefix
    attr_accessor :install_folder
    attr_accessor :use_middleware
    attr_accessor :use_vcr_middleware
    attr_accessor :use_vcr_use_cassette_middleware
    # Optional shared secret. When set, every middleware that executes
    # commands or resets state requires a matching X-Cypress-On-Rails-Token
    # header. Defaults to ENV['CYPRESS_ON_RAILS_TOKEN'].
    #
    # Always reads back as nil (no token required) or as a non empty string,
    # see #middleware_token=.
    attr_reader :middleware_token
    attr_accessor :logger
    attr_accessor :vcr_options

    # Hooks are user-supplied callables. `before_request` runs inside the
    # middleware; the rest run around the rake-task server lifecycle.
    HOOKS = %i[
      before_request
      before_server_start
      after_server_start
      after_transaction_start
      after_state_reset
      before_server_stop
    ].freeze

    HOOKS.each do |hook_name|
      attr_reader hook_name

      define_method("#{hook_name}=") do |hook|
        unless hook.nil? || hook.respond_to?(:call)
          raise ArgumentError,
                "#{hook_name} must respond to :call (for example a lambda or proc) or be nil, " \
                "got #{hook.inspect}"
        end

        instance_variable_set("@#{hook_name}", hook)
      end
    end

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
    # Seconds to wait after sending TERM before escalating to KILL when stopping
    # the test server process group (default: 10)
    # Can be set via CYPRESS_RAILS_SHUTDOWN_TIMEOUT environment variable
    attr_reader :server_shutdown_timeout

    def server_shutdown_timeout=(value)
      @server_shutdown_timeout = positive_number!(:server_shutdown_timeout, value)
    end

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

    # `nil`, `false` and a blank string all mean "no token required". `false`
    # is worth calling out: it is the natural mistake for anyone copying the
    # neighbouring `use_middleware = false` style, and storing it verbatim
    # would turn the check on with the secret "false" and 403 every request.
    # `true` is rejected outright, because it can only mean a secret the caller
    # never chose. Everything else is stored as its string form.
    def middleware_token=(value)
      if value == true
        raise ArgumentError,
              'CypressOnRails middleware_token must be a secret string, got `true`. ' \
              'Use a random value such as ENV["CYPRESS_ON_RAILS_TOKEN"], ' \
              'or nil/false to disable the token check.'
      end

      token = (value == false ? nil : value).to_s
      @middleware_token = token.empty? ? nil : token
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
      self.server_shutdown_timeout = ENV.fetch('CYPRESS_RAILS_SHUTDOWN_TIMEOUT', DEFAULT_SERVER_SHUTDOWN_TIMEOUT)
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

    # Accepts a Numeric or a numeric String and returns it as a finite number
    # greater than zero, raising ArgumentError with the offending value
    # otherwise. Infinity would make the shutdown deadline unreachable, so the
    # escalation to KILL would never happen.
    def positive_number!(name, value)
      number = coerce_number(value)
      unless number && number > 0
        raise ArgumentError,
              "#{name} must be a finite number of seconds greater than 0, got #{value.inspect}"
      end

      number
    end

    def coerce_number(value)
      number = case value
               when Numeric
                 value
               when String
                 begin
                   Float(value)
                 rescue ArgumentError
                   nil
                 end
               end
      return nil if number.nil?
      return nil unless finite_as_float?(number)

      number
    end

    # An arbitrary-precision Integer answers #finite? with true at any
    # magnitude, but the deadline arithmetic is float: 10**10000 becomes
    # Infinity as soon as it meets the monotonic clock, which puts the
    # shutdown deadline out of reach and stops the TERM-then-KILL escalation
    # from ever firing. Validate the value the deadline will actually use.
    def finite_as_float?(number)
      number.to_f.finite?
    rescue RangeError, NoMethodError
      false
    end
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield configuration if block_given?
  end
end
