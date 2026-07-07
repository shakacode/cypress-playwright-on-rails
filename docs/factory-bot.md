# FactoryBot

E2E on Rails lets browser tests use FactoryBot through Rails app commands.

Install the current 1.x gem as `cypress-on-rails`:

```ruby
group :test, :development do
  gem 'cypress-on-rails', '~> 1.0'
end
```

FactoryBot setup belongs in Ruby, close to your models and traits. Browser
tests can ask Rails to create records, then focus on the visible user flow.

The generated app command setup includes a FactoryBot command example. Use it
as a starting point for creating records and returning the data your Cypress or
Playwright test needs.

Related docs:

- [FactoryBot Associations](./factory_bot_associations.md)
- [App Commands](./app-commands.md)
- [Best Practices](./BEST_PRACTICES.md)
