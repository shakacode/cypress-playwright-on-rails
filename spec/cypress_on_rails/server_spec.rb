require 'cypress_on_rails/server'
require 'rbconfig'
require 'thread'
require 'json'
require 'stringio'

RSpec.describe CypressOnRails::Server do
  describe '#open' do
    let(:server) { described_class.new(host: '127.0.0.1', port: 4321) }

    before do
      allow($stderr).to receive(:write)
      allow(server).to receive(:server_responding?).and_return(false)
      allow(server).to receive(:run_command)
    end

    it 'wraps a direct spawn exception with command, unavailable status, and cleaned resources' do
      before_stop = spy('before server stop', call: nil)
      allow(CypressOnRails.configuration).to receive(:before_server_stop).and_return(before_stop)
      allow(server).to receive(:spawn).and_raise(Errno::ENOENT, 'bundle')

      expect { server.open }.to raise_error(CypressOnRails::ServerError) { |error|
        expect(error.message).to include('bundle exec rails server -p 4321 -b 127.0.0.1')
        expect(error.message).to include('process status unavailable')
        expect(error.message).to include('No such file or directory')
      }
      expect(ENV['CYPRESS']).to be_nil
      expect(before_stop).not_to have_received(:call)
      expect(server.instance_variable_get(:@server_output_readers)).to all(satisfy { |reader| !reader.alive? })
    end

    it 'cleans a partial capture setup failure before spawning the server' do
      stdout_reader, stdout_writer = IO.pipe
      stderr_reader, stderr_writer = IO.pipe
      created_threads = []
      thread_count = 0
      allow(IO).to receive(:pipe).and_return([stdout_reader, stdout_writer], [stderr_reader, stderr_writer])
      allow(Thread).to receive(:new).and_wrap_original do |original, &block|
        thread_count += 1
        raise ThreadError, 'injected capture setup failure' if thread_count == 2

        thread = original.call(&block)
        created_threads << thread
        thread
      end

      expect { server.open }.to raise_error(ThreadError, 'injected capture setup failure')
      expect(ENV['CYPRESS']).to be_nil
      expect([stdout_reader, stdout_writer, stderr_reader, stderr_writer]).to all(be_closed)
      expect(created_threads).to all(satisfy { |thread| !thread.alive? })
    end

    it 'reports an immediately exiting server with its command, status, and final output line' do
      spawn_exiting_child("#{(1..55).map { |number| "line #{number}" }.join("\n")}\nfinal diagnostic line\n")

      expect { server.open }.to raise_error(CypressOnRails::ServerError) { |error|
        expect(error.message).to include('bundle exec rails server -p 4321 -b 127.0.0.1')
        expect(error.message).to include('exit status 7')
        expect(error.message).to include("\nline 7\n")
        expect(error.message).not_to include("\nline 1\n")
        expect(error.message).to include('final diagnostic line')
        expect(error.message.lines.grep(/^line \d+$/).length).to eq(49)
      }
    end

    it 'keeps a reaped exit status across repeated near-deadline polls' do
      spawn_exiting_child("final diagnostic line\n")
      server.send(:spawn_server)

      begin
        sleep 0.01 until server.send(:server_exited?)

        expect(server.send(:server_exited?)).to be(true)
        error = server.send(:server_start_failure)
        expect(error).to be_a(CypressOnRails::ServerError)
        expect(error.message).to include('exit status 7')
      ensure
        server.send(:drain_server_output)
      end
    end

    it 'cleans a surviving process group after its fast launcher exits' do
      pid = 12_345
      prepare_lifecycle_server(pid)
      allow(server).to receive(:start_server_output_capture)
      allow(server).to receive(:spawn).and_return(pid)
      expect(Process).not_to receive(:getpgid)

      server.send(:spawn_server)
      server.instance_variable_set(:@server_exit_status, exited_process_status)
      allow(server).to receive(:process_group_exists?).and_return(false)

      expect(Process).to receive(:kill).with('TERM', -pid)
      expect(server.send(:stop_server, pid)).to eq(:terminal_group_signaled)
      expect(server.instance_variable_get(:@server_pgid)).to eq(pid)
    end

    it 'escalates a terminal leader process group to KILL after the bounded TERM wait' do
      pid = 12_345
      signals = []
      prepare_lifecycle_server(pid)
      server.instance_variable_set(:@server_pgid, pid)
      server.instance_variable_set(:@server_exit_status, exited_process_status)
      allow(Process).to receive(:kill) { |signal, target| signals << [signal, target] }
      expect(server).to receive(:process_group_exists?).and_return(true, true, false)
      allow(server).to receive(:monotonic_time).and_return(0.0, 10.0)
      allow(server).to receive(:sleep)

      expect(server.send(:stop_server, pid)).to eq(:terminal_group_signaled)

      expect(signals).to eq([['TERM', -pid], ['KILL', -pid]])
    end

    it 'escalates a live leader process group after the leader exits on TERM' do
      pid = 12_345
      signals = []
      polls = 0
      prepare_lifecycle_server(pid)
      status = exited_process_status
      server.instance_variable_set(:@server_pgid, pid)
      allow(Process).to receive(:waitpid2).with(pid, Process::WNOHANG) do
        polls += 1
        polls == 1 ? nil : [pid, status]
      end
      allow(Process).to receive(:kill) { |signal, target| signals << [signal, target] }
      expect(server).to receive(:process_group_exists?).and_return(true, true, false)
      allow(server).to receive(:monotonic_time).and_return(0.0, 10.0)
      allow(server).to receive(:sleep)

      expect(server.send(:stop_server, pid)).to eq(:signaled)

      expect(signals).to eq([['TERM', -pid], ['KILL', -pid]])
      expect(server.instance_variable_get(:@server_exit_status)).to eq(status)
      expect(polls).to eq(2)
    end

    it 'treats an externally reaped server as terminal with unavailable status without TERM' do
      prepare_lifecycle_server(12_345)
      allow(Process).to receive(:waitpid2).with(12_345, Process::WNOHANG).and_raise(Errno::ECHILD)
      allow(server).to receive(:process_exists?).and_return(true)
      allow(server).to receive(:send_term_signal)

      error = server.send(:server_start_timeout_failure, 30)

      expect(error.message).to include('process status unavailable')
      expect(server).not_to have_received(:send_term_signal)
    end

    it 'reports a timeout-boundary zombie exit status without TERM' do
      pid = 12_345
      prepare_lifecycle_server(pid)
      status = exited_process_status
      allow(Process).to receive(:waitpid2).with(pid, Process::WNOHANG).and_return([pid, status])
      allow(server).to receive(:process_exists?).and_return(true)
      allow(server).to receive(:send_term_signal)

      error = server.send(:server_start_timeout_failure, 30)

      expect(error.message).to include('exit status 7')
      expect(server).not_to have_received(:send_term_signal)
    end

    it 'refreshes timeout status when stop reaps the server before TERM' do
      pid = 12_345
      polls = 0
      prepare_lifecycle_server(pid)
      status = exited_process_status
      allow(Process).to receive(:waitpid2).with(pid, Process::WNOHANG) do
        polls += 1
        polls == 1 ? nil : [pid, status]
      end
      allow(server).to receive(:process_exists?).and_return(true)
      allow(server).to receive(:send_term_signal)

      error = server.send(:server_start_timeout_failure, 30)

      expect(error.message).to include('exit status 7')
      expect(server).not_to have_received(:send_term_signal)
      expect(polls).to eq(2)
    end

    it 'retains a reaped status before delivering an interrupted timeout' do
      pid = 12_345
      prepare_lifecycle_server(pid)
      status = exited_process_status
      target = Thread.current
      interrupt = Queue.new
      interrupter = Thread.new do
        interrupt.pop
        target.raise Timeout::Error
      end
      allow(Process).to receive(:waitpid2).with(pid, Process::WNOHANG) do
        interrupt << true
        sleep 0.01
        [pid, status]
      end

      expect { server.send(:server_exited?) }.to raise_error(Timeout::Error)
      expect(server.instance_variable_get(:@server_exit_status)).to eq(status)
    ensure
      interrupter.join
    end

    it 'caches a reaped status through a real readiness timeout' do
      pid = 12_345
      polls = 0
      prepare_lifecycle_server(pid)
      status = exited_process_status
      allow(server).to receive(:server_responding?).and_return(false)
      allow(Process).to receive(:waitpid2).with(pid, Process::WNOHANG) do
        polls += 1
        if polls == 1
          result = [pid, status]
          sleep 0.02
          result
        else
          raise Errno::ECHILD
        end
      end

      expect { server.send(:wait_for_server, 0.001) }.to raise_error(CypressOnRails::ServerError) { |error|
        expect(error.message).to include('exit status 7')
      }
      expect(server.instance_variable_get(:@server_exit_status)).to eq(status)
      expect(polls).to eq(1)
    end

    it 'does not KILL after a wait has already reaped the server' do
      pid = 12_345
      signals = []
      prepare_lifecycle_server(pid)
      status = exited_process_status
      allow(server).to receive(:send_term_signal)
      allow(server).to receive(:safe_kill_process) { |signal, _pid| signals << signal }
      allow(Process).to receive(:waitpid2).with(pid, Process::WNOHANG).and_return([pid, status])
      expect(Process).not_to receive(:wait).with(pid)
      expect(Timeout).not_to receive(:timeout).with(10)

      server.send(:stop_server, pid)

      expect(signals).not_to include('KILL')
      expect(server.instance_variable_get(:@server_exit_status)).to eq(status)
    end

    it 'skips KILL when the pre-KILL guard finds ECHILD after TERM' do
      pid = 12_345
      polls = 0
      signals = []
      prepare_lifecycle_server(pid)
      allow(Process).to receive(:waitpid2).with(pid, Process::WNOHANG) do
        polls += 1
        polls == 1 ? nil : raise(Errno::ECHILD)
      end
      allow(server).to receive(:send_term_signal) { signals << 'TERM' }
      allow(server).to receive(:safe_kill_process) { |signal, _pid| signals << signal }
      allow(server).to receive(:wait_for_server_exit).and_return(false)

      server.send(:stop_server, pid)

      expect(signals).to eq(['TERM'])
      expect(polls).to eq(2)
      expect(server.instance_variable_get(:@server_status_unavailable)).to be(true)
    end

    it 'sends exactly one KILL when the pre-KILL guard remains live' do
      pid = 12_345
      signals = []
      prepare_lifecycle_server(pid)
      allow(server).to receive(:server_exited?).and_return(false)
      allow(server).to receive(:send_term_signal) { signals << 'TERM' }
      allow(server).to receive(:send_kill_signal) { signals << 'KILL' }
      allow(server).to receive(:wait_for_server_exit).and_return(false, true)

      server.send(:stop_server, pid)

      expect(signals).to eq(['TERM', 'KILL'])
      expect(server).to have_received(:send_kill_signal).once.with(pid)
    end

    it 'returns false without a negative sleep when the deadline passes between clock reads' do
      sleeps = []
      allow(server).to receive(:server_exited?).and_return(false)
      allow(server).to receive(:monotonic_time).and_return(0.999, 1.001)
      allow(server).to receive(:sleep) { |duration| sleeps << duration }

      expect(server.send(:wait_for_server_exit, 1.0)).to be(false)
      expect(sleeps).to all(be >= 0)
    end

    it 'bounds a pathological output line without losing the final diagnostic line' do
      spawn_exiting_child("#{'a' * 8_192}\nfinal diagnostic line\n")

      expect { server.open }.to raise_error(CypressOnRails::ServerError) { |error|
        expect(error.message).to include('final diagnostic line')
        expect(error.message.bytesize).to be < 5_000
      }
    end

    it 'keeps a multibyte startup-output tail valid and serializable' do
      final_diagnostic = "final diagnostic line\n"
      tail = "#{'b' * (4_094 - final_diagnostic.bytesize)}#{final_diagnostic}"
      spawn_exiting_child("#{'a' * 10}€#{tail}")

      expect { server.open }.to raise_error(CypressOnRails::ServerError) { |error|
        expect(error.message.encoding).to eq(Encoding::UTF_8)
        expect(error.message).to be_valid_encoding
        expect(error.message).to include('final diagnostic line')
        expect { JSON.generate(error.message) }.not_to raise_error
      }
    end

    it 'reports a live server readiness timeout with its command, running status, and output' do
      captured_output = Queue.new
      signal_attempts = 0
      allow(server).to receive(:capture_server_output).and_wrap_original do |original, output|
        original.call(output).tap { captured_output << true }
      end
      allow(server).to receive(:send_term_signal).and_wrap_original do |original, pid|
        signal_attempts += 1
        original.call(pid)
      end
      allow(server).to receive(:server_responding?) do
        captured_output.pop
        raise Timeout::Error
      end
      spawn_running_child("still starting\n")
      allow(Timeout).to receive(:timeout).and_wrap_original do |original, timeout, exception_class = nil, &block|
        if timeout == 30
          expect(exception_class).to eq(Timeout::Error)
          block.call
        else
          original.call(timeout, exception_class, &block)
        end
      end

      expect { server.open }.to raise_error(CypressOnRails::ServerError) { |error|
        expect(error.message).to include('bundle exec rails server -p 4321 -b 127.0.0.1')
        expect(error.message).to include('process status running')
        expect(error.message).to include('still starting')
      }
      expect(signal_attempts).to eq(1)
    end

    it 'runs the stop hook before signaling a live readiness timeout' do
      captured_output = Queue.new
      events = []
      allow(CypressOnRails.configuration).to receive(:before_server_stop).and_return(-> { events << :hook })
      allow(server).to receive(:capture_server_output).and_wrap_original do |original, output|
        original.call(output).tap { captured_output << true }
      end
      allow(server).to receive(:server_responding?) do
        captured_output.pop
        raise Timeout::Error
      end
      allow(server).to receive(:send_term_signal).and_wrap_original do |original, pid|
        events << :term
        original.call(pid)
      end
      spawn_running_child("final diagnostic line\n")
      allow(Timeout).to receive(:timeout).and_wrap_original do |original, timeout, exception_class = nil, &block|
        if timeout == 30
          expect(exception_class).to eq(Timeout::Error)
          block.call
        else
          original.call(timeout, exception_class, &block)
        end
      end

      expect { server.open }.to raise_error(CypressOnRails::ServerError) { |error|
        expect(error.message).to include('bundle exec rails server -p 4321 -b 127.0.0.1')
        expect(error.message).to include('process status running')
        expect(error.message).to include('final diagnostic line')
      }
      expect(events).to eq([:hook, :term])
    end

    it 'drains a lagging reader before building a live-timeout error' do
      reader_entered = Queue.new
      release_reader = Queue.new
      term_started = Queue.new
      allow(server).to receive(:capture_server_output).and_wrap_original do |original, output|
        reader_entered << true
        release_reader.pop
        original.call(output)
      end
      allow(server).to receive(:server_responding?) do
        reader_entered.pop
        raise Timeout::Error
      end
      allow(server).to receive(:send_term_signal).and_wrap_original do |original, pid|
        term_started << true
        original.call(pid)
      end
      spawn_running_child("final diagnostic line\n")
      allow(Timeout).to receive(:timeout).and_wrap_original do |original, timeout, exception_class = nil, &block|
        if timeout == 30
          expect(exception_class).to eq(Timeout::Error)
          block.call
        else
          original.call(timeout, exception_class, &block)
        end
      end

      result = Queue.new
      opening = Thread.new do
        begin
          server.open
        rescue StandardError => error
          result << error
        end
      end
      term_started.pop
      release_reader << true
      error = result.pop
      opening.join

      expect(error).to be_a(CypressOnRails::ServerError)
      expect(error.message).to include('final diagnostic line')
      expect(term_started.size).to eq(0)
    end

    it 'captures final output after terminal forwarding raises EPIPE' do
      allow($stderr).to receive(:write).and_raise(Errno::EPIPE)
      spawn_exiting_child("first output\n", "sleep 0.05; STDERR.write('final diagnostic line\\n')")

      expect { server.open }.to raise_error(CypressOnRails::ServerError) { |error|
        expect(error.message).to include('final diagnostic line')
      }
    end

    it 'captures diagnostics when terminal forwarding raises an encoding error' do
      allow($stderr).to receive(:write) { |chunk| chunk.encode(Encoding::US_ASCII) }
      spawn_exiting_child("€ final diagnostic line\n")

      expect { server.open }.to raise_error(CypressOnRails::ServerError) { |error|
        expect(error.message).to include('final diagnostic line')
      }
      expect(server.instance_variable_get(:@server_output_forwarders)).to all(satisfy { |thread| !thread.alive? })
    end

    it 'forwards every burst byte after a healthy slow terminal catches up' do
      output = "#{'a' * (1_024 * 18)}final diagnostic line\n"
      captured_bytes = 0
      capture_ready = Queue.new
      sink_started = Queue.new
      release_sink = Queue.new
      received = +''.b
      first_write = true
      allow(server).to receive(:capture_server_output).and_wrap_original do |original, chunk|
        original.call(chunk)
        captured_bytes += chunk.bytesize
        capture_ready << true if captured_bytes >= 1_024 * 18
      end
      allow($stderr).to receive(:write) do |chunk|
        if first_write
          first_write = false
          sink_started << true
          release_sink.pop
        end
        received << chunk
      end
      spawn_exiting_child(output)

      result = Queue.new
      opening = Thread.new do
        begin
          server.open
        rescue StandardError => error
          result << error
        end
      end
      sink_started.pop
      capture_ready.pop
      release_sink << true
      error = result.pop
      opening.join

      expect(error).to be_a(CypressOnRails::ServerError)
      expect(received).to eq(output.b)
    end

    it 'drains every byte to a healthy continuously slow terminal within the drain budget' do
      output = "#{'a' * (1_024 * 18)}final diagnostic line\n"
      received = +''.b
      allow($stderr).to receive(:write) do |chunk|
        received << chunk
        sleep 0.01
      end
      spawn_exiting_child(output)

      expect { server.open }.to raise_error(CypressOnRails::ServerError)

      expect(received).to eq(output.b)
      expect(server.instance_variable_get(:@server_output_forwarders)).to all(satisfy { |thread| !thread.alive? })
    end

    it 'keeps the final diagnostic when a terminal remains stalled beyond the forwarding backlog' do
      sink_started = Queue.new
      never_release_sink = Queue.new
      output = "#{'a' * (1_024 * 18)}final diagnostic line\n"
      allow($stderr).to receive(:write) do
        sink_started << true
        never_release_sink.pop
      end
      spawn_exiting_child(output)

      result = Queue.new
      opening = Thread.new do
        begin
          server.open
        rescue StandardError => error
          result << error
        end
      end
      sink_started.pop
      error = Timeout.timeout(3) { result.pop }
      opening.join(1)

      expect(error).to be_a(CypressOnRails::ServerError)
      expect(error.message).to include('final diagnostic line')
      expect(opening).not_to be_alive
      expect(server.instance_variable_get(:@server_output_readers)).to all(satisfy { |reader| !reader.alive? })
      expect(server.instance_variable_get(:@server_output_forwarders)).to all(satisfy { |forwarder| !forwarder.alive? })
    end

    it 'keeps the final diagnostic when a terminal drains the forwarding queue gradually' do
      sink_started = Queue.new
      output = "#{'a' * (1_024 * 48)}final diagnostic line\n"
      reader = StringIO.new(output)
      queue = SizedQueue.new(described_class::SERVER_OUTPUT_FORWARD_QUEUE_SIZE)
      allow($stderr).to receive(:write) do
        sink_started << true
        sleep 0.02
      end
      server.instance_variable_set(:@server_output, +'')
      server.instance_variable_set(:@server_output_mutex, Mutex.new)
      server.instance_variable_set(:@server_output_streams, [[reader, queue, $stderr]])
      server.instance_variable_set(:@server_output_readers, [server.send(:start_server_output_reader, reader, queue)])
      server.instance_variable_set(:@server_output_forwarders, [server.send(:start_server_output_forwarder, queue, $stderr)])

      sink_started.pop
      server.send(:drain_server_output)

      expect(server.send(:recent_server_output)).to include('final diagnostic line')
      expect(server.instance_variable_get(:@server_output_readers)).to all(satisfy { |thread| !thread.alive? })
      expect(server.instance_variable_get(:@server_output_forwarders)).to all(satisfy { |thread| !thread.alive? })
    end

    it 'retains a chunk already read by a capture reader while draining' do
      entered_capture = Queue.new
      release_capture = Queue.new
      allow(server).to receive(:capture_server_output).and_wrap_original do |original, output|
        entered_capture << true
        release_capture.pop
        original.call(output)
      end
      spawn_exiting_child("final diagnostic line\n")

      pid = server.send(:spawn_server)
      entered_capture.pop
      draining = Thread.new { server.send(:drain_server_output) }
      sleep 0.05
      release_capture << true
      draining.join
      Process.wait(pid)

      expect(server.send(:recent_server_output)).to include('final diagnostic line')
    end

    def spawn_exiting_child(output, after_output = nil)
      allow(server).to receive(:spawn) do |*_command, **options|
        script = ["STDERR.write(#{output.dump})", after_output, 'exit 7'].compact.join('; ')
        Process.spawn(RbConfig.ruby, '-e', script, **options)
      end
    end

    def spawn_running_child(output)
      allow(server).to receive(:spawn) do |*_command, **options|
        Process.spawn(RbConfig.ruby, '-e', "STDERR.write(#{output.dump}); sleep 10", **options)
      end
    end

    def prepare_lifecycle_server(pid)
      server.instance_variable_set(:@server_pid, pid)
      server.instance_variable_set(:@server_command, ['bundle', 'exec', 'rails', 'server'])
      server.instance_variable_set(:@server_exit_status, nil)
      server.instance_variable_set(:@server_status_unavailable, false)
      server.instance_variable_set(:@server_stopped, false)
      server.instance_variable_set(:@server_output, +'')
      server.instance_variable_set(:@server_output_mutex, Mutex.new)
      server.instance_variable_set(:@server_output_streams, [])
      server.instance_variable_set(:@server_output_readers, [])
      server.instance_variable_set(:@server_output_forwarders, [])
    end

    def exited_process_status
      pid = Process.spawn(RbConfig.ruby, '-e', 'exit 7')
      Process.wait2(pid).last
    end
  end
end
