# frozen_string_literal: true

RSpec.describe FastMcp::Transports::StdioTransport do
  let(:logger_output) { StringIO.new }
  let(:logger) { Logger.new(logger_output) }
  let(:server) { instance_double(FastMcp::Server, logger: logger, handle_request: nil) }
  let(:stdin_mock) { StringIO.new }
  let(:stdout_mock) { StringIO.new }
  let(:stderr_mock) { StringIO.new }
  let(:io_handler) { FastMcp::IOHandler.new(input: stdin_mock, output: stdout_mock, error: stderr_mock) }
  let(:transport) { described_class.new(server, logger: logger, io_handler: io_handler) }

  before do
    allow(Signal).to receive(:trap)
  end

  describe '#initialize' do
    it 'initializes with server and logger' do
      expect(transport.server).to eq(server)
      expect(transport.logger).to eq(logger)
    end
    
    it 'accepts custom IOHandler' do
      expect(transport.io_handler).to eq(io_handler)
    end
    
    it 'creates default IOHandler when not provided' do
      default_transport = described_class.new(server, logger: logger)
      expect(default_transport.io_handler).to be_a(FastMcp::IOHandler)
    end

    it 'initializes running state to false' do
      expect(transport.running?).to be(false)
    end

    it 'initializes mutex for thread safety' do
      expect(transport.instance_variable_get(:@mutex)).to be_a(Mutex)
    end
  end

  describe '#start' do
    it 'logs startup message' do
      logger.level = Logger::INFO
      
      # Stop the transport immediately to prevent blocking
      allow(transport).to receive(:running?).and_return(false)
      transport.start
      
      expect(logger_output.string).to include('Starting STDIO transport')
    end

    it 'sets running state to true' do
      allow(transport).to receive(:running?).and_return(false, true)
      transport.start
      expect(transport.running?).to be(true)
    end

    it 'processes messages from stdin' do
      message = '{"jsonrpc": "2.0", "method": "test"}'
      stdin_mock.puts(message)
      stdin_mock.rewind
      
      expect(transport).to receive(:process_message).with(message)
      
      # Stop after processing one message
      allow(transport).to receive(:running?).and_return(true, false)
      transport.start
    end

    it 'handles errors during message processing' do
      logger.level = Logger::ERROR
      message = '{"jsonrpc": "2.0", "method": "test"}'
      stdin_mock.puts(message)
      stdin_mock.rewind
      
      error = StandardError.new('Processing error')
      allow(transport).to receive(:process_message).and_raise(error)
      expect(transport).to receive(:send_error).with(-32_000, 'Internal error: Processing error')
      
      allow(transport).to receive(:running?).and_return(true, false)
      transport.start
      
      # Verify error messages were logged
      expect(logger_output.string).to include('Error processing message: Processing error')
      expect(logger_output.string).to include(error.backtrace.first || 'backtrace')
    end
  end

  describe '#stop' do
    it 'logs stop message' do
      logger.level = Logger::INFO
      transport.stop
      
      expect(logger_output.string).to include('Stopping STDIO transport')
    end

    it 'sets running state to false' do
      transport.instance_variable_set(:@running, true)
      transport.stop
      expect(transport.running?).to be(false)
    end

    it 'closes IO handler' do
      expect(io_handler).to receive(:close)
      transport.stop
    end
    
    it 'can be called multiple times safely' do
      logger.level = Logger::INFO
      
      # First stop
      transport.instance_variable_set(:@running, true)
      transport.stop
      expect(transport.running?).to be(false)
      
      # Clear the logger output
      logger_output.truncate(0)
      logger_output.rewind
      
      # Second stop should still work without errors
      expect { transport.stop }.not_to raise_error
      expect(transport.running?).to be(false)
      expect(logger_output.string).to include('Stopping STDIO transport')
    end
  end

  describe '#send_message' do
    context 'when transport is running' do
      before do
        transport.instance_variable_set(:@running, true)
      end

      it 'sends JSON message to output' do
        message = { 'jsonrpc' => '2.0', 'result' => 'test' }
        transport.send_message(message)
        
        stdout_mock.rewind
        expect(stdout_mock.read).to eq(JSON.generate(message) + "\n")
      end

      it 'sends string message directly to output' do
        message = '{"jsonrpc": "2.0", "result": "test"}'
        transport.send_message(message)
        
        stdout_mock.rewind
        expect(stdout_mock.read).to eq(message + "\n")
      end

      it 'uses mutex for thread safety' do
        mutex = transport.instance_variable_get(:@mutex)
        expect(mutex).to receive(:synchronize).at_least(:once).and_call_original
        transport.send_message('test')
      end
    end

    context 'when transport is not running' do
      before do
        transport.instance_variable_set(:@running, false)
      end

      it 'returns early without sending message' do
        transport.send_message('test')
        stdout_mock.rewind
        expect(stdout_mock.read).to be_empty
      end

      it 'checks running state with mutex synchronization' do
        mutex = transport.instance_variable_get(:@mutex)
        expect(mutex).to receive(:synchronize).at_least(:once).and_call_original
        transport.send_message('test')
      end
    end

    context 'thread safety' do
      it 'prevents concurrent writes using mutex' do
        transport.instance_variable_set(:@running, true)
        
        threads = []
        messages = []
        
        10.times do |i|
          threads << Thread.new do
            transport.send_message({ 'id' => i })
            messages << i
          end
        end
        
        threads.each(&:join)
        
        # All messages should have been sent
        expect(messages.size).to eq(10)
        
        # Check that all messages are in output
        stdout_mock.rewind
        output_lines = stdout_mock.read.split("\n")
        expect(output_lines.size).to eq(10)
      end
    end
  end

  describe '#running?' do
    it 'returns running state' do
      transport.instance_variable_set(:@running, false)
      expect(transport.running?).to be(false)
      
      transport.instance_variable_set(:@running, true)
      expect(transport.running?).to be(true)
    end

    it 'uses mutex for thread-safe access' do
      mutex = transport.instance_variable_get(:@mutex)
      expect(mutex).to receive(:synchronize).and_call_original
      transport.running?
    end

    context 'thread safety' do
      it 'provides consistent state across concurrent reads' do
        transport.instance_variable_set(:@running, true)
        
        results = []
        threads = []
        
        20.times do
          threads << Thread.new do
            results << transport.running?
          end
        end
        
        threads.each(&:join)
        
        # All reads should return the same value
        expect(results.all? { |r| r == true }).to be(true)
      end
    end
  end

  describe '#send_error' do
    before do
      transport.instance_variable_set(:@running, true)
    end

    it 'sends JSON-RPC error response' do
      transport.send(:send_error, -32700, 'Parse error', 1)
      
      stdout_mock.rewind
      response = JSON.parse(stdout_mock.read)
      
      expect(response['jsonrpc']).to eq('2.0')
      expect(response['error']['code']).to eq(-32700)
      expect(response['error']['message']).to eq('Parse error')
      expect(response['id']).to eq(1)
    end

    it 'handles nil id' do
      transport.send(:send_error, -32600, 'Invalid Request', nil)
      
      stdout_mock.rewind
      response = JSON.parse(stdout_mock.read)
      
      expect(response['id']).to be_nil
    end
  end

  describe 'integration with BaseTransport' do
    it 'inherits from BaseTransport' do
      expect(described_class.superclass).to eq(FastMcp::Transports::BaseTransport)
    end

    it 'properly overrides abstract methods' do
      # All abstract methods should be implemented
      expect(transport).to respond_to(:start)
      expect(transport).to respond_to(:stop)
      expect(transport).to respond_to(:send_message)
      
      # Should not raise NotImplementedError
      expect { transport.stop }.not_to raise_error
      # Note: start would block on stdin, so we don't test it here
    end
  end
end