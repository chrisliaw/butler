
require 'colorize'
require 'tty-prompt'
require 'fileutils'
require_relative '../cli_app'

module Butler
  class Rubygem < CliApp
    VERSION = "0.1"
    def initialize(args, &block)
      @exe = "gem"    
      super
      
      # if there is global version value defined
      @rversion = @engine.get(Engine::GKEY_RELEASING_VERSION)
      @tty = TTY::Prompt.new
      invoke_method(&block)
    end

    def build(spec = nil, params = {}, &block)

      if spec != nil and not spec.empty?
      else
        
        ss = Dir[File.join(@working_dir,"**/*.gemspec")]
        if ss.length > 0
          sel = @tty.select("Please select one of the gemspec below:") do |m|
            ss.each do |s|
              name = s[@working_dir.length..-1]
              m.choice name, s
            end
            
            m.choice "None of the above", :q
          end

          if sel != nil and sel != :q
            spec = sel
          else
            @tty.error "Invalid selection for rubygem build command"
            exit(-1)
          end

        else
          @tty.error "Please create an .gemspec file first before calling build"
          exit(-1)
        end
        
      end

      @output.puts "Building gem using spec '#{spec}'".yellow
      #if args.length > 0
      #  @spec = args[0]
      #  params = args[1]
      #end
      if params != nil
        @expected_status = params[:expected_status]
        @version = params[:version] || @rversion
        @versionFile = params[:version_file]
      end

      if @version != nil and not @version.empty? and (@versionFile == nil or @versionFile.empty?)
        @versionFile = prompt_version_file
      end

      if @version != nil and not @version.empty? and @versionFile != nil and not @versionFile.empty?
        update_version(@versionFile, @version)
      end

      res = {}
      assess_status(with_working_dir("#{@exe} build #{spec}") do |cmd|
        
        #STDOUT.puts "  Building rubygem spec '#{spec}'".colorize(Butler::WI_HEADER_COLOR)
        OS::ExecCommand.call(cmd) do |mod, spec|
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

      end)
      # end with_working_dir() block

      if block
        block.call(res)
      end

      res
    end
    # end build()
    #

    def publish(rel, params = {})

      @output.puts "Publishing gem '#{rel[:file]}'".yellow
      ignoreStatus = false
      #rel = args[0]
      #if rel != nil

        #params = args[1]
        if params != nil
          ignoreStatus = params[:ignore_status]
        end

        assess_status(with_working_dir("#{@exe} push #{rel[:file]}") do |cmd|
          OS::ExecCommand.call(cmd) do |mod, spec|
            @output.puts spec[:output].strip
          end
        end)
        
      #end    
    end
    # end publish()
    # 

    def uninstall(name)

      @output.puts "Uninstalling gem '#{name}'".yellow
      #name = args[0]
      if name != nil

        with_working_dir("#{@exe} uninstall #{name}") do |cmd|
          assess_status(OS::ExecCommand.call(cmd) do |mod, spec|
            @output.puts spec[:output].strip
          end)
        end
      else
        @errOut.puts "Name is needed for gem uninstall operation"
      end    
    end
    # end method uninstall()
    
    #
    # method install()
    def install(name, params = {})
      
      @output.puts "Installing gem '#{name}'".yellow
      if name != nil

        with_working_dir("#{@exe} install #{name}") do |cmd|
          assess_status(OS::ExecCommand.call(cmd) do |mod, spec|
            @output.puts spec[:output].strip
          end)
        end
      else
        @errOut.puts "Name is needed for gem install operation"
      end    
    end
    # end method uninstall()

    def update_version(file, version)
      @output.puts "Updating version in file '#{file}'"
      if file != nil and not file.empty? and File.exist?(file)

        workFile = "#{file}.wf"
        FileUtils.cp file,workFile
        File.open(file,"w") do |f|

          File.read(workFile).each_line do |l|
            if l =~ /VERSION/
              ll = l.split("=")
              f.puts "  #{ll[0].strip} = \"#{version.strip}\""
            else
              f.puts l
            end
          end

        end

        FileUtils.rm_f workFile
        
      end
    end
    # end update_version()
    # 

    def assist
      msg = []
      msg << "rubygem DSL options and usage (V#{VERSION}):"
      msg << ""
      msg << "  rubygem do"
      msg << "    build [spec file]    # build gem with given spec file or prompt for one if not given"
      msg << "    publish [gem file]   # push the gemfile to rubygems repository"
      msg << "    install [gem name]   # install the gemfile with given name to system"
      msg << "    uninstall [gem name] # uninstall the gemfile with given name from system"
      msg << "  end"
      msg << "  "

      @output.puts msg.join("\n").yellow
    end

    def prompt_version_file
      tty = TTY::Prompt.new
      vfile = Dir[File.join(@working_dir,"**/version.rb")]
      sel = ""
      if vfile != nil and vfile.length > 0
        ans = tty.yes?("Found #{vfile[0]}.\nUse this file?") do |q|
          q.default true
        end
        
        if ans
          sel = vfile[0]
        end
      end

      if sel == nil or sel.empty?

        files = Dir[File.join(@working_dir,"**/*.rb")]    
        cnt = @working_dir.length
        sel = tty.select("Select version file to update:", per_page: 10) do |m|
          files.each do |f|
            name = f[cnt..-1]
            m.choice name, f
          end
        end
        
      end

      sel
    end
    # end prompt_version_file
    #
  
  end
  # end class Rubygem
  # 

end
# end module Butler
#
