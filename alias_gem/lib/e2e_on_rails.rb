# frozen_string_literal: true

# The parent gem's entry point is lib/cypress-on-rails.rb (dashed); there is no
# lib/cypress_on_rails.rb, so requiring the underscored name would raise LoadError.
require 'cypress-on-rails'
