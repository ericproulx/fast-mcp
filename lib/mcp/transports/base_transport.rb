# frozen_string_literal: true

require_relative '../signal_handler'

module FastMcp
  module Transports
    # Base class for all MCP transports
    # This defines the interface that all transports must implement
    class BaseTransport
      attr_reader :server, :logger, :signal_handler

      def initialize(server, logger: nil, signal_handler: nil)
        @server = server
        @logger = logger || server.logger
        @signal_handler = signal_handler || FastMcp::SignalHandler.new(logger: @logger)
        setup_signal_handlers
      end

      # Start the transport
      # This method should be implemented by subclasses
      def start
        raise NotImplementedError, "#{self.class} must implement #start"
      end

      # Stop the transport
      # This method should be implemented by subclasses
      def stop
        raise NotImplementedError, "#{self.class} must implement #stop"
      end

      # Send a message to the client
      # This method should be implemented by subclasses
      def send_message(message)
        raise NotImplementedError, "#{self.class} must implement #send_message"
      end

      # Process an incoming message
      # This is a helper method that can be used by subclasses
      def process_message(message, headers: {})
        server.handle_request(message, headers: headers)
      end

      private

      def setup_signal_handlers
        @signal_handler.register('INT', 'TERM', 'QUIT') { stop }
      end
    end
  end
end
