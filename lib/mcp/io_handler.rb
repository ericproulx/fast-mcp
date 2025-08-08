# frozen_string_literal: true

require 'logger'

module FastMcp
  # Handles IO operations for transports
  # Provides a configurable interface for input/output streams
  class IOHandler
    attr_reader :input, :output, :error, :logger

    def initialize(input: $stdin, output: $stdout, error: $stderr, logger: nil)
      @input = input
      @output = output
      @error = error
      @logger = logger || ::Logger.new(nil)

      # Ensure streams are sync'd to avoid buffering issues
      @input.sync = true
      @output.sync = true
      @error.sync = true
    end

    # Read a line from input stream
    def gets
      @input.gets
    rescue IOError, Errno::EPIPE => e
      log_error(@input, e)
      nil
    end

    # Write a message to output stream with thread safety
    def write(message)
      io_write(@output, message)
    end

    # Write to error stream
    def write_error(message)
      io_write(@error, message)
    end

    # Close all streams
    def close
      close_streams(@input, @output, @error)
    end

    # Check if all streams are closed
    def closed?
      stream_closed?(@input) && stream_closed?(@output) && stream_closed?(@error)
    end

    private

    def close_streams(*streams)
      streams.each do |stream|
        stream.close unless stream.closed?
      end
    end

    def io_write(stream, message)
      stream.write("#{message}\n")
    rescue IOError, Errno::EPIPE => e
      log_error(stream, e)
    end

    def stream_closed?(stream)
      stream.closed?
    rescue NoMethodError
      false
    end

    def log_error(stream, exception)
      @logger.error { "IO Error on #{stream.class}: #{exception.message}" }
      @logger.error { exception.backtrace.join("\n") } if exception.backtrace&.any?
    end
  end
end
