require 'cypress_on_rails/configuration'

module CypressOnRails
  # The transaction behind `transactional_server`. The rake tasks run the app
  # server in its own process, so the transaction has to be opened there, on
  # the connection every request uses: a transaction held by the rake process
  # cannot see or undo anything the server writes.
  #
  # At boot the server pins one connection per writing pool, shared by all of
  # its threads, and opens a transaction on it (what Rails system tests do for
  # Capybara's in-process server). Reading roles (replicas) are pointed at the
  # writing pool, as Rails transactional fixtures do, so they see the
  # uncommitted rows. Pools established later (a lazily loaded abstract class
  # with connects_to) get the same treatment when they connect. A state reset
  # rolls the transactions back and opens new ones. Nothing ever commits them:
  # when the server exits, the database discards them, even after a KILL.
  #
  # The server must not fork (Puma workers): a forked child cannot share the
  # transaction, so it stops the server before serving anything.
  module TransactionalServer
    # Set by CypressOnRails::Server on the server process it spawns.
    ENV_KEY = 'CYPRESS_ON_RAILS_TRANSACTIONAL_SERVER'.freeze

    class << self
      # Runs once the application has booted, see Railtie.
      def boot
        return unless ENV[ENV_KEY] == '1'
        return unless defined?(ActiveRecord::Base)

        unless supported?
          warn '[cypress_on_rails] transactional_server needs Rails 7.2 or later to roll back what the ' \
               'server writes; on this Rails version those writes are committed. ' \
               'Set transactional_server = false and reset state with app commands instead.'
          return
        end

        begin!
        ActiveSupport::ForkTracker.after_fork { refuse_fork }
      end

      # Runs in the rake task. transactional_server used to default to true, so
      # an app may set after_transaction_start without opting in, and the hook
      # would silently never run.
      def warn_unused_hook(transactional)
        return if transactional || CypressOnRails.configuration.after_transaction_start.nil?

        warn '[cypress_on_rails] after_transaction_start is configured but transactional_server is off ' \
             '(the default), so it will not run. Set c.transactional_server = true to opt in, or move the ' \
             'code to after_server_start or an app command.'
      end

      # True in the process that holds the transaction.
      def active?
        !@pools.nil? && @pid == Process.pid
      end

      # Rolls back everything written since the server booted (or since the
      # previous reset) and opens a fresh transaction.
      def reset!
        @mutex.synchronize { @pools.dup }.each do |pool|
          connection = pool.lease_connection
          connection.lock.synchronize do
            # Another thread may have opened a savepoint on top of the boot
            # transaction; roll the whole stack back rather than nest inside it.
            connection.rollback_transaction while connection.transaction_open?
            connection.begin_transaction(joinable: false, _lazy: false)
          end
        end
        run_after_transaction_start
      end

      private

      # pin_connection! is :nodoc: Rails API, added in 7.2.
      def supported?
        ActiveRecord::ConnectionAdapters::ConnectionPool.method_defined?(:pin_connection!)
      end

      # Runs on the main thread, which lives as long as the server does: the
      # pinned connections are checked out by it, and the pool reaper would
      # reset a connection whose owner thread had died.
      def begin!
        @mutex = Mutex.new
        @pools = []
        @pid = Process.pid
        share_writing_pools
        ActiveRecord::Base.connection_handler.connection_pool_list(ActiveRecord.writing_role).each { |pool| pin(pool) }
        ActiveSupport::Notifications.subscribe('!connection.active_record') { |*, payload| pin_established(payload) }
        run_after_transaction_start
      end

      # A pool established after boot, on whatever thread first connects it
      # (as with Rails transactional fixtures, the subscriber below). Puma's
      # threads live as long as the server, so the pool reaper leaves the
      # pinned connection alone.
      def pin_established(payload)
        connection_name = payload[:connection_name]
        return unless connection_name

        pool = ActiveRecord::Base.connection_handler.retrieve_connection_pool(connection_name, shard: payload[:shard])
        return unless pool

        share_writing_pools
        pin(pool)
      end

      def pin(pool)
        @mutex.synchronize do
          next if @pools.include?(pool)

          pool.pin_connection!(true)
          pool.lease_connection
          @pools << pool
        end
      end

      # Points every other role (reading replicas) at its writing pool, so a
      # query in connected_to(role: :reading) runs on the pinned connection and
      # sees the uncommitted rows. Same as Rails' setup_shared_connection_pool
      # (ActiveRecord::TestFixtures, 7.2 to 8.1), relying on the same :nodoc:
      # pool manager API.
      def share_writing_pools
        handler = ActiveRecord::Base.connection_handler
        handler.connection_pool_names.each do |name|
          pool_manager = handler.send(:connection_name_to_pool_manager)[name]
          pool_manager.shard_names.each do |shard|
            writing_pool_config = pool_manager.get_pool_config(ActiveRecord.writing_role, shard)
            next unless writing_pool_config

            pool_manager.role_names.each do |role|
              pool_config = pool_manager.get_pool_config(role, shard)
              next if pool_config.nil? || pool_config == writing_pool_config

              pool_manager.set_pool_config(role, shard, writing_pool_config)
            end
          end
        end
      end

      # Runs in a child forked from the server holding the transaction (Puma
      # workers, solid_queue's supervisor, a fork in app code). The child
      # cannot share the transaction: its writes would be committed and a
      # reset would truncate instead of rolling back. Stop the whole server
      # before the child serves a request; exit! skips the inherited at_exit
      # hooks and connection finalizers, which belong to the parent.
      def refuse_fork
        warn "[cypress_on_rails] transactional_server: process #{Process.pid} was forked from the " \
             "transactional server (#{@pid}), by Puma workers, solid_queue's supervisor or a fork in app " \
             'code. A forked process cannot share that transaction, so the server is stopping. ' \
             'Run the test server in a single process (no Puma workers, WEB_CONCURRENCY unset or 0), ' \
             'or set transactional_server = false.'
        begin
          Process.kill('TERM', @pid)
        ensure
          Process.exit!(1)
        end
      end

      def run_after_transaction_start
        hook = CypressOnRails.configuration.after_transaction_start
        hook&.call
      end
    end
  end
end
