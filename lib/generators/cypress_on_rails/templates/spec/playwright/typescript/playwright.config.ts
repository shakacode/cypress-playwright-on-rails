import { defineConfig, devices } from '@playwright/test'

// See https://playwright.dev/docs/test-configuration
export default defineConfig({
  testDir: './playwright/e2e',
  // One Rails server and database are shared, and the example spec runs app('clean')
  // before each test, so parallel workers wipe each other's rows; raise with isolation.
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: 1,
  // Do not serve the report: `rake playwright:run` must exit to stop its Rails server.
  reporter: [['html', { open: 'never' }]],
  use: {
    // rake playwright:run / playwright:open export the Rails server's URL as BASE_URL.
    baseURL: process.env.BASE_URL || 'http://127.0.0.1:5017',
    trace: 'on-first-retry',
  },
  // Same browser set as the JavaScript config.
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'firefox', use: { ...devices['Desktop Firefox'] } },
    { name: 'webkit', use: { ...devices['Desktop Safari'] } },
  ],
})
