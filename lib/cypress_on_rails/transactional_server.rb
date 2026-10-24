require 'cypress_on_rails/configuration'

module CypressOnRails
  # The transaction behind `transactional_server`. The rake tasks run the app
  # server in its own process, so the transaction has to be opened there, on
  # the connection every request uses: a transaction held by the rake process
  # cannot see or undo anything the server writes.
  #
  # At boot the server pins one connection per writing pool, shared by all of
  # its threads, and opens a transaction on it (what Rails system tests do for
  # Capybara's in-process server). A state reset rolls that transaction back
  # and opens a new one. Nothing ever commits it: when the server exits, the
  # database discards it, even after a KILL.
  module TransactionalServer
    # Set by CypressOnRails::Server on the server process it spawns.
    ENV_KEY = 'CYPRESS_ON_RAILS_TRANSACTIONAL_SERVER'.freeze

    class << self
      # Runs once the application has booted, see Railtie.
      def boot
        return unless ENV[ENV_KEY] == '1'

        unless supported?
          warn '[cypress_on_rails] transactional_server needs Rails 7.2 or later to roll back what the ' \
               'server writes; on this Rails version those writes are committed. ' \
               'Set transactional_server = false and reset state with app commands instead.'
          return
        end

        begin!
        ActiveSupport::ForkTracker.after_fork { warn_forked }
      end

      # True in the process that holds the transaction. A forked child (Puma
      # workers) does not share it.
      def active?
        !@pools.nil? && @pid == Process.pid
      end

      # Rolls back everything written since the server booted (or since the
      # previous reset) and opens a fresh transaction.
      def reset!
        @pools.each do |pool|
          connection = pool.lease_connection
          connection.lock.synchronize do
            connection.rollback_transaction if connection.transaction_open?
            connection.begin_transaction(joinable: false, _lazy: false)
          end
        end
        run_after_transaction_start
      end

      private

      def supported?
        defined?(ActiveRecord::Base) &&
          ActiveRecord::ConnectionAdapters::ConnectionPool.method_defined?(:pin_connection!)
      end

      # Runs on the main thread, which lives as long as the server does: the
      # pinned connections are checked out by it, and the pool reaper would
      # reset a connection whose owner thread had died.
      def begin!
        @pools = ActiveRecord::Base.connection_handler.connection_pool_list(:writing)
        @pools.each do |pool|
          pool.pin_connection!(true)
          pool.lease_connection
        end
        @pid = Process.pid
        run_after_transaction_start
      end

      def warn_forked
        warn "[cypress_on_rails] transactional_server: server process #{Process.pid} was forked from the one " \
             'holding the transaction (Puma workers?), so its writes are committed. ' \
             'Run the test server in single mode.'
      end

      def run_after_transaction_start
        hook = CypressOnRails.configuration.after_transaction_start
        hook&.call
      end
    end
  end
end
