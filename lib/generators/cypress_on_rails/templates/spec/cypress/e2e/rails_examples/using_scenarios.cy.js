describe('Rails using scenarios examples', function() {
  beforeEach(() => {
    cy.app('clean') // have a look at e2e/app_commands/clean.rb
  })

  it('setup basic scenario', function() {
    cy.appScenario('basic')
    cy.visit('/')
    cy.get('table').find('tbody').should(($tbody) => {
      // clean should have removed these from other tests
      expect($tbody).not.to.contain('Good bye Mars')
      expect($tbody).not.to.contain('Hello World')

      expect($tbody).to.contain('I am a Postman')
    })
  })


  it('example of missing scenario failure', function() {
    cy.visit('/')
    cy.appScenario('basic')
    // cy.appScenario('missing') // uncomment these if you want to see what happens
  })

  it('example of missing app failure', function() {
    cy.visit('/')
    cy.appScenario('basic')
    // cy.app('run_me') // uncomment these if you want to see what happens
  })
})
