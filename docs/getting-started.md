# Getting Started

Install the 1.x gem as `cypress-on-rails`. The public project brand is E2E on
Rails; the staged `e2e_on_rails` gem flip comes later.

```ruby
group :test, :development do
  gem 'cypress-on-rails', '~> 1.0'
end
```

Run the installer for Cypress:

```sh
bundle install
bin/rails g cypress_on_rails:install
bin/rails cypress:open
```

Run the installer for Playwright:

```sh
bundle install
bin/rails g cypress_on_rails:install --framework playwright
bin/rails playwright:open
```

The generator creates an `e2e/` folder with Rails-side helper code and
framework-specific support files. Cypress and Playwright share the same Rails
app commands, scenarios, and test data setup.

## What gets installed

- `e2e/e2e_helper.rb` for Rails test setup.
- `e2e/app_commands/` for Ruby commands callable from browser tests.
- `e2e/app_commands/scenarios/` for named test states.
- Cypress or Playwright support files under `e2e/cypress/` or
  `e2e/playwright/`.

## Next steps

- Use [FactoryBot](./factory-bot.md) for test records.
- Use [Scenarios](./scenarios.md) for named browser-test states.
- Review [Best Practices](./BEST_PRACTICES.md) before adding a large suite.
