require 'socket'
require 'timeout'
require 'fileutils'
require 'net/http'
require 'thread'
require 'cypress_on_rails/configuration'

module CypressOnRails
  class ServerError < StandardError
  end

  class Server
    MAX_STARTUP_OUTPUT_BYTES = 4_096
    MAX_STARTUP_OUTPUT_LINES = 50
    SERVER_OUTPUT_DRAIN_TIMEOUT = 0.5
    SERVER_OUTPUT_THREAD_JOIN_TIMEOUT = 0.05
    SERVER_OUTPUT_FORWARD_QUEUE_SIZE = 16
    SERVER_OUTPUT_FORWARD_BACKPRESSURE_TIMEOUT = 0.1
    SERVER_STOP_TIMEOUT = 10
    SERVER_STOP_POLL_INTERVAL = 0.05

    attr_reader :host, :port, :framework, :install_folder

    def initialize(options = {})
      config = CypressOnRails.configuration

      @framework = options[:framework] || :cypress
      @host = options[:host] || config.server_host
      @port = options[:port] || config.server_port || find_available_port
      @port = @port.to_i if @port
      @install_folder = options[:install_folder] || config.install_folder || detect_install_folder
      @transactional = options.fetch(:transactional, config.transactional_server)
      # Process management: track PID and process group for proper cleanup
      @server_pid = nil
      @server_pgid = nil
    end

    def open
      start_server do
        run_command(open_command, "Opening #{framework} test runner")
      end
    end

    def run
      start_server do
        result = run_command(run_command_args, "Running #{framework} tests")
        exit(result ? 0 : 1)
      end
    end

    def init
      ensure_install_folder_exists
      puts "#{framework.to_s.capitalize} configuration initialized at #{install_folder}"
    end

    private

    def detect_install_folder
      # Check common locations for cypress/playwright installation
      possible_folders = ['e2e', 'spec/e2e', 'spec/cypress', 'spec/playwright', 'cypress', 'playwright']
      folder = possible_folders.find { |f| File.exist?(File.expand_path(f)) }
      folder || 'e2e'
    end

    def ensure_install_folder_exists
      unless File.exist?(install_folder)
        puts "Creating #{install_folder} directory..."
        FileUtils.mkdir_p(install_folder)
      end
    end

    def find_available_port
      server = TCPServer.new('127.0.0.1', 0)
      port = server.addr[1]
      server.close
      port
    end

    def start_server(&block)
      config = CypressOnRails.configuration
      
      run_hook(config.before_server_start)
      
      ENV['CYPRESS'] = '1'
      ENV['RAILS_ENV'] ||= 'test'
      
      begin
        server_pid = spawn_server
      rescue StandardError
        ENV.delete('CYPRESS')
        raise
      end

      begin
        wait_for_server
        run_hook(config.after_server_start)
        
        puts "Rails server started on #{base_url}"
        
        if @transactional && defined?(ActiveRecord::Base)
          ActiveRecord::Base.connection.begin_transaction(joinable: false)
          run_hook(config.after_transaction_start)
        end
        
        yield
        
      ensure
        run_hook(config.before_server_stop)
        
        if @transactional && defined?(ActiveRecord::Base)
          ActiveRecord::Base.connection.rollback_transaction if ActiveRecord::Base.connection.transaction_open?
        end
        
        stop_server(server_pid)
        ENV.delete('CYPRESS')
      end
    end

    def spawn_server
      rails_args = if File.exist?('bin/rails')
        ['bin/rails']
      else
        ['bundle', 'exec', 'rails']
      end

      server_args = rails_args + ['server', '-p', port.to_s, '-b', host]

      puts "Starting Rails server: #{server_args.join(' ')}"

      @server_command = server_args
      @server_exit_status = nil
      @server_status_unavailable = false
      @server_stopped = false
      start_server_output_capture
      begin
        @server_pid = spawn(*server_args, out: @server_stdout_writer, err: @server_stderr_writer, pgroup: true)
      rescue SystemCallError, ArgumentError => error
        close_server_output_writers
        drain_server_output
        raise ServerError, "Rails server command #{@server_command.join(' ')} failed to spawn; " \
                           "process status unavailable: #{error.class}: #{error.message}"
      ensure
        close_server_output_writers
      end
      begin
        @server_pgid = Process.getpgid(@server_pid)
      rescue Errno::ESRCH => e
        # Edge case: process terminated before we could get pgid
        # This is OK - send_term_signal will fall back to single-process kill
        CypressOnRails.configuration.logger.warn("Process #{@server_pid} terminated immediately after spawn: #{e.message}")
        @server_pgid = nil
      end
      @server_pid
    end

    def wait_for_server(timeout = 30)
      Timeout.timeout(timeout, Timeout::Error) do
        loop do
          break if server_responding?
          raise server_start_failure if server_exited?

          sleep 0.1
        end
      end
    rescue Timeout::Error
      raise server_start_failure if server_exited?

      raise server_start_timeout_failure(timeout)
    end

    def server_responding?
      config = CypressOnRails.configuration
      readiness_path = config.server_readiness_path || '/'
      timeout = config.server_readiness_timeout || 5
      uri = URI("http://#{host}:#{port}#{readiness_path}")

      response = Net::HTTP.start(uri.host, uri.port, open_timeout: timeout, read_timeout: timeout) do |http|
        http.get(uri.path)
      end

      # Accept 200-399 (success and redirects), reject 404 and 5xx
      # 3xx redirects are considered "ready" because the server is responding correctly
      (200..399).cover?(response.code.to_i)
    rescue Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL, Errno::ETIMEDOUT, SocketError,
           Net::OpenTimeout, Net::ReadTimeout, Net::HTTPBadResponse
      false
    end

    def stop_server(pid)
      return :terminal unless pid
      begin
        return :terminal if server_terminal? || server_exited?

        puts "Stopping Rails server (PID: #{pid})"
        send_term_signal(pid)

        unless wait_for_server_exit(monotonic_time + SERVER_STOP_TIMEOUT)
          CypressOnRails.configuration.logger.warn("Server did not terminate after TERM signal, sending KILL")
          unless server_exited?
            safe_kill_process('KILL', pid)
            wait_for_server_exit(monotonic_time + SERVER_STOP_TIMEOUT)
          end
        end
        :signaled
      ensure
        wait_for_server_output
      end
    end

    def wait_for_server_exit(deadline)
      loop do
        return true if server_exited?
        now = monotonic_time
        return false if now >= deadline

        sleep [SERVER_STOP_POLL_INTERVAL, deadline - now].min
      end
    end

    def start_server_output_capture
      @server_output = +''
      @server_output_mutex = Mutex.new
      @server_output_streams = []
      @server_output_readers = []
      @server_output_forwarders = []

      begin
        stdout_reader, @server_stdout_writer = IO.pipe
        @server_output_streams << [stdout_reader, SizedQueue.new(SERVER_OUTPUT_FORWARD_QUEUE_SIZE), $stdout]
        stderr_reader, @server_stderr_writer = IO.pipe
        @server_output_streams << [stderr_reader, SizedQueue.new(SERVER_OUTPUT_FORWARD_QUEUE_SIZE), $stderr]

        @server_output_streams.each do |reader, queue, _stream|
          @server_output_readers << start_server_output_reader(reader, queue)
        end
        @server_output_streams.each do |_reader, queue, stream|
          @server_output_forwarders << start_server_output_forwarder(queue, stream)
        end
      rescue StandardError
        close_server_output_writers
        Array(@server_output_streams).each do |reader, _queue, _stream|
          reader.close unless reader.closed?
        end
        stop_server_output_readers
        stop_server_output_forwarders
        raise
      end
    end

    def start_server_output_reader(reader, queue)
      Thread.new do
        forwarding = true
        forwarding_deadline = nil
        loop do
          output = reader.readpartial(1_024)
          capture_server_output(output)
          if forwarding
            forwarding, forwarding_deadline = enqueue_server_output(queue, output, forwarding_deadline)
          end
        end
      rescue EOFError, IOError
        # The server closed its output stream.
      ensure
        enqueue_server_output_end(queue, forwarding_deadline) if forwarding
        reader.close unless reader.closed?
      end
    end

    def start_server_output_forwarder(queue, stream)
      Thread.new do
        forwarding = true
        loop do
          output = queue.pop
          break unless output

          next unless forwarding

          begin
            stream.write(output)
            stream.flush
          rescue SystemCallError, IOError, EncodingError
            forwarding = false
          end
        end
      end
    end

    def capture_server_output(output)
      @server_output_mutex.synchronize do
        @server_output << output
        if @server_output.bytesize > MAX_STARTUP_OUTPUT_BYTES
          @server_output = @server_output.byteslice(-MAX_STARTUP_OUTPUT_BYTES, MAX_STARTUP_OUTPUT_BYTES)
        end
      end
    end

    def server_exited?
      return true if server_terminal?

      terminal = false
      Thread.handle_interrupt(Timeout::Error => :never) do
        begin
          result = Process.waitpid2(@server_pid, Process::WNOHANG)
          if result
            @server_exit_status = result.last
            @server_stopped = true
            terminal = true
          end
        rescue Errno::ECHILD
          @server_status_unavailable = true
          @server_stopped = true
          terminal = true
        end
      end
      terminal
    end

    def server_start_failure
      drain_server_output
      status = @server_exit_status
      message = "Rails server command #{@server_command.join(' ')} exited during startup with #{process_status(status)}"
      output = recent_server_output
      message += "\nRecent server output:\n#{output}" unless output.empty?
      ServerError.new(message)
    end

    def server_start_timeout_failure(timeout)
      if server_exited?
        status = startup_process_status
        drain_server_output
      else
        status = process_exists?(@server_pid) ? 'process status running' : 'process status unavailable'
        stop_result = stop_server(@server_pid)
        status = startup_process_status if stop_result == :terminal
      end
      message = "Rails server command #{@server_command.join(' ')} failed to become ready after #{timeout} seconds with #{status}"
      output = recent_server_output
      message += "\nRecent server output:\n#{output}" unless output.empty?
      ServerError.new(message)
    end

    def process_status(status)
      return 'process status unavailable' if @server_status_unavailable
      return 'an unknown process status' unless status
      return "exit status #{status.exitstatus}" if status.exited?

      "signal #{status.termsig}"
    end

    def startup_process_status
      return 'process status unavailable' if @server_status_unavailable

      process_status(@server_exit_status)
    end

    def server_terminal?
      @server_exit_status || @server_status_unavailable || @server_stopped
    end

    def recent_server_output
      @server_output_mutex.synchronize do
        output = @server_output.each_line.to_a.last(MAX_STARTUP_OUTPUT_LINES).join
        output = output.byteslice(-MAX_STARTUP_OUTPUT_BYTES, MAX_STARTUP_OUTPUT_BYTES) if output.bytesize > MAX_STARTUP_OUTPUT_BYTES
        output.force_encoding(Encoding::UTF_8).scrub('')
      end
    end

    def close_server_output_writers
      [@server_stdout_writer, @server_stderr_writer].compact.each do |writer|
        writer.close unless writer.closed?
      end
    end

    def wait_for_server_output
      drain_server_output
    end

    def drain_server_output
      deadline = monotonic_time + SERVER_OUTPUT_DRAIN_TIMEOUT
      close_server_output_writers
      wait_for_server_output_readers(deadline)
    ensure
      Array(@server_output_streams).each do |reader, _queue, _stream|
        reader.close unless reader.closed?
      end
      stop_server_output_readers
      stop_server_output_forwarders(deadline)
    end

    def wait_for_server_output_readers(deadline)
      Array(@server_output_readers).each do |reader|
        timeout = deadline - monotonic_time
        break if timeout <= 0

        reader.join(timeout)
      end
    end

    def enqueue_server_output_end(queue, deadline)
      enqueue_server_output(queue, nil, deadline)
    end

    def enqueue_server_output(queue, output, deadline)
      deadline = nil if deadline && queue.empty?
      loop do
        queue.push(output, true)
        return [true, deadline]
      rescue ThreadError
        deadline ||= monotonic_time + SERVER_OUTPUT_FORWARD_BACKPRESSURE_TIMEOUT
        return false if monotonic_time >= deadline

        sleep 0.001
      end
    end

    def stop_server_output_forwarders(deadline = nil)
      deadline ||= monotonic_time + SERVER_OUTPUT_THREAD_JOIN_TIMEOUT
      forwarders = Array(@server_output_forwarders)
      forwarders.each do |forwarder|
        timeout = deadline - monotonic_time
        forwarder.join(timeout) if timeout > 0
      end
      forwarders.each do |forwarder|
        forwarder.kill if forwarder.alive?
        forwarder.join(SERVER_OUTPUT_THREAD_JOIN_TIMEOUT)
      end
    end

    def stop_server_output_readers
      Array(@server_output_readers).each do |reader|
        reader.kill if reader.alive?
      end
      Array(@server_output_readers).each { |reader| reader.join(SERVER_OUTPUT_THREAD_JOIN_TIMEOUT) }
    end

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def send_term_signal(pid)
      if @server_pgid && process_exists?(pid)
        Process.kill('TERM', -@server_pgid)
      else
        safe_kill_process('TERM', pid)
      end
    rescue Errno::ESRCH, Errno::EPERM => e
      CypressOnRails.configuration.logger.warn("Failed to kill process group #{@server_pgid}: #{e.message}, trying single process")
      safe_kill_process('TERM', pid)
    end

    def process_exists?(pid)
      return false unless pid
      Process.kill(0, pid)
      true
    rescue Errno::ESRCH, Errno::EPERM
      false
    end

    def safe_kill_process(signal, pid)
      Process.kill(signal, pid) if pid
    rescue Errno::ESRCH, Errno::EPERM
      # Process already terminated or permission denied
    end

    def base_url
      "http://#{host}:#{port}"
    end

    def open_command
      case framework
      when :cypress
        if command_exists?('yarn')
          ['yarn', 'cypress', 'open', '--project', install_folder, '--config', "baseUrl=#{base_url}"]
        elsif command_exists?('npx')
          ['npx', 'cypress', 'open', '--project', install_folder, '--config', "baseUrl=#{base_url}"]
        else
          ['cypress', 'open', '--project', install_folder, '--config', "baseUrl=#{base_url}"]
        end
      when :playwright
        if command_exists?('yarn')
          ['yarn', 'playwright', 'test', '--ui']
        elsif command_exists?('npx')
          ['npx', 'playwright', 'test', '--ui']
        else
          ['playwright', 'test', '--ui']
        end
      end
    end

    def run_command_args
      case framework
      when :cypress
        if command_exists?('yarn')
          ['yarn', 'cypress', 'run', '--project', install_folder, '--config', "baseUrl=#{base_url}"]
        elsif command_exists?('npx')
          ['npx', 'cypress', 'run', '--project', install_folder, '--config', "baseUrl=#{base_url}"]
        else
          ['cypress', 'run', '--project', install_folder, '--config', "baseUrl=#{base_url}"]
        end
      when :playwright
        if command_exists?('yarn')
          ['yarn', 'playwright', 'test']
        elsif command_exists?('npx')
          ['npx', 'playwright', 'test']
        else
          ['playwright', 'test']
        end
      end
    end

    def run_command(command_args, description)
      puts "#{description}: #{command_args.join(' ')}"
      system(*command_args)
    end

    def command_exists?(command)
      system("which #{command} > /dev/null 2>&1")
    end

    def run_hook(hook)
      if hook && hook.respond_to?(:call)
        hook.call
      end
    end
  end
end
