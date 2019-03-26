
Dir[File.join(File.dirname(__FILE__),"app","*.rb")].each do |d|
  require d
end

require "active_support/core_ext/string"
require 'tty/prompt'
require "colorize"

module Butler
  class Job
    include Alog
    attr_reader :title
    # first param is always the title
    # 2nd param is going to be a hash
    def initialize(title, args)
      @title = title
      params = args 
      @output = params[:output] || STDOUT
      @errOut = params[:error] || STDERR
      @engine = params[:engine]
    end

    def parse_block(&block)
      start = Time.now
      
      if block
        instance_eval(&block)
      end

      @output.puts "\nJob '#{@title}' is completed. (#{Time.now-start} s) ".green
    end

    def dir(path)
      @working_dir = path
    end

    def prompt(msg, params = { required: true }, &block)
      tty = TTY::Prompt.new
      sel = tty.ask(msg) do |q|
        req = params[:required] || false
        q.required params[:required] 
      end
      
      if block
        block.call(sel)
      else
        sel
      end

    end
    # end prompt()
    # 

    def method_missing(mtd, *args, &block)
      clog "method_missing #{mtd} / #{args}", :debug, :job
      if mtd[-1] != '='
        begin

          params = {}
          params[:working_dir] = @working_dir
          params[:output] = @output
          params[:errOut] = @errOut
          params[:engine] = @engine
          params[:job] = self
          
          args << params

          obj = mtd
          #mm = mtd.to_s.split("_")
          #obj = mm[0]  

          clog "Creating Butler::#{obj.to_s.classify}", :debug, :job
          handler = eval("Butler::#{obj.to_s.classify}.new(args, &block)")
          clog "handler is #{handler}", :debug, :job
          
          #if mm.length > 1
          #  handler.send(mm[1], *args, &block)
          #end
          
          if block
            clog "#{handler} parse_block", :debug, :job
            handler.parse_block(&block)
          end
          
        rescue TTY::Reader::InputInterrupt
          @output.puts "\nJob aborted.".yellow
          exit(-1)
        rescue JobExecutionException => ex
          @errOut.puts "#{NL}Job title '#{title}' halt due to execution of work item. Actual work item error was:".red
          @errOut.puts "  #{ex.message}#{NL}".red
          clog ex.message, :error
          exit(-1)
        rescue NameError
          # try on engine
          if self.respond_to?(mtd.to_sym)
            clog "Job able to handle #{mtd}. Handle by job.", :debug, :job
            self.send(mtd, *args, &block)
          elsif @engine.respond_to?(mtd.to_sym)
            clog "Engine able to handle #{mtd}. Redirect to engine.", :debug, :job
            @engine.send(mtd,*args,&block)
          else
            raise
          end
        rescue Exception => ex
          @errOut.puts "#{NL}Job title '#{title}' halt due to exception! Actual error was:".red
          @errOut.puts "  #{ex.message}#{NL}".red
          @errOut.puts ex.backtrace.join(NL).red
          clog ex.message, :error
          exit(-10)
        end
      else
        super
      end
    end

  end
end
