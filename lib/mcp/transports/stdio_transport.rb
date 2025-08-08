# frozen_string_literal: true

require_relative 'base_transport'
require_relative '../io_handler'

module FastMcp
  module Transports
    # STDIO transport for MCP
    # This transport uses standard input/output for communication
    class StdioTransport < BaseTransport
      attr_reader :io_handler

      def initialize(server, logger: nil, signal_handler: nil, io_handler: nil)
        super(server, logger: logger, signal_handler: signal_handler)
        @running = false
        @io_handler = io_handler || IOHandler.new
        @mutex = Mutex.new
      end

      # Start the transport
      def start
        @logger.info('Starting STDIO transport')
        @running = true

        # Process input from stdin
        while running? && (line = @io_handler.gets)
          begin
            process_message(line.strip)
          rescue StandardError => e
            @logger.error("Error processing message: #{e.message}")
            @logger.error(e.backtrace.join("\n")) if e.backtrace.any?
            send_error(-32_000, "Internal error: #{e.message}")
          end
        end
      end

      # Stop the transport
      def stop
        @logger.info('Stopping STDIO transport')
        @running = false
        @io_handler.close
      end

      # Send a message to the client
      def send_message(message)
        @mutex.synchronize do
          return unless @running

          json_message = message.is_a?(String) ? message : JSON.generate(message)
          @io_handler.write(json_message)
        end
      end

      # Thread-safe check if the transport is running
      def running?
        @mutex.synchronize { @running }
      end

      private

      # Send a JSON-RPC error response
      def send_error(code, message, id = nil)
        response = {
          jsonrpc: '2.0',
          error: {
            code: code,
            message: message
          },
          id: id
        }
        send_message(response)
      end
    end
  end
end
