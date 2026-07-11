# Cypress

E2E on Rails lets Cypress tests call into Rails app commands so browser tests
can use Rails factories, fixtures, scenarios, and cleanup.

Install the current 1.x gem as `cypress-on-rails`:

```ruby
group :test, :development do
  gem 'cypress-on-rails', '~> 1.0'
end
```

Generate Cypress support:

```sh
bundle install
bin/rails g cypress_on_rails:install
bin/rails cypress:open
```

Run headless tests:

```sh
bin/rails cypress:run
```

## Rails state from Cypress

Use app commands and scenarios for state setup instead of building every test
through the UI. Keep browser specs focused on the behavior users see, and keep
Rails-side data setup in Ruby where Rails teams can maintain it.

Related docs:

- [App Commands](./app-commands.md)
- [Scenarios](./scenarios.md)
- [Best Practices](./BEST_PRACTICES.md)
