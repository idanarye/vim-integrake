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

    def system(*cmd)
        return VIM::evaluate("integrake#runInShell(#{make_command(*cmd).to_vim})")
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

module IntegrakeUtils
    def cmd(*args)
        return VIM::command(*args)
    end

    def evl(*args)
        return VIM::evaluate(*args)
    end

    def curbuf
        return VIM::Buffer.current
    end

    def selection
        return nil unless $range
        return ($range[:line1]..$range[:line2]).map do|line_number|
            line=curbuf[line_number]
            from=0
            to=line.length
            case $range[:type]
            when :char
                if $range[:line1]==line_number
                    from=$range[:col1]-1
                end
                if $range[:line2]==line_number
                    to=$range[:col2]-1
                end
            when :block
                while vim_call(:strdisplaywidth,line[0...from])<$range[:vcol1]
                    from+=1
                end
                from-=1
                to=0
                while vim_call(:strdisplaywidth,line[0...to])<$range[:vcol2]
                    to+=1
                end
                to-=1
            end
            line[from...to]
        end
    end

    def curwin
        return VIM::Window.current
    end

    def vim_call(function_name,*args)
        return VIM::evaluate("#{function_name}(#{args.map(&:to_vim).join(', ')})")
    end

    def method_missing(method_name,*args,&block)
        if Integrake.vim_exists?("*#{method_name}") # if it's a Vim function
            return vim_call(method_name,*args)
        elsif 2==Integrake.vim_exists_code(":#{method_name.to_s.chomp('!')}") # if it's a Vim command
            VIM::command("#{method_name} #{args.join(' ')}")
        else
            super
        end
    end

    def find_window_numbers(window_identifier)
        if window_identifier.is_a? Integer
            if 0<window_identifier and window_identifier<=VIM::Window.count
                return [window_identifier]
            else
                return []
            end
        end

        if window_identifier.is_a? Array
            return window_identifier.flat_map{|single_identifier|find_window_numbers(single_identifier)}.compact.sort.uniq
        end

        if window_identifier.is_a? Regexp
            return VIM::Window.count.times.map do|i|
                if VIM::Window[i].buffer.name=~window_identifier
                    i+1
                end
            end.compact
        end

        if window_identifier.is_a? Proc
            if 0==window_identifier.arity
                original_window=winnr()
                begin
                    return VIM::Window.count.times.map do|i|
                        cmd "#{i+1}wincmd w"
                        if window_identifier.call
                            i+1
                        end
                    end.compact
                ensure
                    cmd "#{original_window}wincmd w"
                end
            elsif window_identifier.arity<=2
                identifier_proc=if 1==window_identifier.arity
                                    window_identifier
                                else
                                    lambda do|window_number|
                                        window_identifier.call window_number,VIM::Window[window_number-1]
                                    end
                                end
                return VIM::Window.count.times.map do|i|
                    if identifier_proc.call(i+1)
                        i+1
                    end
                end.compact
            else
                raise 'Arity for window identifiying proc can not be larger than 2'
            end
        end

        return []
    end

    def find_window_number(window_identifier)
        return find_window_numbers(window_identifier).first
    end

    def do_in_windows(window_identifier)
        return unless window_identifier
        if defined?(window_identifier.empty?)
            return if window_identifier.empty?
        end
        window_numbers=find_window_numbers(window_identifier)
        original_window=winnr()
        result={}
        begin
            window_numbers.each do|window_number|
                cmd "#{window_number}wincmd w"
                result[window_number]=yield
            end
        ensure
            cmd "#{original_window}wincmd w"
        end
        return result
    end

    def do_in_window(window_identifier,&block)
        do_in_windows(find_window_number(window_identifier),&block).values.first
    end
end

VAR=Object.new
def VAR.[](varname)
    if Integrake.vim_exists?(varname)
        return VIM::evaluate(varname)
    else
        return nil
    end
end
def VAR.[]=(varname,value)
    Integrake.vim_write_var(varname,value)
end

def var
    return VAR
end

class Object
    def to_vim
        return "#{self}".to_vim
    end
end

class String
    def to_vim
        return "'#{self.to_s.gsub("'","''").gsub("\n",'\'."\\n".\'')}'"
    end
end

class Array
    def to_vim
        return "[#{self.map(&:to_vim).join(',')}]"
    end
end

class Numeric
    def to_vim
        return self.to_s
    end
end

class NilClass
    def to_vim
        return '0'
    end
end

class FalseClass
    def to_vim
        return '0'
    end
end

class TrueClass
    def to_vim
        return '1'
    end
end

Rake.application.init
Rake.application.clear

include IntegrakeUtils

module Integrake
    @@rakefile_name=nil
    @@rakefile_last_changed=nil
    @@loaded_files_last_changed={}

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
        VIM::command("return #{value.to_vim}")
    end

    def self.vim_write_var(varname,newvalue)
        VIM::command("let #{varname} = #{newvalue.to_vim}")
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

        if(rakefile_name!=@@rakefile_name or rakefile_last_changed!=@@rakefile_last_changed or
           @@loaded_files_last_changed.any?{|file,last_changed|File.mtime(file)!=last_changed})

            @@loaded_files_last_changed={}
            @@rakefile_name=rakefile_name
            @@rakefile_last_changed=rakefile_last_changed

            Rake.application.clear

            #Load auto-loaded .rb files from runtime path:
            VIM::evaluate('&runtimepath').split(',').map{|e|File.join(e,'integrake')}.select{|e|File.directory?(e)}.each do|integrake_dir|
                Dir.foreach(integrake_dir).grep(/\.rb$/) do|f|
                    Integrake.load File.join(integrake_dir,f)
                end
            end

            Rake.load_rakefile(rakefile_name)

        else
            Rake::Task.tasks.each do|task|
                task.reenable
            end
        end
        return
    end

    def self.load(filename)
        full_path=File.expand_path(filename)
        file_last_changed=File.mtime(full_path)
        @@loaded_files_last_changed[full_path]=file_last_changed
        Kernel.load(full_path)
    end

    def self.invoke_with_range(line1,line2,count,task,*args)
        $range=if -1<count
                   {
                       :type=>{
                           'v'=>:char,
                           'V'=>:line,
                           "\x16"=>:block,
                       }[VIM::evaluate('visualmode()')],
                       :line1=>line1,
                       :line2=>line2,
                   }
               end
        if $range and [:char,:block].include?($range[:type])
            if $range[:line1]==vim_call(:line,"'<") and $range[:line2]==vim_call(:line,"'>")
                $range[:col1]=vim_call(:col,"'<")
                $range[:col2]=vim_call(:col,"'>")
                $range[:vcol1]=vim_call(:virtcol,"'<")
                $range[:vcol2]=vim_call(:virtcol,"'>")
            else
                $range[:type]=:line
            end
        end
        begin
            task.invoke(*args)
        ensure
            $range=nil
        end
    end

    def self.invoke(line1,line2,count,taskname,*args)
        Integrake.prepare
        invoke_with_range(line1,line2,count,Rake::Task[taskname],*args)
    end

    def self.prompt_and_invoke(line1,line2,count)
        Integrake.prepare
        tasks=Rake::Task.tasks
        list_for_input_query=['Select task:']+tasks.each_with_index.map do|t,i|
            "#{i+1} #{t.name}#{
                unless t.arg_names.empty?
                    "(#{t.arg_names.join(', ')})"
                end
            }"
        end
        chosen_task_number=VIM::evaluate("inputlist(#{list_for_input_query.to_vim})")
        if chosen_task_number.between?(1,tasks.count)
            chosen_task=tasks[chosen_task_number-1]
            known_args=[]
            args=chosen_task.arg_names.map do|arg_name|
                arg=VIM::evaluate("input(#{"#{[*known_args,''].join(', ')}#{arg_name}: ".to_vim})")
                unless arg.empty?
                    known_args<<"#{arg_name}: #{arg}"
                    arg
                end
            end
            puts ' '
            invoke_with_range(line1,line2,count,chosen_task,*args)
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
        chosen_file_number=VIM::evaluate("inputlist(#{list_for_input_query.to_vim})")
        if chosen_file_number.between?(1,canadidate_files.count)
            chosen_file=canadidate_files[chosen_file_number-1]
            puts ' '
            buffer_to_update=nil
            if File.exists?(rakefile_name)
                if 'yes'!=VIM::evaluate("input('#{rakefile_name} already exists! Type \"yes\" to override it: ')")
                    return
                end
                buffer_to_update=VIM::evaluate("bufnr(#{rakefile_name.to_vim})")
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
        unless VIM::evaluate('expand("%")')==rakefile_name
            VIM::command "edit #{rakefile_name}"
        end
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
