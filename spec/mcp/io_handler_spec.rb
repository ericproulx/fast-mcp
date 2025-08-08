# frozen_string_literal: true

require 'spec_helper'
require 'mcp/io_handler'

RSpec.describe FastMcp::IOHandler do
  let(:input_stream) { StringIO.new }
  let(:output_stream) { StringIO.new }
  let(:error_stream) { StringIO.new }
  let(:io_handler) { described_class.new(input: input_stream, output: output_stream, error: error_stream) }

  describe '#initialize' do
    it 'accepts custom IO streams' do
      expect(io_handler.input).to eq(input_stream)
      expect(io_handler.output).to eq(output_stream)
      expect(io_handler.error).to eq(error_stream)
    end

    it 'defaults to standard streams when not provided' do
      default_handler = described_class.new
      expect(default_handler.input).to eq($stdin)
      expect(default_handler.output).to eq($stdout)
      expect(default_handler.error).to eq($stderr)
    end
  end

  describe '#gets' do
    it 'reads a line from input stream' do
      input_stream.puts('test line')
      input_stream.rewind
      
      expect(io_handler.gets).to eq("test line\n")
    end

    it 'returns nil at end of input' do
      expect(io_handler.gets).to be_nil
    end
    
    context 'error handling' do
      let(:logger_output) { StringIO.new }
      let(:logger) { Logger.new(logger_output) }
      let(:io_handler_with_logger) { described_class.new(input: input_stream, output: output_stream, error: error_stream, logger: logger) }
      
      it 'handles IOError gracefully' do
        allow(input_stream).to receive(:gets).and_raise(IOError, 'Stream closed')
        
        expect(io_handler_with_logger.gets).to be_nil
        expect(logger_output.string).to include('IO Error on StringIO')
        expect(logger_output.string).to include('Stream closed')
      end
      
      it 'handles Errno::EPIPE gracefully' do
        allow(input_stream).to receive(:gets).and_raise(Errno::EPIPE, 'Broken pipe')
        
        expect(io_handler_with_logger.gets).to be_nil
        expect(logger_output.string).to include('IO Error on StringIO')
        expect(logger_output.string).to include('Broken pipe')
      end
    end
  end

  describe '#write' do
    it 'writes message to output stream' do
      io_handler.write('test message')
      
      output_stream.rewind
      expect(output_stream.read).to eq("test message\n")
    end

    it 'is thread-safe' do
      messages = []
      threads = []
      
      10.times do |i|
        threads << Thread.new do
          io_handler.write("message #{i}")
          messages << i
        end
      end
      
      threads.each(&:join)
      
      output_stream.rewind
      lines = output_stream.read.split("\n")
      expect(lines.size).to eq(10)
      expect(messages.size).to eq(10)
    end
    
    context 'error handling' do
      let(:logger_output) { StringIO.new }
      let(:logger) { Logger.new(logger_output) }
      let(:io_handler_with_logger) { described_class.new(input: input_stream, output: output_stream, error: error_stream, logger: logger) }
      
      it 'handles IOError gracefully' do
        allow(output_stream).to receive(:write).and_raise(IOError, 'Stream closed')
        
        expect { io_handler_with_logger.write('test') }.not_to raise_error
        expect(logger_output.string).to include('IO Error on StringIO')
        expect(logger_output.string).to include('Stream closed')
      end
      
      it 'handles Errno::EPIPE gracefully' do
        allow(output_stream).to receive(:write).and_raise(Errno::EPIPE, 'Broken pipe')
        
        expect { io_handler_with_logger.write('test') }.not_to raise_error
        expect(logger_output.string).to include('IO Error on StringIO')
        expect(logger_output.string).to include('Broken pipe')
      end
    end
  end

  describe '#write_error' do
    it 'writes message to error stream' do
      io_handler.write_error('error message')
      
      error_stream.rewind
      expect(error_stream.read).to eq("error message\n")
    end

    context 'error handling' do
      let(:logger_output) { StringIO.new }
      let(:logger) { Logger.new(logger_output) }
      let(:io_handler_with_logger) { described_class.new(input: input_stream, output: output_stream, error: error_stream, logger: logger) }
      
      it 'handles IOError gracefully' do
        allow(error_stream).to receive(:write).and_raise(IOError, 'Stream closed')
        
        expect { io_handler_with_logger.write_error('error') }.not_to raise_error
        expect(logger_output.string).to include('IO Error on StringIO')
        expect(logger_output.string).to include('Stream closed')
      end
      
      it 'handles Errno::EPIPE gracefully' do
        allow(error_stream).to receive(:write).and_raise(Errno::EPIPE, 'Broken pipe')
        
        expect { io_handler_with_logger.write_error('error') }.not_to raise_error
        expect(logger_output.string).to include('IO Error on StringIO')
        expect(logger_output.string).to include('Broken pipe')
      end
    end
  end

  describe '#close' do
    it 'closes all streams' do
      io_handler.close
      
      expect(input_stream).to be_closed
      expect(output_stream).to be_closed
      expect(error_stream).to be_closed
    end

    it 'handles already closed streams without error' do
      input_stream.close
      output_stream.close
      error_stream.close
      
      expect { io_handler.close }.not_to raise_error
    end
  end

  describe '#closed?' do
    it 'returns false when streams are open' do
      expect(io_handler.closed?).to be(false)
    end

    it 'returns true when all streams are closed' do
      io_handler.close
      expect(io_handler.closed?).to be(true)
    end

    it 'returns false when only some streams are closed' do
      input_stream.close
      expect(io_handler.closed?).to be(false)
    end
  end
end