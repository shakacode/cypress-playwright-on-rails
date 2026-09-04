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

    # Rails >= 7 stores the main autoloader in ActiveSupport::Dependencies
    # .autoloader and leaves it nil whenever reloading is disabled, which is the
    # usual test-environment setting (config.enable_reloading = false). Calling
    # .clear then raises NoMethodError on nil, which turned every state reset
    # request into a 500. Nothing is reloadable in that case, so skip it.
    def clear_autoloaded_constants
      return unless defined?(ActiveSupport::Dependencies)
      return unless ActiveSupport::Dependencies.respond_to?(:clear)
      if ActiveSupport::Dependencies.respond_to?(:autoloader)
        return if ActiveSupport::Dependencies.autoloader.nil?
      end

      ActiveSupport::Dependencies.clear
    end

    def run_hook(hook)
      hook.call if hook && hook.respond_to?(:call)
    end
  end
end
