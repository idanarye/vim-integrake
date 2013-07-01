require 'rake'
require 'rake/alt_system'
require 'shellwords'

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
end

Rake.application.init
Rake.application.clear

module Integrake
    @@rakefile_name=nil
    @@rakefile_last_changed=nil

    def self.to_vim(source)
        if source.is_a? String or source.is_a? Symbol
            return "'#{source.to_s.gsub("'","''")}'"
        elsif source.is_a? Numeric
            return source.to_s
        elsif source.is_a? Array
            return "[#{source.map{|e|to_vim(e)}.join(',')}]"
        end
    end

    def self.vim_var_exists?(varname)
        return 0!=VIM::evaluate("exists('#{varname}')")
    end

    def self.vim_read_var(varname)
        return VIM::evaluate(varname)
    end

    def self.vim_read_vars(*varnames)
        return varnames.map do|varname|
            Integrake.vim_read_var(varname)
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

    def self.prepare
        unless Integrake.vim_var_exists?('g:integrake_filePrefix')
            fail "You can't use Integrake until you set g:integrake_filePrefix"
        end
        rakefile_name="#{Integrake.vim_read_var('g:integrake_filePrefix')}.integrake"
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
        self.prepare
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
            puts ' ' #unless chosen_task.arg_names.empty?
            chosen_task.invoke(*args)
        end
    end

    def self.complete(argLead,cmdLine,cursorPos)
        Integrake.prepare
        return Rake::Task.tasks.map{|e|e.name}.select{|e|e.start_with?(argLead)}
    end
end
