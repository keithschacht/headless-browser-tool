# frozen_string_literal: true

require "net/http"
require "timeout"
require "socket"

module TestServerHelper
  # Use ports in the 55000-59999 range to avoid conflicts
  BASE_PORT = 55_000
  PORT_RANGE = 5000

  # Track allocated ports to prevent conflicts within the same process
  @allocated_ports = Set.new
  @port_mutex = Mutex.new
  @test_counter = 0

  class << self
    def allocate_port
      @port_mutex.synchronize do
        # Increment counter for each allocation
        @test_counter += 1

        # Debug output
        puts "Test counter: #{@test_counter}, Process: #{Process.pid}" if ENV["DEBUG_PORTS"]

        # Simple sequential allocation - each test gets the next port
        # This avoids conflicts between tests running in the same process
        base_offset = @test_counter * 10 # Space ports by 10 to allow for multiple ports per test

        # Find an available port starting from the base + offset
        10.times do |i|
          port = BASE_PORT + base_offset + i

          # Skip if we've already allocated this port
          next if @allocated_ports.include?(port)

          # Check if port is actually available
          begin
            server = TCPServer.new("localhost", port)
            server.close
            @allocated_ports.add(port)

            puts "Allocated port #{port} (test #{@test_counter})" if ENV["DEBUG_PORTS"]

            return port
          rescue Errno::EADDRINUSE
            # Port in use, try next one
            next
          end
        end

        # If we couldn't find a port in our range, fall back to random search
        100.times do
          port = BASE_PORT + rand(PORT_RANGE)
          next if @allocated_ports.include?(port)

          begin
            server = TCPServer.new("localhost", port)
            server.close
            @allocated_ports.add(port)
            return port
          rescue Errno::EADDRINUSE
            next
          end
        end

        raise "Could not find available port"
      end
    end

    def release_port(port)
      @port_mutex.synchronize do
        @allocated_ports.delete(port)
      end
    end

    def ensure_port_free(port)
      # Just check if port is free, don't kill processes

      TCPSocket.new("localhost", port).close
      raise "Port #{port} is already in use"
    rescue Errno::ECONNREFUSED
      # Port is free, good to go
    end

    def wait_for_server(host, port, timeout: 10, path: "/")
      start_time = Time.now
      last_error = nil

      while Time.now - start_time < timeout
        begin
          uri = URI("http://#{host}:#{port}#{path}")
          response = Net::HTTP.get_response(uri)
          return true if response.code.to_i < 500
        rescue StandardError => e
          last_error = e
          sleep 0.1
        end
      end

      raise "Server at #{host}:#{port} failed to start within #{timeout} seconds. Last error: #{last_error}"
    end

    def start_server_process(command, port:, wait: true)
      pid = spawn(command, out: "/dev/null", err: "/dev/null")

      wait_for_server("localhost", port) if wait

      pid
    end

    def stop_server_process(pid)
      return unless pid

      begin
        Process.kill("TERM", pid)
        # Give it a moment to clean up
        Timeout.timeout(5) do
          Process.wait(pid)
        end
      rescue Errno::ESRCH
        # Process already dead
      rescue Timeout::Error
        # Force kill if it doesn't stop gracefully
        Process.kill("KILL", pid)
        Process.wait(pid)
      end
    end
  end
end
