# Changelog

All notable changes to this project will be documented in this file.  
This project adheres to [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

## [1.19.0] - 2025-10-01

### Added
* **Rake tasks for test execution**: Added `cypress:open` and `cypress:run` rake tasks for seamless test execution, similar to cypress-rails functionality. Also added `playwright:open` and `playwright:run` tasks.
* **Server lifecycle hooks**: Added configuration hooks for test server management:
  - `before_server_start`: Run code before Rails server starts
  - `after_server_start`: Run code after Rails server is ready
  - `after_transaction_start`: Run code after database transaction begins
  - `after_state_reset`: Run code after application state is reset
  - `before_server_stop`: Run code before Rails server stops
* **State reset endpoint**: Added `/cypress_rails_reset_state` and `/__cypress__/reset_state` endpoints for compatibility with cypress-rails
* **Transactional test mode**: Added support for automatic database transaction rollback between tests
* **Environment configuration**: Support for `CYPRESS_RAILS_HOST` and `CYPRESS_RAILS_PORT` environment variables
* **Automatic server management**: Test server automatically starts and stops with test execution

### Migration Guide

#### From Manual Server Management (Old Way)
If you were previously running tests manually:

**Before (Manual Process):**
```bash
# Terminal 1: Start Rails server
CYPRESS=1 bin/rails server -p 5017

# Terminal 2: Run tests
yarn cypress open --project ./e2e
# or
npx cypress run --project ./e2e
```

**After (Automated with Rake Tasks):**
```bash
# Single command - server managed automatically!
bin/rails cypress:open
# or
bin/rails cypress:run
```

#### From cypress-rails Gem
If migrating from the `cypress-rails` gem:

1. Update your Gemfile:
   ```ruby
   # Remove
   gem 'cypress-rails'

   # Add
   gem 'cypress-on-rails', '~> 1.0'
   ```

2. Run bundle and generator:
   ```bash
   bundle install
   rails g cypress_on_rails:install
   ```

3. Configure hooks in `config/initializers/cypress_on_rails.rb` (optional):
   ```ruby
   CypressOnRails.configure do |c|
     # These hooks match cypress-rails functionality
     c.before_server_start = -> { DatabaseCleaner.clean }
     c.after_server_start = -> { Rails.application.load_seed }
     c.transactional_server = true
   end
   ```

4. Use the same commands you're familiar with:
   ```bash
   bin/rails cypress:open
   bin/rails cypress:run
   ```

---

## [1.18.0] — 2025-08-27
[Compare]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.17.0...v1.18.0

### Added
* **VCR middleware (use_cassette)**: optional middleware that wraps each request with `VCR.use_cassette` (GraphQL supported). Includes configuration via `config/cypress_on_rails.rb` and Cypress commands. [PR 167]
* **Rails 8 example app & CI job** to validate against the newest framework version. [PR 174]

### Changed
* **Rails 7.2 example app** updates and CI wiring. [PR 171]
* Updated JetBrains logo/assets in README. [PR 177]

### Removed
* Dropped Rails 4 and 5 from CI matrix. [PR 172]

---

## [1.17.0] — 2024-01-28
[Compare]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.16.0...v1.17.0

### Changed
* Removed the update generator and reduced options for install generator [PR 149]

### Fixed
* Fix update `index.js` in install generator [PR 147] by [Judahmeek]
* Support Rails 7.1 by adding `content-type` header to generated `on-rails.js` file [PR 148] by [anark]
* Rewind body before reading it [PR 150]

---

## [1.16.0]
[Compare]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.15.1...v1.16.0

### Added
* Add support for `before_request` options on the middleware, for authentication [PR 138] by [RomainEndelin]

---

## [1.15.1]
[Compare]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.15.0...v1.15.1

### Fixed
* Fix `cypress_folder` deprecation warning by internal code [PR 136]

---

## [1.15.0]
[Compare]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.14.0...v1.15.0

### Changed
* Add support for any e2e testing framework starting with Playwright [PR 131] by [KhaledEmaraDev]

---

## [1.14.0]
[Compare]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.13.1...v1.14.0

### Changed
* Add support for proxy routes through `api_prefix` [PR 130] by [RomainEndelin]

### Fixed
* Properly copies the cypress_helper file when running the update generator [PR 117] by [alvincrespo]

### Tasks
* Pass Cypress record key to GitHub Action [PR 110]

---

## [1.13.1]
[Compare]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.13.0...v1.13.1

### Fixed
* `use_vcr_middleware` disabled by default [PR 109]

---

## [1.13.0]
[Compare]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.12.1...v1.13.0

### Changed
* Add support for matching npm package and VCR
* Generate for Cypress 10 [PR 108]

---

## [1.12.1]
[Compare]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.12.0...v1.12.1

### Tasks
* Document how to setup Factory Associations [PR 100]

### Fixed
* Keep track of factory manual reloads to prevent auto_reload from reloading again [PR 98]

---

## [1.12.0]
[Compare]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.11.0...v1.12.0

### Changed
* Only reload factories on clean instead of every factory create request [PR 95]
* Alternative command added for get tail of logs [PR 89] by [ccrockett]

### Tasks
* Switch from Travis to GitHub Actions [PR 96]

---

## [1.11.0]
[Compare]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.10.1...v1.11.0

### Changed
* Improve app command logging on Cypress
* Allow build and build_list commands to be executed against FactoryBot [PR 87] by [Alexander-Blair]

---

## [1.10.1]
[Compare]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.9.1...v1.10.1

### Changed
* Improve error message received from failed command

---

## [1.9.1]
[Compare]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.9.0...v1.9.1

### Fixed
* Fix using `load` in command files

---

## [1.9.0]
[Compare]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.8.1...v1.9.0

### Changed
* Update default generated folder to `cypress` instead of `spec/cypress`
* Add a generator option to not install Cypress
* Generator by default does not include examples
* Default on local to run Cypress in development mode

---

## [1.8.1]
[Compare]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.8.0...v1.8.1

### Fixed
* Remove `--silent` option when adding Cypress [PR 76]
* Update Cypress examples to use "preserve" instead of "whitelist" [PR 75] by [alvincrespo]

---

## [1.8.0]
[Compare]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.7.0...v1.8.0

### Changed
* Use `FactoryBot#reload` to reset FactoryBot

---

## [1.7.0]
[Compare]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.6.0...v1.7.0

### Changed
* Improve eval() in command executor [PR 46] by [Systho]

### Fixed
* Add middleware after load_config_initializers [PR 62] by [duytd]

---

## [1.6.0]
[Compare]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.5.1...v1.6.0

### Changed
* Change default port to 5017 [PR 49] by [vfonic]

### Fixed
* Fix file location warning message in clean.rb [PR 54] by [ootoovak]

---

## [1.5.1]
[Compare]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.5.0...v1.5.1

### Fixed
* Fix FactoryBot Trait not registered error [PR 43]

---

## [1.5.0]
[Compare]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.4.2...v1.5.0

### Added
* Serialize and return responses to be used in tests [PR 34]
* Update generator to make it easier to update core generated files [PR 35]

### Tasks
* Update integration tests [PR 36]

---

## [1.4.2]
[Compare]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.4.1...v1.4.2

### Fixed
* Update generator to use full paths for Factory files [PR 33]

---

## [1.4.1]
[Compare]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.4.0...v1.4.1

### Fixed
* Fix install generator when using npm [PR 22] by [josephan]

### Tasks
* Fix typo in authentication docs [PR 29] by [badimalex]
* Gemspec: Drop EOL'd property `rubyforge_project` [PR 27] by [olleolleolle]
* Update Travis CI badge in README [PR 31]
* Fix CI by installing Cypress dependencies on Travis CI [PR 31]

---

## [1.4.0]
[Compare]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.3.0...v1.4.0

* Accept an options argument for scenarios [PR 18] by [ericraio]

### Changed
* Renamed CypressDev to CypressOnRails

---

## [1.3.0]
### Added
* Send any arguments to simple Rails factory, not only hashes by [grantspeelman]

### Improved
* Stop running Cypress examples on CI

---

## [1.2.1]
### Fixed
* Simple factory fails silently, changed to use `create!`

---

## [1.2.0]
### Tasks
* Add additional log failure logging

---

## [1.1.1]
### Fixed
* Smart factory wrapper can handle when factory files get deleted

---

## [1.1.0]
### Tasks
* Add Cypress examples to install generator
* Add ActiveRecord integration specs

---

## 1.0.1
### Fixed
* Install generator adding `on-rails.js` to `import.js`

---

## 1.0.0
* Renamed to CypressDev
* Middleware stripped down to make it more flexible and generic
* Concept of generic commands introduced that can have any Ruby in it
* And lots of other changes

---

## 0.2.2 (2018-03-24)
### Fixed
* Fix major bug when using scenarios

---

## 0.2.1 (2017-11-05)
### Fixed
* Fix failure in API tests

---

## 0.2.0 (2017-11-05)
### Changed
* Remove the need for a separate port for the setup calls. Requires rerunning `cypress:install` generator

---

## 0.1.5 (2017-11-01)
### Added
* `cy.rails` command for executing raw Ruby on the backend
* `cy.setupRails` command for resetting application state
* `cypress:install` generator now adds a `beforeEach` call to `cy.setupRails`
* `cypress:install` generator configures the `cache_classes` setting in `config/environments/test.rb`
* Configuration option to include further modules in your runcontext

---

## 0.1.2 (2017-10-31)
* First release.

---

[PR 167]: https://github.com/shakacode/cypress-playwright-on-rails/pull/167
[PR 174]: https://github.com/shakacode/cypress-playwright-on-rails/pull/174
[PR 171]: https://github.com/shakacode/cypress-playwright-on-rails/pull/171
[PR 177]: https://github.com/shakacode/cypress-playwright-on-rails/pull/177
[PR 172]: https://github.com/shakacode/cypress-playwright-on-rails/pull/172
[PR 149]: https://github.com/shakacode/cypress-playwright-on-rails/pull/149
[PR 147]: https://github.com/shakacode/cypress-playwright-on-rails/pull/147
[PR 148]: https://github.com/shakacode/cypress-playwright-on-rails/pull/148
[PR 150]: https://github.com/shakacode/cypress-playwright-on-rails/pull/150
[PR 138]: https://github.com/shakacode/cypress-playwright-on-rails/pull/138
[PR 136]: https://github.com/shakacode/cypress-playwright-on-rails/pull/136
[PR 131]: https://github.com/shakacode/cypress-playwright-on-rails/pull/131
[PR 130]: https://github.com/shakacode/cypress-playwright-on-rails/pull/130
[PR 117]: https://github.com/shakacode/cypress-playwright-on-rails/pull/117
[PR 110]: https://github.com/shakacode/cypress-playwright-on-rails/pull/110
[PR 109]: https://github.com/shakacode/cypress-playwright-on-rails/pull/109
[PR 108]: https://github.com/shakacode/cypress-playwright-on-rails/pull/108
[PR 100]: https://github.com/shakacode/cypress-playwright-on-rails/pull/100
[PR 98]: https://github.com/shakacode/cypress-playwright-on-rails/pull/98
[PR 95]: https://github.com/shakacode/cypress-playwright-on-rails/pull/95
[PR 89]: https://github.com/shakacode/cypress-playwright-on-rails/pull/89
[PR 96]: https://github.com/shakacode/cypress-playwright-on-rails/pull/96
[PR 87]: https://github.com/shakacode/cypress-playwright-on-rails/pull/87
[PR 76]: https://github.com/shakacode/cypress-playwright-on-rails/pull/76
[PR 75]: https://github.com/shakacode/cypress-playwright-on-rails/pull/75
[PR 46]: https://github.com/shakacode/cypress-playwright-on-rails/pull/46
[PR 62]: https://github.com/shakacode/cypress-playwright-on-rails/pull/62
[PR 49]: https://github.com/shakacode/cypress-playwright-on-rails/pull/49
[PR 54]: https://github.com/shakacode/cypress-playwright-on-rails/pull/54
[PR 43]: https://github.com/shakacode/cypress-playwright-on-rails/pull/43
[PR 34]: https://github.com/shakacode/cypress-playwright-on-rails/pull/34
[PR 35]: https://github.com/shakacode/cypress-playwright-on-rails/pull/35
[PR 36]: https://github.com/shakacode/cypress-playwright-on-rails/pull/36
[PR 33]: https://github.com/shakacode/cypress-playwright-on-rails/pull/33
[PR 22]: https://github.com/shakacode/cypress-playwright-on-rails/pull/22
[PR 29]: https://github.com/shakacode/cypress-playwright-on-rails/pull/29
[PR 27]: https://github.com/shakacode/cypress-playwright-on-rails/pull/27
[PR 31]: https://github.com/shakacode/cypress-playwright-on-rails/pull/31
[PR 18]: https://github.com/shakacode/cypress-playwright-on-rails/pull/18

<!-- Version diff reference list -->
[1.19.0]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.18.0...v1.19.0
[1.18.0]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.17.0...v1.18.0
[1.17.0]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.16.0...v1.17.0
[1.16.0]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.15.1...v1.16.0
[1.15.1]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.15.0...v1.15.1
[1.15.0]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.14.0...v1.15.0
[1.14.0]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.13.1...v1.14.0
[1.13.1]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.13.0...v1.13.1
[1.13.0]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.12.1...v1.13.0
[1.12.1]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.12.0...v1.12.1
[1.12.0]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.11.0...v1.12.0
[1.11.0]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.10.1...v1.11.0
[1.10.1]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.9.1...v1.10.1
[1.9.1]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.9.0...v1.9.1
[1.9.0]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.8.1...v1.9.0
[1.8.1]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.8.0...v1.8.1
[1.8.0]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.7.0...v1.8.0
[1.7.0]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.6.0...v1.7.0
[1.6.0]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.5.1...v1.6.0
[1.5.1]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.5.0...v1.5.1
[1.5.0]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.4.2...v1.5.0
[1.4.2]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.4.1...v1.4.2
[1.4.1]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.4.0...v1.4.1
[1.4.0]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.2.1...v1.3.0
[1.2.1]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.1.1...v1.2.0
[1.1.1]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/shakacode/cypress-playwright-on-rails/compare/v1.0.0...v1.1.0
