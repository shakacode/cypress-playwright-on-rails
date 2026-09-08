# E2E on Rails

E2E on Rails is the Rails test bridge for Cypress and Playwright.

Use browser tests with the Rails test setup you already trust: FactoryBot,
fixtures, database cleanup, scenarios, VCR, and custom app commands. The public
brand is E2E on Rails, while the 1.x gem is still installed as
`cypress-on-rails`.

```ruby
group :test, :development do
  gem 'cypress-on-rails', '~> 1.0'
end
```

## Why teams use it

- Keep browser tests close to Rails state and conventions.
- Share app commands between Cypress and Playwright.
- Reset data predictably between tests.
- Move from Cypress to Playwright without throwing away Rails-side helpers.

## Start here

- [Getting Started](./getting-started.md)
- [Cypress](./cypress.md)
- [Playwright](./playwright.md)
- [FactoryBot](./factory-bot.md)
- [Scenarios](./scenarios.md)
