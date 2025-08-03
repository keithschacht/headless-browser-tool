# frozen_string_literal: true

require "logger"
require "fileutils"
require_relative "directory_setup"

module HeadlessBrowserTool
  class Logger
    class << self
      attr_accessor :instance

      def initialize_logger(mode: :http)
        @instance = if mode == :stdio
                      # In stdio mode, write to log file
                      DirectorySetup.setup_directories(include_logs: true)
                      log_file = File.join(DirectorySetup::LOGS_DIR, "#{Process.pid}.log")
                      ::Logger.new(log_file, progname: "HBT")
                    else
                      # In HTTP mode, write to stdout
                      ::Logger.new($stdout, progname: "HBT")
                    end

        @instance.level = ::Logger::INFO
        @instance
      end

      def log
        @instance ||= initialize_logger
      end
    end
  end
end
