require 'active_support/core_ext/module/delegation'
require 'rails/railtie'
require 'cypress_on_rails/configuration'

module CypressOnRails
  class Railtie < Rails::Railtie
    rake_tasks do
      load 'tasks/cypress.rake'
    end
    initializer :setup_cypress_middleware, after: :load_config_initializers do |app|
      if CypressOnRails.configuration.use_middleware?
        require 'cypress_on_rails/middleware'
        app.middleware.use Middleware
        
        # Add state reset middleware for compatibility with cypress-rails
        require 'cypress_on_rails/state_reset_middleware'
        app.middleware.use StateResetMiddleware
      end
      if CypressOnRails.configuration.use_vcr_middleware?
        require 'cypress_on_rails/vcr/insert_eject_middleware'
        app.middleware.use Vcr::InsertEjectMiddleware
      end
      if CypressOnRails.configuration.use_vcr_use_cassette_middleware?
        if CypressOnRails.configuration.use_vcr_middleware?
          raise 'Configure only one VCR middleware at a time: use_vcr_middleware OR use_vcr_use_cassette_middleware'
        end

        require 'cypress_on_rails/vcr/use_cassette_middleware'
        app.middleware.use Vcr::UseCassetteMiddleware
      end
    end
  end
end
