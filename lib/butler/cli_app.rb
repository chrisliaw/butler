

module Butler
  class CliApp
    include Alog
    
    def initialize(args, &block)
      @expected_status = 0
      # last hash is constructed by the system so should be there always
      params = args[-1]
      if params[:working_dir] != nil
        @working_dir = File.expand_path(params[:working_dir])
      else
        @working_dir = File.expand_path(Dir.getwd)
      end
      @output = params[:output]
      @errOut = params[:errOut]
      @engine = params[:engine]
      @logger = params[:logger]
      @job = params[:job]
      @ignoreStatus = params[:ignore_status] || true

      @userParams = args[0..-2] # ignore the last one
      
    end   

    def invoke_method(&block)
      # support one line invocation 
      if @userParams != nil and @userParams.size > 0
        if self.respond_to?(@userParams[0])
          args = @userParams[1..-1]
          args = [] if args == nil
          self.send(@userParams[0], *args, &block) 
        end
      end
    end

    def parse_block(&block)
      instance_eval(&block) if block
    end

    def success?(code)
      code.to_i == @expected_status.to_i
    end

    def assist
      @output.puts "This app developer did not provide any assistance to you. Sorry..."
    end
    # 
    # construct final command prefix with working dir
    # 
    def with_working_dir(cmd, &block)
      ccmd = []
      if @working_dir != nil and not @working_dir.empty?
        ccmd << "cd #{@working_dir}"
      end
      ccmd << cmd

      if block
        block.call(ccmd.join(" && "))
      end 
    end
    # end with_working_dir()
    # 
  
    def assess_status(st, &block)
      #if block
      #  block.call(:error_status, { current: st,  expected: @expected_status })
      #else
      if not @ignoreStatus and not success?(st)
        msg = block(:msg) if block
        msg = "Cli app return status code : #{st}" if msg == nil or msg.empty?
        raise JobExecutionException, msg
      end
      #end
    end

    def method_missing(mtd, *args, &block)
      if @job != nil and @job.respond_to?(mtd.to_sym)
        @job.send(mtd, *args, &block)
      elsif @engine != nil and @engine.respond_to?(mtd.to_sym)
        @engine.send(mtd, *args, &block)
      else
        super
      end      
    end
    # end method_missing()
    #
  
  end
  # end class CliApp
  #

end
