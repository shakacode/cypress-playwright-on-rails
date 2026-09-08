# Fixtures

Rails fixtures work well for stable baseline data in E2E browser tests.

Install the current 1.x gem as `cypress-on-rails`:

```ruby
group :test, :development do
  gem 'cypress-on-rails', '~> 1.0'
end
```

Use fixtures when many tests need the same known records. Use scenarios or app
commands when a test needs custom state for one flow.

Typical pattern:

1. Load baseline fixture data in Rails.
2. Reset state between browser tests.
3. Use app commands for test-specific data.

Related docs:

- [Scenarios](./scenarios.md)
- [App Commands](./app-commands.md)
- [Troubleshooting](./TROUBLESHOOTING.md)
