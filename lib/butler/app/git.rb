
require_relative "../cli_app"
require "tty-prompt"

module Butler
  class Git < CliApp
    
    def initialize(params)
      super
      @exe = "git"
      @tty = TTY::Prompt.new
    end

    def parse_block(&block)
      if block
        instance_eval(&block)
      end
    end
    
    def commit(*args)
      files = {}
      files.merge!(find_changes([:staged, :modified, :untracked]))
      commit_console(files)
    end

    def push(*args)
      if args.length > 0
        
        remote = args[0]
        repo = args[1]
        
        with_working_dir("#{@exe} push #{remote} #{repo}") do |cmd|
          c = OS::ExecCommand.call(cmd) do |mod, spec|
            @output.puts spec[:output].strip
          end

          if not success?(c)
            raise JobExecutionException, "Git execution of 'push' command failed with exit code #{c}"
          end
        end
        
      else
        raise JobExecutionException, "No destination given for git push"
      end
    end

    #### 
    #### Implementation
    ####
    def commit_console(files)

      loop do
        
        @tty.say "GIT Commit Console:".yellow
        @tty.say

        @tty.say "\nFiles ready to be committed: (#{files[:staged].length} selected)".green
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
          
          # refresh the record
          files = find_changes(files.keys)
          
        when :diff

          prompt_diff(files)

        when :commit 
          msg = @tty.ask("Commit message : ")
          git_commit(msg)
          @tty.say "Changes commited to git.".green
          break
        when :quit
          break
        end

      end
      # end loop

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

      p sel
      sel
      
    end

    def git_diff(file, staged = false)
      with_working_dir("#{@exe} diff #{staged ? '--staged' : ''} --color #{file}") do |cmd|
        c = OS::ExecCommand.call(cmd) do |mod, spec|
          @output.puts spec[:output].strip
        end

        if not success?(c)
          raise JobExecutionException, "Git execution of 'diff' command failed with exit code #{c}"
        end
      end
    end

    def git_unstage(files)
      with_working_dir("#{@exe} reset HEAD #{files.join(" ")}") do |cmd|
        c = OS::ExecCommand.call(cmd) do |mod, spec|
          @output.puts spec[:output]
        end

        if not success?(c)
          raise JobExecutionException, "Git execution of 'reset' command failed with exit code #{c}"
        end
      end
    end

    def git_add(files)
      with_working_dir("#{@exe} add #{files.join(" ")}") do |cmd|
        c = OS::ExecCommand.call(cmd)

        if not success?(c)
          raise JobExecutionException, "Git execution of 'add' command failed with exit code #{c}"
        end
      end
    end

    def git_commit(msg)
      
      with_working_dir("#{@exe} commit -m '#{msg}'") do |cmd|
        c = OS::ExecCommand.call(cmd) do |mod, spec|
          @output.puts spec[:output]
        end

        if not success?(c)
          raise JobExecutionException, "Git execution of 'commit' command failed with exit code #{c}"
        end
      end
     
    end

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

  end
end
