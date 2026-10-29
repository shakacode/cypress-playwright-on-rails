# Hooks for specs_e2e/transactional_server_smoke_test.rb, which sets the variable
# on the server it spawns. Defined in an initializer, as an app would, because
# with transactional_server they run in the server, not in the rake task.
module TransactionalServerSmoke
  HOOK_SEED_TITLE = 'smoke-seed-from-after-transaction-start'.freeze
  @log = []
  @mutex = Mutex.new

  def self.log
    @mutex.synchronize { @log.dup }
  end

  def self.record(entry)
    @mutex.synchronize { @log << entry }
  end
end

if defined?(CypressOnRails) && ENV['TRANSACTIONAL_SERVER_SMOKE'] == '1'
  CypressOnRails.configure do |c|
    c.after_transaction_start = lambda {
      Post.create!(title: TransactionalServerSmoke::HOOK_SEED_TITLE, body: 'written by after_transaction_start')
      TransactionalServerSmoke.record('event' => 'after_transaction_start')
    }
    c.after_state_reset = lambda {
      TransactionalServerSmoke.record(
        'event' => 'after_state_reset',
        'hook_seed_rows' => Post.where(title: TransactionalServerSmoke::HOOK_SEED_TITLE).count
      )
    }
  end
end
