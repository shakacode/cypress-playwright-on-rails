describe('Rails using factory bot examples', function() {
  beforeEach(() => {
    cy.app('clean') // have a look at e2e/app_commands/clean.rb
  })

  it('using single factory bot', function() {
    cy.appFactories([
      ['create', 'post', {title: 'Good bye Mars'} ]
    ])
    cy.visit('/')
    cy.get('table').find('tbody').should(($tbody) => {
      // clean should have removed these from other tests
      expect($tbody).not.to.contain('Hello World')

      expect($tbody).to.contain('Good bye Mars')
    })
  })

  it('using multiple factory bot', function() {
    cy.appFactories([
      ['create_list', 'post', 10],
      ['create', 'post', {title: 'Hello World'} ]
    ])
    cy.visit('/')
    cy.get('table').find('tbody').should(($tbody) => {
      // clean should have removed these from other tests
      expect($tbody).to.contain('Hello World')
      expect($tbody).not.to.contain('Good bye Mars')
    })
  })
})
