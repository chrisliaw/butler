
require_relative "job"

module Butler
  class Engine
    attr_reader :jobs
    def initialize(*args)
      @jobs = {}
      @output = STDOUT
      @errOut = STDERR
      if args.length > 0
        params = args[0]
        @output = params[:output] if params[:output] != nil
        @errOut = params[:errOut] if params[:errOut] != nil
      end
    end

    def parse_file(path)
      if path != nil and File.exist?(path)
        cont = File.read(path)
        instance_eval(cont)
      end
    end

    def job(*args, &block)
      
      args[0][:engine] = self
      args[0][:output] = @output
      args[0][:errOut] = @errOut
      
      j = Job.new(*args)
      @jobs[j.title] = [j, block]
      
      #j.parse_block(&block)
    end

    def start_job(title)
      if @jobs.keys.include?(title)
        job = @jobs[title]
        job[0].parse_block(&job[1])
      else
        raise JobExecutionException, "Job with title '#{title}' not found"
      end
    end

    def include_job(title)
      start_job(title)
    end

  end
end
