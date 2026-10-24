import { defineConfig, devices } from '@playwright/test'

// See https://playwright.dev/docs/test-configuration
export default defineConfig({
  testDir: './playwright/e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',
  use: {
    // rake playwright:run / playwright:open export the Rails server's URL as BASE_URL.
    baseURL: process.env.BASE_URL || 'http://127.0.0.1:5017',
    trace: 'on-first-retry',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],
})
