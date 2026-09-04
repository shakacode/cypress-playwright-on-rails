import { request, expect } from '@playwright/test'
import config from '../../playwright.config'

// Sends the shared secret when one is configured, see the "Security model"
// section of the cypress-on-rails README. Applied to every request made with
// this context, including the VCR insert/eject helpers below.
const cypressOnRailsToken = process.env.CYPRESS_ON_RAILS_TOKEN

const contextPromise = request.newContext({
  baseURL: config.use ? config.use.baseURL : 'http://localhost:5017',
  extraHTTPHeaders: cypressOnRailsToken ? { 'X-Cypress-On-Rails-Token': cypressOnRailsToken } : {}
})

const appCommands = async (data) => {
  const context = await contextPromise
  const response = await context.post('/__e2e__/command', { data })

  expect(response.ok()).toBeTruthy()
  return response.json();
}

const app = (name, options = {}) => appCommands({ name, options }).then((body) => body[0])
const appScenario = (name, options = {}) => app('scenarios/' + name, options)
const appEval = (code) => app('eval', code)
const appFactories = (options) => app('factory_bot', options)

const appVcrInsertCassette = async (cassette_name, options) => {
  const context = await contextPromise;
  if (!options) options = {};

  Object.keys(options).forEach(key => options[key] === undefined ? delete options[key] : {});
  const response = await context.post("/__e2e__/vcr/insert", {data: [cassette_name,options]});
  expect(response.ok()).toBeTruthy();
  return response.json();
}

const appVcrEjectCassette = async () => {
  const context = await contextPromise;

  const response = await context.post("/__e2e__/vcr/eject");
  expect(response.ok()).toBeTruthy();
  return response.json();
}

export { appCommands, app, appScenario, appEval, appFactories, appVcrInsertCassette, appVcrEjectCassette }
