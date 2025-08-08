# frozen_string_literal: true

require 'spec_helper'
require 'mcp/signal_handler'

RSpec.describe FastMcp::SignalHandler do
  let(:logger_output) { StringIO.new }
  let(:logger) { Logger.new(logger_output) }
  let(:signal_handler) { described_class.new(logger: logger) }

  describe '#initialize' do
    it 'initializes with a logger' do
      expect(signal_handler).to be_a(described_class)
    end

    it 'creates a default logger if none provided' do
      handler = described_class.new
      expect(handler).to be_a(described_class)
    end
  end

  describe '#register' do
    it 'registers a single signal with a callback' do
      callback_called = false
      signal_handler.register('USR1') { callback_called = true }
      
      expect(signal_handler.registered?('USR1')).to be true
      
      # Clean up
      signal_handler.clear
    end

    it 'registers multiple signals with a callback' do
      callback_called = false
      signal_handler.register('USR1', 'USR2') { callback_called = true }
      
      expect(signal_handler.registered?('USR1')).to be true
      expect(signal_handler.registered?('USR2')).to be true
      
      # Clean up
      signal_handler.clear
    end

    it 'allows multiple callbacks for the same signal' do
      counter = 0
      signal_handler.register('USR1') { counter += 1 }
      signal_handler.register('USR1') { counter += 2 }
      
      expect(signal_handler.registered?('USR1')).to be true
      
      # Clean up
      signal_handler.clear
    end

    it 'handles invalid signal names gracefully' do
      logger.level = Logger::WARN
      
      signal_handler.register('INVALID_SIGNAL') { puts 'test' }
      
      expect(logger_output.string).to include('Failed to set up signal handler')
    end
  end

  describe '#registered?' do
    it 'returns false for unregistered signals' do
      expect(signal_handler.registered?('USR1')).to be false
    end

    it 'returns true for registered signals' do
      signal_handler.register('USR1') { puts 'test' }
      expect(signal_handler.registered?('USR1')).to be true
      
      # Clean up
      signal_handler.clear
    end
  end

  describe '#clear' do
    it 'removes all registered signal handlers' do
      signal_handler.register('USR1', 'USR2') { puts 'test' }
      
      expect(signal_handler.registered?('USR1')).to be true
      expect(signal_handler.registered?('USR2')).to be true
      
      signal_handler.clear
      
      expect(signal_handler.registered?('USR1')).to be false
      expect(signal_handler.registered?('USR2')).to be false
    end

    it 'resets signal traps to default' do
      signal_handler.register('USR1') { puts 'test' }
      
      expect(Signal).to receive(:trap).with('USR1', 'DEFAULT')
      signal_handler.clear
    end

    it 'handles errors when resetting signals' do
      logger.level = Logger::WARN
      signal_handler.register('USR1') { puts 'test' }
      
      allow(Signal).to receive(:trap).and_raise(ArgumentError, 'test error')
      
      signal_handler.clear
      
      expect(logger_output.string).to include('Failed to reset signal')
      expect(logger_output.string).to include('test error')
    end
  end

  describe 'signal handling' do
    it 'executes callbacks when signal is received' do
      callback_executed = false
      
      # Capture the trap block when it's set
      allow(Signal).to receive(:trap).with('USR1') do |&block|
        # Execute the block immediately to simulate signal reception
        block.call if block
      end
      
      signal_handler.register('USR1') { callback_executed = true }
      
      expect(callback_executed).to be true
      
      # Clean up
      allow(Signal).to receive(:trap).with('USR1', 'DEFAULT')
      signal_handler.clear
    end

    it 'handles errors in callbacks gracefully' do
      logger.level = Logger::ERROR
      
      # Capture the trap block and execute it
      allow(Signal).to receive(:trap).with('USR1') do |&block|
        block.call if block
      end
      
      signal_handler.register('USR1') { raise 'Test error' }
      
      expect(logger_output.string).to include('Error executing callback')
      expect(logger_output.string).to include('Test error')
      
      # Clean up
      allow(Signal).to receive(:trap).with('USR1', 'DEFAULT')
      signal_handler.clear
    end

    it 'executes multiple callbacks in order' do
      results = []
      
      # Mock Signal.trap to capture and immediately execute the block
      trap_count = 0
      allow(Signal).to receive(:trap).with('USR1') do |&block|
        trap_count += 1
        # Only execute the block after all callbacks are registered
        if trap_count == 1 && block
          # Let the first trap be set up without executing
          nil
        end
      end
      
      # Register multiple callbacks
      signal_handler.register('USR1') { results << 1 }
      signal_handler.register('USR1') { results << 2 }
      signal_handler.register('USR1') { results << 3 }
      
      # Manually trigger the signal to test callback execution
      # Access the private method to simulate signal reception
      signal_handler.send(:execute_callbacks, 'USR1')
      
      # All three callbacks should have been executed in order
      expect(results).to eq([1, 2, 3])
      
      # Clean up
      allow(Signal).to receive(:trap).with('USR1', 'DEFAULT')
      signal_handler.clear
    end
  end
end