# Playwright

E2E on Rails supports Playwright through the same Rails-side command and state
setup model used for Cypress.

Install the current 1.x gem as `cypress-on-rails`:

```ruby
group :test, :development do
  gem 'cypress-on-rails', '~> 1.0'
end
```

Generate Playwright support:

```sh
bundle install
bin/rails g cypress_on_rails:install --framework playwright
bin/rails playwright:open
```

Run headless tests:

```sh
bin/rails playwright:run
```

Playwright support shares the `e2e/e2e_helper.rb` file and
`e2e/app_commands/` folder with Cypress, so Rails data setup stays in one
place.

Read the full [Playwright Guide](./PLAYWRIGHT_GUIDE.md) for configuration,
commands, and examples.
