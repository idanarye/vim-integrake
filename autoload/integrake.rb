require 'rake'
require 'rake/alt_system'
require 'shellwords'

Rake::TaskManager.record_task_metadata=true

module FileUtils
    def make_command(*cmd)
        if 1<cmd.length
            return "#{cmd[0]} #{Shellwords.shelljoin(cmd.drop(1))}"
        else
            return cmd[0]
        end
    end
    private :make_command


    def system(*cmd)
        return VIM::evaluate("integrake#runInShell(#{Integrake.to_vim(make_command(*cmd))})")
    end

    def sh(*cmd,&block)
        cmd.pop if cmd.last.is_a? Hash
        result=system(*cmd)
        if block_given?
            block.call(0==result)
        else
            if 0!=result
                fail "Command failed with status (#{result}): [#{make_command(*cmd)}]"
            end
        end
    end

    def method_missing(method_name,*args,&block)
        if Integrake.vim_exists?("*#{method_name}") # if it's a Vim function
            return VIM::evaluate("#{method_name}(#{Integrake.to_vim(*args)})")
        elsif 2==Integrake.vim_exists_code(":#{method_name}") # if it's a Vim command
            VIM::command("#{method_name} #{args.join(' ')}")
        else
            super
        end
    end
end

Rake.application.init
Rake.application.clear

module Integrake
    @@rakefile_name=nil
    @@rakefile_last_changed=nil

    def self.to_vim(*sources)
        if 1!=sources.count
            return sources.map{|e|Integrake.to_vim(e)}
        end
        source=sources[0]
        if source.is_a? String or source.is_a? Symbol
            return "'#{source.to_s.gsub("'","''")}'"
        elsif source.is_a? Numeric
            return source.to_s
        elsif source.is_a? Array
            return "[#{source.map{|e|to_vim(e)}.join(',')}]"
        end
    end

    def self.to_vim_splice(*sources)
    end

    def self.vim_exists_code(identifier)
        return VIM::evaluate("exists('#{identifier}')")
    end
    def self.vim_exists?(identifier)
        return 0!=Integrake.vim_exists_code(identifier)
    end

    def self.vim_read_vars(*varnames)
        return varnames.map do|varname|
            VIM::evaluate(varname)
        end
    end

    def self.vim_return_value(value)
        $x= "return #{to_vim(value)}"
        $y=value
        VIM::command("return #{to_vim(value)}")
    end

    def self.vim_write_var(varname,newvalue)
        VIM::command("let #{varname} = #{self.to_vim(newvalue)}")
    end

    def self.rakefile_name
        unless Integrake.vim_exists?('g:integrake_filePrefix')
            fail "You can't use Integrake until you set g:integrake_filePrefix"
        end
        return "#{VIM::evaluate('g:integrake_filePrefix')}.integrake"
    end

    def self.prepare
        rakefile_name=self.rakefile_name
        rakefile_last_changed=File.mtime(rakefile_name)

        if rakefile_name!=@@rakefile_name or rakefile_last_changed!=@@rakefile_last_changed
            @@rakefile_name=rakefile_name
            @@rakefile_last_changed=rakefile_last_changed
            Rake.application.clear
            Rake.load_rakefile(rakefile_name)
        else
            Rake::Task.tasks.each do|task|
                task.reenable
            end
        end
        return
    end

    def self.invoke(taskname,*args)
        Integrake.prepare
        Rake::Task[taskname].invoke(*args)
    end

    def self.prompt_and_invoke
        Integrake.prepare
        tasks=Rake::Task.tasks
        list_for_input_query=['Select task:']+tasks.each_with_index.map do|t,i|
            "#{i+1} #{t.name}#{
                unless t.arg_names.empty?
                    "(#{t.arg_names.join(', ')})"
                end
            }"
        end
        chosen_task_number=VIM::evaluate("inputlist(#{to_vim(list_for_input_query)})")
        if chosen_task_number.between?(1,tasks.count)
            chosen_task=tasks[chosen_task_number-1]
            known_args=[]
            args=chosen_task.arg_names.map do|arg_name|
                arg=VIM::evaluate("input(#{Integrake.to_vim("#{[*known_args,''].join(', ')}#{arg_name}: ")})")
                unless arg.empty?
                    known_args<<"#{arg_name}: #{arg}"
                    arg
                end
            end
            puts ' '
            chosen_task.invoke(*args)
        end
    end

    def self.complete(argLead,cmdLine,cursorPos)
        Integrake.prepare
        return Rake::Task.tasks.map{|e|e.name}.select{|e|e.start_with?(argLead)}
    end

    def self.prompt_to_grab
        rakefile_name=self.rakefile_name
        unless Integrake.vim_exists?('g:integrake_grabDirs')
            fail "You can't grab an Integrake file until you set g:integrake_grabDirs"
        end
        grab_sources=[*VIM::evaluate('g:integrake_grabDirs')]
        canadidate_files=grab_sources.flat_map do|src_dir|
            Dir.entries(src_dir).select{|e|e.end_with?('.integrake')}.map do|src_file|
                [src_dir,src_file]
            end
        end
        list_for_input_query=['Select template for integrake_file:']+
            canadidate_files.each_with_index.map{|f,i|"#{i+1} #{f[1]}"}
        chosen_file_number=VIM::evaluate("inputlist(#{to_vim(list_for_input_query)})")
        if chosen_file_number.between?(1,canadidate_files.count)
            chosen_file=canadidate_files[chosen_file_number-1]
            puts ' '
            buffer_to_update=nil
            if File.exists?(rakefile_name)
                if 'yes'!=VIM::evaluate("input('#{rakefile_name} already exists! Type \"yes\" to override it: ')")
                    return
                end
                buffer_to_update=VIM::evaluate("bufnr(#{Integrake.to_vim(rakefile_name)})")
                buffer_to_update=nil if -1==buffer_to_update
            end
            FileUtils.copy_file(File.join(chosen_file),rakefile_name)
            if buffer_to_update
                VIM::command("windo if #{buffer_to_update}==winbufnr(0) | edit | endif")
            end
        end
    end

    def self.edit_task(task_name)
        rakefile_name=self.rakefile_name
        if task_name.empty?
            VIM::command "edit #{rakefile_name}"
            return
        end
        if (exists=File.exists?(rakefile_name))
            Integrake.prepare
            task=Rake::Task[task_name] rescue nil
            if task
                task_parts=task.locations.first.split(':')
                VIM::command "edit #{task_parts[0]}"
                VIM::command task_parts[1].to_s
                return
            end
        end
        VIM::command "edit #{rakefile_name}"
        last_line=VIM::Buffer.current.count
        if exists
            VIM::Buffer.current.append(last_line,"")
        else
            last_line-=2
        end
        VIM::Buffer.current.append(last_line+1,"task #{task_name.to_s.to_sym.inspect} do")
        VIM::Buffer.current.append(last_line+2,"")
        VIM::Buffer.current.append(last_line+3,"end")
        VIM::command (last_line+3).to_s
    end
end
