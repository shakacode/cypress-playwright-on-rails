import { request, expect, type APIRequestContext } from '@playwright/test'

// The Rails server under test. `rake playwright:run` and `rake playwright:open`
// export the URL of the server they start as BASE_URL.
const baseURL = process.env.BASE_URL || 'http://127.0.0.1:5017'

// Sends the shared secret when one is configured, see the "Security model"
// section of the cypress-on-rails README. Applied to every request made with
// this context, including the VCR insert/eject helpers below.
const cypressOnRailsToken = process.env.CYPRESS_ON_RAILS_TOKEN

// One request context per Playwright worker, created on first use.
let contextPromise: Promise<APIRequestContext> | undefined
const context = (): Promise<APIRequestContext> => {
  if (!contextPromise) {
    contextPromise = request.newContext({
      baseURL,
      extraHTTPHeaders: cypressOnRailsToken ? { 'X-Cypress-On-Rails-Token': cypressOnRailsToken } : {}
    })
  }
  return contextPromise
}

export interface AppCommand {
  name: string
  options?: unknown
}

export interface RequestOptions {
  // Milliseconds before the request fails; 0 waits forever. Playwright's
  // default is 30 s, too short for a command that waits on a background job.
  timeout?: number
}

// Runs one or more app commands (Ruby files under app_commands/) in the Rails
// process and returns their results, in order.
export async function appCommands<T = unknown>(
  data: AppCommand | AppCommand[],
  requestOptions: RequestOptions = {}
): Promise<T[]> {
  const response = await (await context()).post('/__e2e__/command', { data, timeout: requestOptions.timeout })
  expect(response.ok(), `app command answered ${response.status()}: ${await response.text()}`).toBeTruthy()
  return response.json()
}

export async function app<T = unknown>(name: string, options: unknown = {}, requestOptions?: RequestOptions): Promise<T> {
  const [result] = await appCommands<T>({ name, options }, requestOptions)
  return result
}

export const appScenario = <T = unknown>(name: string, options: unknown = {}) => app<T>('scenarios/' + name, options)
export const appEval = <T = unknown>(code: string) => app<T>('eval', code)
export const appFactories = <T = unknown>(options: unknown) => app<T>('factory_bot', options)

// Resets the application state. Prefer this over a raw request so that the token
// header is sent when one is configured. The endpoint is also mounted at
// /cypress_rails_reset_state for cypress-rails compatibility.
export async function appResetState(): Promise<string> {
  const response = await (await context()).post('/__cypress__/reset_state')
  expect(response.ok()).toBeTruthy()
  return response.text()
}

export async function appVcrInsertCassette(cassetteName: string, options: Record<string, unknown> = {}) {
  const defined = Object.fromEntries(Object.entries(options).filter(([, value]) => value !== undefined))
  const response = await (await context()).post('/__e2e__/vcr/insert', { data: [cassetteName, defined] })
  expect(response.ok()).toBeTruthy()
  return response.json()
}

export async function appVcrEjectCassette() {
  const response = await (await context()).post('/__e2e__/vcr/eject')
  expect(response.ok()).toBeTruthy()
  return response.json()
}
