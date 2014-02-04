require 'logger'

module Amber

  def self.logger
    @logger ||= begin
      logger = Logger.new(STDOUT)
      logger.level = Logger::INFO
      logger.formatter = proc do |severity, datetime, progname, msg|
        "#{severity}: #{msg}\n"
      end
      logger
    end
  end

  def self.log_exception(e)
    @logger.error(e)
    @logger.error(e.backtrace.join("\n       "))
  end

end
