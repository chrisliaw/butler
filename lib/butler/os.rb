
require 'rbconfig'
require 'logger'
require 'open3'

module Butler
  extend Alog
  
  # Proc for platform ExecCommand()
  PtySpawn = Proc.new do |cmd, params = { intBufSize: 1024, expect: {}, output: {}, log: nil } , &block|
    require 'pty'
    require 'expect'
    require 'io/console'
     
    expect = params[:expect]
    log = params[:log] || Logger.new(nil)
    bufSize = params[:intBufSize]

    if bufSize != nil and bufSize.to_i > 0
    else
      bufSize = 1024
    end

    clog "OS cmd: #{cmd}", :debug, :os_cmd

    PTY.spawn(cmd, 'env TERM=ansi') do |stdout, stdin, pid|

      stdin.sync = true

      begin
        loop do
          dat = []
          loop do
            # 19 March 2019
            # This read for some reasons read together with
            # all the coloring or terminal escape code...
            # Good to display but not good to be read by program
            # If output want to read by program can try the ExecCmdOnly() method
            d = stdout.sysread(bufSize)
            dat << d
            break if d.length < bufSize
          end
          dat = dat.join("\r\n")
          
          if block
            block.call(:inspect, { data: dat, output: stdout, input: stdin })
          end
          
        end
      rescue EOFError => ex
        #clog "EOF reached. Waiting to kill process.", :debug, :os_cmd
        Process.wait(pid)
        #clog "Processed killed.", :debug, :os_cmd
      rescue Exception => ex
        clog ex.message, :error, :os_cmd
        clog ex.backtrace.join("\n"), :error, :os_cmd
      end

    end
    # end PTY.spawn() method

    $?.exitstatus

  end
  # end ExexCommand() proc

  # ExecCmdOnly proc
  ExecCmdOnly = Proc.new do |cmd, params = {}, &block|
    clog "Open3 : #{cmd}", :debug, :os_cmd
    stdout, stderr, status = Open3.capture3(cmd)
    clog "Open3 status : #{status}", :debug, :os_cmd
    
    if block
      block.call(:inspect, { data: "", output: stdout, errout: stderr, status: status })
    end

    status
  end
  # end ExexCmdOnly proc

  NotImplYet = Proc.new do |*args|
    raise ButlerExcepion, "Not Implemented Yet"
  end

  # specific OS binding
  module Mac
    ExecCommandInt = PtySpawn  
    ExecCommand = ExecCmdOnly
    ClearConsole = Proc.new do
      system('clear')
    end
  end
  # end Mac binding

  module Windows
    ExecCommandInt = PtySpawn
    ExecCommand = ExecCmdOnly
  end
  # end Windows binding

  module Linux
    ExecCommandInt = PtySpawn
    ExecCommand = ExecCmdOnly
  end
  # end Linux binding
  # end specific os binding
    

  os = RbConfig::CONFIG['host_os']
  platform = RUBY_PLATFORM

  #if platform.downcase == "java"
  #else
    case os
    when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
      OS = Windows
    when /darwin|mac os/
      OS = Mac
    when /linux/
      OS = Linux
    when /solaris|bsd/
      OS = Linux
    else
      raise ButlerExcepion, "Unknown os: #{host_os.inspect}"
    end      
  #end

end
