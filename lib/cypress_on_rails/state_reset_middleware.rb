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
      
      # Run after_state_reset hook if configured
      run_hook(config.after_state_reset)
      
      # Default state reset actions
      if defined?(DatabaseCleaner)
        DatabaseCleaner.clean_with(:truncation)
      elsif defined?(ActiveRecord::Base)
        ActiveRecord::Base.connection.tables.each do |table|
          next if table == 'schema_migrations' || table == 'ar_internal_metadata'
          ActiveRecord::Base.connection.execute("DELETE FROM #{table}")
        end
      end
      
      # Clear Rails cache
      Rails.cache.clear if defined?(Rails) && Rails.cache
      
      # Reset any class-level state
      ActiveSupport::Dependencies.clear if defined?(ActiveSupport::Dependencies)
    end
    
    def run_hook(hook)
      hook.call if hook && hook.respond_to?(:call)
    end
  end
end