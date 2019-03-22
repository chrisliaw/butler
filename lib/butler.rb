
require 'alog'

if ENV['BUTLER_DEV']
require_relative "butler/version"
else
require "butler/version"
end

require_relative "butler/os"

require_relative "butler/engine"
require_relative "butler/cli_app"

module Butler
  extend Alog
  
  class ButlerException < StandardError; end
  class JobExecutionException < StandardError; end
  
  NL = "\r\n"

  Alog::LogFacts[:default] = [STDOUT] 
  
  #Alog::LogTag << :os_cmd
  #Alog::LogTag << :job

  WI_HEADER_COLOR = :yellow
  WI_DETAILS_COLOR = :blue
  

end


