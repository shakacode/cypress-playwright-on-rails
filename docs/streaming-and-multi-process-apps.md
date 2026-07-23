# Streaming RSC and Multi-Process Testing with Playwright

This guide explains how to use React Server Components (RSC) streaming features with the cypress-on-rails gem and how to configure multi-process testing for improved performance.

## Table of Contents
- [Understanding Streaming RSC in Rails](#understanding-streaming-rsc-in-rails)
- [Setting Up Streaming RSC with Cypress on Rails](#setting-up-streaming-rsc-with-cypress-on-rails)
- [Multi-Process Testing with Playwright](#multi-process-testing-with-playwright)
- [Configuration Options](#configuration-options)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Understanding Streaming RSC in Rails

React Server Components (RSC) allow React components to be rendered on the server and streamed to the client as HTML. This approach can significantly improve initial load times and SEO by sending HTML first, then hydrating with JavaScript.

When using Rails as a backend for a React application with RSC:

1. Rails serves as the API/backend
2. React components (both server and client components) are rendered by a Node.js server
3. The rendered HTML is streamed to the client
4. Client-side JavaScript hydrates the components for interactivity

For end-to-end testing with cypress-on-rails, you need to ensure that:
- Your Rails API endpoints are properly mocked or served
- The frontend development server (likely Next.js or similar) is running
- Streaming responses are handled correctly during tests

## Setting Up Streaming RSC with Cypress on Rails

To test applications that use Streaming RSC with cypress-on-rails:

### 1. Architecture Setup

Your application likely consists of:
- Rails API backend (handled by cypress-on-rails)
- Next.js frontend application (or similar React framework)
- Database (PostgreSQL, MySQL, etc.)

### 2. Test Environment Configuration

Ensure both your Rails server and frontend dev server are running during tests:

```ruby
# config/initializers/cypress_on_rails.rb
CypressOnRails.configure do |c|
  # Start both Rails and frontend dev server
  c.server_command = -> do
    # Start Rails server
    rails_pid = spawn("bundle exec rails server -p 5000")
    
    # Start frontend dev server (adjust command for your setup)
    frontend_pid = spawn("npm run dev", chdir: "../frontend")
    
    # Return both PIDs for cleanup
    [rails_pid, frontend_pid]
  end
  
  # Clean up both servers
  c.server_cleanup = ->(pids) do
    Array(pids).each do |pid|
      Process.kill("TERM", pid) rescue Errno::ESRCH
    end
  end
end
```

### 3. Handling Streaming Responses in Tests

When testing pages that use streaming RSC:

```javascript
// e2e/playwright/e2e/dashboard.spec.js
const { test, expect } = require('@playwright/test');
const { app, appClean } = require('../support/on-rails');

test.describe('Dashboard with Streaming RSC', () => {
  test.beforeEach(async () => {
    await appClean(); // Clean database between tests
  });

  test('displays streamed content correctly', async ({ page }) => {
    // Navigate to a page that uses streaming RSC
    await page.goto('/dashboard');
    
    // Wait for initial HTML to load (from stream)
    await expect(page.locator('h1')).toHaveText('Dashboard', { timeout: 10000 });
    
    // Wait for hydration to complete and interactive elements to be ready
    await expect(page.locator('[data-loading="false"]')).toBeVisible();
    
    // Interact with hydrated components
    await page.click('[data-action="refresh"]');
    await expect(page.locator('.refresh-status')).toHaveText('Updated just now');
  });
});
```

## Multi-Process Testing with Playwright

Running tests in parallel can significantly reduce test suite execution time. Here's how to configure multi-process testing with Playwright and cypress-on-rails.

### 1. Database Configuration for Parallel Testing

Each parallel process needs its own database to avoid conflicts:

```ruby
# config/environments/test.rb
if ENV['TEST_ENV_NUMBER'].present?
  # Use different database for each parallel process
  config.database_name = "myapp_test#{ENV['TEST_ENV_NUMBER']}"
end
```

Or using the built-in Rails mechanism:

```yaml
# config/database.yml
test:
  <<: *default
  database: myapp_test<%= ENV['TEST_ENV_NUMBER'] %>
```

### 2. Parallel Configuration in Playwright

Update your Playwright configuration to run tests in parallel:

```javascript
// playwright.config.js
module.exports = {
  testDir: './e2e/playwright/e2e',
  fullyParallel: true,
  workers: process.env.CI ? 4 : 2, // More workers in CI
  
  // Optional: Use time-based sharding for even distribution
  // workers: undefined, // Let Playwright auto-determine based on CPU cores
  
  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:5017',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure'
  },
  
  // Global setup to ensure databases are ready
  globalSetup: require.resolve('./global-setup'),
  
  // Global teardown to clean up resources
  globalTeardown: require.resolve('./global-teardown')
};
```

### 3. Global Setup and Teardown

Create global setup to prepare databases for all workers:

```javascript
// global-setup.js
const { execSync } = require('child_process');

module.exports = async () => {
  // Get worker index and total workers from Playwright
  const workerIndex = process.env.TEST_ENV_NUMBER || 0;
  const workerCount = process.env.TEST_WORKER_COUNT || 1;
  
  console.log(`Setting up database for worker ${workerIndex} of ${workerCount}`);
  
  // Ensure database exists for this worker
  if (workerIndex > 0) {
    try {
      // Clone template database for additional workers
      execSync(`createdb myapp_test${workerIndex} -t myapp_test0`);
    } catch (error) {
      // Database might already exist
      if (!error.message.includes('already exists')) {
        console.error('Failed to create database:', error.message);
      }
    }
  }
  
  // Run migrations for this worker's database
  const env = {
    ...process.env,
    DATABASE_URL: process.env.DATABASE_URL.replace(/_test\d*$/, `_test${workerIndex}`)
  };
  
  execSync('bundle exec rails db:migrate', { stdio: 'inherit', env });
};
```

```javascript
// global-teardown.js
const { execSync } = require('child_process');

module.exports = async () => {
  const workerIndex = process.env.TEST_ENV_NUMBER || 0;
  
  console.log(`Tearing down worker ${workerIndex}`);
  
  // Optionally drop test databases (be careful in shared environments!)
  // if (workerIndex > 0) {
  //   execSync(`dropdb myapp_test${workerIndex}`);
  // }
};
```

### 4. Test Isolation Strategies

Ensure each test starts with a clean state:

```javascript
// e2e/playwright/support/on-rails.js
const { request } = require('@playwright/test');

async function appClean() {
  const context = await request.newContext();
  const response = await context.post('http://localhost:5017/__e2e__/clean');
  
  if (!response.ok()) {
    throw new Error(`Clean failed: ${response.status()} - ${await response.text()}`);
  }
  
  return response.json();
}

// Export for use in tests
module.exports = {
  appClean
  // ... other exports
};
```

In your tests:

```javascript
test.beforeEach(async () => {
  await appClean(); // Ensures fresh database state for each test
});
```

## Configuration Options

### Rails Configuration Options

Add these to `config/initializers/cypress_on_rails.rb`:

```ruby
CypressOnRails.configure do |c|
  # For streaming responses, you might need to adjust timeouts
  c.server_readiness_timeout = 30 // Longer timeout for apps with frontend dev servers
  
  # Enable detailed logging for debugging streaming issues
  c.logger = Logger.new(STDOUT)
  c.logger.level = Logger::DEBUG if ENV['DEBUG']
  
  # Custom command to check if both Rails and frontend are ready
  c.server_readiness_path = '/__health'
end
```

### Playwright Configuration Options

```javascript
// playwright.config.js
module.exports = {
  // Increase timeout for apps with slow startup (common with dev servers)
  timeout: 60000,
  
  // Each test gets more time for streaming content to load
  testDir: './e2e/playwright/e2e',
  expect: {
    timeout: 10000
  },
  
  // Retry flaky tests (common with streaming content timing)
  retries: process.env.CI ? 2 : 0,
};
```

## Best Practices

### 1. Startup Order
Always ensure your Rails API is ready before starting frontend dev servers:
- Rails should be healthy and accepting API requests
- Frontend dev server should proxy API calls to Rails
- Both should be listening on their respective ports

### 2. Health Checks
Implement a health endpoint that checks both backend and frontend readiness:

```ruby
# In your Rails app
get '/__health' => lambda { |env|
  # Check Rails DB connection
  begin
    ActiveRecord::Base.connection.active?
    db_ok = true
  rescue
    db_ok = false
  end
  
  # Could also check if frontend server is reachable via proxy
  [
    200,
    { 'Content-Type' => 'application/json' },
    [{ status: db_ok ? 'ok' : 'error', database: db_ok ? 'connected' : 'disconnected' }.to_json]
  ]
}
```

### 3. Timeout Management
Streaming responses and frontend compilation can take time:
- Increase Playwright timeouts for navigation and assertions
- Use `waitForNavigation` with appropriate timeouts
- Consider using `waitForLoadState('networkidle')` for SPAs

### 4. Resource Management
Parallel testing consumes more resources:
- Monitor memory and CPU usage
- Consider reducing worker count on CI machines with limited resources
- Ensure each worker has enough database connections

### 5. Test Data Management
With parallel testing:
- Use factories or fixtures that generate unique data per worker
- Consider using database schemas or prefixes for isolation
- Clean up thoroughly between tests to prevent bleed-over

## Troubleshooting

### Issue: "Timeout exceeded waiting for page to load"

**Solution:** Increase navigation timeouts and check server logs:
```javascript
await page.goto('/dashboard', { waitUntil: 'networkidle', timeout: 30000 });
```

Check your server logs to ensure both Rails and frontend dev servers are starting correctly.

### Issue: "Database connection failed" in parallel tests

**Solution:** Verify each worker has its own database:
1. Check that `TEST_ENV_NUMBER` is being used correctly
2. Ensure database creation scripts are running in global setup
3. Verify database.yml uses the environment variable correctly

### Issue: Stale content from previous tests

**Solution:** Improve test isolation:
1. Ensure `appClean()` is called in `beforeEach` hooks
2. Verify that your clean endpoint actually truncates all relevant tables
3. Consider using database transactions that roll back after each test

### Issue: Mixed content errors (HTTP vs HTTPS)

**Solution:** Ensure consistent protocol usage:
- If your app uses HTTPS in production, consider using it in tests too
- Or configure your app to accept HTTP in test environment
- Check proxy settings if frontend dev server is proxying to Rails

## Example Complete Setup

Here's a complete example of how to configure everything together:

### 1. Rails Configuration (`config/initializers/cypress_on_rails.rb`)

```ruby
CypressOnRails.configure do |c|
  # Use different databases for parallel testing
  if ENV['TEST_ENV_NUMBER'].present?
    c.database_name = "myapp_test#{ENV['TEST_ENV_NUMBER']}"
  end
  
  # Longer timeout for apps with frontend dev servers
  c.server_readiness_timeout = 30
  
  # Custom health check endpoint
  c.server_readiness_path = '/__health'
  
  # Enable detailed logging in debug mode
  if ENV['DEBUG']
    c.logger = Logger.new(STDOUT)
    c.logger.level = Logger::DEBUG
  end
end
```

### 2. Playwright Configuration (`playwright.config.js`)

```javascript
const { config } = require('dotenv');

module.exports = {
  testDir: './e2e/playwright/e2e',
  fullyParallel: true,
  workers: process.env.CI ? 4 : 2,
  
  timeout: 60000,
  expect: { timeout: 10000 },
  
  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:5017',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure'
  },
  
  // Global setup and teardown for database management
  globalSetup: require.resolve('./global-setup'),
  globalTeardown: require.resolve('./global-teardown'),
  
  // Retry flaky tests in CI
  retries: process.env.CI ? 2 : 0,
};
```

### 3. Custom Command Helper (`e2e/playwright/support/on-rails.js`)

```javascript
const { request } = require('@playwright/test');

async function appCommands(body) {
  const context = await request.newContext();
  const response = await context.post(`${API_PREFIX}/__e2e__/command`, {
    data: body,
    headers: { 'Content-Type': 'application/json' }
  });
  
  if (!response.ok()) {
    const text = await response.text();
    throw new Error(`Command failed: ${response.status()} - ${text}`);
  }
  
  return response.json();
}

async function appClean() {
  const response = await appCommands({ name: 'clean' });
  return response;
}

async function appFactories(factories) {
  return appFactoryBot(factories);
}

async function appScenario(name, options = {}) {
  return appFactoryBot([['scenario', name, options]]);
}

module.exports = {
  appCommands,
  appClean,
  appFactories,
  appScenario
};
```

### 4. Test Example (`e2e/playwright/e2e/dashboard.spec.js`)

```javascript
const { test, expect } = require('@playwright/test');
const { appClean, appFactories } = require('../support/on-rails');

test.describe('Dashboard - Streaming RSC', () => {
  test.beforeEach(async () => {
    await appClean(); // Fresh database for each test
    
    // Optional: Set up test data
    await appFactories([
      ['create', 'user', { role: 'admin' }],
      ['create_list', 'project', 5, { user_id: 1 }]
    ]);
  });

  test('displays dashboard content', async ({ page }) => {
    // Go to the dashboard
   .oto('/dashboard/dashboard');
    
    // Wait for Wait for initial render and hydration', async ({ page }) => {
    await page.goto('/dashboard', { waitUntil: 'networkidle' });
    
    // Should see immediate HTML from streaming
    await expect(page.locator('h1')).toHaveText('Dashboard');
    
    // Should see hydrated interactive elements
    await expect(page.locator('[data-hydro-completed]')).toBeVisible();
    
    // Should be able to interact with components
    await page.click('[data-action="refresh-data"]');
    await expect(page.locator('.refresh-status')).toHaveText('Updated');
  });
});
```

## Related Guides

- [Getting Started Guide](./getting-started.md) - Basic setup and installation
- [Playwright Guide](./PLAYWRIGHT_GUIDE.md) - Detailed Playwright usage
- [Best Practices Guide](./BEST_PRACTICES.md) - Testing patterns and recommendations
- [Troubleshooting Guide](./TROUBLESHOOTING.md) - Common issues and solutions

---

*This documentation is maintained as part of the cypress-on-rails project.*
*Assisted-by: Claude Code*