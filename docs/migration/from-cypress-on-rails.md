# Migrating from cypress-rails

E2E on Rails is the maintained path for Rails teams that want Cypress or
Playwright browser tests with Rails-side test data.

Install the current 1.x gem as `cypress-on-rails`:

```ruby
group :test, :development do
  gem 'cypress-on-rails', '~> 1.0'
end
```

Then run the installer for your runner:

```sh
bin/rails g cypress_on_rails:install
bin/rails g cypress_on_rails:install --framework playwright
```

## Concept map

| cypress-rails concept | E2E on Rails path |
| --- | --- |
| Reset endpoint | Generated reset/app-command middleware |
| Cypress-only workflow | Cypress or Playwright |
| Test data setup | App commands, scenarios, FactoryBot, fixtures |
| Browser specs | Cypress specs or Playwright specs |

## Migration shape

1. Add `gem 'cypress-on-rails'` to the Rails app.
2. Run the generator.
3. Move reusable state setup into `e2e/app_commands/`.
4. Convert repeated setup flows into [Scenarios](../scenarios.md).
5. Run the suite through `bin/rails cypress:run` or
   `bin/rails playwright:run`.

For deeper migration planning, see the roadmap docs in this repository and the
current [Best Practices](../BEST_PRACTICES.md).
