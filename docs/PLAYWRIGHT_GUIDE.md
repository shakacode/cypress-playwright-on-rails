# Complete Playwright Guide

This guide provides comprehensive documentation for using Playwright with cypress-playwright-on-rails.

## Table of Contents
- [Installation](#installation)
- [Basic Setup](#basic-setup)
- [Commands and Helpers](#commands-and-helpers)
- [Factory Bot Integration](#factory-bot-integration)
- [Fixtures and Scenarios](#fixtures-and-scenarios)
- [Database Management](#database-management)
- [Advanced Configuration](#advanced-configuration)
- [Migration from Cypress](#migration-from-cypress)

## Installation

### 1. Add the gem to your Gemfile
```ruby
group :test, :development do
  gem 'cypress-on-rails', '~> 1.0'
end
```

### 2. Install with Playwright framework
```bash
bundle install
bin/rails g cypress_on_rails:install --framework playwright

# Or with custom folder
bin/rails g cypress_on_rails:install --framework playwright --install_folder=spec/e2e
```

### 3. Install Playwright
```bash
# Using yarn
yarn add -D @playwright/test

# Using npm
npm install --save-dev @playwright/test

# Install browsers
npx playwright install
```

## Basic Setup

### Directory Structure
```
e2e/
├── playwright/
│   ├── e2e/                    # Test files
│   │   └── example.spec.js
│   ├── support/
│   │   └── on-rails.js        # Helper functions
│   ├── e2e_helper.rb          # Ruby helper
│   └── app_commands/          # Ruby commands
│       ├── clean.rb
│       ├── factory_bot.rb
│       └── scenarios/
│           └── basic.rb
└── playwright.config.js       # Playwright configuration
```

### Playwright Configuration
```js
// playwright.config.js
module.exports = {
  testDir: './e2e/playwright/e2e',
  timeout: 30000,
  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:5017',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure'
  },
  projects: [
    { name: 'chromium', use: { browserName: 'chromium' } },
    { name: 'firefox', use: { browserName: 'firefox' } },
    { name: 'webkit', use: { browserName: 'webkit' } }
  ]
};
```

## Commands and Helpers

### Complete on-rails.js Helper File
```js
// e2e/playwright/support/on-rails.js
const { request } = require('@playwright/test');

const API_PREFIX = '';  // or '/api' if configured

async function appCommands(body) {
  const context = await request.newContext();
  const response = await context.post(`${API_PREFIX}/__e2e__/command`, {
    data: body,
    headers: {
      'Content-Type': 'application/json'
    }
  });

  if (!response.ok()) {
    const text = await response.text();
    throw new Error(`Command failed: ${response.status()} - ${text}`);
  }

  return response.json();
}

async function app(name, commandOptions = {}) {
  const result = await appCommands({ 
    name, 
    options: commandOptions 
  });
  return result[0];
}

async function appScenario(name, options = {}) {
  return app(`scenarios/${name}`, options);
}

async function appFactories(factories) {
  return app('factory_bot', factories);
}

async function appFixtures() {
  return app('activerecord_fixtures');
}

async function appClean() {
  return app('clean');
}

async function appEval(code) {
  return app('eval', { code });
}

module.exports = {
  app,
  appCommands,
  appScenario,
  appFactories,
  appFixtures,
  appClean,
  appEval
};
```

### Using Helpers in Tests
```js
// e2e/playwright/e2e/user.spec.js
const { test, expect } = require('@playwright/test');
const { app, appFactories, appScenario, appClean } = require('../support/on-rails');

test.describe('User Management', () => {
  test.beforeEach(async () => {
    await appClean();
  });

  test('create and view user', async ({ page }) => {
    // Create user with factory bot
    const users = await appFactories([
      ['create', 'user', { name: 'John Doe', email: 'john@example.com' }]
    ]);
    
    await page.goto(`/users/${users[0].id}`);
    await expect(page.locator('h1')).toContainText('John Doe');
  });

  test('load scenario', async ({ page }) => {
    await appScenario('user_with_posts');
    await page.goto('/users');
    await expect(page.locator('.user-count')).toContainText('5 users');
  });
});
```

## Factory Bot Integration

### Creating Records
```js
test('factory bot examples', async ({ page }) => {
  // Single record
  const user = await appFactories([
    ['create', 'user', { name: 'Alice' }]
  ]);

  // Multiple records
  const posts = await appFactories([
    ['create_list', 'post', 3, { published: true }]
  ]);

  // With traits
  const adminUser = await appFactories([
    ['create', 'user', 'admin', { name: 'Admin User' }]
  ]);

  // With associations
  const postWithComments = await appFactories([
    ['create', 'post', 'with_comments', { comment_count: 5 }]
  ]);

  // Building without saving
  const userData = await appFactories([
    ['build', 'user', { name: 'Not Saved' }]
  ]);
});
```

### Using Attributes For
```js
test('get factory attributes', async ({ page }) => {
  const attributes = await appFactories([
    ['attributes_for', 'user']
  ]);
  
  // Use attributes to fill form
  await page.fill('[name="user[name]"]', attributes[0].name);
  await page.fill('[name="user[email]"]', attributes[0].email);
});
```

## Fixtures and Scenarios

### Loading Rails Fixtures
```js
test('load fixtures', async ({ page }) => {
  await appFixtures();
  
  await page.goto('/products');
  // Fixtures are loaded
});
```

### Creating Scenarios
```ruby
# e2e/playwright/app_commands/scenarios/complex_setup.rb
# Create a complex test scenario
5.times do |i|
  user = User.create!(
    name: "User #{i}",
    email: "user#{i}@example.com"
  )
  
  3.times do |j|
    user.posts.create!(
      title: "Post #{j} by User #{i}",
      content: "Content for post #{j}",
      published: j.even?
    )
  end
end

# Add some comments
Post.published.each do |post|
  2.times do
    post.comments.create!(
      author: "Commenter",
      content: "Great post!"
    )
  end
end
```

Using scenarios in tests:
```js
test('complex scenario', async ({ page }) => {
  await appScenario('complex_setup');
  
  await page.goto('/posts');
  await expect(page.locator('.post')).toHaveCount(15);
  await expect(page.locator('.published')).toHaveCount(7);
});
```

## Database Management

### Cleaning Between Tests
```js
// Global setup
test.beforeEach(async () => {
  await appClean();
});

// Or selectively
test('with fresh database', async ({ page }) => {
  await appClean();
  await app('load_seed');  // Optionally load seeds
  
  // Your test here
});
```

### Custom Clean Commands
```ruby
# e2e/playwright/app_commands/clean.rb
if defined?(DatabaseCleaner)
  DatabaseCleaner.strategy = :truncation
  DatabaseCleaner.clean
else
  # Manual cleaning
  tables = ActiveRecord::Base.connection.tables
  tables.delete('schema_migrations')
  tables.delete('ar_internal_metadata')
  
  tables.each do |table|
    ActiveRecord::Base.connection.execute("DELETE FROM #{table}")
  end
end

# Reset sequences for PostgreSQL
if ActiveRecord::Base.connection.adapter_name == 'PostgreSQL'
  ActiveRecord::Base.connection.tables.each do |table|
    ActiveRecord::Base.connection.reset_pk_sequence!(table)
  end
end

Rails.cache.clear if Rails.cache
```

## Advanced Configuration

### Running Custom Ruby Code
```js
test('execute ruby code', async ({ page }) => {
  // Run arbitrary Ruby code
  const result = await appEval(`
    User.count
  `);
  console.log('User count:', result);

  // More complex evaluation
  const stats = await appEval(`
    {
      users: User.count,
      posts: Post.count,
      latest_user: User.last&.name
    }
  `);
});
```

### Authentication for Commands
```js
// e2e/playwright/support/authenticated-on-rails.js
const TOKEN = process.env.CYPRESS_SECRET_TOKEN;

async function authenticatedCommand(name, options = {}) {
  const context = await request.newContext();
  const response = await context.post('/__e2e__/command', {
    data: {
      name,
      options,
      cypress_token: TOKEN
    },
    headers: {
      'Content-Type': 'application/json'
    }
  });
  
  if (response.status() === 401) {
    throw new Error('Authentication failed');
  }
  
  return response.json();
}
```

### Parallel Testing
```js
// playwright.config.js
module.exports = {
  workers: 4,  // Run 4 tests in parallel
  fullyParallel: true,
  
  use: {
    // Each worker gets unique database
    baseURL: process.env.BASE_URL || 'http://localhost:5017',
  },
  
  globalSetup: './global-setup.js',
  globalTeardown: './global-teardown.js'
};

// global-setup.js
module.exports = async config => {
  // Setup databases for parallel workers
  for (let i = 0; i < config.workers; i++) {
    process.env[`TEST_ENV_NUMBER_${i}`] = i.toString();
  }
};
```

## Migration from Cypress

### Command Comparison

| Cypress | Playwright |
|---------|------------|
| `cy.app('clean')` | `await app('clean')` |
| `cy.appFactories([...])` | `await appFactories([...])` |
| `cy.appScenario('name')` | `await appScenario('name')` |
| `cy.visit('/path')` | `await page.goto('/path')` |
| `cy.contains('text')` | `await expect(page.locator('text')).toBeVisible()` |
| `cy.get('.class')` | `page.locator('.class')` |
| `cy.click()` | `await locator.click()` |

### Converting Test Files
```js
// Cypress version
describe('Test', () => {
  beforeEach(() => {
    cy.app('clean');
    cy.appFactories([
      ['create', 'user', { name: 'Test' }]
    ]);
  });
  
  it('works', () => {
    cy.visit('/users');
    cy.contains('Test');
  });
});

// Playwright version
const { test, expect } = require('@playwright/test');
const { app, appFactories } = require('../support/on-rails');

test.describe('Test', () => {
  test.beforeEach(async () => {
    await app('clean');
    await appFactories([
      ['create', 'user', { name: 'Test' }]
    ]);
  });
  
  test('works', async ({ page }) => {
    await page.goto('/users');
    await expect(page.locator('text=Test')).toBeVisible();
  });
});
```

## Running Tests

### Using Rake Tasks
```bash
# Open Playwright UI
bin/rails playwright:open

# Run tests headless
bin/rails playwright:run
```

### Manual Execution
```bash
# Start Rails server
CYPRESS=1 bin/rails server -p 5017

# In another terminal
npx playwright test

# With specific browser
npx playwright test --project=chromium

# With UI mode
npx playwright test --ui

# Debug mode
npx playwright test --debug
```

### CI Configuration
```yaml
# .github/workflows/playwright.yml
name: Playwright Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      
      - run: yarn install
      - run: npx playwright install --with-deps
      
      - run: bundle exec rails db:create db:schema:load
        env:
          RAILS_ENV: test
      
      - run: bundle exec rails playwright:run
        env:
          RAILS_ENV: test
      
      - uses: actions/upload-artifact@v3
        if: failure()
        with:
          name: playwright-traces
          path: test-results/
```

## Best Practices

1. **Always clean between tests** to ensure isolation
2. **Use Page Object Model** for complex applications
3. **Leverage Playwright's auto-waiting** instead of explicit waits
4. **Run tests in parallel** for faster CI
5. **Use fixtures for static data**, factories for dynamic data
6. **Commit test recordings** for debugging failures

## Debugging

### Enable Debug Mode
```bash
# Run with debug
PWDEBUG=1 npx playwright test

# This will:
# - Open browser in headed mode
# - Open Playwright Inspector
# - Pause at the start of each test
```

### Using Traces
```js
// Enable traces for debugging
const { chromium } = require('playwright');

test('debug this', async ({ page }, testInfo) => {
  // Start tracing
  await page.context().tracing.start({ 
    screenshots: true, 
    snapshots: true 
  });
  
  // Your test
  await page.goto('/');
  
  // Save trace
  await page.context().tracing.stop({ 
    path: `trace-${testInfo.title}.zip` 
  });
});
```

View traces:
```bash
npx playwright show-trace trace-debug-this.zip
```