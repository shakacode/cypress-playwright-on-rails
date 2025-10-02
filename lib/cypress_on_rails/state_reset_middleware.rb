module CypressOnRails
  class StateResetMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      if ['/__cypress__/reset_state', '/cypress_rails_reset_state'].include?(env['PATH_INFO'])
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
              next if %w[schema_migrations ar_internal_metadata].include?(table)

              connection.execute("DELETE FROM #{connection.quote_table_name(table)}")
            end
          end
        else
          # Fallback to regular deletion with proper table name quoting
          connection.tables.each do |table|
            next if %w[schema_migrations ar_internal_metadata].include?(table)

            connection.execute("DELETE FROM #{connection.quote_table_name(table)}")
          end
        end
      end

      # Clear Rails cache
      Rails.cache.clear if defined?(Rails) && Rails.cache

      # Reset any class-level state
      ActiveSupport::Dependencies.clear if defined?(ActiveSupport::Dependencies)

      # Run after_state_reset hook after cleanup is complete
      run_hook(config.after_state_reset)
    end

    def run_hook(hook)
      hook.call if hook && hook.respond_to?(:call)
    end
  end
end
