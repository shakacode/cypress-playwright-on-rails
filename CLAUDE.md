# Claude Code Guidelines for cypress-playwright-on-rails

This document provides guidance for Claude Code agents working on the cypress-playwright-on-rails gem.

## ⚠️ Critical Requirements

### Testing Protocol
- **ALWAYS run corresponding RSpec tests when changing source files**
  - Changing `lib/cypress_on_rails/middleware.rb`? Run `bundle exec rspec spec/cypress_on_rails/middleware_spec.rb`
  - Changing `lib/cypress_on_rails/command_executor.rb`? Run `bundle exec rspec spec/cypress_on_rails/command_executor_spec.rb`
- **Run full test suite before pushing**: `bundle exec rake`
- **Test against multiple Rails versions** when making significant changes:
  ```bash
  ./specs_e2e/rails_6_1/test.sh
  ./specs_e2e/rails_7_2/test.sh
  ./specs_e2e/rails_8/test.sh
  ```

### Code Quality
- **ALWAYS use `bundle exec` prefix** when running Ruby tools: `bundle exec rubocop`, `bundle exec rspec`, `bundle exec rake`
- **ALWAYS run `bundle exec rubocop` and fix all violations before committing**
- **NEVER push code that fails RuboCop locally** - if CI fails but local passes, add the exact disable directive CI expects
- **ALWAYS end files with a newline character** - this is mandatory for all files

### Git Workflow
- **NEVER push directly to master** - always create feature branches and use PRs
- **Keep PRs focused and minimal** - one logical change per PR
- **Run `bundle exec rubocop` before every commit**
- **Check CI status after pushing**: `gh pr view --json statusCheckRollup`

## 🚀 Common Commands

### Testing
```bash
# Run all unit tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/cypress_on_rails/middleware_spec.rb

# Run tests with focus tag
bundle exec rspec --focus

# Run full suite (tests + build gem)
bundle exec rake

# Run integration tests for specific Rails version
./specs_e2e/rails_8/test.sh
```

### Code Quality
```bash
# Run RuboCop (Ruby linter)
bundle exec rubocop

# Auto-fix RuboCop violations
bundle exec rubocop -a

# Check specific file
bundle exec rubocop lib/cypress_on_rails/middleware.rb
```

### Gem Development
```bash
# Install dependencies
bundle install

# Build gem
gem build cypress-on-rails.gemspec

# Install gem locally for testing
gem install cypress-on-rails-*.gem
```

### Generator Testing
```bash
# Test generator in a Rails app
cd /path/to/test/rails/app
bundle exec rails g cypress_on_rails:install

# With options
bundle exec rails g cypress_on_rails:install --framework=playwright
bundle exec rails g cypress_on_rails:install --install_folder=e2e
```

## 📁 Project Architecture

### Core Components

**Middleware Layer** (`lib/cypress_on_rails/middleware.rb`)
- Rack middleware that intercepts `/__e2e__/command` endpoint
- Parses JSON requests and routes to CommandExecutor
- Returns JSON responses with appropriate status codes (201/404/500)

**Command Executor** (`lib/cypress_on_rails/command_executor.rb`)
- Loads `e2e_helper.rb` to set up test environment
- Executes Ruby command files using `eval()` in binding context
- Provides access to Rails, ActiveRecord, factories, and custom app code

**Smart Factory Wrapper** (`lib/cypress_on_rails/smart_factory_wrapper.rb`)
- Abstraction layer over FactoryBot/SimpleRailsFactory
- Auto-reloads factory definitions when files change (mtime tracking)
- Supports: `create()`, `create_list()`, `build()`, `build_list()`

**Configuration** (`lib/cypress_on_rails/configuration.rb`)
- Central configuration: `api_prefix`, `install_folder`, middleware settings
- `before_request` hook for authentication/metrics
- VCR options for HTTP recording/stubbing

**Rails Integration** (`lib/cypress_on_rails/railtie.rb`)
- Automatically injects middleware into Rails stack
- Conditional loading based on configuration
- Supports VCR middleware variants

### Directory Structure
```
lib/cypress_on_rails/
├── middleware.rb              # Main HTTP request handler
├── command_executor.rb        # Ruby code execution engine
├── smart_factory_wrapper.rb   # Factory abstraction with auto-reload
├── simple_rails_factory.rb    # Fallback factory implementation
├── configuration.rb           # Settings management
├── railtie.rb                # Rails auto-integration
├── middleware_config.rb      # Shared middleware configuration
└── vcr/                      # VCR middleware variants
    ├── insert_eject_middleware.rb    # Manual cassette control
    ├── use_cassette_middleware.rb    # Automatic cassette wrapping
    └── middleware_helpers.rb         # VCR utilities

lib/generators/cypress_on_rails/
├── install_generator.rb      # Rails generator for project setup
└── templates/               # Generated boilerplate files
    ├── config/initializers/cypress_on_rails.rb.erb
    ├── spec/e2e/e2e_helper.rb.erb
    ├── spec/e2e/app_commands/    # Command files
    ├── spec/cypress/             # Cypress setup
    └── spec/playwright/          # Playwright setup

spec/cypress_on_rails/        # Unit tests (RSpec)
specs_e2e/                   # Integration tests
├── rails_6_1/               # Rails 6.1 example app
├── rails_7_2/               # Rails 7.2 example app
└── rails_8/                 # Rails 8.0 example app
```

## 🔧 Development Patterns

### Request Flow
```
Cypress/Playwright Test
    ↓
POST /__e2e__/command { name: 'clean', options: {} }
    ↓
Middleware.call(env)
    ↓
Configuration.before_request hook (optional auth/metrics)
    ↓
Parse JSON → Validate command file exists
    ↓
CommandExecutor.perform(file_path, options)
    ├─ Load e2e_helper.rb (setup factories, DatabaseCleaner)
    └─ eval(file_content) in binding context
    ↓
Return [status, headers, [json_body]]
```

### Command File Pattern
Command files are plain Ruby evaluated in application context:

```ruby
# spec/e2e/app_commands/clean.rb
DatabaseCleaner.strategy = :truncation
DatabaseCleaner.clean
CypressOnRails::SmartFactoryWrapper.reload

# spec/e2e/app_commands/factory_bot.rb
Array.wrap(command_options).map do |factory_options|
  factory_method = factory_options.shift
  CypressOnRails::SmartFactoryWrapper.public_send(factory_method, *factory_options)
end

# spec/e2e/app_commands/scenarios/user_with_posts.rb
user = CypressOnRails::SmartFactoryWrapper.create(:user, email: 'test@example.com')
CypressOnRails::SmartFactoryWrapper.create_list(:post, 3, author: user)
```

### Testing Patterns

**Unit Tests** - Isolated component testing with doubles/mocks:
```ruby
# spec/cypress_on_rails/middleware_spec.rb
let(:app) { ->(env) { [200, {}, ["app response"]] } }
let(:command_executor) { class_double(CypressOnRails::CommandExecutor) }
let(:file) { class_double(File) }
subject { described_class.new(app, command_executor, file) }

it "parses JSON and calls executor" do
  env['rack.input'] = StringIO.new(JSON.generate({name: 'seed'}))
  expect(command_executor).to receive(:perform)
  subject.call(env)
end
```

**Integration Tests** - Full Rails app with Cypress/Playwright:
```bash
# specs_e2e/rails_8/test.sh
bundle install
bin/rails db:drop db:create db:migrate
bin/rails g cypress_on_rails:install
CYPRESS=1 bin/rails server -p 3001 &
bundle exec cypress run
# or
bundle exec playwright test
```

### Code Style Conventions

**Module Organization**
- Use modules for namespacing: `module CypressOnRails`
- Class methods for singletons: `CommandExecutor.perform`, `SmartFactoryWrapper.create`

**Dependency Injection**
- Middleware accepts dependencies in constructor for testability:
  ```ruby
  def initialize(app, command_executor = CommandExecutor, file = File)
  ```

**Error Handling**
- Rescue exceptions and log them
- Return appropriate HTTP status codes (404 for missing files, 500 for errors)
- Include error details in JSON response body

**Configuration**
- Centralize settings in `Configuration` class
- Provide sensible defaults
- Document configuration options in initializer template

## 🔄 Backward Compatibility

**Active Deprecations** (maintain compatibility but warn):
1. `cypress_folder` → `install_folder`
2. `/__cypress__/command` → `/__e2e__/command`
3. `cypress_helper.rb` → `e2e_helper.rb`
4. `CypressDev` constant → `CypressOnRails`

**When maintaining backward compatibility:**
- Keep old code paths functional
- Log deprecation warnings via `Configuration.logger.warn`
- Update documentation to recommend new approach
- Provide migration path in CHANGELOG

## 📝 Changelog Guidelines

**What merits a changelog entry:**
- New features or middleware options
- Bug fixes affecting user-facing behavior
- Breaking changes or deprecations
- Performance improvements
- Security fixes

**What doesn't:**
- Internal refactoring
- Test improvements
- Documentation updates (unless user-facing)
- Development tooling changes

**Format:**
```markdown
## [Unreleased]

### Added
- VCR use_cassette middleware for automatic cassette wrapping (#123)

### Changed
- Improved error messages for missing command files (#124)

### Deprecated
- `cypress_folder` configuration option, use `install_folder` instead

### Fixed
- Factory auto-reload not detecting file changes on Windows (#125)
```

## 🔒 Security Considerations

**CRITICAL**: This gem executes arbitrary Ruby code in the application context.

- **NEVER enable in production** (disabled by default via `!Rails.env.production?`)
- **Implement `before_request` hook** for authentication in sensitive environments:
  ```ruby
  c.before_request = lambda { |request|
    auth_token = request.env['HTTP_AUTHORIZATION']
    raise 'Unauthorized' unless valid_token?(auth_token)
  }
  ```
- **Bind to localhost only** when running Rails server for E2E tests
- **Use in CI/CD pipelines safely** - isolated environments only

## 🎯 cypress-on-rails Specific Considerations

### Multi-Framework Support
The gem supports **both Cypress and Playwright**. When making changes:
- Test generator with both `--framework=cypress` and `--framework=playwright`
- Update both JavaScript support files (`on-rails.js`) when changing API
- Verify examples in both `spec/cypress/` and `spec/playwright/` templates

### VCR Middleware Variants
Two VCR integration modes exist:
1. **Insert/Eject** (`use_vcr_middleware: true`) - Manual cassette control via endpoints
2. **Use Cassette** (`use_vcr_use_cassette_middleware: true`) - Automatic wrapping

When modifying VCR functionality, test both modes.

### Factory Wrapper Intelligence
The `SmartFactoryWrapper` auto-reloads factories when files change:
- Test with file modifications during test runs
- Verify mtime tracking works correctly
- Ensure fallback to `SimpleRailsFactory` when FactoryBot unavailable

### Rails Version Compatibility
This gem targets **Rails 6.1, 7.2, and 8.0+**:
- Test changes against all three versions in `specs_e2e/`
- Be mindful of Rails API changes (e.g., Rails 8.1 delegation requirements)
- Check CI pipeline covers all versions

### Generator Flexibility
The generator supports multiple options:
```bash
--framework=cypress|playwright    # Test framework choice
--install_folder=e2e             # Custom location
--install_with=yarn|npm|skip     # Package manager
--api_prefix=/api                # Proxy routing
--experimental                   # VCR features
```
Test generator combinations when modifying templates.

## 📚 Useful Resources

- **RSpec Documentation**: https://rspec.info/
- **Rack Specification**: https://github.com/rack/rack/blob/main/SPEC.rdoc
- **Cypress Best Practices**: https://docs.cypress.io/guides/references/best-practices
- **Playwright Best Practices**: https://playwright.dev/docs/best-practices
- **FactoryBot Documentation**: https://github.com/thoughtbot/factory_bot
- **VCR Documentation**: https://github.com/vcr/vcr

## 🤝 Contributing Workflow

1. **Create feature branch** from master: `git checkout -b feature/my-feature`
2. **Make focused changes** - one logical change per PR
3. **Write/update tests** for your changes
4. **Run full test suite**: `bundle exec rake`
5. **Run RuboCop**: `bundle exec rubocop`
6. **Update CHANGELOG.md** if user-facing change
7. **Commit with descriptive message**
8. **Push and create PR**: `git push -u origin feature/my-feature && gh pr create`
9. **Address CI failures** immediately - don't wait for merge

## 💡 Tips for Claude Code Agents

- **Read tests first** when understanding a component - they document intended behavior
- **Check `specs_e2e/` examples** to understand real-world usage patterns
- **Use `bundle exec rspec --focus`** to iterate quickly on single test
- **Reference existing middleware** when adding new endpoints
- **Follow Rack middleware conventions** (call next app, return 3-element array)
- **Log liberally** during development - users need debugging info
- **Consider backward compatibility** before changing public APIs
- **Test generator output** by running it in a fresh Rails app

---

**Questions?** Check the README.md, docs/ folder, or existing tests for examples.
