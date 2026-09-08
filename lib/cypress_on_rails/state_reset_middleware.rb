module CypressOnRails
  class StateResetMiddleware
    def initialize(app)
      @app = app
    end
    
    def call(env)
      if env['PATH_INFO'] == '/__cypress__/reset_state' || env['PATH_INFO'] == '/cypress_rails_reset_state'
        reset_application_state
        [200, { 'Content-Type' => 'text/plain' }, ['State reset completed']]
      else
        @app.call(env)
      end
    end
    
    private
    
    def reset_application_state
      config = CypressOnRails.configuration

      # Default state reset actions
      if defined?(DatabaseCleaner)
        DatabaseCleaner.clean_with(:truncation)
      elsif defined?(ActiveRecord::Base)
        connection = ActiveRecord::Base.connection

        # Use disable_referential_integrity if available for safer table clearing
        if connection.respond_to?(:disable_referential_integrity)
          connection.disable_referential_integrity do
            connection.tables.each do |table|
              next if table == 'schema_migrations' || table == 'ar_internal_metadata'
              connection.execute("DELETE FROM #{connection.quote_table_name(table)}")
            end
          end
        else
          # Fallback to regular deletion with proper table name quoting
          connection.tables.each do |table|
            next if table == 'schema_migrations' || table == 'ar_internal_metadata'
            connection.execute("DELETE FROM #{connection.quote_table_name(table)}")
          end
        end
      end

      # Clear Rails cache
      Rails.cache.clear if defined?(Rails) && Rails.cache

      # Reset any class-level state
      clear_autoloaded_constants

      # Run after_state_reset hook after cleanup is complete
      run_hook(config.after_state_reset)
    end

    # Rails only builds a reloadable autoloader when reloading is enabled, and
    # test environments normally disable it (config.enable_reloading = false on
    # Rails 7.1+, config.cache_classes = true before that). Clearing anyway
    # raises, and it raises differently per version: on Rails 7.0+
    # ActiveSupport::Dependencies.autoloader is left nil and .clear fails with
    # NoMethodError, while Rails 6.1 has no .autoloader accessor at all and
    # .clear raises RuntimeError("reloading is disabled ..."). Either way it
    # happened after the tables were truncated, so every state reset returned a
    # 500 from a half-finished reset. Ask the application whether reloading is
    # on first, and keep the nil-autoloader check as a second line of defence.
    def clear_autoloaded_constants
      return unless defined?(ActiveSupport::Dependencies)
      return unless ActiveSupport::Dependencies.respond_to?(:clear)
      return unless application_reloading_enabled?
      if ActiveSupport::Dependencies.respond_to?(:autoloader)
        return if ActiveSupport::Dependencies.autoloader.nil?
      end

      ActiveSupport::Dependencies.clear
    end

    # Defaults to true when there is no Rails application to ask, so plain Rack
    # apps keep the previous behaviour.
    def application_reloading_enabled?
      return true unless defined?(Rails) && Rails.respond_to?(:application) && Rails.application

      config = Rails.application.config
      return config.reloading_enabled? if config.respond_to?(:reloading_enabled?)
      return !config.cache_classes if config.respond_to?(:cache_classes)

      true
    end

    def run_hook(hook)
      hook.call if hook && hook.respond_to?(:call)
    end
  end
end
