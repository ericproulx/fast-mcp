# frozen_string_literal: true

require 'logger'

module FastMcp
  # Handles signal trapping and management for graceful shutdowns
  class SignalHandler
    def initialize(logger: nil)
      @logger = logger || ::Logger.new($stderr)
      @callbacks = Hash.new { |h, k| h[k] = [] }
      @trapped_signals = []
    end

    # Register signals with a callback
    # @param signals [Array<String>, String] Signal names to trap (e.g., 'INT', 'TERM', 'QUIT')
    # @param callback [Proc] The callback to execute when signal is received
    def register(*signals, &callback)
      signals.each do |signal|
        # Store the callback
        @callbacks[signal] << callback

        # Set up the trap if not already done
        setup_trap(signal) unless @trapped_signals.include?(signal)
      end
    end

    # Remove all signal handlers
    def clear
      @trapped_signals.each do |signal|
        Signal.trap(signal, 'DEFAULT')
      rescue ArgumentError => e
        @logger.warn("Failed to reset signal #{signal}: #{e.message}")
      end

      @trapped_signals.clear
      @callbacks.clear
    end

    # Check if a signal has handlers registered
    def registered?(signal)
      @callbacks.key?(signal) && !@callbacks[signal].empty?
    end

    private

    def setup_trap(signal)
      Signal.trap(signal) do
        @logger.info("Received #{signal} signal")
        execute_callbacks(signal)
      end
      @trapped_signals << signal
      @logger.debug("Set up signal handler for #{signal}")
    rescue ArgumentError => e
      @logger.warn("Failed to set up signal handler for #{signal}: #{e.message}")
    end

    def execute_callbacks(signal)
      return unless @callbacks[signal]

      @callbacks[signal].each do |callback|
        callback.call
      rescue StandardError => e
        @logger.error("Error executing callback for signal #{signal}: #{e.message}")
      end
    end
  end
end
