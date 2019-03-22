

module Butler
  class CliApp
    include Alog
    
    def initialize(*args)
      @expected_status = 0
      params = args[-1]
      @working_dir = params[:working_dir]
      @output = params[:output]
      @errOut = params[:errOut]
      @engine = params[:engine]
      @logger = params[:logger]
    end   

    def parse_block(&block)
      instance_eval(&block) if block
    end

    def success?(code)
      code.to_i == @expected_status.to_i
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
  
  end
  # end class CliApp
  #

end
