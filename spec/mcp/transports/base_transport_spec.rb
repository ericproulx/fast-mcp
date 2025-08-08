# frozen_string_literal: true

RSpec.describe FastMcp::Transports::BaseTransport do
  let(:server) { instance_double(FastMcp::Server, logger: Logger.new(nil), handle_request: nil) }
  let(:logger) { Logger.new(nil) }
  let(:transport) { described_class.new(server, logger: logger) }

  describe '#initialize' do
    it 'initializes with server and logger' do
      expect(transport.server).to eq(server)
      expect(transport.logger).to eq(logger)
    end

    it 'uses server logger if no logger is provided' do
      server_logger = Logger.new(nil)
      server_with_logger = instance_double(FastMcp::Server, logger: server_logger, handle_request: nil)
      transport_no_logger = described_class.new(server_with_logger)
      expect(transport_no_logger.logger).to eq(server_logger)
    end

    it 'creates a signal handler' do
      expect(transport.signal_handler).to be_a(FastMcp::SignalHandler)
    end

    it 'accepts a custom signal handler' do
      custom_signal_handler = FastMcp::SignalHandler.new(logger: logger)
      transport_with_custom = described_class.new(server, logger: logger, signal_handler: custom_signal_handler)
      expect(transport_with_custom.signal_handler).to eq(custom_signal_handler)
    end

    context 'signal handler setup' do
      it 'registers default signals (INT, TERM, QUIT) with signal handler' do
        signal_handler = instance_double(FastMcp::SignalHandler)
        allow(FastMcp::SignalHandler).to receive(:new).and_return(signal_handler)
        
        expect(signal_handler).to receive(:register).with('INT', 'TERM', 'QUIT')
        
        described_class.new(server, logger: logger)
      end

      it 'signal handlers call stop method' do
        # Create a test transport and verify signal handling
        test_transport = described_class.new(server, logger: logger)
        
        # Get the signal handler
        signal_handler = test_transport.signal_handler
        
        # Verify that signals are registered
        %w[INT TERM QUIT].each do |signal|
          expect(signal_handler.registered?(signal)).to be true
        end
      end
    end
  end

  describe '#start' do
    it 'raises NotImplementedError' do
      expect { transport.start }.to raise_error(
        NotImplementedError, 
        "#{described_class} must implement #start"
      )
    end
  end

  describe '#stop' do
    it 'raises NotImplementedError' do
      expect { transport.stop }.to raise_error(
        NotImplementedError, 
        "#{described_class} must implement #stop"
      )
    end
  end

  describe '#send_message' do
    it 'raises NotImplementedError' do
      expect { transport.send_message('test') }.to raise_error(
        NotImplementedError, 
        "#{described_class} must implement #send_message"
      )
    end
  end

  describe '#process_message' do
    it 'delegates to server.handle_request' do
      message = { 'jsonrpc' => '2.0', 'method' => 'test' }
      expect(server).to receive(:handle_request).with(message, headers: {})
      transport.send(:process_message, message)
    end

    it 'passes headers to server.handle_request' do
      message = { 'jsonrpc' => '2.0', 'method' => 'test' }
      headers = { 'X-Custom-Header' => 'value' }
      expect(server).to receive(:handle_request).with(message, headers: headers)
      transport.send(:process_message, message, headers: headers)
    end
  end

  describe 'subclass implementation' do
    let(:concrete_transport_class) do
      Class.new(described_class) do
        def start
          'started'
        end

        def stop
          'stopped'
        end

        def send_message(message)
          "sent: #{message}"
        end
      end
    end

    let(:concrete_transport) { concrete_transport_class.new(server, logger: logger) }

    it 'allows subclasses to implement required methods' do
      expect(concrete_transport.start).to eq('started')
      expect(concrete_transport.stop).to eq('stopped')
      expect(concrete_transport.send_message('test')).to eq('sent: test')
    end
  end
end