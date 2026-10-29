import { request, expect, type APIRequestContext } from '@playwright/test'
import config from '../../playwright.config'

// The Rails server under test: the config's `use.baseURL`, so the helpers and
// `page.goto()` always reach the same server. The generated config reads the
// BASE_URL that `rake playwright:run` and `rake playwright:open` export.
const baseURL = config.use?.baseURL

// Sends the shared secret when one is configured, see the "Security model"
// section of the cypress-on-rails README. Applied to every request made with
// this context, including the VCR insert/eject helpers below.
const cypressOnRailsToken = process.env.CYPRESS_ON_RAILS_TOKEN

// One request context per Playwright worker, created on first use.
let contextPromise: Promise<APIRequestContext> | undefined
const context = (): Promise<APIRequestContext> => {
  if (!contextPromise) {
    contextPromise = request.newContext({
      ...(baseURL ? { baseURL } : {}),
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
  // Milliseconds before the request fails; 0 disables the request timeout.
  // Playwright's default is 30 s, too short for a command that waits on a
  // background job. The enclosing test timeout still applies: raise it with
  // test.setTimeout() too.
  timeout?: number
}

// Runs one or more app commands (Ruby files under app_commands/) in the Rails
// process and returns their results, in order.
export async function appCommands<T = unknown>(
  data: AppCommand | AppCommand[],
  requestOptions: RequestOptions = {}
): Promise<T[]> {
  const response = await (await context()).post('/__e2e__/command', {
    data,
    ...(requestOptions.timeout === undefined ? {} : { timeout: requestOptions.timeout })
  })
  expect(response.ok(), `app command answered ${response.status()}: ${await response.text()}`).toBeTruthy()
  return response.json()
}

export async function app<T = unknown>(name: string, options: unknown = {}, requestOptions?: RequestOptions): Promise<T> {
  const [result] = await appCommands<T>({ name, options }, requestOptions)
  return result as T
}

export const appScenario = <T = unknown>(name: string, options: unknown = {}, requestOptions?: RequestOptions) =>
  app<T>('scenarios/' + name, options, requestOptions)
export const appEval = <T = unknown>(code: string, requestOptions?: RequestOptions) => app<T>('eval', code, requestOptions)
export const appFactories = <T = unknown>(options: unknown, requestOptions?: RequestOptions) =>
  app<T>('factory_bot', options, requestOptions)

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
