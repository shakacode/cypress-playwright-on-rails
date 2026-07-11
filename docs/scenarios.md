# Scenarios

Scenarios are named Rails-side setup files for browser tests.

Install the current 1.x gem as `cypress-on-rails`:

```ruby
group :test, :development do
  gem 'cypress-on-rails', '~> 1.0'
end
```

The generator creates `e2e/app_commands/scenarios/`. Put reusable setup flows
there so Cypress and Playwright tests can request the same Rails state by name.

Use scenarios for:

- Signed-in users with specific roles.
- Products, accounts, or teams needed by many tests.
- Complex setup that should stay out of JavaScript test files.

Use [App Commands](./app-commands.md) when a test needs custom parameters or
returns data directly to the browser test.
