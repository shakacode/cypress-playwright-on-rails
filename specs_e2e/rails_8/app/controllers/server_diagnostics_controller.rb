# Diagnostics about the process that is actually serving requests, as opposed
# to the process that spawned it. Used by specs_e2e/transactional_server_smoke_test.rb.
class ServerDiagnosticsController < ApplicationController
  # Asserts that the test server really is running Puma with more than one
  # thread, in its own process.
  def puma_stats
    render json: puma_stats_hash.transform_keys(&:to_s).merge('server_pid' => Process.pid)
  end

  # The post titles as seen through the reading role (primary_replica).
  def reading_titles
    titles = ApplicationRecord.connected_to(role: :reading) { Post.pluck(:title) }
    render json: titles
  end

  # The hooks recorded by config/initializers/transactional_server_smoke.rb.
  def hook_log
    render json: TransactionalServerSmoke.log
  end

  private

  # Puma >= 6 exposes the hash directly; older versions only return JSON.
  def puma_stats_hash
    return Puma.stats_hash if Puma.respond_to?(:stats_hash)

    JSON.parse(Puma.stats)
  end
end
