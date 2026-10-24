require 'cypress_on_rails/transactional_server'

# The end-to-end proof, against a real spawned Puma server and database, is
# specs_e2e/rails_8/script/transactional_server_smoke_test.rb. These examples
# pin the protocol with Active Record stand-ins.
module TransactionalServerFakes
  # Stands in for an adapter: records the transaction calls it receives.
  class Connection
    attr_reader :calls, :lock

    def initialize
      @calls = []
      @lock = Monitor.new
      @open = false
    end

    def transaction_open?
      @open
    end

    def begin_transaction(**options)
      @calls << [:begin, options]
      @open = true
    end

    def rollback_transaction
      @calls << [:rollback]
      @open = false
    end
  end

  # Rails 7.2+ ConnectionPool#pin_connection! opens the transaction itself.
  class Pool
    attr_reader :connection, :pinned_with

    def initialize
      @connection = Connection.new
    end

    def pin_connection!(lock_thread)
      @pinned_with = lock_thread
      @connection.begin_transaction(joinable: false, _lazy: false)
    end

    def lease_connection
      @connection
    end
  end

  # ActiveRecord::Base.connection_handler, serving the given writing pools.
  ConnectionHandler = Struct.new(:pools) do
    def connection_pool_list(role)
      role == :writing ? pools : []
    end
  end
end

RSpec.describe CypressOnRails::TransactionalServer do
  let(:pools) { [TransactionalServerFakes::Pool.new, TransactionalServerFakes::Pool.new] }
  let(:hook_calls) { [] }
  let(:fork_hooks) { [] }

  before do
    described_class.instance_variable_set(:@pools, nil)
    described_class.instance_variable_set(:@pid, nil)
    handler = TransactionalServerFakes::ConnectionHandler.new(pools)
    stub_const('ActiveRecord::Base', Module.new { define_singleton_method(:connection_handler) { handler } })
    stub_const('ActiveRecord::ConnectionAdapters::ConnectionPool', TransactionalServerFakes::Pool)
    hooks = fork_hooks
    stub_const('ActiveSupport::ForkTracker', Module.new { define_singleton_method(:after_fork) { |&hook| hooks << hook } })
    calls = hook_calls
    CypressOnRails.configuration.after_transaction_start = -> { calls << :after_transaction_start }
  end

  after do
    ENV.delete(described_class::ENV_KEY)
    CypressOnRails.configuration.reset
    described_class.instance_variable_set(:@pools, nil)
  end

  it 'does nothing unless the rake task asked for it' do
    described_class.boot

    aggregate_failures do
      expect(described_class).not_to be_active
      expect(pools.map(&:pinned_with)).to eq([nil, nil])
      expect(hook_calls).to be_empty
    end
  end

  context 'when the rake task asked for a transactional server' do
    before { ENV[described_class::ENV_KEY] = '1' }

    it 'pins every writing pool to one connection shared by all threads, then runs the hook' do
      described_class.boot

      aggregate_failures do
        expect(described_class).to be_active
        expect(pools.map(&:pinned_with)).to eq([true, true])
        expect(pools.map { |pool| pool.connection.transaction_open? }).to eq([true, true])
        expect(hook_calls).to eq([:after_transaction_start])
      end
    end

    it 'rolls back and opens a fresh transaction on reset, then runs the hook again' do
      described_class.boot
      described_class.reset!

      aggregate_failures do
        pools.each do |pool|
          expect(pool.connection.calls).to eq(
            [[:begin, { joinable: false, _lazy: false }], [:rollback], [:begin, { joinable: false, _lazy: false }]]
          )
        end
        expect(hook_calls).to eq(%i[after_transaction_start after_transaction_start])
      end
    end

    it 'is not active in a forked child, and says so' do
      described_class.boot
      allow(Process).to receive(:pid).and_return(Process.pid + 1)

      expect { fork_hooks.each(&:call) }.to output(/was forked .* its writes are committed/).to_stderr
      expect(described_class).not_to be_active
    end

    it 'warns and leaves the database alone before Rails 7.2' do
      stub_const('ActiveRecord::ConnectionAdapters::ConnectionPool', Class.new)

      expect { described_class.boot }.to output(/needs Rails 7.2 or later/).to_stderr
      aggregate_failures do
        expect(described_class).not_to be_active
        expect(pools.map(&:pinned_with)).to eq([nil, nil])
      end
    end
  end
end
