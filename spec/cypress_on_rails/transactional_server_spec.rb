require 'cypress_on_rails/transactional_server'

# The end-to-end proof, against a real spawned Puma server and database, is
# specs_e2e/transactional_server_smoke_test.rb (Rails 7.2 and 8, SQLite and
# PostgreSQL). These examples pin the protocol with Active Record stand-ins.
module TransactionalServerFakes
  # Stands in for an adapter: records the transaction calls it receives and
  # tracks how many transactions (nested savepoints included) are open.
  class Connection
    attr_reader :calls, :lock, :depth

    def initialize
      @calls = []
      @lock = Monitor.new
      @depth = 0
    end

    def transaction_open?
      @depth.positive?
    end

    def begin_transaction(**options)
      @calls << [:begin, options]
      @depth += 1
    end

    def rollback_transaction
      @calls << [:rollback]
      @depth -= 1
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

  # The pool manager behind one connection name: pool configs by role and
  # shard. A pool config stands in for its pool.
  class PoolManager
    def initialize(configs)
      @configs = configs
    end

    def shard_names
      @configs.values.flat_map(&:keys).uniq
    end

    def role_names
      @configs.keys
    end

    def get_pool_config(role, shard)
      @configs.dig(role, shard)
    end

    def set_pool_config(role, shard, pool_config)
      (@configs[role] ||= {})[shard] = pool_config
    end
  end

  # ActiveRecord::Base.connection_handler: one pool manager per connection
  # name, the writing pools listed by #connection_pool_list.
  class ConnectionHandler
    attr_reader :pool_managers

    def initialize(pool_managers)
      @pool_managers = pool_managers
    end

    def connection_pool_names
      @pool_managers.keys
    end

    def connection_pool_list(role)
      @pool_managers.values.filter_map { |manager| manager.get_pool_config(role, :default) }
    end

    def retrieve_connection_pool(connection_name, shard:)
      @pool_managers[connection_name]&.get_pool_config(:writing, shard || :default)
    end

    private

    def connection_name_to_pool_manager
      @pool_managers
    end
  end
end

RSpec.describe CypressOnRails::TransactionalServer do
  let(:pools) { [TransactionalServerFakes::Pool.new, TransactionalServerFakes::Pool.new] }
  let(:replica_pool) { TransactionalServerFakes::Pool.new }
  let(:pool_managers) do
    {
      'ActiveRecord::Base' => TransactionalServerFakes::PoolManager.new(
        writing: { default: pools.first }, reading: { default: replica_pool }
      ),
      'AnimalsRecord' => TransactionalServerFakes::PoolManager.new(writing: { default: pools.last })
    }
  end
  let(:hook_calls) { [] }
  let(:fork_hooks) { [] }
  let(:subscribers) { {} }

  # What Active Record publishes when it establishes a pool after boot.
  def establish(connection_name, writing:, reading: nil)
    configs = { writing: { default: writing } }
    configs[:reading] = { default: reading } if reading
    pool_managers[connection_name] = TransactionalServerFakes::PoolManager.new(configs)
    subscribers.fetch('!connection.active_record').call(
      '!connection.active_record', nil, nil, nil, { connection_name: connection_name, shard: :default }
    )
  end

  before do
    described_class.instance_variable_set(:@pools, nil)
    described_class.instance_variable_set(:@pid, nil)
    handler = TransactionalServerFakes::ConnectionHandler.new(pool_managers)
    stub_const('ActiveRecord', Module.new { define_singleton_method(:writing_role) { :writing } })
    stub_const('ActiveRecord::Base', Module.new { define_singleton_method(:connection_handler) { handler } })
    stub_const('ActiveRecord::ConnectionAdapters::ConnectionPool', TransactionalServerFakes::Pool)
    hooks = fork_hooks
    stub_const('ActiveSupport::ForkTracker', Module.new { define_singleton_method(:after_fork) { |&hook| hooks << hook } })
    subs = subscribers
    stub_const('ActiveSupport::Notifications',
               Module.new { define_singleton_method(:subscribe) { |name, &block| subs[name] = block } })
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

    # Rails' transactional fixtures do the same (setup_shared_connection_pool).
    it 'points reading roles at the writing pool, so replicas see the uncommitted rows' do
      described_class.boot

      aggregate_failures do
        expect(pool_managers['ActiveRecord::Base'].get_pool_config(:reading, :default)).to be(pools.first)
        expect(pool_managers['AnimalsRecord'].role_names).to eq([:writing])
        expect(replica_pool.pinned_with).to be_nil
      end
    end

    # Also what Rails' transactional fixtures do: a lazily loaded abstract
    # class with connects_to establishes its pools after boot.
    it 'shares and pins pools established after boot, and rolls them back on reset' do
      described_class.boot
      late_writer = TransactionalServerFakes::Pool.new
      late_reader = TransactionalServerFakes::Pool.new
      establish('AnimalsReplicaRecord', writing: late_writer, reading: late_reader)
      establish('AnimalsReplicaRecord', writing: late_writer, reading: late_reader)
      described_class.reset!

      aggregate_failures do
        expect(pool_managers['AnimalsReplicaRecord'].get_pool_config(:reading, :default)).to be(late_writer)
        expect(late_writer.pinned_with).to be(true)
        expect(late_reader.pinned_with).to be_nil
        expect(late_writer.connection.calls).to eq(
          [[:begin, { joinable: false, _lazy: false }], [:rollback], [:begin, { joinable: false, _lazy: false }]]
        )
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

    it 'rolls back a savepoint left open by another thread before opening the new transaction' do
      described_class.boot
      connection = pools.first.connection
      connection.begin_transaction(requires_new: true)

      described_class.reset!

      aggregate_failures do
        expect(connection.calls).to eq(
          [
            [:begin, { joinable: false, _lazy: false }],
            [:begin, { requires_new: true }],
            [:rollback],
            [:rollback],
            [:begin, { joinable: false, _lazy: false }]
          ]
        )
        expect(connection.depth).to eq(1)
      end
    end

    # The end-to-end proof with real Puma workers is in the smoke test.
    it 'stops the server from a forked child before it serves anything' do
      described_class.boot
      server_pid = Process.pid
      allow(Process).to receive(:kill)
      allow(Process).to receive(:exit!)

      expect { fork_hooks.each(&:call) }.to output(/was forked from the transactional server .* the server is stopping/).to_stderr
      aggregate_failures do
        expect(Process).to have_received(:kill).with('TERM', server_pid).ordered
        expect(Process).to have_received(:exit!).with(1).ordered
      end
    end

    it 'still exits the forked child when the server cannot be signalled' do
      described_class.boot
      allow(Process).to receive(:kill).and_raise(Errno::ESRCH)
      allow(Process).to receive(:exit!)

      expect { fork_hooks.each(&:call) }.to output.to_stderr.and raise_error(Errno::ESRCH)
      expect(Process).to have_received(:exit!).with(1)
    end

    it 'does nothing, and says nothing about Rails versions, without Active Record' do
      hide_const('ActiveRecord')

      expect { described_class.boot }.not_to output.to_stderr
      expect(described_class).not_to be_active
    end

    it 'warns and leaves the database alone before Rails 7.2' do
      stub_const('ActiveRecord::ConnectionAdapters::ConnectionPool', Class.new)

      expect { described_class.boot }.to output(/needs Rails 7.2 or later/).to_stderr
      aggregate_failures do
        expect(described_class).not_to be_active
        expect(pools.map(&:pinned_with)).to eq([nil, nil])
        expect(pool_managers['ActiveRecord::Base'].get_pool_config(:reading, :default)).to be(replica_pool)
        expect(hook_calls).to be_empty
      end
    end
  end
end
