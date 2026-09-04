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
#     blocking CI forever.
#
# It also pins the most surprising property of transactional_server with an
# out-of-process server: the transaction belongs to *this* process, so rolling
# it back does not undo anything the server wrote. See the final check.
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
transaction_opened = false

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
  config.after_transaction_start = -> { transaction_opened = true }
end

server = CypressOnRails::Server.new(host: '127.0.0.1')
base_url = "http://127.0.0.1:#{server.port}"
spec_one_titles = %w[smoke-spec-one-a smoke-spec-one-b smoke-spec-one-c]
spec_two_title = 'smoke-spec-two-a'

puts "-- transactional server smoke test (RAILS_MAX_THREADS=#{EXPECTED_THREADS}, " \
     "budget #{TIME_BUDGET}s, driver pid #{Process.pid})"

begin
  Timeout.timeout(TIME_BUDGET) do
    # start_server is the private core that boots the server, opens the
    # transactional_server transaction and guarantees shutdown. The public
    # entry points (#open / #run) additionally shell out to Cypress or
    # Playwright, which is not what we want to exercise here.
    server.send(:start_server) do
      report(failures, 'the transactional_server transaction was opened', transaction_opened)

      # Known-clean starting point, through the same endpoint under test.
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
report(failures, 'server process group is gone',
       server.instance_variable_get(:@server_pgid).nil? ||
         !server.send(:process_exists?, server.instance_variable_get(:@server_pid)))

# transactional_server rolls back a transaction held by *this* process. The
# server has its own process and its own connections, so its committed writes
# survive. This is deliberately asserted so that a future change to
# transactional semantics has to update it consciously.
ActiveRecord::Base.connection.reconnect!
surviving = Post.pluck(:title)
report(failures, 'server-side writes survive the driver rollback (transactional_server does not isolate them)',
       surviving.include?(spec_two_title), surviving.inspect)
Post.delete_all

if failures.empty?
  puts '-- transactional server smoke test PASSED'
  exit 0
else
  puts "-- transactional server smoke test FAILED (#{failures.length}):"
  failures.each { |failure| puts "     #{failure}" }
  exit 1
end
