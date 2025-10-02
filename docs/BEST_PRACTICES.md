# Best Practices Guide

This guide provides recommended patterns and practices for using cypress-playwright-on-rails effectively.

## Table of Contents
- [Project Structure](#project-structure)
- [Test Organization](#test-organization)
- [Data Management](#data-management)
- [Performance Optimization](#performance-optimization)
- [CI/CD Integration](#cicd-integration)
- [Security Considerations](#security-considerations)
- [Debugging Strategies](#debugging-strategies)
- [Common Patterns](#common-patterns)

## Project Structure

### Recommended Directory Layout
```
├── e2e/                        # All E2E test related files
│   ├── cypress/                # Cypress tests
│   │   ├── e2e/               # Test specs
│   │   │   ├── auth/          # Grouped by feature
│   │   │   ├── users/
│   │   │   └── products/
│   │   ├── fixtures/          # Test data
│   │   ├── support/           # Helpers and commands
│   │   └── downloads/         # Downloaded files during tests
│   ├── playwright/            # Playwright tests
│   │   ├── e2e/              # Test specs
│   │   └── support/          # Helpers
│   ├── app_commands/         # Shared Ruby commands
│   │   ├── scenarios/        # Complex test setups
│   │   └── helpers/          # Ruby helper modules
│   └── shared/               # Shared utilities
└── config/
    └── initializers/
        └── cypress_on_rails.rb # Configuration
```

### Separating Concerns
```ruby
# e2e/app_commands/helpers/test_data.rb
module TestData
  def self.standard_user
    {
      name: 'John Doe',
      email: 'john@example.com',
      role: 'user'
    }
  end
  
  def self.admin_user
    {
      name: 'Admin User',
      email: 'admin@example.com',
      role: 'admin'
    }
  end
end

# e2e/app_commands/scenarios/standard_setup.rb
require_relative '../helpers/test_data'

User.create!(TestData.standard_user)
User.create!(TestData.admin_user)
```

## Test Organization

### Group Related Tests
```js
// e2e/cypress/e2e/users/registration.cy.js
describe('User Registration', () => {
  context('Valid Input', () => {
    it('registers with email', () => {
      // Test implementation
    });
    
    it('registers with social login', () => {
      // Test implementation
    });
  });
  
  context('Invalid Input', () => {
    it('shows error for duplicate email', () => {
      // Test implementation
    });
  });
});
```

### Use Page Objects
```js
// e2e/cypress/support/pages/LoginPage.js
class LoginPage {
  visit() {
    cy.visit('/login');
  }
  
  fillEmail(email) {
    cy.get('[data-cy=email]').type(email);
  }
  
  fillPassword(password) {
    cy.get('[data-cy=password]').type(password);
  }
  
  submit() {
    cy.get('[data-cy=submit]').click();
  }
  
  login(email, password) {
    this.visit();
    this.fillEmail(email);
    this.fillPassword(password);
    this.submit();
  }
}

export default new LoginPage();

// Usage in test
import LoginPage from '../../support/pages/LoginPage';

it('user can login', () => {
  LoginPage.login('user@example.com', 'password');
  cy.url().should('include', '/dashboard');
});
```

### Data-Test Attributes
```erb
<!-- app/views/users/new.html.erb -->
<form data-cy="registration-form">
  <input 
    type="email" 
    name="user[email]" 
    data-cy="email-input"
    data-test-id="user-email"
  />
  <button 
    type="submit" 
    data-cy="submit-button"
    data-test-id="register-submit"
  >
    Register
  </button>
</form>
```

```js
// Prefer data-cy or data-test-id over classes/IDs
cy.get('[data-cy=email-input]').type('test@example.com');
// NOT: cy.get('#email').type('test@example.com');
```

## Data Management

### Factory Bot Best Practices
```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    name { Faker::Name.name }
    confirmed_at { Time.current }
    
    trait :admin do
      role { 'admin' }
    end
    
    trait :with_posts do
      transient do
        posts_count { 3 }
      end
      
      after(:create) do |user, evaluator|
        create_list(:post, evaluator.posts_count, user: user)
      end
    end
  end
end
```

### Scenario Patterns
```ruby
# e2e/app_commands/scenarios/e_commerce_setup.rb
class ECommerceSetup
  def self.run(options = {})
    ActiveRecord::Base.transaction do
      # Create categories
      categories = create_categories
      
      # Create products
      products = create_products(categories)
      
      # Create users
      users = create_users
      
      # Create orders
      create_orders(users, products) if options[:with_orders]
      
      { categories: categories, products: products, users: users }
    end
  end
  
  private
  
  def self.create_categories
    ['Electronics', 'Clothing', 'Books'].map do |name|
      Category.create!(name: name)
    end
  end
  
  def self.create_products(categories)
    # Implementation
  end
end

# Usage in test
ECommerceSetup.run(with_orders: true)
```

### Database Cleaning Strategies
```ruby
# e2e/app_commands/clean.rb
class SmartCleaner
  PRESERVE_TABLES = %w[
    schema_migrations 
    ar_internal_metadata
    spatial_ref_sys  # PostGIS
  ].freeze
  
  def self.clean(strategy: :transaction)
    case strategy
    when :transaction
      DatabaseCleaner.strategy = :transaction
    when :truncation
      DatabaseCleaner.strategy = :truncation, {
        except: PRESERVE_TABLES
      }
    when :deletion
      DatabaseCleaner.strategy = :deletion, {
        except: PRESERVE_TABLES
      }
    end
    
    DatabaseCleaner.clean
    
    # Reset sequences
    reset_sequences if postgresql?
    
    # Clear caches
    clear_caches
  end
  
  private
  
  def self.postgresql?
    ActiveRecord::Base.connection.adapter_name == 'PostgreSQL'
  end
  
  def self.reset_sequences
    ActiveRecord::Base.connection.tables.each do |table|
      ActiveRecord::Base.connection.reset_pk_sequence!(table)
    end
  end
  
  def self.clear_caches
    Rails.cache.clear
    I18n.reload! if defined?(I18n)
  end
end
```

## Performance Optimization

### Minimize Database Operations
```js
// Bad: Multiple database operations
it('creates multiple users', () => {
  cy.appFactories([['create', 'user', { name: 'User 1' }]]);
  cy.appFactories([['create', 'user', { name: 'User 2' }]]);
  cy.appFactories([['create', 'user', { name: 'User 3' }]]);
});

// Good: Batch operations
it('creates multiple users', () => {
  cy.appFactories([
    ['create', 'user', { name: 'User 1' }],
    ['create', 'user', { name: 'User 2' }],
    ['create', 'user', { name: 'User 3' }]
  ]);
});

// Better: Use create_list
it('creates multiple users', () => {
  cy.appFactories([
    ['create_list', 'user', 3]
  ]);
});
```

### Smart Waiting Strategies
```js
// Bad: Fixed waits
cy.wait(5000);

// Good: Wait for specific conditions
cy.get('[data-cy=loading]').should('not.exist');
cy.get('[data-cy=user-list]').should('be.visible');

// Better: Wait for API calls
cy.intercept('GET', '/api/users').as('getUsers');
cy.visit('/users');
cy.wait('@getUsers');
```

### Parallel Testing Configuration
```ruby
# config/database.yml
test:
  <<: *default
  database: myapp_test<%= ENV['TEST_ENV_NUMBER'] %>
  
# config/initializers/cypress_on_rails.rb
if ENV['PARALLEL_WORKERS'].present?
  CypressOnRails.configure do |c|
    worker_id = ENV['TEST_ENV_NUMBER'] || '1'
    c.server_port = 5000 + worker_id.to_i
  end
end
```

## CI/CD Integration

### GitHub Actions Example
```yaml
# .github/workflows/e2e.yml
name: E2E Tests
on: [push, pull_request]

jobs:
  cypress:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        browser: [chrome, firefox, edge]
    
    services:
      postgres:
        image: postgres:14
        env:
          POSTGRES_PASSWORD: password
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      
      - name: Setup Node
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'yarn'
      
      - name: Install dependencies
        run: |
          yarn install --frozen-lockfile
          bundle install
      
      - name: Setup database
        env:
          RAILS_ENV: test
          DATABASE_URL: postgresql://postgres:password@localhost:5432/test
        run: |
          bundle exec rails db:create
          bundle exec rails db:schema:load
      
      - name: Run E2E tests
        env:
          RAILS_ENV: test
          DATABASE_URL: postgresql://postgres:password@localhost:5432/test
        run: |
          bundle exec rails cypress:run
      
      - name: Upload artifacts
        uses: actions/upload-artifact@v3
        if: failure()
        with:
          name: cypress-artifacts-${{ matrix.browser }}
          path: |
            e2e/cypress/screenshots
            e2e/cypress/videos
```

### CircleCI Configuration
```yaml
# .circleci/config.yml
version: 2.1

orbs:
  cypress: cypress-io/cypress@2

jobs:
  e2e-tests:
    docker:
      - image: cimg/ruby:3.2-browsers
      - image: cimg/postgres:14.0
        environment:
          POSTGRES_PASSWORD: password
    
    parallelism: 4
    
    steps:
      - checkout
      
      - restore_cache:
          keys:
            - gem-cache-{{ checksum "Gemfile.lock" }}
            - yarn-cache-{{ checksum "yarn.lock" }}
      
      - run:
          name: Install dependencies
          command: |
            bundle install --path vendor/bundle
            yarn install --frozen-lockfile
      
      - save_cache:
          key: gem-cache-{{ checksum "Gemfile.lock" }}
          paths:
            - vendor/bundle
      
      - save_cache:
          key: yarn-cache-{{ checksum "yarn.lock" }}
          paths:
            - node_modules
      
      - run:
          name: Setup database
          command: |
            bundle exec rails db:create db:schema:load
          environment:
            RAILS_ENV: test
      
      - run:
          name: Run E2E tests
          command: |
            TESTFILES=$(circleci tests glob "e2e/cypress/e2e/**/*.cy.js" | circleci tests split)
            bundle exec rails cypress:run -- --spec $TESTFILES
      
      - store_test_results:
          path: test-results
      
      - store_artifacts:
          path: e2e/cypress/screenshots
      
      - store_artifacts:
          path: e2e/cypress/videos

workflows:
  test:
    jobs:
      - e2e-tests
```

## Security Considerations

### Protecting Test Endpoints
```ruby
# config/initializers/cypress_on_rails.rb
CypressOnRails.configure do |c|
  # Only enable in test/development
  c.use_middleware = !Rails.env.production?
  
  # Add authentication
  c.before_request = lambda { |request|
    # IP whitelist for CI
    allowed_ips = ['127.0.0.1', '::1']
    allowed_ips += ENV['ALLOWED_CI_IPS'].split(',') if ENV['ALLOWED_CI_IPS']
    
    unless allowed_ips.include?(request.ip)
      return [403, {}, ['Forbidden']]
    end
    
    # Token authentication
    body = JSON.parse(request.body.string)
    expected_token = ENV.fetch('CYPRESS_SECRET_TOKEN', 'development-token')
    
    if body['auth_token'] != expected_token
      return [401, {}, ['Unauthorized']]
    end
    
    nil
  }
end
```

### Environment Variables
```bash
# .env.test
CYPRESS_SECRET_TOKEN=secure-random-token-here
CYPRESS_BASE_URL=http://localhost:5017
CYPRESS_RAILS_HOST=localhost
CYPRESS_RAILS_PORT=5017

# Never commit real credentials
DATABASE_URL=postgresql://localhost/myapp_test
REDIS_URL=redis://localhost:6379/1
```

### Sanitizing Test Data
```ruby
# e2e/app_commands/factory_bot.rb
class SafeFactoryBot
  BLOCKED_FACTORIES = %w[admin super_admin payment_method].freeze
  
  def self.create(factory_name, *args)
    raise "Factory '#{factory_name}' is blocked in tests" if BLOCKED_FACTORIES.include?(factory_name.to_s)
    
    FactoryBot.create(factory_name, *args)
  end
end
```

## Debugging Strategies

### Verbose Logging
```ruby
# config/initializers/cypress_on_rails.rb
CypressOnRails.configure do |c|
  c.logger = Logger.new(STDOUT)
  c.logger.level = ENV['DEBUG'] ? Logger::DEBUG : Logger::INFO
end

# e2e/app_commands/debug.rb
def perform
  logger.debug "Current user count: #{User.count}"
  logger.debug "Environment: #{Rails.env}"
  logger.debug "Database: #{ActiveRecord::Base.connection.current_database}"
  
  result = yield if block_given?
  
  logger.debug "Result: #{result.inspect}"
  result
end
```

### Screenshot on Failure
```js
// cypress/support/index.js
Cypress.on('fail', (error, runnable) => {
  // Take screenshot before failing
  cy.screenshot(`failed-${runnable.title}`, { capture: 'fullPage' });
  
  // Log additional debugging info
  cy.task('log', {
    test: runnable.title,
    error: error.message,
    url: cy.url(),
    timestamp: new Date().toISOString()
  });
  
  throw error;
});
```

### Interactive Debugging
```js
// Add debugger statements
it('debug this test', () => {
  cy.appFactories([['create', 'user']]);
  
  cy.visit('/users');
  debugger; // Cypress will pause here in open mode
  
  cy.get('[data-cy=user-list]').should('exist');
});

// Or use cy.pause()
it('pause execution', () => {
  cy.visit('/users');
  cy.pause(); // Manually resume in Cypress UI
  cy.get('[data-cy=user-list]').should('exist');
});
```

## Common Patterns

### Authentication Flow
```js
// cypress/support/commands.js
Cypress.Commands.add('login', (email, password) => {
  cy.session([email, password], () => {
    cy.visit('/login');
    cy.get('[data-cy=email]').type(email);
    cy.get('[data-cy=password]').type(password);
    cy.get('[data-cy=submit]').click();
    cy.url().should('include', '/dashboard');
  });
});

// Usage
beforeEach(() => {
  cy.login('user@example.com', 'password');
});
```

### File Upload Testing
```js
it('uploads a file', () => {
  cy.fixture('document.pdf', 'base64').then(fileContent => {
    cy.get('[data-cy=file-input]').attachFile({
      fileContent,
      fileName: 'document.pdf',
      mimeType: 'application/pdf',
      encoding: 'base64'
    });
  });
  
  cy.get('[data-cy=upload-button]').click();
  cy.contains('File uploaded successfully');
});
```

### API Mocking
```js
it('handles API errors gracefully', () => {
  // Mock failed API response
  cy.intercept('POST', '/api/users', {
    statusCode: 500,
    body: { error: 'Internal Server Error' }
  }).as('createUser');
  
  cy.visit('/users/new');
  cy.get('[data-cy=submit]').click();
  
  cy.wait('@createUser');
  cy.contains('Something went wrong');
});
```

### Testing Async Operations
```js
it('waits for async operations', () => {
  // Start a background job
  cy.appEval(`
    ImportJob.perform_later('large_dataset.csv')
  `);
  
  cy.visit('/imports');
  
  // Poll for completion
  cy.get('[data-cy=import-status]', { timeout: 30000 })
    .should('contain', 'Completed');
});
```

## Summary

Following these best practices will help you:
- Write more maintainable and reliable tests
- Improve test performance and reduce flakiness
- Better organize your test code
- Secure your test infrastructure
- Debug issues more effectively

Remember: E2E tests should focus on critical user journeys. Use unit and integration tests for comprehensive coverage of edge cases.
