namespace :cypress do
  desc "Open Cypress test runner UI"
  task :open => :environment do
    require 'cypress_on_rails/server'
    CypressOnRails::Server.new.open
  end

  desc "Run Cypress tests in headless mode"
  task :run => :environment do
    require 'cypress_on_rails/server'
    CypressOnRails::Server.new.run
  end

  desc "Initialize Cypress configuration"
  task :init => :environment do
    require 'cypress_on_rails/server'
    CypressOnRails::Server.new.init
  end
end

namespace :playwright do
  desc "Open Playwright test runner UI"
  task :open => :environment do
    require 'cypress_on_rails/server'
    CypressOnRails::Server.new(framework: :playwright).open
  end

  desc "Run Playwright tests in headless mode"
  task :run => :environment do
    require 'cypress_on_rails/server'
    CypressOnRails::Server.new(framework: :playwright).run
  end
end