# VCR Integration Guide

Complete guide for recording and replaying HTTP interactions in your tests using VCR with cypress-playwright-on-rails.

## Table of Contents
- [Overview](#overview)
- [Installation](#installation)
- [Configuration](#configuration)
- [Insert/Eject Mode](#inserteject-mode)
- [Use Cassette Mode](#use-cassette-mode)
- [GraphQL Integration](#graphql-integration)
- [Advanced Usage](#advanced-usage)
- [Troubleshooting](#troubleshooting)

## Overview

VCR (Video Cassette Recorder) records your test suite's HTTP interactions and replays them during future test runs for fast, deterministic tests. This is particularly useful for:
- Testing against third-party APIs
- Avoiding rate limits
- Testing without internet connection
- Ensuring consistent test data
- Speeding up test execution

## Installation

### 1. Add required gems
```ruby
# Gemfile
group :test, :development do
  gem 'vcr'
  gem 'webmock'
  gem 'cypress-on-rails', '~> 1.0'
end
```

### 2. Install npm package (optional, for enhanced features)
```bash
yarn add -D cypress-on-rails
# or
npm install --save-dev cypress-on-rails
```

## Configuration

### Basic VCR Setup

```ruby
# config/initializers/cypress_on_rails.rb
CypressOnRails.configure do |c|
  # Enable VCR middleware
  c.use_vcr_middleware = !Rails.env.production? && ENV['CYPRESS'].present?
  
  # VCR configuration options
  c.vcr_options = {
    # HTTP library to hook into
    hook_into: :webmock,
    
    # Default recording mode
    default_cassette_options: { 
      record: :once,  # :once, :new_episodes, :none, :all
      match_requests_on: [:method, :uri, :body],
      allow_unused_http_interactions: false
    },
    
    # Where to save cassettes
    cassette_library_dir: Rails.root.join('spec/fixtures/vcr_cassettes'),
    
    # Configure which hosts to ignore
    ignore_hosts: ['localhost', '127.0.0.1', '0.0.0.0'],
    
    # Filter sensitive data
    filter_sensitive_data: {
      '<API_KEY>' => ENV['EXTERNAL_API_KEY'],
      '<AUTH_TOKEN>' => ENV['AUTH_TOKEN']
    },
    
    # Preserve exact body bytes for binary data
    preserve_exact_body_bytes: true,
    
    # Allow HTTP connections when no cassette
    allow_http_connections_when_no_cassette: false
  }
end
```

### Cypress Setup

```js
// cypress/support/index.js
import 'cypress-on-rails/support/index'

// Optional: Configure VCR commands
Cypress.Commands.add('vcrInsert', (name, options = {}) => {
  cy.app('vcr_insert_cassette', { name, ...options });
});

Cypress.Commands.add('vcrEject', () => {
  cy.app('vcr_eject_cassette');
});
```

### Clean Command Setup

```ruby
# e2e/app_commands/clean.rb
# Ensure cassettes are ejected between tests
VCR.eject_cassette if VCR.current_cassette
VCR.turn_off!
WebMock.disable! if defined?(WebMock)

# Your existing clean logic...
DatabaseCleaner.clean
```

## Insert/Eject Mode

Insert/eject mode gives you explicit control over when to start and stop recording.

### Configuration
```ruby
CypressOnRails.configure do |c|
  c.use_vcr_middleware = !Rails.env.production? && ENV['CYPRESS'].present?
  # Don't enable use_cassette mode
end
```

### Basic Usage
```js
describe('External API Tests', () => {
  afterEach(() => {
    cy.vcr_eject_cassette();
  });

  it('fetches weather data', () => {
    // Start recording
    cy.vcr_insert_cassette('weather_api', { 
      record: 'new_episodes' 
    });
    
    cy.visit('/weather');
    cy.contains('Current Temperature');
    
    // Recording continues until ejected
  });

  it('handles API errors', () => {
    // Use pre-recorded cassette
    cy.vcr_insert_cassette('weather_api_error', { 
      record: 'none'  // Only replay, don't record
    });
    
    cy.visit('/weather?city=invalid');
    cy.contains('City not found');
  });
});
```

### Advanced Options
```js
cy.vcr_insert_cassette('api_calls', {
  record: 'new_episodes',           // Recording mode
  match_requests_on: ['method', 'uri', 'body'],  // Request matching
  erb: true,                         // Enable ERB in cassettes
  allow_playback_repeats: true,     // Allow multiple replays
  exclusive: true,                   // Disallow other cassettes
  serialize_with: 'json',           // Use JSON format
  preserve_exact_body_bytes: true,  // For binary data
  decode_compressed_response: true  // Handle gzipped responses
});
```

## Use Cassette Mode

Use cassette mode automatically wraps each request with VCR.use_cassette.

### Configuration
```ruby
CypressOnRails.configure do |c|
  # Use this instead of use_vcr_middleware
  c.use_vcr_use_cassette_middleware = !Rails.env.production? && ENV['CYPRESS'].present?
  
  c.vcr_options = {
    hook_into: :webmock,
    default_cassette_options: { 
      record: :once,
      match_requests_on: [:method, :uri]
    },
    cassette_library_dir: Rails.root.join('spec/fixtures/vcr_cassettes')
  }
end
```

### How It Works
Each request is automatically wrapped with `VCR.use_cassette`. The cassette name is derived from the request URL or operation name.

### Directory Structure
```
spec/fixtures/vcr_cassettes/
├── api/
│   ├── users/
│   │   └── index.yml
│   └── products/
│       ├── index.yml
│       └── show.yml
└── graphql/
    ├── GetUser.yml
    └── CreatePost.yml
```

## GraphQL Integration

GraphQL requires special handling due to all requests going to the same endpoint.

### Setup for GraphQL

```js
// cypress/support/commands.js
Cypress.Commands.add('mockGraphQL', () => {
  cy.on('window:before:load', (win) => {
    const originalFetch = win.fetch;
    const fetch = (path, options, ...rest) => {
      if (options && options.body) {
        try {
          const body = JSON.parse(options.body);
          // Add operation name to URL for VCR matching
          if (body.operationName) {
            return originalFetch(
              `${path}?operation=${body.operationName}`, 
              options, 
              ...rest
            );
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

// cypress/support/index.js
beforeEach(() => {
  cy.mockGraphQL();  // Enable GraphQL operation tracking
});
```

### GraphQL Test Example
```js
it('queries user data', () => {
  // Cassette will be saved as vcr_cassettes/graphql/GetUser.yml
  cy.visit('/profile');
  
  // The GraphQL query with operationName: 'GetUser' 
  // will be automatically recorded
  
  cy.contains('John Doe');
});
```

### Custom GraphQL Matching
```ruby
# config/initializers/cypress_on_rails.rb
c.vcr_options = {
  match_requests_on: [:method, :uri, 
    lambda { |req1, req2|
      # Custom matching for GraphQL requests
      if req1.uri.path == '/graphql' && req2.uri.path == '/graphql'
        body1 = JSON.parse(req1.body)
        body2 = JSON.parse(req2.body)
        
        # Match by operation name and variables
        body1['operationName'] == body2['operationName'] &&
        body1['variables'] == body2['variables']
      else
        true
      end
    }
  ]
}
```

## Advanced Usage

### Dynamic Cassette Names
```js
// Use test context for cassette names
it('fetches user data', function() {
  const cassetteName = `${this.currentTest.parent.title}_${this.currentTest.title}`
    .replace(/\s+/g, '_')
    .toLowerCase();
  
  cy.vcr_insert_cassette(cassetteName, { record: 'once' });
  
  cy.visit('/users');
  // Test continues...
});
```

### Conditional Recording
```js
const shouldRecord = Cypress.env('RECORD_VCR') === 'true';

cy.vcr_insert_cassette('api_calls', {
  record: shouldRecord ? 'new_episodes' : 'none'
});
```

### Multiple Cassettes
```js
it('combines multiple API sources', () => {
  // Stack multiple cassettes
  cy.vcr_insert_cassette('weather_api');
  cy.vcr_insert_cassette('news_api');
  
  cy.visit('/dashboard');
  
  // Both APIs will be recorded
  
  // Eject in reverse order
  cy.vcr_eject_cassette(); // Ejects news_api
  cy.vcr_eject_cassette(); // Ejects weather_api
});
```

### Custom Matchers
```ruby
# e2e/app_commands/vcr_custom.rb
VCR.configure do |c|
  # Custom request matcher
  c.register_request_matcher :uri_ignoring_params do |req1, req2|
    URI(req1.uri).host == URI(req2.uri).host &&
    URI(req1.uri).path == URI(req2.uri).path
  end
end

# Use in test
VCR.use_cassette('api_call', 
  match_requests_on: [:method, :uri_ignoring_params]
)
```

### Filtering Sensitive Data
```ruby
VCR.configure do |c|
  # Filter authorization headers
  c.filter_sensitive_data('<AUTHORIZATION>') do |interaction|
    interaction.request.headers['Authorization']&.first
  end
  
  # Filter API keys from URLs
  c.filter_sensitive_data('<API_KEY>') do |interaction|
    URI(interaction.request.uri).query
      &.match(/api_key=([^&]+)/)
      &.captures
      &.first
  end
  
  # Filter response tokens
  c.filter_sensitive_data('<TOKEN>') do |interaction|
    JSON.parse(interaction.response.body)['token'] rescue nil
  end
end
```

## Troubleshooting

### Issue: "No route matches [POST] '/api/__e2e__/vcr/insert'"

**Solution:** Ensure VCR middleware is enabled:
```ruby
# config/initializers/cypress_on_rails.rb
c.use_vcr_middleware = !Rails.env.production? && ENV['CYPRESS'].present?
```

And that the API prefix matches:
```ruby
c.api_prefix = '/api'  # If your app uses /api prefix
```

### Issue: "VCR::Errors::UnhandledHTTPRequestError"

**Cause:** Request not matching any cassette.

**Solutions:**
1. Re-record the cassette:
```js
cy.vcr_insert_cassette('my_cassette', { record: 'new_episodes' });
```

2. Adjust matching criteria:
```ruby
c.vcr_options = {
  default_cassette_options: {
    match_requests_on: [:method, :host, :path]  # Ignore query params
  }
}
```

3. Allow new requests:
```ruby
c.vcr_options = {
  default_cassette_options: {
    record: 'new_episodes',  # Record new requests
    allow_unused_http_interactions: true
  }
}
```

### Issue: "Cassette not found"

**Solution:** Check the cassette path:
```ruby
# Verify the directory exists
c.vcr_options = {
  cassette_library_dir: Rails.root.join('spec/fixtures/vcr_cassettes')
}
```

Create the directory if needed:
```bash
mkdir -p spec/fixtures/vcr_cassettes
```

### Issue: "WebMock::NetConnectNotAllowedError"

**Cause:** HTTP connection attempted without cassette.

**Solutions:**
1. Insert a cassette before the request:
```js
cy.vcr_insert_cassette('api_calls');
```

2. Allow connections to specific hosts:
```ruby
WebMock.disable_net_connect!(
  allow_localhost: true,
  allow: ['chromedriver.storage.googleapis.com']
)
```

3. Disable WebMock for specific tests:
```js
cy.app('eval', { code: 'WebMock.disable!' });
// Run test
cy.app('eval', { code: 'WebMock.enable!' });
```

### Issue: Binary/Encoded Response Issues

**Solution:** Configure VCR to handle binary data:
```ruby
c.vcr_options = {
  preserve_exact_body_bytes: true,
  decode_compressed_response: true
}
```

### Issue: Timestamps in Recordings

**Solution:** Filter dynamic timestamps:
```ruby
VCR.configure do |c|
  c.before_record do |interaction|
    # Normalize timestamps in responses
    if interaction.response.headers['date']
      interaction.response.headers['date'] = ['2024-01-01 00:00:00']
    end
  end
end
```

## Best Practices

1. **Organize cassettes by feature**: Use subdirectories for different features
2. **Use descriptive names**: Make cassette names self-documenting
3. **Commit cassettes to version control**: Share recordings with team
4. **Periodically refresh cassettes**: Re-record to catch API changes
5. **Filter sensitive data**: Never commit real API keys or tokens
6. **Use appropriate record modes**:
   - `:once` for stable APIs
   - `:new_episodes` during development
   - `:none` for CI/production
7. **Document external dependencies**: List which APIs are being mocked
8. **Handle errors gracefully**: Record both success and error responses

## Summary

VCR integration with cypress-playwright-on-rails provides powerful HTTP mocking capabilities. Choose between:
- **Insert/Eject mode**: For explicit control over recording
- **Use Cassette mode**: For automatic recording, especially with GraphQL

Remember to:
- Configure VCR appropriately for your needs
- Filter sensitive data
- Organize cassettes logically
- Keep cassettes up to date