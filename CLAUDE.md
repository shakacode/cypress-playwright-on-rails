# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## ⚠️ CRITICAL REQUIREMENTS

**BEFORE EVERY COMMIT/PUSH:**

1. **ALWAYS ensure files end with a newline character**
2. **ALWAYS run tests before pushing**

These requirements are non-negotiable. CI will fail if not followed.

## Development Commands

### Essential Commands

- **Install dependencies**: `bundle`
- **Run tests**:
  - Ruby tests: `bundle exec rspec`
  - All tests: `bundle exec rake` (default task runs tests)
- **⚠️ MANDATORY BEFORE GIT PUSH**: Ensure tests pass + ensure trailing newlines

## Changelog

- **Update CHANGELOG.md for user-visible changes only** (features, bug fixes, breaking changes, deprecations, performance improvements)
- **Do NOT add entries for**: linting, formatting, refactoring, tests, or documentation fixes
- **Format**: `[PR 123](https://github.com/shakacode/cypress-on-rails/pull/123) by [username](https://github.com/username)` (no hash in PR number)
- **Use `/update-changelog` command** for guided changelog updates with automatic formatting
- **Version management**: Run `bundle exec rake update_changelog` after releases to update version headers (if rake task exists)
- **Examples**: Run `grep -A 3 "^#### " CHANGELOG.md | head -30` to see real formatting examples

## Project Architecture

### Core Components

This is a Ruby gem that provides integration between Cypress/Playwright and Rails applications.

#### Ruby Side (`lib/cypress_on_rails/`)

- **`middleware.rb`**: Rack middleware for handling Cypress/Playwright commands
- **`configuration.rb`**: Global configuration management
- **Generators**: Located in `lib/generators/cypress_on_rails/`

#### Test Framework Support

- **Cypress**: JavaScript-based E2E testing framework
- **Playwright**: Modern browser automation framework
- Both frameworks share the same Ruby backend commands

### Build System

- **Ruby**: Standard gemspec-based build
- **Testing**: RSpec for Ruby tests
- **Linting**: RuboCop for Ruby

### Examples and Testing

- **Specs**: `spec/` - RSpec tests for the gem
- **E2E Examples**: `specs_e2e/` - End-to-end test examples
- **Rake tasks**: Defined in `rakelib/` for various development operations

## Important Notes

- Server-side commands are executed via Rack middleware
- Commands can use factory_bot, database_cleaner, and other test helpers
- VCR integration available for HTTP mocking
- Supports both Cypress and Playwright frameworks
- Configuration is done in `config/initializers/cypress_on_rails.rb`
