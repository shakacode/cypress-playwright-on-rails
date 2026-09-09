# Streamed and Multi-process Applications

Use E2E on Rails with Playwright when a browser journey needs a real Rails
server plus an RSC/SSR renderer, asset server, WebSocket service, or local fake
API. It is also a good fit for streaming HTTP, Suspense/Flight chunks, factories
visible to external server connections, and precise browser/network diagnostics.
Ordinary Capybara system specs remain reasonable with the normal Rails-managed
server. The problematic pattern is rebuilding a multi-process application origin
inside every example or retry.

E2E on Rails is runner-neutral. This guide uses Playwright for its browser
contexts, network events, and trace artifacts. Install the current 1.x package
as `cypress-on-rails`; the Ruby module remains `CypressOnRails`.

## Separate runtime lifetime from test state

| Owner | Responsibility |
| --- | --- |
| Application / process supervisor | Start services, connect Rails to them, wait for readiness, capture logs, stop processes |
| E2E on Rails | Execute Ruby app commands in the serving Rails process; provide data setup/reset endpoints |
| Playwright | Fresh context/page per test, browser assertions, diagnostics and artifacts |
| Application's test setup | Reset databases, caches, jobs, uploads and external service state safely |

E2E on Rails does **not** discover or manage arbitrary renderers. Its managed
Rails rake tasks are useful for simpler apps; do not start a second Rails server
with those tasks when a supervisor already owns the origin.

```text
Focused suite / CI job starts
  start auxiliary service -> wait for readiness
  start one Rails server -> wait for readiness
  each test (and retry):
    fresh browser context/page
    reset Rails data -> create scenario through app commands
    consume the real stream -> verify completion and interaction
    collect diagnostics -> close browser context
  stop Rails -> stop auxiliary service
Focused suite / CI job ends
```

Keep the runtime alive across test failures and retries. A retry may replace a
Playwright worker; it should not replace the application origin. Before the
next reset, finish or cancel application-owned jobs/subscriptions so late writes
cannot repopulate cleared data. Closing a page alone does not cancel server jobs.

## An explicit Rails + renderer recipe

This **adaptable POSIX recipe** runs from the Rails app root on Linux or macOS.
First follow [Getting Started](./getting-started.md) to generate support into
`e2e/`, install the app's dependencies and Playwright browsers, and prepare a
**dedicated disposable test database**. Reserve ports 5017 (Rails) and 5018
(renderer) for this job. Do not share them or the database with another run.

Application contracts to supply before running:

- A foreground renderer command that listens on `127.0.0.1:5018` and exposes
  `/health` with HTTP 200 only when ready. It must not daemonize.
- Rails reads `ENV.fetch('E2E_RENDERER_URL')` in its renderer client configuration.
  This is an example application variable, **not** a gem setting.
- Rails exposes `/up` with HTTP 200 when ready (or adapt the probe to your app).
- The app has `Post(title: ...)` and the streamed route/test markers described
  below; substitute your actual model, route, and UI contract.
- The initializer enables E2E on Rails only in the isolated test environment.
  See the [security model](https://github.com/shakacode/cypress-playwright-on-rails/blob/master/README.md#security-model). Generated helpers pass
  `CYPRESS_ON_RAILS_TOKEN` when configured; never expose the command endpoint publicly.

Use a dedicated Puma configuration, `config/puma.e2e.rb`, rather than inheriting
an application's cluster defaults:

```ruby
workers 0
threads 1, 1
bind 'tcp://127.0.0.1:5017'
environment 'test'
```

One process avoids multiplying the runtime and splitting process-local state.
One thread makes this baseline predictable, but an app whose streaming requests
need concurrent Rails callbacks must raise the thread count and validate its
state model. Never run cleanup while requests are still reading or writing data.

Save this supervisor as `script/e2e-streaming.rb`. It starts dependencies in order,
checks readiness, preserves the test exit code, and tears down owned process
groups in reverse order, including after startup failure or interruption:

```ruby
require 'fileutils'
require 'net/http'
require 'shellwords'
require 'socket'
require 'timeout'

# Fail rather than accepting an unrelated service's readiness response.
[5017, 5018].each { |port| TCPServer.new('127.0.0.1', port).close }
FileUtils.mkdir_p('log/e2e')
children = []
start = lambda do |name, env, argv|
  log = File.open("log/e2e/#{name}.log", 'w')
  begin
    pid = Process.spawn(env, *argv, pgroup: true, out: log, err: log)
    children << pid
    pid
  ensure
    log.close
  end
end
ready = lambda do |url, pid|
  uri = URI(url)
  Timeout.timeout(60) do
    loop do
      raise "Service exited before ready: #{url}" if Process.waitpid(pid, Process::WNOHANG)
      begin
        response = Net::HTTP.start(uri.host, uri.port, open_timeout: 1, read_timeout: 1) do |http|
          http.get(uri.request_uri)
        end
        break if response.code == '200'
      rescue SystemCallError, IOError, Timeout::Error
        # Retry until the overall readiness deadline.
      end
      sleep 0.1
    end
  end
end
signal_group = lambda do |signal, pid|
  Process.kill(signal, -pid)
rescue Errno::ESRCH
  nil
end
%w[INT TERM].each { |signal| Signal.trap(signal) { raise Interrupt } }

begin
  env = { 'RAILS_ENV' => 'test', 'CYPRESS' => '1',
          'E2E_RENDERER_URL' => 'http://127.0.0.1:5018' }
  renderer = start.call('renderer', env, Shellwords.split(ENV.fetch('E2E_RENDERER_COMMAND')))
  ready.call('http://127.0.0.1:5018/health', renderer)
  rails = start.call('rails', env, %w[bundle exec puma -C config/puma.e2e.rb])
  ready.call('http://127.0.0.1:5017/up', rails)
  tests = Process.spawn(env, 'npx', 'playwright', 'test', '-c', 'e2e/playwright.config.js',
                        *ARGV, pgroup: true)
  children << tests
  _, result = Process.wait2(tests)
  exit(result.exitstatus || 1)
ensure
  children.reverse_each do |pid|
    signal_group.call('TERM', pid)
    begin
      Timeout.timeout(10) { Process.waitpid(pid) }
    rescue Errno::ECHILD, Timeout::Error
      # Already reaped, or the foreground process exceeded its grace period.
    ensure
      signal_group.call('KILL', pid) # Also stop any remaining owned descendants.
    end
    begin
      Timeout.timeout(5) { Process.waitpid(pid) }
    rescue Errno::ECHILD
      nil
    end
  end
end
```

Run with your renderer's actual foreground command, for example **if your app
provides** `script/renderer.js` with these flags:

```sh
E2E_RENDERER_COMMAND='node script/renderer.js --port 5018' ruby script/e2e-streaming.rb
```

The supervisor inherits environment variables such as the database URL and
middleware token. Its shutdown grace is independent of the gem's managed-server
settings. No wrapper can clean up after its own `SIGKILL`; CI/container teardown
must provide that final boundary. Keep services in their process groups.

An alternative is Playwright's [webServer configuration](https://playwright.dev/docs/test-webserver).
Put dependencies before consumers and configure a readiness URL for each entry:
Playwright 1.58.2 starts entries sequentially, awaiting readiness before the next
entry. Recheck this behavior when upgrading. Set
`reuseExistingServer: false` for owned CI services; reusing a developer server
can target the wrong data. The public API documentation does not promise reverse shutdown ordering
for multiple entries; retain an explicit supervisor when that ordering matters.

## Data visible to the serving application

A factory inside an uncommitted RSpec transaction belongs to that process's
connection. A separately running Rails server normally cannot see it. Creating
committed records elsewhere can work, but leaves cleanup and ownership to you.
E2E app commands execute Ruby inside the **serving Rails process**; without a
wrapping transaction, completed writes are committed for other connections.
They do not magically share transactions with renderer processes or job workers.

For this recipe, leave `transactional_server` disabled. Adapt the generated
`e2e/app_commands/clean.rb` to explicitly truncate/delete all relevant test data
(using DatabaseCleaner if installed), clear caches, and reset external state.
The generated fallback only deletes `Post` records; it is not general cleanup.
A minimal single-model demo can use:

```ruby
# e2e/app_commands/clean.rb — demo only; extend for your application.
Post.delete_all
Rails.cache.clear
CypressOnRails::SmartFactoryWrapper.reload
```

A scenario is a Ruby file, not a class with a `perform` method:

```ruby
# e2e/app_commands/scenarios/streaming.rb
Post.create!(title: 'Streamed example')
```

Call `await app('clean')` followed by `await appScenario('streaming')` as below.
Alternatively, use the generated `appFactories([['create', 'post', {...}]])`
with your project's FactoryBot factory; see [Scenarios](./scenarios.md),
[FactoryBot](./factory-bot.md), and [App Commands](./app-commands.md).

The generated `appResetState()` is another explicit reset option; the reset
middleware cleans database tables and Rails cache and runs `after_state_reset`.
It cannot know how to clear your auxiliary service. Do not confuse this endpoint
with starting a transactional server. The gem's managed launcher has a separate
[transactional-server and hooks configuration](https://github.com/shakacode/cypress-playwright-on-rails/blob/master/README.md#server-hooks-configuration).
Use that mode only after verifying all participating processes, threads, and
connections support its transaction-sharing assumptions. Merely setting
`transactional_server: true` does not activate the launcher in this external
Puma recipe. [Hardening issue #185](https://github.com/shakacode/cypress-playwright-on-rails/issues/185)
is closed; its fixes do not make arbitrary multi-process transactions safe.

## Playwright configuration and streaming assertions

Replace `e2e/playwright.config.js` with this focused configuration. The generated
`playwright/support/on-rails.js` imports this exact config location, so keep its
`baseURL` aligned with the browser. Run directly through the supervisor, not
`bin/rails playwright:run` (which would own another Rails lifecycle).

```js
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './playwright/e2e',
  fullyParallel: false,
  workers: 1,
  retries: 0,
  forbidOnly: !!process.env.CI,
  reporter: 'list',
  outputDir: '../test-results/streaming',
  use: {
    baseURL: 'http://127.0.0.1:5017',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [{ name: 'chromium', use: { browserName: 'chromium' } }],
});
```

One worker prevents tests from cleaning each other's database. To scale, give
each CI job/shard its own complete topology, ports, database, and external-state
namespace. Browser contexts alone do not isolate Rails data.

The following test is adaptable to RSC, SSR, or other streamed UI. Its application
contract is `/streamed-posts`, a visible `stream-fallback` until streamed content
replaces it, `stream-result` containing the seeded title, and a `client-island`
that sets `data-hydrated="true"` **from client code after handlers are attached**.
The island's Like button sends exactly one POST to `/likes` and updates `like-count`
to `1`. These routes/markers are application code, not features generated by the gem.
For deterministic fallback coverage, use an application-owned test gate to hold
stream completion until the fallback is observable; do not depend on network speed.

```js
// e2e/playwright/e2e/streaming.spec.js
import { test, expect } from '@playwright/test';
import { app, appScenario } from '../support/on-rails';

test.beforeEach(async () => {
  await app('clean');
  await appScenario('streaming');
});

test('consumes streamed content and activates the client island', async ({ page }, testInfo) => {
  const errors = [];
  let likes = 0;
  page.on('console', message => {
    if (message.type() === 'error') errors.push(`console: ${message.text()}`);
  });
  page.on('pageerror', error => errors.push(`pageerror: ${error.message}`));
  page.on('requestfailed', request => {
    errors.push(`failed: ${request.url()} ${request.failure()?.errorText}`);
  });
  page.on('response', response => {
    if (response.status() >= 400) errors.push(`HTTP ${response.status()}: ${response.url()}`);
  });
  page.on('request', request => {
    if (request.method() === 'POST' && new URL(request.url()).pathname === '/likes') likes++;
  });

  try {
    await page.goto('/streamed-posts', { waitUntil: 'commit' });
    await expect(page.getByTestId('stream-fallback')).toBeVisible();
    // Release your app-owned stream gate here if one is used.
    await expect(page.getByTestId('stream-result')).toHaveText('Streamed example');
    await expect(page.getByTestId('stream-fallback')).toHaveCount(0);
    await expect(page.getByTestId('client-island')).toHaveAttribute('data-hydrated', 'true');
    const liked = page.waitForResponse(response =>
      new URL(response.url()).pathname === '/likes' && response.request().method() === 'POST');
    await page.getByRole('button', { name: 'Like', exact: true }).click();
    expect((await liked).ok()).toBeTruthy();
    await expect(page.getByTestId('like-count')).toHaveText('1');
    expect(likes).toBe(1);
    expect(errors).toEqual([]);
  } finally {
    await testInfo.attach('browser-errors', {
      body: Buffer.from(JSON.stringify(errors, null, 2)), contentType: 'application/json',
    });
  }
});
```

Initial HTML alone does not prove hydration. Observe fallback replacement,
application completion, and a working client interaction. A finite stream can
also be awaited with `response.finished()`; for Action Cable, register
`page.on('websocket', ...)` before navigation and assert the expected subscription
acknowledgement and application frames through `socket.on('framereceived', ...)`.
Assert app-specific request counts at the journey's completion boundary.
Do not wait for global `networkidle` on long-lived connections.

Keep listeners active through that boundary; an early log drain can miss late
chunks. No finite test can prove that errors never occur afterward: define a
meaningful application completion signal and finish pending work before teardown.
`requestfailed` catches transport failures; HTTP error responses need the separate
response listener. Avoid broad allowlists such as ignoring all chunk-load errors.
Any unavoidable exception should match a specific request/error and documented reason.
Do not buffer, proxy-replay, or stub the stream under test and call that hydration
proof. Validate the real browser path, including any production-like proxy that
could buffer it.

## Diagnostics and cleanup

On failure, preserve `test-results/streaming/` (trace, screenshot, video, attached
errors), `log/e2e/rails.log`, and `log/e2e/renderer.log` as CI artifacts. Upload
with your CI's always/failure condition, even when startup or tests fail.
Logs are overwritten on the next run, so collect them first. Capture the browser,
Rails, renderer versions and commands, job identity, timestamps, and exit status.
Keep credentials and personal data out of artifacts.

Use `npx playwright show-trace path/to/trace.zip` to inspect a retained trace.
Check failed resources and HTTP status alongside server logs; do not hide the
first crash by adding retries. After shutdown, confirm the job's service ports
are released and owned descendants have exited. Reset residual external state
before reusing a job environment. See [Troubleshooting](./TROUBLESHOOTING.md).

## HiChee migration case study

The public [issue #244 discussion](https://github.com/shakacode/cypress-playwright-on-rails/issues/244)
records a HiChee Rails/RSC suite where per-example Rails/Node startup, inherited
multi-worker Puma, and origin teardown during late chunks produced misleading
browser failures. A tactical change kept one runtime per file. The subsequent
Playwright migration landed with suite-scoped services and removed superseded
Capybara coverage and its custom runtime helper in the same change.

| Before | Migration pattern |
| --- | --- |
| Test process creates committed fixtures | E2E app commands create data in serving Rails process |
| Rails + renderer start per example/retry | One runtime topology per focused run |
| Browser reset can coincide with destroying an in-flight origin | Reset browser/data while keeping the origin alive |
| Custom free-port/process helper | Documented runtime commands with explicit readiness dependencies |
| One browser-log drain can miss late chunk errors | Persistent page/console listeners and HTTP diagnostics with traces |
| Risk of duplicated old/new coverage | Land replacement coverage and remove superseded specs atomically |

HiChee's migration uses Playwright `webServer` teardown, not a proven reverse
shutdown contract. Its recorded collector covers console/page errors and HTTP
5xx responses; `requestfailed` coverage is recommended hardening in this guide,
not a claim about that migration. Apply these lifecycle lessons to other auxiliary
services without requiring an RSC-specific feature in E2E on Rails.
