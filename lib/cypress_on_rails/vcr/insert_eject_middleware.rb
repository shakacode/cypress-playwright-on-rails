require_relative 'base_middleware'

module CypressOnRails
  module Vcr
    # Middleware to handle vcr with insert/eject endpoints
    class InsertEjectMiddleware < BaseMiddleware
      def initialize(app, vcr = nil)
        @app = app
        @vcr = vcr
        @first_call = false
      end

      def call(env)
        request = Rack::Request.new(env)
        if request.path.start_with?('/__e2e__/vcr/insert')
          configuration.tagged_logged { handle_insert(request) }
        elsif request.path.start_with?('/__e2e__/vcr/eject')
          configuration.tagged_logged { handle_eject }
        else
          do_first_call unless @first_call
          @app.call(env)
        end
      end

      private

      def handle_insert(req)
        WebMock.enable! if defined?(WebMock)
        vcr.turn_on!
        body = parse_request_body(req)
        logger.info "vcr insert cassette: #{body}"
        cassette_name, options = extract_cassette_info(body)
        vcr.insert_cassette(cassette_name, options)
        [201, { 'Content-Type' => 'application/json' }, [{ 'message': 'OK' }.to_json]]
      rescue LoadError, ArgumentError => e
        [501, { 'Content-Type' => 'application/json' }, [{ 'message': e.message }.to_json]]
      end

      def parse_request_body(req)
        JSON.parse(req.body.read)
      end

      def extract_cassette_info(body)
        cassette_name = body[0]
        options = (body[1] || {}).symbolize_keys
        options[:record] = options[:record].to_sym if options[:record]
        options[:match_requests_on] = options[:match_requests_on].map(&:to_sym) if options[:match_requests_on]
        options[:serialize_with] = options[:serialize_with].to_sym if options[:serialize_with]
        options[:persist_with] = options[:persist_with].to_sym if options[:persist_with]
        [cassette_name, options]
      end

      def handle_eject
        logger.info 'vcr eject cassette'
        vcr.eject_cassette
        do_first_call
        [201, { 'Content-Type' => 'application/json' }, [{ 'message': 'OK' }.to_json]]
      rescue LoadError, ArgumentError => e
        [501, { 'Content-Type' => 'application/json' }, [{ 'message': e.message }.to_json]]
      end

      def do_first_call
        @first_call = true
        vcr.turn_off!
        WebMock.disable! if defined?(WebMock)
      rescue LoadError
        # nop
      end
    end
  end
end
