require 'cypress_on_rails/version'
require 'cypress_on_rails/configuration'
require_relative 'cypress_on_rails/railtie' if defined?(Rails)

# maintain backward compatibility
CypressDev = CypressOnRails unless defined?(CypressDev)
Cypress = CypressDev unless defined?(Cypress)
