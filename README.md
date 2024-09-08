# CypressOnRails

![Build Status](https://github.com/shakacode/cypress-on-rails/actions/workflows/ruby.yml/badge.svg)
[![cypress-on-rails](https://img.shields.io/endpoint?url=https://dashboard.cypress.io/badge/simple/2b6cjr/master&style=plastic&logo=cypress)](https://dashboard.cypress.io/projects/2b6cjr/runs)
[![Gem Version](https://badge.fury.io/rb/cypress-on-rails.svg)](https://badge.fury.io/rb/cypress-on-rails)

----

This project is sponsored by the software consulting firm [ShakaCode](https://www.shakacode.com), creator of the [React on Rails Gem](https://github.com/shakacode/react_on_rails). 

### ShakaCode Support

[ShakaCode](https://www.shakacode.com) focuses on helping Ruby on Rails teams use React and Webpack better. We can upgrade your project and improve your development and customer experiences, allowing you to focus on building new features or fixing bugs instead. 

For an overview of working with us, see our [Client Engagement Model](https://www.shakacode.com/blog/client-engagement-model/) article and [how we bill for time](https://www.shakacode.com/blog/shortcut-jira-trello-github-toggl-time-and-task-tracking/).

We also specialize in helping development teams lower infrastructure and CI costs. Check out our project [Control Plane Flow](https://github.com/shakacode/control-plane-flow/), which can allow you to get the ease of Heroku with the power of Kubernetes and big cost savings.

If you think ShakaCode can help your project, [click here](https://meetings.hubspot.com/justingordon/30-minute-consultation) to book a call with [Justin Gordon](mailto:justin@shakacode.com), the creator of React on Rails and Shakapacker.

Here's a testimonial of how ShakaCode can help from [Florian Gößler](https://github.com/FGoessler) of [Blinkist](https://www.blinkist.com/), January 2, 2023:
> Hey Justin 👋
>
> I just wanted to let you know that we today shipped the webpacker to shakapacker upgrades and it all seems to be running smoothly! Thanks again for all your support and your teams work! 😍
>
> On top of your work, it was now also very easy for me to upgrade Tailwind and include our external node_module based web component library which we were using for our other (more modern) apps already. That work is going to be shipped later this week though as we are polishing the last bits of it. 😉
>
> Have a great 2023 and maybe we get to work together again later in the year! 🙌

Read the [full review here](https://clutch.co/profile/shakacode#reviews?sort_by=date_DESC#review-2118154).

---

Feel free to engage in discussions around this gem at our [Slack Channel](https://join.slack.com/t/reactrails/shared_invite/enQtNjY3NTczMjczNzYxLTlmYjdiZmY3MTVlMzU2YWE0OWM0MzNiZDI0MzdkZGFiZTFkYTFkOGVjODBmOWEyYWQ3MzA2NGE1YWJjNmVlMGE) or our [forum category for Cypress](https://forum.shakacode.com/c/cypress-on-rails/55).

Need help with cypress-on-rails? Contact [Justin Gordon](mailto:justin@shakacode.com).

----

# New to Cypress?
Consider first learning the basics of Cypress before attempting to integrate with Ruby on Rails.

* [Good start Here](https://docs.cypress.io/examples/tutorials.html#Best-Practices)

# Totally new to Playwright?
Consider first learning the basics of Playwright before attempting to integrate with Ruby on Rails.

* [Good start Here](https://playwright.dev/docs/writing-tests)

## Overview

Gem for using [cypress.io](http://github.com/cypress-io/) or [playwright.dev](https://playwright.dev/) in Rails and Ruby Rack applications to control state as mentioned in [Cypress Best Practices](https://docs.cypress.io/guides/references/best-practices.html#Organizing-Tests-Logging-In-Controlling-State). 

It allows you to run code in the context of the application when executing Cypress or Playwright tests.
Do things like:
* use database_cleaner before each test
* seed the database with default data for each test
* use factory_bot to set up data
* create scenario files used for specific tests

Has examples of setting up state with:
* factory_bot
* rails test fixtures
* scenarios
* custom commands

## Resources
* [Video of getting started with this gem](https://grant-ps.blog/2018/08/10/getting-started-with-cypress-io-and-ruby-on-rails/)
* [Article: Introduction to Cypress on Rails](https://www.shakacode.com/blog/introduction-to-cypress-on-rails/)

## Installation

Add this to your `Gemfile`:

```ruby
group :test, :development do
  gem 'cypress-on-rails', '~> 1.0'
end
```

Generate the boilerplate code using:

```shell
# by default installs only cypress
bin/rails g cypress_on_rails:install

# if you have/want a different cypress folder (default is e2e)
bin/rails g cypress_on_rails:install --install_folder=spec/cypress

# to install playwright instead of cypress
bin/rails g cypress_on_rails:install --framework playwright

# if you target the Rails server with a path prefix to your URL
bin/rails g cypress_on_rails:install --api_prefix=/api

# if you want to install with npm instead
bin/rails g cypress_on_rails:install --install_with=npm

# if you already have cypress installed globally
bin/rails g cypress_on_rails:install --install_with=skip

# to update the generated files run
bin/rails g cypress_on_rails:install --install_with=skip
```

The generator modifies/adds the following files/directory in your application:
* `config/initializers/cypress_on_rails.rb` used to configure Cypress on Rails
* `e2e/cypress/integration/` contains your cypress tests
* `e2e/cypress/support/on-rails.js` contains Cypress on Rails support code
* `e2e/cypress/e2e_helper.rb` contains helper code to require libraries like factory_bot
* `e2e/cypress/app_commands/` contains your scenario definitions
* `e2e/playwright/e2e/` contains your playwright tests
* `e2e/playwright/support/on-rails.js` contains Playwright on Rails support code

If you are not using `database_cleaner` look at `e2e/cypress/app_commands/clean.rb`.
If you are not using `factory_bot` look at `e2e/cypress/app_commands/factory_bot.rb`.

Now you can create scenarios and commands that are plain Ruby files that get loaded through middleware, the ruby sky is your limit.

### Update your database.yml

When writing and running tests on your local computer, it's recommended to start your server in development mode so that changes you
make are picked up without having to restart your local server.

It's recommended you update your `database.yml` to check if the `CYPRESS` environment variable is set and switch it to the test database
otherwise, cypress will keep clearing your development database.

For example:
```yaml
development:
  <<: *default
  database: <%= ENV['CYPRESS'] ? 'my_db_test' : 'my_db_development' %>
test:
  <<: *default
  database: my_db_test
```

### WARNING
*WARNING!!:* cypress-on-rails can execute arbitrary ruby code
Please use with extra caution if starting your local server on 0.0.0.0 or running the gem on a hosted server

## Usage

Getting started on your local environment

```shell
# start rails
CYPRESS=1 bin/rails server -p 5017

# in separate window start cypress
yarn cypress open --project ./e2e
# or for npm
npx cypress open --project ./e2e
# or for playwright
yarn playwright test --ui
# or using npm
npx playwright test --ui
```

How to run cypress on CI

```shell
# setup rails and start server in background
# ...

yarn run cypress run --project ./e2e
# or for npm
npx cypress run --project ./e2e
```

### Example of using factory bot

You can run your [factory_bot](https://github.com/thoughtbot/factory_bot) directly as well

then in Cypress
```js
// spec/cypress/e2e/simple.cy.js
describe('My First Test', () => {
  it('visit root', () => {
    // This calls to the backend to prepare the application state
    cy.appFactories([
      ['create_list', 'post', 10],
      ['create', 'post', {title: 'Hello World'} ],
      ['create', 'post', 'with_comments', {title: 'Factory_bot Traits here'} ] // use traits
    ])

    // Visit the application under test
    cy.visit('/')

    cy.contains('Hello World')

    // Accessing result
    cy.appFactories([['create', 'invoice', { paid: false }]]).then((records) => {
     cy.visit(`/invoices/${records[0].id}`);
    });
  })
})
```

then in Playwright
```js
const { test, expect, request } = require('@playwright/test');

test.describe('My First Test', () => {
    test('visit root', async ({ page }) => {
        // This calls to the backend to prepare the application state
        await appFactories([
            ['create_list', 'post', 10],
            ['create', 'post', { title: 'Hello World' }],
            ['create', 'post', 'with_comments', { title: 'Factory_bot Traits here' }]
        ]);

        // Visit the application under test
        await page.goto('/');
        
        await expect(page).toHaveText('Hello World');

        // Accessing result
        const records = await appFactories([['create', 'invoice', { paid: false }]]);
        await page.goto(`/invoices/${records[0].id}`);
    });
});
```

You can check the [association docs](docs/factory_bot_associations.md) on more ways to setup association with the correct data.

In some cases, using static Cypress fixtures may not provide sufficient flexibility when mocking HTTP response bodies. It's possible to use `FactoryBot.build` to generate Ruby hashes that can then be used as mock JSON responses:
```ruby
FactoryBot.define do
  factory :some_web_response, class: Hash do
    initialize_with { attributes.deep_stringify_keys }

    id { 123 }
    name { 'Mr Blobby' }
    occupation { 'Evil pink clown' }
  end
end

FactoryBot.build(:some_web_response => { 'id' => 123, 'name' => 'Mr Blobby', 'occupation' => 'Evil pink clown' })
```

This can then be combined with Cypress mocks:
```js
describe('My First Test', () => {
  it('visit root', () => {
    // This calls to the backend to generate the mocked response
    cy.appFactories([
      ['build', 'some_web_response', { name: 'Baby Blobby' }]
    ]).then(([responseBody]) => {
      cy.intercept('http://some-external-url.com/endpoint', {
        body: responseBody
      });

      // Visit the application under test
      cy.visit('/')
    })

    cy.contains('Hello World')
  })
})
```

### Example of loading Rails test fixtures
```ruby
# spec/e2e/app_commands/activerecord_fixtures.rb
require "active_record/fixtures"

fixtures_dir = ActiveRecord::Tasks::DatabaseTasks.fixtures_path
fixture_files = Dir["#{fixtures_dir}/**/*.yml"].map { |f| f[(fixtures_dir.size + 1)..-5] }

logger.debug "loading fixtures: { dir: #{fixtures_dir}, files: #{fixture_files} }"
ActiveRecord::FixtureSet.reset_cache
ActiveRecord::FixtureSet.create_fixtures(fixtures_dir, fixture_files)
```

```js
// spec/cypress/e2e/simple.cy.js
describe('My First Test', () => {
  it('visit root', () => {
    // This calls to the backend to prepare the application state
    cy.appFixtures()

    // Visit the application under test
    cy.visit('/')

    cy.contains('Hello World')
  })
})
```

### Example of using scenarios

Scenarios are named `before` blocks that you can reference in your test.

You define a scenario in the `spec/e2e/app_commands/scenarios` directory:
```ruby
# spec/cypress/app_commands/scenarios/basic.rb
Profile.create name: "Cypress Hill"

# or if you have factory_bot enabled in your cypress_helper
CypressOnRails::SmartFactoryWrapper.create(:profile, name: "Cypress Hill")
```

Then reference the scenario in your test:
```js
// spec/cypress/e2e/scenario_example.cy.js
describe('My First Test', () => {
  it('visit root', () => {
    // This calls to the backend to prepare the application state
    cy.appScenario('basic')

    cy.visit('/profiles')

    cy.contains('Cypress Hill')
  })
})
```

### Example of using app commands

Create a Ruby file in the `spec/e2e/app_commands` directory:
```ruby
# spec/e2e/app_commands/load_seed.rb
load "#{Rails.root}/db/seeds.rb"
```

Then reference the command in your test with `cy.app('load_seed')`:
```js
// spec/cypress/e2e/simple.cy.js
describe('My First Test', () => {
  beforeEach(() => { cy.app('load_seed') })

  it('visit root', () => {
    cy.visit('/')

    cy.contains("Seeds")
  })
})
```

### Example of using scenario with Playwright

Scenarios are named `before` blocks that you can reference in your test.

You define a scenario in the `spec/e2e/app_commands/scenarios` directory:
```ruby
# spec/e2e/app_commands/scenarios/basic.rb
Profile.create name: "Cypress Hill"

# or if you have factory_bot enabled in your cypress_helper
CypressOnRails::SmartFactoryWrapper.create(:profile, name: "Cypress Hill")
```

Then reference the scenario in your test:
```js
// spec/playwright/e2e/scenario_example.spec.js
import { test, expect } from "@playwright/test";
import { app, appScenario } from '../../support/on-rails';

test.describe("Rails using scenarios examples", () => {
  test.beforeEach(async ({ page }) => {
    await app('clean');
  });

  test("setup basic scenario", async ({ page }) => {
    await appScenario('basic');
    await page.goto("/");
  });
});
```

## Experimental Features (matching npm package)

Please test and give feedback.

Add the npm package:

```
yarn add cypress-on-rails --dev
```

### for VCR

This only works when you start the Rails server with a single worker and single thread
It can be used in two modes:
- with separate insert/eject calls (more general, recommended way)
- with use_cassette wrapper (supports only GraphQL integration)

#### basic setup

Add your VCR configuration to your `cypress_helper.rb`

```ruby
require 'vcr'
VCR.configure do |config|
  config.hook_into :webmock
end
```

Add to your `cypress/support/index.js`:

```js
import 'cypress-on-rails/support/index'
```

Add to your `cypress/app_commands/clean.rb`:

```ruby
VCR.eject_cassette # make sure we no cassettes inserted before the next test starts
VCR.turn_off!
WebMock.disable! if defined?(WebMock)
```

#### insert/eject setup

Add to your `config/cypress_on_rails.rb`:

```ruby
  c.use_vcr_middleware = !Rails.env.production? && ENV['CYPRESS'].present?
  # c.use_vcr_use_cassette_middleware = !Rails.env.production? && ENV['CYPRESS'].present?
```

#### insert/eject usage

You have `vcr_insert_cassette` and `vcr_eject_cassette` available. https://www.rubydoc.info/github/vcr/vcr/VCR:insert_cassette


```js
describe('My First Test', () => {
  beforeEach(() => { cy.app('load_seed') })

  it('visit root', () => {
    cy.app('clean') // have a look at e2e/app_commands/clean.rb

    cy.vcr_insert_cassette('cats', { record: "new_episodes" })
    cy.visit('/using_vcr/index')

    cy.get('a').contains('Cats').click()
    cy.contains('Wikipedia has a recording of a cat meowing, because why not?')

    cy.vcr_eject_cassette()

    cy.vcr_insert_cassette('cats')
    cy.visit('/using_vcr/record_cats')
    cy.contains('Wikipedia has a recording of a cat meowing, because why not?')
  })
})
```

#### use_cassette setup

Add to your `config/cypress_on_rails.rb`:

```ruby
  # c.use_vcr_middleware = !Rails.env.production? && ENV['CYPRESS'].present?
  c.use_vcr_use_cassette_middleware = !Rails.env.production? && ENV['CYPRESS'].present?
```

Adjust record mode in `config/cypress_on_rails.rb` if needed:

```ruby
  c.vcr_record_mode = :once # Use to choose VCR record mode 
```

Add to your `cypress/support/command.js`:

```js
  // Add proxy-like mock to add operation name into query string
  Cypress.Commands.add('mockGraphQL', () => {
    cy.on('window:before:load', (win) => {
      const originalFetch = win.fetch;
      const fetch = (path, options, ...rest) => {
        if (options && options.body) {
          try {
            const body = JSON.parse(options.body);
            if (body.operationName) {
              return originalFetch(`${path}?operation=${body.operationName}`, options, ...rest);
            }
          } catch (e) {
            return originalFetch(path, options, ...rest);
          }
        }
        return originalFetch(path, options, ...rest);
      };
      cy.stub(win, 'fetch', fetch);
    });
  });
```

Add to your `cypress/support/on-rails.js`, to `beforeEach`:

```js
  cy.mockGraphQL() // for GraphQL usage with use_cassette, see cypress/support/commands.rb
```

#### use_cassette usage

There is nothing special to be called during the Cypress scenario. Each request is wrapped with `VCR.use_cassette`.
Consider VCR configuration in `cypress_helper.rb` to ignore hosts.

All cassettes will be recorded and saved automatically, using the pattern `<vcs_cassettes_path>/graphql/<operation_name>`


## `before_request` configuration

You may perform any custom action before running a CypressOnRails command, such as authentication, or sending metrics.  Please set `before_request` as part of the CypressOnRails configuration.

You should get familiar with [Rack middlewares](https://www.rubyguides.com/2018/09/rack-middleware/).
If your function returns a `[status, header, body]` response, CypressOnRails will halt, and your command will not be executed. To execute the command, `before_request` should return `nil`.

### Authenticate CypressOnRails

```ruby
  CypressOnRails.configure do |c|
    # ...

    # Refer to https://www.rubydoc.info/gems/rack/Rack/Request for the `request` argument.
    c.before_request = lambda { |request|
      body = JSON.parse(request.body.string)
      if body['cypress_token'] != ENV.fetch('SWEEP_CYPRESS_SECRET_TOKEN')
        # You may also use warden for authentication:
        #   if !request.env['warden'].authenticate(:secret_key)
        return [401, {}, ['unauthorized']]
      end

    }
  end
```

### Send usage metrics

```ruby
  CypressOnRails.configure do |c|
    # ...

    # Refer to https://www.rubydoc.info/gems/rack/Rack/Request for the `request` argument.
    c.before_request = lambda { |request|
      statsd = Datadog::Statsd.new('localhost', 8125)

      statsd.increment('cypress_on_rails.requests')
    }
  end
```

## Usage with other rack applications

Add CypressOnRails to your config.ru

```ruby
# an example config.ru
require File.expand_path('my_app', File.dirname(__FILE__))

require 'cypress_on_rails/middleware'
CypressOnRails.configure do |c|
  c.cypress_folder = File.expand_path("#{__dir__}/test/cypress")
end
use CypressOnRails::Middleware

run MyApp
```

add the following file to Cypress

```js
// test/cypress/support/on-rails.js
// CypressOnRails: don't remove these commands
Cypress.Commands.add('appCommands', (body) => {
  cy.request({
    method: 'POST',
    url: '/__cypress__/command',
    body: JSON.stringify(body),
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
    },
    log: true,
    failOnStatusCode: true
  })
});

Cypress.Commands.add('app', (name, command_options) => {
  cy.appCommands({name: name, options: command_options})
});

Cypress.Commands.add('appScenario', (name) => {
  cy.app('scenarios/' + name)
});

Cypress.Commands.add('appFactories', (options) => {
  cy.app('factory_bot', options)
});
// CypressOnRails: end

// The next is optional
beforeEach(() => {
  cy.app('clean') // have a look at cypress/app_commands/clean.rb
});
```

add the following file to Playwright
```js
// test/playwright/support/on-rails.js
async function appCommands(body) {
    const context = await request.newContext();
    const response = await context.post('/__e2e__/command', {
        data: body,
        headers: {
            'Content-Type': 'application/json'
        }
    });

    if (response.status() !== 201) {
        const responseBody = await response.text();
        throw new Error(`Expected status 201 but got ${response.status()} - ${responseBody}`);
    }

    return response.json();
}

async function app(name, commandOptions = {}) {
    const body = await appCommands({ name, options: commandOptions });
    return body[0];
}

async function appScenario(name, options = {}) {
    const body = { name: `scenarios/${name}`, options };
    const result = await appCommands(body);
    return result[0];
}

async function appFactories(options) {
    return app('factory_bot', options);
}

async function clean() {
    await app('clean');
}
```

## API Prefix

If your Rails server is exposed under a proxy, typically https://my-local.dev/api, you can use the `api_prefix` option.
In `config/initializers/cypress_on_rails.rb`, add this line:
```ruby
  CypressOnRails.configure do |c|
    # ...
    c.api_prefix = '/api'
  end
```

## Contributing

1. Fork it ( https://github.com/shakacode/cypress-on-rails/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Supporters

<a href="https://www.jetbrains.com">
  <img src="https://user-images.githubusercontent.com/4244251/184881139-42e4076b-024b-4b30-8c60-c3cd0e758c0a.png" alt="JetBrains" height="120px">
</a>
<a href="https://scoutapp.com">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://user-images.githubusercontent.com/4244251/184881147-0d077438-3978-40da-ace9-4f650d2efe2e.png">
    <source media="(prefers-color-scheme: light)" srcset="https://user-images.githubusercontent.com/4244251/184881152-9f2d8fba-88ac-4ba6-873b-22387f8711c5.png">
    <img alt="ScoutAPM" src="https://user-images.githubusercontent.com/4244251/184881152-9f2d8fba-88ac-4ba6-873b-22387f8711c5.png" height="120px">
  </picture>
</a>
<a href="https://shakacode.controlplane.com">
  <picture>
    <img alt="Control Plane" src="https://github.com/shakacode/.github/assets/20628911/90babd87-62c4-4de3-baa4-3d78ef4bec25" height="120px">
  </picture>
</a>
<br />
<a href="https://www.browserstack.com">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://user-images.githubusercontent.com/4244251/184881122-407dcc29-df78-4b20-a9ad-f597b56f6cdb.png">
    <source media="(prefers-color-scheme: light)" srcset="https://user-images.githubusercontent.com/4244251/184881129-e1edf4b7-3ae1-4ea8-9e6d-3595cf01609e.png">
    <img alt="BrowserStack" src="https://user-images.githubusercontent.com/4244251/184881129-e1edf4b7-3ae1-4ea8-9e6d-3595cf01609e.png" height="55px">
  </picture>
</a>
<a href="https://railsautoscale.com">
  <img src="https://user-images.githubusercontent.com/4244251/184881144-95c2c25c-9879-4069-864d-4e67d6ed39d2.png" alt="Rails Autoscale" height="55px">
</a>
<a href="https://www.honeybadger.io">
  <img src="https://user-images.githubusercontent.com/4244251/184881133-79ee9c3c-8165-4852-958e-31687b9536f4.png" alt="Honeybadger" height="55px">
</a>
<a href="https://reviewable.io">
  <img src="https://user-images.githubusercontent.com/20628911/230848305-c94510a4-82d7-468f-bf9f-eeb81d3f2ce0.png" alt="Reviewable" height="55px">
</a>

<br />
<br />

The following companies support our open source projects, and ShakaCode uses their products!
