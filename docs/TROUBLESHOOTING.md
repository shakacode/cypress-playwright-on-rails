# Troubleshooting Guide

This guide addresses common issues and questions when using cypress-playwright-on-rails.

## Table of Contents
- [VCR Integration Issues](#vcr-integration-issues)
- [Playwright Support](#playwright-support)
- [Test Environment Configuration](#test-environment-configuration)
- [Database and Transaction Issues](#database-and-transaction-issues)
- [Authentication and Security](#authentication-and-security)
- [Performance and Parallel Testing](#performance-and-parallel-testing)
- [Common Errors](#common-errors)

## VCR Integration Issues

### Issue: "No route matches [POST] '/api/__e2e__/vcr/insert'" (#175)

**Problem:** VCR middleware is not properly configured or mounted.

**Solution:**
1. Ensure VCR middleware is enabled in `config/initializers/cypress_on_rails.rb`:
```ruby
CypressOnRails.configure do |c|
  c.use_vcr_middleware = !Rails.env.production? && ENV['CYPRESS'].present?
  
  c.vcr_options = {
    hook_into: :webmock,
    default_cassette_options: { record: :once },
    cassette_library_dir: Rails.root.join('spec/fixtures/vcr_cassettes')
  }
end
```

2. Add to your `cypress/support/index.js`:
```js
import 'cypress-on-rails/support/index'
```

3. Make sure your API prefix matches:
```ruby
c.api_prefix = '/api'  # If your app uses /api prefix
```

### Using VCR with GraphQL (#160)

For GraphQL operations with `use_cassette`:
```ruby
CypressOnRails.configure do |c|
  c.use_vcr_use_cassette_middleware = !Rails.env.production? && ENV['CYPRESS'].present?
  # Note: Don't enable both VCR middlewares simultaneously
end
```

Add to `cypress/support/commands.js`:
```js
Cypress.Commands.add('mockGraphQL', () => {
  cy.on('window:before:load', (win) => {
    const originalFetch = win.fetch;
    const fetch = (path, options, ...rest) => {
      if (options && options.body) {
        try {
          const body = JSON.parse(options.body);
          if (body.operationName) {
            return originalFetch(`${path}?operation=${body.operationName}`, options, ...rest);
          }
        } catch (e) {
          return originalFetch(path, options, ...rest);
        }
      }
      return originalFetch(path, options, ...rest);
    };
    cy.stub(win, 'fetch', fetch);
  });
});
```

## Playwright Support

### Loading Fixtures in Playwright (#169)

While Cypress has `cy.appFixtures()`, Playwright requires a different approach:

**Solution 1: Create helper functions**
```js
// spec/playwright/support/on-rails.js
async function appFixtures() {
  const response = await page.request.post('/__e2e__/command', {
    data: {
      name: 'activerecord_fixtures',
      options: {}
    }
  });
  return response.json();
}

// Use in tests
test('load fixtures', async ({ page }) => {
  await appFixtures();
  await page.goto('/');
});
```

**Solution 2: Use Factory Bot instead**
```js
// spec/playwright/support/factories.js
async function appFactories(factories) {
  const response = await page.request.post('/__e2e__/command', {
    data: {
      name: 'factory_bot',
      options: factories
    }
  });
  return response.json();
}

// Use in tests
test('create data', async ({ page }) => {
  await appFactories([
    ['create', 'user', { name: 'Test User' }]
  ]);
  await page.goto('/users');
});
```

## Test Environment Configuration

### Running Tests in Test Environment with Change Detection (#157)

**Problem:** Running in development mode has different configuration than test mode.

**Solution 1: Configure test environment with file watching**
```ruby
# config/environments/test.rb
if ENV['CYPRESS'].present?
  # Enable file watching in test environment for Cypress
  config.file_watcher = ActiveSupport::FileUpdateChecker
  config.cache_classes = false
  config.reload_classes_only_on_change = true
end
```

**Solution 2: Use custom environment**
```bash
# Create config/environments/cypress.rb based on test.rb
cp config/environments/test.rb config/environments/cypress.rb

# Modify cypress.rb to enable reloading
# Run with:
RAILS_ENV=cypress CYPRESS=1 bin/rails server
```

### Headless Mode Configuration (#118)

To run Cypress in truly headless mode:
```bash
# For CI/headless execution
bin/rails cypress:run

# Or manually:
CYPRESS=1 bin/rails server -p 5017 &
yarn cypress run --headless --project ./e2e
```

## Database and Transaction Issues

### ApplicationRecord MySQL Error (#155)

**Problem:** ApplicationRecord being queried as a table.

**Solution:** Exclude ApplicationRecord from logging:
```ruby
# spec/e2e/app_commands/log_fail.rb
def perform
  load "#{Rails.root}/db/seeds.rb" if options && options['load_seeds']
  
  descendants = ActiveRecord::Base.descendants
  # Exclude abstract classes
  descendants.reject! { |model| model.abstract_class? || model == ApplicationRecord }
  
  descendants.each_with_object({}) do |model, result|
    result[model.name] = model.limit(100).map(&:attributes)
  rescue => e
    result[model.name] = { error: e.message }
  end
end
```

### Using Rails Transactional Fixtures (#114)

Instead of database_cleaner, use Rails built-in transactional fixtures:

```ruby
# spec/e2e/app_commands/clean.rb
require 'active_record/test_fixtures'

class TransactionalClean
  include ActiveRecord::TestFixtures
  
  def perform
    setup_fixtures
    yield if block_given?
  ensure
    teardown_fixtures
  end
end

# Use with new rake tasks:
CypressOnRails.configure do |c|
  c.transactional_server = true  # Enables automatic rollback
end
```

## Authentication and Security

### Authenticating Commands (#137)

Protect your commands with authentication:

```ruby
# config/initializers/cypress_on_rails.rb
CypressOnRails.configure do |c|
  c.before_request = lambda { |request|
    body = JSON.parse(request.body.string)
    
    # Option 1: Token-based auth
    if body['cypress_token'] != ENV.fetch('CYPRESS_SECRET_TOKEN')
      return [401, {}, ['unauthorized']]
    end
    
    # Option 2: Warden/Devise auth
    # if !request.env['warden'].authenticate(:secret_key)
    #   return [403, {}, ['forbidden']]
    # end
    
    nil  # Continue with command execution
  }
end
```

In Cypress tests:
```js
Cypress.Commands.overwrite('app', (originalFn, name, options) => {
  return originalFn(name, {
    ...options,
    cypress_token: Cypress.env('SECRET_TOKEN')
  });
});
```

## Performance and Parallel Testing

### Parallel Test Execution (#119)

While not built-in, you can achieve parallel testing:

**Option 1: Using cypress-parallel**
```bash
yarn add -D cypress-parallel

# In package.json
"scripts": {
  "cy:parallel": "cypress-parallel -s cy:run -t 4"
}
```

**Option 2: Database partitioning**
```ruby
# config/initializers/cypress_on_rails.rb
if ENV['CYPRESS_PARALLEL_ID'].present?
  # Use different database per parallel process
  config.database_name = "test_cypress_#{ENV['CYPRESS_PARALLEL_ID']}"
end
```

**Option 3: CircleCI Parallelization**
```yaml
# .circleci/config.yml
jobs:
  cypress:
    parallelism: 4
    steps:
      - run:
          command: |
            TESTFILES=$(circleci tests glob "e2e/**/*.cy.js" | circleci tests split)
            yarn cypress run --spec $TESTFILES
```

## Common Errors

### Webpack Compilation Error (#146)

**Error:** "Module not found: Error: Can't resolve 'cypress-factory'"

**Solution:** This is usually a path issue. Check:
1. Your support file imports the correct path:
```js
// cypress/support/index.js
import './on-rails'  // Not 'cypress-factory'
```

2. Ensure the file exists at the expected location
3. Clear Cypress cache if needed:
```bash
yarn cypress cache clear
yarn install
```

### Server Not Starting

If rake tasks fail to start the server:
```ruby
# Check for port conflicts
lsof -i :3001

# Use a different port
CYPRESS_RAILS_PORT=5017 bin/rails cypress:open

# Or configure in initializer
CypressOnRails.configure do |c|
  c.server_port = 5017
end
```

### State Not Resetting Between Tests

Ensure clean state:
```js
// cypress/support/index.js
beforeEach(() => {
  cy.app('clean');
  cy.app('load_seed');  // Optional
});

// Or use state reset endpoint
beforeEach(() => {
  cy.request('POST', '/cypress_rails_reset_state');
});
```

## Getting Help

If you encounter issues not covered here:

1. Check existing [GitHub issues](https://github.com/shakacode/cypress-playwright-on-rails/issues)
2. Search the [Slack channel](https://join.slack.com/t/reactrails/shared_invite/enQtNjY3NTczMjczNzYxLTlmYjdiZmY3MTVlMzU2YWE0OWM0MzNiZDI0MzdkZGFiZTFkYTFkOGVjODBmOWEyYWQ3MzA2NGE1YWJjNmVlMGE)
3. Post in the [forum](https://forum.shakacode.com/c/cypress-on-rails/55)
4. Create a new issue with:
   - Your Rails version
   - cypress-on-rails version
   - Minimal reproduction steps
   - Full error messages and stack traces
