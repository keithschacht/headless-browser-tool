# frozen_string_literal: true

require "logger"
require "fileutils"
require_relative "directory_setup"

module HeadlessBrowserTool
  class Logger
    class << self
      attr_accessor :log

      def initialize_logger(mode: :http)
        @log = if mode == :stdio
                 # In stdio mode, write to log file
                 DirectorySetup.setup_directories(include_logs: true)
                 log_file = File.join(DirectorySetup::LOGS_DIR, "#{Process.pid}.log")
                 ::Logger.new(log_file, progname: "HBT")
               else
                 # In HTTP mode, write to stdout
                 ::Logger.new($stdout, progname: "HBT")
               end

        @log.level = ENV["HBT_LOG_LEVEL"] ? ::Logger.const_get(ENV["HBT_LOG_LEVEL"]) : ::Logger::INFO
        @log
      end

      # Keep instance as an alias for backward compatibility
      def instance
        @log
      end
    end
  end
end
