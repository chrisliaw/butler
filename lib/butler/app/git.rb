
require_relative "../cli_app"
require "tty-prompt"

module Butler
  class Git < CliApp
    VERSION = "0.1"
    
    def initialize(args, &block)
      super
      @exe = "git"
      @tty = TTY::Prompt.new
      @rversion = @engine.get(Engine::GKEY_RELEASING_VERSION)

      invoke_method(&block)
    end

    ###
    ### DSL
    ###
    # Commit DSL
    def commit(*args)
      @tty.say "Committing source code".yellow
      files = {}
      files.merge!(find_changes([:staged, :modified, :untracked]))
      commit_console(files)
    end
    # end commit DSL
    #

    def tag(version = "", msg = "")
      @tty.say "Tagging source code".yellow
      if version != nil and not version.empty?
        ver = version
      elsif @rversion != nil and not @rversion.empty?
        ver = @rversion
      else
        ver = nil
      end

      v = @tty.ask("Tag with name #{ver != nil ? "(Default: #{ver})" : ""}:", default: ver)
      if v != nil and not v.empty?
        msg = @tty.ask("Message of the tag : ", required: true)
      end
      
      git_tag(v,msg)
    end

    # push DSL
    def push(repo, branch = "master")
      #@tty.say "Pushing source code".yellow
      
      if repo != nil and not repo.empty?
        @tty.say "Pushing to repository #{repo}#{branch == nil ? "" : " and branch #{branch}"}".yellow
      else
        @tty.say "Pushing to default repository origin and branch master".yellow
        repo = 'origin'
        branch = 'master' if branch == nil or branch.empty?
      end
      
      with_working_dir("#{@exe} push #{repo} #{branch}") do |cmd|
        assess_status(OS::ExecCommand.call(cmd) do |mod, spec|
          @output.puts spec[:output].strip
        end)

      end
      
    end
    # end push dsl
    # 

    def push_tag(repo)
      push(repo,"--tags")
    end   

    def info(*args)

      @logCnt = -1
      if args.length > 0
        cnt = 0
        args[0].each do |a|
          if a == '-log-entry'
            @logCnt = args[0][cnt+1]
            cnt += 2
          else
            cnt += 1
          end
        end
      end
      
      # global config
      @tty.say "Git Global Config:".yellow
      git_config("--global -l") do |res|
        res[:output].each_line do |l|
          @output.print " #{l.colorize(:green)}"
        end
      end    
      @tty.say "Git Local Config:".yellow
      git_config("--local -l") do |res|
        res[:output].each_line do |l|
          @output.print " #{l.colorize(:green)}"
        end
      end
      @tty.say "Git Remote Config:".yellow
      rem = git_remote
      if rem.length > 0
        @tty.say " #{rem.keys.length} remote repository defined:".green
        rem.each do |k,v|
          v.each do |kk,vv|
            @tty.say " #{k} : #{vv} [#{kk}]".green
          end
        end
      else
        @tty.error " No remote repository defined"
        @tty.say
      end
      @tty.say "Branches:".yellow
      br = git_branch
      if br.length > 0
        @tty.say " Workspace current branch : #{br[:current]}".green
        if br[:others] != nil and br[:others].length > 0
          @tty.say " Other branches:"
          br[:others].each do |b|
            @tty.say "  #{b}".green
          end
        end
      else
        @tty.error "No branch info available."
        @tty.say
      end

      @tty.say "Log Entry #{@logCnt.to_i < 0 ? "latest #{@logCnt.to_i*-1}" : "oldest #{@logCnt}"}:".yellow
      git_log(@logCnt) do |res|
        res[:output].each_line do |l|
          @output.print " #{l}".green
        end
      end

      @output.puts 
    end
    ###
    ### End DSL
    ###

    def assist
      
      msg = []
      msg << "git DSL options and usage (V#{VERSION}):"
      msg << ""
      msg << "  git do"
      msg << "    info                 # print out some info for the current git workspace"
      msg << "    commit               # trigger the commit console"
      msg << "    tag [name],[msg]     # tag the source code with given name and message. If not given shall be prompted "
      msg << "    push [repo],[branch] # push the source code to given repository and branch. If not given shall defaulted to 'origin' and 'master'"
      msg << "    push_tag [repo]      # push the tag to repository"
      msg << "  end"
      msg << ""
      
      @output.puts msg.join("\n").yellow
    end

    #### 
    #### Implementation
    ####
    def commit_console(files)

      loop do
        
        @tty.say "\nGIT Commit Console V#{VERSION}:".yellow
        @tty.say

        @tty.say "\nFiles ready to be committed in staging: (#{files[:staged].length} selected)".green
        if files[:staged].length > 0
          files[:staged].each do |st|
            case st[0]
            when "A"
              str = "[New]"
              col = :yellow
            when "M"
              str = "[Modified]"
              col = :light_green
            end
            @output.puts "  #{str} #{st[1]}".colorize(col)
          end
        end

        @output.puts 

        @ops = @tty.expand("Available Operations:") do |q|
          q.choice key: "a", name: 'Add more files', value: :add
          if files[:staged].length > 0
            q.choice key: "r", name: 'Remove staged file', value: :remove_staged
            q.choice key: "c", name: 'Commit staged file', value: :commit
          end
          q.choice key: "i", name: "Ignore file(s)", value: :ignore
          q.choice key: "d", name: 'Diff a file (modified or new only)', value: :diff
          q.choice key: "q", name: 'Quit', value: :quit
        end

        case @ops
        when :add
          ffiles = files.clone
          ffiles.delete(:staged)
          f = prompt_add(ffiles)
          if f.length > 0
            git_add(f)
          end

          # refresh the record
          files = find_changes(files.keys)
          
        when :remove_staged
          f = prompt_unstage(files[:staged])
          if f.length > 0
            git_unstage(f)
          end

          if f.length > 1
            @tty.ok "Selected files removed from staging."
          else
            @tty.ok "'#{f[0]}' removed from staging."
          end
          
          # refresh the record
          files = find_changes(files.keys)
          
        when :diff

          prompt_diff(files)

        when :ignore
          f = prompt_ignore(files[:untracked])
          if f.length > 0
            git_ignore(f)
          end
        when :commit 
          msg = @tty.ask("Commit message : ", required: true) 
          git_commit(msg)
          @tty.say "Changes commited to git.".green
          break
        when :quit
          break
        end

      end
      # end loop

    end

    def prompt_ignore(staged)
      sel = []
      loop do
        sel = @tty.multi_select("Select files to ignore:", per_page: 10) do |m|
          staged.each do |v|
            m.choice "#{v}".green, v
          end

          m.choice "Pattern", :pattern
          m.choice "Done", :q
        end

        if sel.length > 0
          if sel.include?(:q)
            sel.delete(:q)
          end

          if sel.include?(:pattern)
            pattern = @tty.ask("Please provide pattern to ignore for files : ") do |q|
              q.required true
            end
            sel.delete(:pattern)
            sel << pattern
          end

          break
        else
          ans = @tty.yes?("Hardly any files selected. Try again?")
          if not ans
            break
          end
        end
        
      end

      sel
      
    end

    def prompt_diff(files)
      loop do
        sel = @tty.select("Select file to diff:", per_page: 10) do |m|
          files.each do |k,v|
           
            if k == :modified or k == :staged
              v.each do |vv|
                if vv.is_a?(Array)
                  m.choice "#{vv[1]}".green, vv[1]
                else
                  m.choice "#{vv}".green, vv
                end
              end
            end
            
          end

          m.choice "Done", :q
          
        end

        if sel == :q
          break
        else
          @output.puts "******************** DIFF #{sel} ***********************".cyan
          git_diff(sel)
          git_diff(sel, staged: true)
          @output.puts "******************** END DIFF #{sel} ***********************".cyan
        end
       
      end
      
    end

    def prompt_unstage(staged)
      sel = []
      loop do
        sel = @tty.multi_select("Select files to unstage:", per_page: 10) do |m|
          staged.each do |v|
            m.choice "#{v[1]}".green, v[1]
          end

          m.choice "Done", :q
        end

        if sel.length > 0
          if sel.include?(:q)
            sel.delete(:q)
          end
          break
        else
          ans = @tty.yes?("Hardly any files selected. Try again?")
          if not ans
            break
          end
        end
        
      end

      sel
      
    end

    def prompt_add(files)
      sel = []
      loop do
        sel = @tty.multi_select("Select files to commit:", per_page: 10, filter: true) do |m|
          files.each do |k,v|
            v.each do |vv|
              case k
              when :modified
                color = :red
              when :untracked
                color = :yellow
              end
              m.choice "[#{k.to_s.titleize}] #{vv}".colorize(color), vv
            end
          end
          
          m.choice "Done", :q
        end

        if sel.length > 0 
          if sel.include?(:q)
            sel.delete(:q)
          end

          break
        else
          ans = @tty.yes?("Hardly any files selected. Try again?")
          if not ans
            break
          end
        end
        
      end

      sel
      
    end
    
    def prompt_tag(tag)

      msg = @tty.ask("Tag message for tag '#{tag}' : ", required: true)
      git_tag(tag,msg)
     
    end

    ## 
    ## Git call
    ##
    def git_ignore(files)
      root = git_find_root
      if root != nil and not root.empty?
        f = File.join(root,".gitignore")
        begin
          @ignore = File.open(f,"a")
          files.each do |f|
            @ignore.puts f
          end
        rescue Exception => ex
          @logger.ext_error(ex)
        ensure 
          @ignore.close if @ignore != nil
        end
      else
        raise JobExecutionException, "Cannot find the git workspace root directory. Not a git workspace?"
      end   
    end

    def git_find_root
      root = ""
      assess_status(with_working_dir("#{@exe} rev-parse --show-toplevel") do |cmd|
        OS::ExecCommand.call(cmd) do |mod, spec|
          root = spec[:output].strip
        end
        
      end)
      
      root
    end
    
    def git_diff(file, staged = false)
      assess_status(with_working_dir("#{@exe} diff #{staged ? '--staged' : ''} --color #{file}") do |cmd|
        OS::ExecCommand.call(cmd) do |mod, spec|
          @output.puts spec[:output].strip
        end
      end)
    end

    def git_unstage(files)
      assess_status(with_working_dir("#{@exe} reset HEAD #{files.join(" ")}") do |cmd|
        c = OS::ExecCommand.call(cmd) do |mod, spec|
          @output.puts spec[:output]
        end
      end)
    end

    def git_add(files)
      assess_status(with_working_dir("#{@exe} add #{files.join(" ")}") do |cmd|
        OS::ExecCommand.call(cmd)
      end)
    end

    def git_commit(msg)
      
      assess_status(with_working_dir("#{@exe} commit -m '#{msg}'") do |cmd|
        c = OS::ExecCommand.call(cmd) do |mod, spec|
          @output.puts spec[:output]
        end

        if not success?(c)
          raise JobExecutionException, "Git execution of 'commit' command failed with exit code #{c}"
        end
      end)
     
    end

    def git_remote
      
      remote = {}
      
      assess_status(with_working_dir("#{@exe} remote -vv") do |cmd|
        OS::ExecCommand.call(cmd) do |mod, spec|
          #@output.puts spec[:output].strip
          spec[:output].each_line do |l|
            sp = l.strip.split(" ")
            name = sp[0].strip
            url = sp[1].strip
            mode = sp[2].gsub("(","").gsub(")","").strip
            
            remote[name] = {} if remote[name] == nil
            remote[name][mode] = url
            
          end
        end
        
      end)

      remote
      
    end

    def git_tag(tag, msg)
      assess_status(with_working_dir("#{@exe} tag -a #{tag} -m '#{msg}'") do |cmd|
        OS::ExecCommand.call(cmd)
      end)
    end

    # 
    # method git_branch
    # 
    def git_branch
      branch = {}
      
      assess_status(with_working_dir("#{@exe} branch -ra") do |cmd|
        OS::ExecCommand.call(cmd) do |mod, spec|
          #@output.puts spec[:output].strip
          spec[:output].each_line do |l|
            sp = l.strip.split(" ")
            marker = sp[0].strip
            if marker == "*"
              branch[:current] = sp[1].strip
            else
              branch[:others] = [] if branch[:others] == nil
              branch[:others] << l.strip
            end
          end
        end
      end)

      branch
    end
    #
    # end method git_branch
    # 

    # 
    # method git_log
    # 
    def git_log(*args, &block)
      
      assess_status(with_working_dir("#{@exe} log #{args.join(" ")}") do |cmd|
        OS::ExecCommand.call(cmd) do |mod, spec|
          if block
            block.call(spec)
          else
            @output.puts spec[:output].strip
          end
        end
        
      end)

      
    end
    # 
    # end method git_log()
    # 

    def git_config(*args,&block)
      
      assess_status(with_working_dir("#{@exe} config #{args.join(" ")}") do |cmd|
        OS::ExecCommand.call(cmd) do |mod, spec|
          if block
            block.call(spec)
          else
            @output.puts spec[:output].strip
          end
        end
        
      end)
      
    end

    ##
    ## End Git call
    ##

    ###
    ### Helpers
    ###
    # find_changes() helper
    def find_changes(spec = [:modified, :untracked])
      file = {}
      spec.each do |s|
        case s
        when :modified
          cmd = "#{@exe} diff --name-only --diff-filter=M"
        when :untracked
          cmd = "#{@exe} ls-files --others --exclude-standard --directory"
        when :staged
          cmd = "#{@exe} diff --name-status --cached"
        when :ignored
          cmd = "#{@exe} ls-files --ignored --exclude-standard --others"
        end
      
        with_working_dir(cmd) do |ccmd|
          c = OS::ExecCommand.call(ccmd) do |mod, spec|
            if s == :staged
              file[s] = []
              spec[:output].each_line do |l|
                st = l.split(" ")
                file[s] << st
              end
              #file[s] = spec[:output].split("\n")
            else
              file[s] = spec[:output].split("\n")
            end
          end

          if not success?(c)
            raise JobExecutionException, "Git execution of 'status' (#{s}) command failed with exit code #{c} [Expected #{@expected_status}]"
          end
        end
        
      end

      file
    end
    # end find_changes() method
    # 
    ###
    ### End helpers
    ###

  end
end
