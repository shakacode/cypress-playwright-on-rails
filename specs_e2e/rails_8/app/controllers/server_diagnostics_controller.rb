# Diagnostics about the process that is actually serving requests, as opposed
# to the process that spawned it. Used by
# script/transactional_server_smoke_test.rb to assert that the test server
# really is running Puma with more than one thread.
class ServerDiagnosticsController < ApplicationController
  def puma_stats
    render json: puma_stats_hash.transform_keys(&:to_s).merge('server_pid' => Process.pid)
  end

  private

  # Puma >= 6 exposes the hash directly; older versions only return JSON.
  def puma_stats_hash
    return Puma.stats_hash if Puma.respond_to?(:stats_hash)

    JSON.parse(Puma.stats)
  end
end
