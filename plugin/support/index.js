// Sends the shared secret when one is configured, see the "Security model"
// section of the cypress-on-rails README. Set it in cypress.env.json as
// CYPRESS_ON_RAILS_TOKEN, or in the shell as CYPRESS_CYPRESS_ON_RAILS_TOKEN
// (cypress strips the CYPRESS_ prefix from OS environment variables).
// Cypress coerces environment values, so a token of "0" or "false" arrives here
// as a number or a boolean: only undefined, null and '' count as unset.
const cypressOnRailsTokenGiven = (value) => value !== undefined && value !== null && value !== ''

const cypressOnRailsHeaders = (headers) => {
  let token = Cypress.env('CYPRESS_ON_RAILS_TOKEN')
  if (!cypressOnRailsTokenGiven(token)) token = Cypress.env('ON_RAILS_TOKEN')
  if (!cypressOnRailsTokenGiven(token)) return headers

  return Object.assign({}, headers, { 'X-Cypress-On-Rails-Token': String(token) })
}

Cypress.Commands.add("vcr_insert_cassette", (cassette_name, options) => {
  if (!options) options = {};

  Object.keys(options).forEach(key => options[key] === undefined ? delete options[key] : {});
  const log = Cypress.log({ name: "VCR Insert", message: cassette_name, autoEnd: false })
  return cy.request({
    method: 'POST',
    url: "/__e2e__/vcr/insert",
    body: JSON.stringify([cassette_name,options]),
    headers: cypressOnRailsHeaders({}),
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

Cypress.Commands.add("vcr_eject_cassette", () => {
  const log = Cypress.log({ name: "VCR Eject", autoEnd: false })
  return cy.request({
    method: 'POST',
    url: "/__e2e__/vcr/eject",
    headers: cypressOnRailsHeaders({}),
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
