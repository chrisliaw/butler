
require 'colorize'
require_relative '../cli_app'

module Butler
  class Rubygem < CliApp
    def initialize(params)
      super
      @exe = "gem"    
    end

    def build(*args, &block)
      if args.length > 0
        @spec = args[0]
        params = args[1]
      end

      if params != nil
        @expected_status = params[:expected_status]
      end

      res = {}
      with_working_dir("#{@exe} build #{@spec}") do |cmd|
        
        STDOUT.puts "  Building rubygem spec '#{@spec}'".colorize(Butler::WI_HEADER_COLOR)
        c = OS::ExecCommand.call(cmd) do |mod, spec|
          spec[:output].each_line do |l|
            if l =~ /File:/
              res[:file] = l.split(":")[1].strip
            elsif l =~ /Name:/
              res[:name] = l.split(":")[1].strip
            elsif l =~ /Version:/
              res[:version] = l.split(":")[1].strip
            end
            STDOUT.puts "  #{l.strip.colorize(Butler::WI_DETAILS_COLOR)}"
          end
          #STDOUT.puts spec[:data].blue
        end

        if not success?(c)
          raise JobExecutionException, "Rubygem execution of 'build' command failed with exit status #{c} [Expected #{@expected_status}]"
        end

      end
      # end with_working_dir() block

      if block
        block.call(res)
      end

      res
    end

    def publish(*args)

      ignoreStatus = false
      rel = args[0]
      if rel != nil

        params = args[1]
        if params != nil
          ignoreStatus = params[:ignore_status]
        end

        with_working_dir("#{@exe} push #{rel[:file]}") do |cmd|
          c = OS::ExecCommand.call(cmd) do |mod, spec|
            @output.puts spec[:output].strip
          end

          if not ignoreStatus and not success?(c)
            raise JobExecutionException, "Rubygem execution of 'publish' (push) command failed with exit code #{c}"
          end
        end
        
      end    
    end

    def uninstall(*args)

      name = args[0]
      if name != nil

        with_working_dir("#{@exe} uninstall #{name}") do |cmd|
          c = OS::ExecCommand.call(cmd) do |mod, spec|
            @output.puts spec[:output].strip
          end

          if not success?(c)
            raise JobExecutionException, "Rubygem execution of 'uninstall' command failed with exit code #{c}"
          end
        end
      else
        @errOut.puts "Name is needed for gem uninstall operation"
      end    
    end
    # end method uninstall()
    
    #
    # method install()
    def install(*args)

      name = args[0]
      if name != nil

        with_working_dir("#{@exe} install #{name}") do |cmd|
          c = OS::ExecCommand.call(cmd) do |mod, spec|
            @output.puts spec[:output].strip
          end

          if not success?(c)
            raise JobExecutionException, "Rubygem execution of 'install' command failed with exit code #{c}"
          end
        end
      else
        @errOut.puts "Name is needed for gem install operation"
      end    
    end
    # end method uninstall()


  end
  # end class Rubygem
  # 

end
# end module Butler
#
