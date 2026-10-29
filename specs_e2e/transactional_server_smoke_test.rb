# Smoke test for the transactional test server under multi-threaded Puma.
#
# cypress-rails died from a fragile transactional server under multi-threaded
# Puma (testdouble/cypress-rails#164). This script proves the equivalent story
# holds here, end to end, against a real spawned Rails server:
#
#   * the server really is Puma with more than one thread, in its own process;
#   * with transactional_server = true, concurrent writes through the server
#     succeed rather than deadlocking;
#   * GET /cypress_rails_reset_state between two "specs" really clears state,
#     so the second spec starts clean;
#   * the whole run is bounded by a hard timeout, so a hang fails instead of
#     blocking CI forever;
#   * the transaction lives in the server process: a reset rolls back to the
#     state the server booted with (a row committed before the run survives it,
#     unlike a truncation), and nothing the server wrote outlives the run.
#
# Run with: RAILS_MAX_THREADS=3 bin/rails runner script/transactional_server_smoke_test.rb

require 'cypress_on_rails/server'
require 'json'
require 'net/http'
require 'timeout'
require 'uri'

EXPECTED_THREADS = Integer(ENV.fetch('RAILS_MAX_THREADS', '3'))
TIME_BUDGET = Integer(ENV.fetch('SMOKE_TEST_TIMEOUT', '180'))
SHUTDOWN_TIMEOUT = 10

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

def create_post(base, title)
  request = Net::HTTP::Post.new('/posts')
  request.set_form_data('post[title]' => title, 'post[body]' => 'smoke test body')
  http_request(base, request)
end

def reset_state(base)
  http_get(base, '/cypress_rails_reset_state')
end

if EXPECTED_THREADS < 2
  abort "This smoke test must run with RAILS_MAX_THREADS > 1, got #{EXPECTED_THREADS}"
end

CypressOnRails.configure do |config|
  config.transactional_server = true
  config.server_shutdown_timeout = SHUTDOWN_TIMEOUT
end

server = CypressOnRails::Server.new(host: '127.0.0.1')
spec_one_titles = %w[smoke-spec-one-a smoke-spec-one-b smoke-spec-one-c]
spec_two_title = 'smoke-spec-two-a'
seed_title = 'smoke-seed-committed-before-the-run'

# Committed before the server boots, so it is part of the state every reset
# returns to.
Post.delete_all
Post.create!(title: seed_title, body: 'committed before the server started')

puts "-- transactional server smoke test (RAILS_MAX_THREADS=#{EXPECTED_THREADS}, " \
     "budget #{TIME_BUDGET}s, driver pid #{Process.pid})"

begin
  Timeout.timeout(TIME_BUDGET) do
    # start_server is the private core that boots the server, opens the
    # transactional_server transaction and guarantees shutdown. The public
    # entry points (#open / #run) additionally shell out to Cypress or
    # Playwright, which is not what we want to exercise here.
    server.send(:start_server) do
      # Derive the URL only once the server is ready: an auto-selected port
      # that loses the final bind race is re-selected and the server respawned,
      # so the port this run ends up on is not necessarily the first one.
      base_url = server.send(:base_url)

      # Known starting point, through the same endpoint under test.
      reset_state(base_url)

      stats_response = http_get(base_url, '/server_diagnostics/puma_stats')
      report(failures, 'puma stats endpoint responds', stats_response.code == '200', stats_response.code)
      if stats_response.code == '200'
        stats = JSON.parse(stats_response.body)
        report(failures, "server runs Puma with #{EXPECTED_THREADS} threads",
               stats['max_threads'] == EXPECTED_THREADS, stats.inspect)
        report(failures, 'server runs in its own process', stats['server_pid'] != Process.pid,
               "server_pid=#{stats['server_pid']} driver_pid=#{Process.pid}")
      end

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

      puts '-- reset: GET /cypress_rails_reset_state'
      reset = reset_state(base_url)
      report(failures, 'reset endpoint returned 200', reset.code == '200', reset.body.lines.first.to_s.strip)
      report(failures, 'reset endpoint reported completion', reset.body == 'State reset completed', reset.body[0, 120])

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
Post.delete_all

if failures.empty?
  puts '-- transactional server smoke test PASSED'
  exit 0
else
  puts "-- transactional server smoke test FAILED (#{failures.length}):"
  failures.each { |failure| puts "     #{failure}" }
  exit 1
end
