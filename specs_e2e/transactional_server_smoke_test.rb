# Smoke test for transactional_server against a real spawned Rails server.
#
# cypress-rails died from a fragile transactional server under multi-threaded
# Puma (testdouble/cypress-rails#164). This script proves the equivalent story
# holds here, end to end, on the Rails 7.2 and Rails 8 sample apps, against
# SQLite or PostgreSQL (E2E_DATABASE=postgresql):
#
#   * the server really is Puma with more than one thread, in its own process;
#   * concurrent writes through the server succeed rather than deadlocking;
#   * GET /cypress_rails_reset_state between two "specs" clears their state;
#   * the transaction lives in the server process: a reset rolls back to the
#     state the server booted with (a row committed before the run survives it,
#     unlike a truncation), and nothing the server wrote outlives the run;
#   * after_transaction_start, defined in an app initializer
#     (config/initializers/transactional_server_smoke.rb), runs in the server:
#     its seed is there at boot and exactly once after every reset, and
#     after_state_reset runs after it;
#   * a reading role (ApplicationRecord connects_to primary_replica) sees the
#     rows the server has not committed;
#   * a server that forks Puma workers stops before serving a request;
#   * the whole run is bounded by a hard timeout, so a hang fails instead of
#     blocking CI forever.
#
# Run from a sample app with:
#   RAILS_MAX_THREADS=3 bin/rails runner ../transactional_server_smoke_test.rb
# or through ../transactional_server_smoke.sh, which also prepares the database.

require 'cypress_on_rails/server'
require 'json'
require 'net/http'
require 'timeout'
require 'uri'

EXPECTED_THREADS = Integer(ENV.fetch('RAILS_MAX_THREADS', '3'))
TIME_BUDGET = Integer(ENV.fetch('SMOKE_TEST_TIMEOUT', '180'))
SHUTDOWN_TIMEOUT = 10
HOOK_SEED_TITLE = 'smoke-seed-from-after-transaction-start'.freeze

failures = []

def report(failures, description, ok, detail = nil)
  if ok
    puts "  ok   #{description}"
  else
    failures << description
    puts "  FAIL #{description}#{detail ? " -- #{detail}" : ''}"
  end
end

def http_request(base, request)
  uri = URI("#{base}#{request.path}")
  Net::HTTP.start(uri.host, uri.port, open_timeout: 15, read_timeout: 60) do |http|
    http.request(request)
  end
end

def http_get(base, path)
  http_request(base, Net::HTTP::Get.new(path))
end

def get_json(base, path)
  JSON.parse(http_get(base, path).body)
end

def create_post(base, title)
  request = Net::HTTP::Post.new('/posts')
  request.set_form_data('post[title]' => title, 'post[body]' => 'smoke test body')
  http_request(base, request)
end

def reset_state(base)
  http_get(base, '/cypress_rails_reset_state')
end

def hook_seed_count(base)
  http_get(base, '/posts').body.scan(HOOK_SEED_TITLE).size
end

if EXPECTED_THREADS < 2
  abort "This smoke test must run with RAILS_MAX_THREADS > 1, got #{EXPECTED_THREADS}"
end

CypressOnRails.configure do |config|
  config.transactional_server = true
  config.server_shutdown_timeout = SHUTDOWN_TIMEOUT
end

# Read by the spawned server: turns on the initializer-defined hooks, and eager
# loading (config/environments/test.rb), which establishes ApplicationRecord's
# reading pool at boot.
ENV['TRANSACTIONAL_SERVER_SMOKE'] = '1'
ENV['CI'] ||= 'true'
ENV.delete('WEB_CONCURRENCY')

server = CypressOnRails::Server.new(host: '127.0.0.1')
spec_one_titles = %w[smoke-spec-one-a smoke-spec-one-b smoke-spec-one-c]
spec_two_title = 'smoke-spec-two-a'
seed_title = 'smoke-seed-committed-before-the-run'

# Committed before the server boots, so it is part of the state every reset
# returns to.
Post.delete_all
Post.create!(title: seed_title, body: 'committed before the server started')

puts "-- transactional server smoke test (#{ActiveRecord::Base.connection.adapter_name}, " \
     "Rails #{Rails.version}, RAILS_MAX_THREADS=#{EXPECTED_THREADS}, budget #{TIME_BUDGET}s, " \
     "driver pid #{Process.pid})"

begin
  Timeout.timeout(TIME_BUDGET) do
    # start_server is the private core that boots the server and guarantees
    # shutdown. The public entry points (#open / #run) additionally shell out
    # to Cypress or Playwright, which is not what we want to exercise here.
    server.send(:start_server) do
      # Derive the URL only once the server is ready: an auto-selected port
      # that loses the final bind race is re-selected and the server respawned,
      # so the port this run ends up on is not necessarily the first one.
      base_url = server.send(:base_url)

      stats_response = http_get(base_url, '/server_diagnostics/puma_stats')
      report(failures, 'puma stats endpoint responds', stats_response.code == '200', stats_response.code)
      if stats_response.code == '200'
        stats = JSON.parse(stats_response.body)
        report(failures, "server runs Puma with #{EXPECTED_THREADS} threads",
               stats['max_threads'] == EXPECTED_THREADS, stats.inspect)
        report(failures, 'server runs in its own process', stats['server_pid'] != Process.pid,
               "server_pid=#{stats['server_pid']} driver_pid=#{Process.pid}")
      end

      puts '-- boot: after_transaction_start from the app initializer'
      report(failures, 'the hook seeded the server at boot', hook_seed_count(base_url) == 1,
             "#{hook_seed_count(base_url)} rows")
      log = get_json(base_url, '/server_diagnostics/hook_log')
      report(failures, 'the hook ran once, in the server', log == [{ 'event' => 'after_transaction_start' }],
             log.inspect)

      puts '-- spec one: writes through the running server'
      codes = []
      codes_mutex = Mutex.new
      spec_one_titles.map { |title|
        Thread.new do
          response = create_post(base_url, title)
          codes_mutex.synchronize { codes << response.code }
        end
      }.each(&:join)
      report(failures, 'concurrent writes all succeeded', codes.uniq == ['302'], codes.inspect)

      index = http_get(base_url, '/posts').body
      report(failures, 'spec one sees the rows it created',
             spec_one_titles.all? { |title| index.include?(title) })
      reading = get_json(base_url, '/server_diagnostics/reading_titles')
      report(failures, 'the reading role sees the uncommitted rows',
             (spec_one_titles + [HOOK_SEED_TITLE, seed_title]).all? { |title| reading.include?(title) },
             reading.inspect)

      2.times do |i|
        puts "-- reset #{i + 1}: GET /cypress_rails_reset_state"
        reset = reset_state(base_url)
        report(failures, 'reset endpoint returned 200', reset.code == '200', reset.body.lines.first.to_s.strip)
        report(failures, 'reset endpoint reported completion', reset.body == 'State reset completed',
               reset.body[0, 120])
        report(failures, 'the hook seed is there exactly once', hook_seed_count(base_url) == 1,
               "#{hook_seed_count(base_url)} rows")
      end

      log = get_json(base_url, '/server_diagnostics/hook_log')
      expected_log = [{ 'event' => 'after_transaction_start' }] +
                     [{ 'event' => 'after_transaction_start' },
                      { 'event' => 'after_state_reset', 'hook_seed_rows' => 1 }] * 2
      report(failures, 'each reset ran after_transaction_start, then after_state_reset', log == expected_log,
             log.inspect)

      puts '-- spec two: starts from a clean state'
      index = http_get(base_url, '/posts').body
      report(failures, 'spec two does not see spec one rows',
             spec_one_titles.none? { |title| index.include?(title) })
      report(failures, 'the reset rolled back to the booted state instead of truncating',
             index.include?(seed_title))

      created = create_post(base_url, spec_two_title)
      report(failures, 'spec two can write', created.code == '302', created.code)
      index = http_get(base_url, '/posts').body
      report(failures, 'spec two sees only its own row',
             index.include?(spec_two_title) && spec_one_titles.none? { |title| index.include?(title) })
    end
  end
rescue Timeout::Error
  failures << "run exceeded the #{TIME_BUDGET}s time budget"
  puts "  FAIL run exceeded the #{TIME_BUDGET}s time budget"
end

puts '-- after shutdown'
# The whole group has to be gone, not just its former leader: a surviving
# member would keep the port and contaminate later CI steps. The predicate
# signals the group (negative pgid) and is false when no group was recorded.
report(failures, 'server process group is gone', !server.send(:process_group_exists?))

# The server held its transaction on its own connection; when it exited, the
# database discarded it. Only the row committed before the run is left.
ActiveRecord::Base.connection.reconnect!
surviving = Post.pluck(:title)
report(failures, 'nothing the server wrote outlives the run', surviving == [seed_title], surviving.inspect)

puts '-- Puma workers: the server stops before serving a request'
# Puma reads WEB_CONCURRENCY as its worker count.
ENV['WEB_CONCURRENCY'] = '2'
clustered = CypressOnRails::Server.new(host: '127.0.0.1')
served = false
error = nil
started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
begin
  Timeout.timeout(TIME_BUDGET) do
    clustered.send(:start_server) { served = true }
  end
rescue CypressOnRails::ServerError => e
  error = e
rescue Timeout::Error
  error = :timeout
ensure
  ENV.delete('WEB_CONCURRENCY')
end
elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
report(failures, 'the clustered server never became ready', !served)
report(failures, 'startup failed with a ServerError naming the fork', error.is_a?(CypressOnRails::ServerError) &&
       error.message.include?('A forked process cannot share that transaction'), error.inspect[0, 2000])
report(failures, 'the failure came well within the time budget', elapsed < 60, "#{elapsed.round(1)}s")
report(failures, 'the clustered server process group is gone', !clustered.send(:process_group_exists?))
ActiveRecord::Base.connection.reconnect!
surviving = Post.pluck(:title)
report(failures, 'the clustered server committed nothing', surviving == [seed_title], surviving.inspect)
Post.delete_all

if failures.empty?
  puts '-- transactional server smoke test PASSED'
  exit 0
else
  puts "-- transactional server smoke test FAILED (#{failures.length}):"
  failures.each { |failure| puts "     #{failure}" }
  exit 1
end
