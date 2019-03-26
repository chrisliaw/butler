
require_relative "job"

module Butler
  class Engine

    GKEY_RELEASING_VERSION = :releasing_version
    
    attr_reader :jobs
    attr_accessor :gval
    def initialize(*args)
      @jobs = {}
      @gvar = {}
      @output = STDOUT
      @errOut = STDERR
      @logger = BLogger
      #@logger = Alog::AOlogger.new( { key: :butler_engine, logEng: [:default], active_tag: [:global, :butler_engine] }) 
      if args.length > 0
        params = args[0]
        @output = params[:output] if params[:output] != nil
        @errOut = params[:errOut] if params[:errOut] != nil
        @logger = params[:logger] if params[:logger] != nil
      end
    end

    def parse_file(path)
      if path != nil and File.exist?(path)
        @logger.debug "Parsing file : #{path}"
        cont = File.read(path)
        instance_eval(cont)
      end
    end

    def parse_string(str)
      if str != nil and not str.empty?

        st = []
        st << "job :cli do "
        st << str
        st << "end"
        st << "start_job :cli"
        
        #@logger.debug "Parsing string: #{st.join("\r\n")}"
        
        begin
          instance_eval(st.join("\r\n"))
        rescue Exception => ex
          #@errOut.puts ex.message
          #@logger.ext_error(ex)
        end
      end
    end
    
    def set(key, val, params = {})
      @gvar[key] = val if key != nil
    end

    def get(key, params = {})
      @gvar[key]
    end

    def job(*args, &block)
     
      params = {}
      params[:engine] = self
      params[:output] = @output
      params[:errOut] = @errOut
      params[:logger] = @logger
      args << params
      
      j = Job.new(*args)
      @jobs[j.title] = [j, block]
      @logger.debug "Register job #{j.title}"
      
      #j.parse_block(&block)
    end

    def start_job(title)
      title = title.to_sym
      if @jobs.keys.include?(title)
        @logger.debug "Starting job #{title}"
        job = @jobs[title]
        job[0].parse_block(&job[1])
      else
        raise JobExecutionException, "Job with title '#{title}' not found"
      end
    end

    def include_job(*args, &block)
      title = args[0]
      start_job(title)
    end

  end
end
