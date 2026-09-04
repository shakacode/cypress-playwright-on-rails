// CypressOnRails: don't remove these commands
// Sends the shared secret when one is configured, see the "Security model"
// section of the cypress-on-rails README. Set it in cypress.env.json as
// CYPRESS_ON_RAILS_TOKEN, or in the shell as CYPRESS_CYPRESS_ON_RAILS_TOKEN
// (cypress strips the CYPRESS_ prefix from OS environment variables).
const cypressOnRailsHeaders = (headers) => {
  const token = Cypress.env('CYPRESS_ON_RAILS_TOKEN') || Cypress.env('ON_RAILS_TOKEN')
  if (!token) return headers

  return Object.assign({}, headers, { 'X-Cypress-On-Rails-Token': token })
}

Cypress.Commands.add('appCommands', function (body) {
  Object.keys(body).forEach(key => body[key] === undefined ? delete body[key] : {});
  const log = Cypress.log({ name: "APP", message: body, autoEnd: false })
  return cy.request({
    method: 'POST',
    url: "/__e2e__/command",
    body: JSON.stringify(body),
    headers: cypressOnRailsHeaders({
      'Content-Type': 'application/json',
    }),
    log: false,
    failOnStatusCode: false
  }).then((response) => {
    log.end();
    if (response.status !== 201) {
      expect(response.body.message).to.equal('')
      expect(response.status).to.be.equal(201)
    }
    return response.body
  });
});

Cypress.Commands.add('app', function (name, command_options) {
  return cy.appCommands({name: name, options: command_options}).then((body) => {
    return body[0]
  });
});

Cypress.Commands.add('appScenario', function (name, options = {}) {
  return cy.app('scenarios/' + name, options)
});

Cypress.Commands.add('appEval', function (code) {
  return cy.app('eval', code)
});

Cypress.Commands.add('appFactories', function (options) {
  return cy.app('factory_bot', options)
});

Cypress.Commands.add('appFixtures', function (options) {
  cy.app('activerecord_fixtures', options)
});
// CypressOnRails: end

// The next is optional
// beforeEach(() => {
//  cy.app('clean') // have a look at cypress/app_commands/clean.rb
//  cy.mockGraphQL() // for GraphQL usage with use_cassette, see cypress/support/commands.rb
// });

// comment this out if you do not want to attempt to log additional info on test fail
Cypress.on('fail', (err, runnable) => {
  // allow app to generate additional logging data
  Cypress.$.ajax({
    url: '/__e2e__/command',
    data: JSON.stringify({name: 'log_fail', options: {error_message: err.message, runnable_full_title: runnable.fullTitle() }}),
    headers: cypressOnRailsHeaders({
      'Content-Type': 'application/json',
    }),
    async: false,
    method: 'POST'
  });

  throw err;
});
