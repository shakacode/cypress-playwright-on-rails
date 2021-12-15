require 'json'
require 'rack'
require 'cypress_on_rails/middleware_config'
require 'cypress_on_rails/command_executor'
require 'cypress_on_rails/vcr_wrapper'

module CypressOnRails
  # Middleware to handle testing framework commands and eval
  class Middleware
    include MiddlewareConfig

    def initialize(app, command_executor = CommandExecutor, file = ::File)
      @app = app
      @command_executor = command_executor
      @file = file
    end

    def call(env)
      request = Rack::Request.new(env)
      if request.path.start_with?("#{configuration.api_prefix}/__e2e__/command")
        configuration.tagged_logged { handle_command(request) }
      elsif request.path.start_with?("#{configuration.api_prefix}/__cypress__/command")
        warn "/__cypress__/command is deprecated. Please use the install generator to use /__e2e__/command instead."
        configuration.tagged_logged { handle_command(request) }
      elsif defined?(VCR) && configuration.use_vcr
        VCRWrapper.new(app: @app, env: env).run_with_cassette 
      else
        @app.call(env)
      end
    end

    private

    Command = Struct.new(:name, :options, :install_folder) do
      # @return [Array<Cypress::Middleware::Command>]
      def self.from_body(body, configuration)
        if body.is_a?(Array)
          command_params = body
        else
          command_params = [body]
        end
        command_params.map do |params|
          new(params.fetch('name'), params['options'], configuration.install_folder)
        end
      end

      def file_path
        "#{install_folder}/app_commands/#{name}.rb"
      end
    end

    def handle_command(req)
      maybe_env = configuration.before_request.call(req)
      # Halt the middleware if an Rack Env was returned by `before_request`
      return maybe_env unless maybe_env.nil?

      req.body.rewind
      body = JSON.parse(req.body.read)
      logger.info "handle_command: #{body}"
      commands = Command.from_body(body, configuration)
      missing_command = commands.find {|command| !@file.exist?(command.file_path) }

      if missing_command.nil?
        begin
          results = commands.map { |command| @command_executor.perform(command.file_path, command.options) }

          begin
            output = results.to_json
          rescue NoMethodError
            output = {"message" => "Cannot convert to json"}.to_json
          end

          logger.debug "output: #{output}"
          [201, {'Content-Type' => 'application/json'}, [output]]
        rescue => e
          output = {"message" => e.message, "class" => e.class.to_s}.to_json
          [500, {'Content-Type' => 'application/json'}, [output]]
        end
      else
        output = {"message" => "could not find command file: #{missing_command.file_path}"}.to_json
        [404, {'Content-Type' => 'application/json'}, [output]]
      end
    end
  end
end
