# App Commands

App commands are Ruby files that browser tests can call through the E2E on
Rails middleware.

Install the current 1.x gem as `cypress-on-rails`:

```ruby
group :test, :development do
  gem 'cypress-on-rails', '~> 1.0'
end
```

Use app commands to keep Rails-specific setup in Ruby:

- Create records with FactoryBot.
- Load or reset test data.
- Build named scenarios.
- Return IDs or attributes needed by the browser test.

Keep commands small and explicit. A good command sets up one kind of test state
and returns only what the browser test needs to continue.

Related docs:

- [Scenarios](./scenarios.md)
- [FactoryBot](./factory-bot.md)
- [Authentication](./authentication.md)
