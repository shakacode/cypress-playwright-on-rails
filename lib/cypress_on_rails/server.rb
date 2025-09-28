require 'socket'
require 'timeout'
require 'fileutils'
require 'cypress_on_rails/configuration'

module CypressOnRails
  class Server
    attr_reader :host, :port, :framework, :install_folder

    def initialize(options = {})
      config = CypressOnRails.configuration
      
      @framework = options[:framework] || :cypress
      @host = options[:host] || config.server_host
      @port = options[:port] || config.server_port || find_available_port
      @port = @port.to_i if @port
      @install_folder = options[:install_folder] || config.install_folder || detect_install_folder
      @transactional = options.fetch(:transactional, config.transactional_server)
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
      ENV['RAILS_ENV'] = 'test'
      
      server_pid = spawn_server
      
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

      spawn(*server_args, out: $stdout, err: $stderr)
    end

    def wait_for_server(timeout = 30)
      Timeout.timeout(timeout) do
        loop do
          begin
            TCPSocket.new(host, port).close
            break
          rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
            sleep 0.1
          end
        end
      end
    rescue Timeout::Error
      raise "Rails server failed to start on #{host}:#{port} after #{timeout} seconds"
    end

    def stop_server(pid)
      if pid
        puts "Stopping Rails server (PID: #{pid})"
        Process.kill('TERM', pid)
        Process.wait(pid)
      end
    rescue Errno::ESRCH
      # Process already terminated
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