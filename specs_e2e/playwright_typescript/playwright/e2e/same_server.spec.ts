import { test, expect } from '@playwright/test'
import { appEval } from '../support/on-rails'

// The lane edits the generated config's fallback URL to this port, unsets BASE_URL and
// starts Rails on it with PORT set, see specs_e2e/rails_8/test_playwright_typescript.sh.
const configuredPort = '4321'

test('browser and helper requests reach the configured server when BASE_URL is unset', async ({ page, baseURL }) => {
  expect(process.env.BASE_URL).toBeUndefined()
  expect(baseURL).toBe(`http://127.0.0.1:${configuredPort}`)

  await page.goto('/')
  expect(new URL(page.url()).port).toBe(configuredPort)
  expect(await appEval<string>("ENV['PORT']")).toBe(configuredPort)
})
