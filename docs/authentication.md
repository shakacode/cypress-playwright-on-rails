# Example for Authenticating a User

In `config/routes.rb`:
```rb
Rails.application.routes.draw do
  # ...... your other routes
  unless Rails.env.production?
    scope path: "/__cypress__", controller: 'cypress' do
      post "forceLogin", action: 'force_login'
    end
  end
end
```

`app/controllers/cypress_controller.rb`:
```rb
class CypressController < ApplicationController
  skip_before_action :verify_authenticity_token

  def force_login
    if params[:email].present?
      user = User.find_by!(email: params.require(:email))
    else
      user = User.first!
    end
    sign_in(user)
    redirect_to URI.parse(params.require(:redirect_to)).path
  end
end
```

In `cypress/support/on-rails.js`:
```js
Cypress.Commands.add('forceLogin', (details) => {
  if (!details) {
    details = {}
  }

  if (!details.redirect_to) {
    details.redirect_to = '/'
  }

  cy.visit('__cypress__/forceLogin',
    { method: 'POST', body: { email: details.email, redirect_to: details.redirect_to } })
})
```

Examples of usage in Cypress specs:
```js
cy.forceLogin()
cy.forceLogin({redirect_to: '/profile'})
cy.forceLogin({email: 'someuser@mail.com'})
```

In `playwright/support/on-rails.js`:

```js
async function forceLogin(page, { email, redirect_to = '/' }) {
    // Validate inputs
    if (typeof email !== 'string'  || typeof redirect_to !== 'string') {
        throw new Error('Invalid input: email and redirect_to must be non-empty strings');
    }

    const response = await page.request.post('/__e2e__/force_login', {
        data: { email: email, redirect_to: redirect_to },
        headers: { 'Content-Type': 'application/json' }
    });

    // Handle response based on status code
    if (response.ok()) {
        await page.goto(redirect_to);
    } else {
        // Throw an exception for specific error statuses
        throw new Error(`Login failed with status: ${response.status()}`);
    }
}
```

Examples of usage in Playwright specs:
```js
await forceLogin(page, { email: 'someuser@mail.com', redirect_to: '/profile' });

```
