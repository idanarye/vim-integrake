require 'rake'
require 'rake/alt_system'
require 'shellwords'

Rake::TaskManager.record_task_metadata=true

module FileUtils
    def make_command(*cmd)
        if 1 < cmd.length
            return "#{cmd[0]} #{Shellwords.shelljoin(cmd.drop(1))}"
        else
            return cmd[0]
        end
    end

    def system(*cmd)
        return VIM::evaluate("integrake#runInShell(#{make_command(*cmd).to_vim})")
    end

    def sh(*cmd, &block)
        cmd.pop if cmd.last.is_a? Hash
        result = system(*cmd)
        if block_given?
            block.call(0 == result)
        else
            if 0 != result
                fail "Command failed with status (#{result}): [#{make_command(*cmd)}]"
            end
        end
    end
end

class IntegrakeEnvironment
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
            line = curbuf[line_number]
            from = 0
            to = line.length
            case $range[:type]
            when :char
                if $range[:line1 ]== line_number
                    from = $range[:col1 ]- 1
                end
                if $range[:line2 ]== line_number
                    to=$range[:col2 ]- 1
                end
            when :block
                while vim_call(:strdisplaywidth,line[0 ... from]) < $range[:vcol1]
                    from += 1
                end
                from -= 1
                to = 0
                while vim_call(:strdisplaywidth,line[0 ... to]) < $range[:vcol2]
                    to += 1
                end
                to -= 1
            end
            line[from ... to]
        end
    end

    def curwin
        return VIM::Window.current
    end

    def vim_call(function_name, *args)
        return VIM::evaluate("#{function_name}(#{args.map(&:to_vim).join(', ')})")
    end

    def method_missing(method_name, *args, &block)
        if Integrake.vim_exists?("*#{method_name}") #if it's a Vim function
            return vim_call(method_name, *args)
        elsif 2 == Integrake.vim_exists_code(":#{method_name.to_s.chomp('!')}") #if it's a Vim command
            VIM::command("#{method_name} #{args.join(' ')}")
        else
            super
        end
    end

    def do_and_return_to_this_window
        original_window = VIM::Window.current
        begin
            yield
        ensure
            original_window.jump
        end
    end

    def find_window_numbers(window_identifier)
        if window_identifier.is_a? Integer
            if 0 < window_identifier and window_identifier <= VIM::Window.count
                return [window_identifier]
            else
                return []
            end
        end

        if window_identifier.is_a? Array
            return window_identifier.flat_map{|single_identifier| find_window_numbers(single_identifier)}.compact.sort.uniq
        end

        if window_identifier.is_a? Regexp
            return VIM::Window.count.times.map do|i|
                if VIM::Window[i].buffer.name =~ window_identifier
                    i + 1
                end
            end.compact
        end

        if window_identifier.is_a? Proc
            if 0 == window_identifier.arity
                do_and_return_to_this_window do
                    return VIM::Window.count.times.map do|i|
                        VIM::command "#{i + 1}wincmd w"
                        if window_identifier.call
                            i + 1
                        end
                    end.compact
                end
            elsif window_identifier.arity <= 2
                identifier_proc = if 1 == window_identifier.arity
                                      window_identifier
                                  else
                                      lambda do|window_number|
                                          window_identifier.call window_number,VIM::Window[window_number - 1]
                                      end
                                  end
                return VIM::Window.count.times.map do|i|
                    if identifier_proc.call(i + 1)
                        i + 1
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
        return ({}) unless window_identifier
        if defined?(window_identifier.empty?)
            return ({}) if window_identifier.empty?
        end
        window_numbers = find_window_numbers(window_identifier)
        do_and_return_to_this_window do
            result = {}
            window_numbers.each do|window_number|
                VIM::command "#{window_number}wincmd w"
                result[window_number] = yield
            end
            return result
        end
    end

    def do_in_window(window_identifier, &block)
        return do_in_windows(find_window_number(window_identifier), &block).values.first
    end

    def input_list(prompt, options)
        take_from = 0
        while take_from < options.length
            take_this_time = VAR['&lines'] - 2
            more_items_remaining = take_from + take_this_time < options.length
            if more_items_remaining
                take_this_time -= 1
            end
            options_slice = options[take_from ... (take_from + take_this_time)]
            take_from += take_this_time

            number_length = options_slice.count.to_s.length

            list_for_input_query = (more_items_remaining ? options_slice + ["*MORE*"] : options_slice).each_with_index.map do|option, index|
                index_text = (index + 1).to_s
                "#{index_text})#{' '*(number_length - index_text.length)} #{option}"
            end
            list_for_input_query.unshift(prompt)
            chosen_option_number = VIM::evaluate("inputlist(#{list_for_input_query.to_vim})")

            if more_items_remaining and chosen_option_number == options_slice.length + 1
                puts ' '
                next
            elsif chosen_option_number < 1 or options_slice.length < chosen_option_number
                return nil
            else
                return options_slice[chosen_option_number - 1]
            end
        end
    end
end

VAR = Object.new
def VAR.[](varname)
    if Integrake.vim_exists?(varname)
        return VIM::evaluate(varname)
    else
        return nil
    end
end
def VAR.[]= (varname, value)
    Integrake.vim_write_var(varname, value)
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
        return "'#{self.to_s.gsub("'", "''").gsub("\n", '\'."\\n".\'')}'"
    end
end

class Array
    def to_vim
        return "[#{self.map(&:to_vim).join(',')}]"
    end
end

class Hash
    def to_vim
        return "{#{self.map{|k,v| "#{k.to_vim}: #{v.to_vim}"}.join(',')}}"
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

class VIM::Window
    def number
        VIM::Window.count.times.select do|i|
            if self == VIM::Window[i]
                return i + 1
            end
        end
        return nil
    end

    def jump
        target = self.number
        if target
            VIM::command "#{target}wincmd w"
        end
    end

    def do_in_here
        Integrake.environment.do_and_return_to_this_window do
            self.jump
            yield
        end
    end
end

class Rake::Task
    def direct_dependants
        search_next = application.top_level_tasks.clone
        already_searched = Set.new
        result = []

        until search_next.empty?
            task_name = search_next.pop
            tsk = Rake::Task[task_name]
            if tsk.prerequisites.include? self.name
                result << tsk
            end
            tsk.prerequisites.each do|prerequisite_name|
                if already_searched.add?(prerequisite_name)
                    search_next << prerequisite_name
                end
            end
        end

        result
    end

    def set_passed_data(passed_from, data)
        @integrake_data_from_prerequisite = {} unless @integrake_data_from_prerequisite
        @integrake_data_from_prerequisite[passed_from.to_s] = data
    end

    def pass_data(data)
        direct_dependants.each do|dd|
            dd.set_passed_data name.to_s,data
        end
    end

    def [](prerequisite_name)
        prerequisite_name = prerequisite_name.to_s
        if @integrake_data_from_prerequisite and @integrake_data_from_prerequisite.has_key?(prerequisite_name)
            return @integrake_data_from_prerequisite[prerequisite_name]
        elsif not(Rake::Task.task_defined? prerequisite_name)
            raise "No such task '#{prerequisite_name}'"
        elsif not(self.prerequisites.include? prerequisite_name)
            raise "Task '#{prerequisite_name}' is not a direct prerequisite of '#{name}'"
        else
            raise "Task '#{prerequisite_name}' did not pass any data to '#{name}'"
        end
    end

    def complete(*args, &block)
        @integrake_complete_functions = [] unless defined? @integrake_complete_functions
        if not args.empty?
            completer = Integrake.get_completer(args[0])
            raise "No completion method named #{args[0]}" unless completer
            @integrake_complete_functions << completer.call(*args[1 .. -1])
        elsif block
            @integrake_complete_functions << block
        else
            raise 'No completion method given'
        end
        return self
    end

    def get_completions(parts)
        return [] unless defined? @integrake_complete_functions
        result = []
        @integrake_complete_functions.each do|complete_function|
            begin
                result += complete_function.call(parts)
            rescue
            end
        end
        result.uniq!
        return result.uniq
    end
end

Rake.application.init
Rake.application.clear

module Integrake
    @@rakefile_name = nil
    @@rakefile_last_changed = nil
    @@loaded_files_last_changed = {}
    @@integrake_environment = IntegrakeEnvironment.new
    @@integrake_environment.instance_eval 'Object.include Kernel'
    @@integrake_environment.instance_eval 'Object.include Rake::DSL'

    def self.environment
        return @@integrake_environment
    end

    def self.vim_exists_code(identifier)
        return VIM::evaluate("exists('#{identifier}')")
    end
    def self.vim_exists?(identifier)
        return 0 != Integrake.vim_exists_code(identifier)
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

    def self.puts_error(error)
        if error.is_a? Exception
            Integrake.puts_error error.message
            error.backtrace.each do|bt|
                unless bt.start_with? __FILE__ or
                    bt.start_with? File.dirname(method(:task).source_location[0])
                    Integrake.puts_error bt
                end
            end
        else
            VIM::command('echohl Error')
            [*error].each do|e|
                VIM::command "echo #{e.to_vim}"
            end
            VIM::command('echohl None')
        end
        return false
    end

    def self.rakefile_name
        unless Integrake.vim_exists?('g:integrake_filePrefix')
            fail "You can't use Integrake until you set g:integrake_filePrefix"
        end
        return "#{VIM::evaluate('g:integrake_filePrefix')}.integrake"
    end

    def self.prepare
        rakefile_name = self.rakefile_name
        rakefile_last_changed = File.mtime(rakefile_name)

        if (rakefile_name != @@rakefile_name or rakefile_last_changed != @@rakefile_last_changed or
           @@loaded_files_last_changed.any?{|file,last_changed| File.mtime(file) != last_changed})

            @@loaded_files_last_changed = {}
            @@rakefile_name = rakefile_name
            @@rakefile_last_changed = rakefile_last_changed

            Rake.application.clear

            #Load auto-loaded .rb files from runtime path:
            VIM::evaluate('&runtimepath').split(',').map{|e| File.join(e, 'integrake')}.select{|e| File.directory?(e)}.each do|integrake_dir|
                Dir.foreach(integrake_dir).grep(/\.rb$/) do|f|
                    Integrake.load File.join(integrake_dir, f)
                end
            end

            begin
                @@integrake_environment.instance_eval IO.read(rakefile_name), rakefile_name
            rescue => exception
                @@rakefile_last_changed = nil
                Integrake.puts_error exception
                return false
            end

        else
            Rake::Task.tasks.each do|task|
                task.reenable
            end
        end
        return true
    end

    def self.load(filename)
        full_path = File.expand_path(filename)
        file_last_changed = File.mtime(full_path)
        @@loaded_files_last_changed[full_path] = file_last_changed
        Kernel.load(full_path)
    end

    def self.invoke_with_range(line1, line2, count, task, *args)
        $range=if -1<count
                   {
                       :type=>{
                           'v' => :char,
                           'V' => :line,
                           "\x16" => :block,
                       }[VIM::evaluate('visualmode()')],
                       :line1 => line1,
                       :line2 => line2,
                   }
               end
        if $range and [:char, :block].include?($range[:type])
            if $range[:line1] == @@integrake_environment.vim_call(:line, "'<") and $range[:line2] == @@integrake_environment.vim_call(:line, "'>")
                $range[:col1] = @@integrake_environment.vim_call(:col, "'<")
                $range[:col2] = @@integrake_environment.vim_call(:col, "'>")
                $range[:vcol1] = @@integrake_environment.vim_call(:virtcol, "'<")
                $range[:vcol2] = @@integrake_environment.vim_call(:virtcol, "'>")
            else
                $range[:type] = :line
            end
        end
        begin
            task.application.instance_variable_set :@top_level_tasks, [task.name]
            task.invoke(*args)
        ensure
            $range = nil
        end
    end

    def self.invoke(line1, line2, count, taskname, *args)
        if Integrake.prepare
            begin
                invoke_with_range(line1, line2, count, Rake::Task[taskname], *args)
            rescue => exception
                Integrake.puts_error exception
            end
        end
    end

    def self.prompt_and_invoke(line1, line2, count)
        if Integrake.prepare
            tasks=Rake::Task.tasks
            list_for_input_query=['Select task:'] + tasks.each_with_index.map do|t, i|
                "#{i + 1} #{t.name}#{
                    unless t.arg_names.empty?
                        "(#{t.arg_names.join(', ')})"
                    end
                }"
            end
            chosen_task_number = VIM::evaluate("inputlist(#{list_for_input_query.to_vim})")
            if chosen_task_number.between?(1, tasks.count)
                chosen_task = tasks[chosen_task_number - 1]
                known_args = []
                args = chosen_task.arg_names.map do|arg_name|
                    arg = VIM::evaluate("input(#{"#{[*known_args,''].join(', ')}#{arg_name}: ".to_vim})")
                    unless arg.empty?
                        known_args << "#{arg_name}: #{arg}"
                        arg
                    end
                end
                puts ' '
                begin
                    invoke_with_range(line1, line2, count, chosen_task, *args)
                rescue => exception
                    Integrake.puts_error exception
                end
            end
        end
    end

    def self.complete(arg_lead, cmd_line, cursor_pos, include_task_args)
        cmd_line_before_cursor = cmd_line[0 .. cursor_pos.to_i - 1]
        parts = cmd_line_before_cursor.scan(/(?:[^\\\s]|(?:\\\\)|(?:\\\s))+/).map{|part| part.gsub(/\\(.)/, '\1')}
        if cmd_line_before_cursor =~ /\s$/
            parts << ''
        end
        task_name_completion = parts.length == 2
        unless include_task_args or task_name_completion
            return []
        end
        if Integrake.prepare
            begin
                if task_name_completion
                    return Rake::Task.tasks.map{|e| e.name}.select{|e| e.start_with?(arg_lead)}
                else
                    task_name = parts[1]
                    begin
                        task = Rake::Task[task_name]
                    rescue
                        return []
                    end
                    def parts.filter_completions(completions)
                        completions.select{|completion| completion.start_with? self.last}
                    end
                    return task.get_completions(parts)
                end
            rescue => exception
                Integrake.puts_error exception
            end
        end
    end

    def self.prompt_to_grab
        rakefile_name = self.rakefile_name
        unless Integrake.vim_exists?('g:integrake_grabDirs')
            fail "You can't grab an Integrake file until you set g:integrake_grabDirs"
        end
        grab_sources = [*VIM::evaluate('g:integrake_grabDirs')]
        canadidate_files = grab_sources.flat_map do|src_dir|
            Dir.entries(src_dir).select{|e| e.end_with?('.integrake')}.map do|src_file|
                [src_dir, src_file]
            end
        end
        list_for_input_query = ['Select template for integrake_file:']+
            canadidate_files.each_with_index.map{|f, i| "#{i + 1} #{f[1]}"}
        chosen_file_number = VIM::evaluate("inputlist(#{list_for_input_query.to_vim})")
        if chosen_file_number.between?(1, canadidate_files.count)
            chosen_file = canadidate_files[chosen_file_number - 1]
            puts ' '
            buffer_to_update = nil
            if File.exists?(rakefile_name)
                if 'yes' != VIM::evaluate("input('#{rakefile_name} already exists! Type \"yes\" to override it: ')")
                    return
                end
                buffer_to_update = VIM::evaluate("bufnr(#{rakefile_name.to_vim})")
                buffer_to_update = nil if -1 == buffer_to_update
            end
            FileUtils.copy_file(File.join(chosen_file),rakefile_name)
            if buffer_to_update
                VIM::command("windo if #{buffer_to_update} == winbufnr(0) | edit | endif")
            end
        end
    end

    def self.edit_task(task_name)
        rakefile_name = self.rakefile_name
        if task_name.empty?
            VIM::command "edit #{rakefile_name}"
            return
        end
        if (exists = File.exists?(rakefile_name))
            Integrake.prepare
            task = Rake::Task[task_name] rescue nil
            if task
                task_parts = task.locations.first.split(':')
                VIM::command "edit #{task_parts[0]}"
                VIM::command task_parts[1].to_s
                return
            end
        end
        unless VIM::evaluate('expand("%")') == rakefile_name
            VIM::command "edit #{rakefile_name}"
        end
        last_line = VIM::Buffer.current.count
        if exists
            VIM::Buffer.current.append(last_line, "")
        else
            last_line -= 2
        end
        VIM::Buffer.current.append(last_line + 1, "task #{task_name.to_s.to_sym.inspect} do")
        VIM::Buffer.current.append(last_line + 2, "")
        VIM::Buffer.current.append(last_line + 3, "end")
        VIM::command (last_line + 3).to_s
    end



    class ChooseOptionTask < Rake::Task
        @@cache = {}
        def needed?
            return true
        end

        def self.define_task(name,options)
            options_captions = if options.is_a? Hash
                                   options.keys
                               else
                                   options
                               end
            options_strings = options_captions.map(&:to_s)
            tsk = Rake.application.define_task self, name, [:option] do|t, args|
                if options.is_a? Hash
                    @@cache.delete name if options[@@cache[name]].nil?
                else
                    @@cache.delete name unless options.include? @@cache[name]
                end
                if not args[:option].nil?
                    chosen_index = options_strings.index(args[:option])
                    chosen_option = if chosen_index.nil?
                                        puts "'#{args[:option]}' is not a valid option for #{name}"
                                        chosen_option = nil
                                    else
                                        options_captions[chosen_index]
                                    end
                    @@cache[name] = chosen_option
                elsif Rake.application.top_level_tasks.include?(name.to_s) or @@cache[name].nil?
                    #chosen_option = prompt_for_options(name, options_captions)
                    chosen_option = Integrake.environment.input_list("Chose #{name}:", options_captions)
                    @@cache[name] = chosen_option
                else
                    chosen_option = @@cache[name]
                end
                if options.is_a? Hash
                    t.pass_data(options[chosen_option])
                else
                    t.pass_data(chosen_option)
                end
            end
            tsk.locations << caller.select{|e| not e.start_with? __FILE__}.first

            tsk.complete :list, options_strings

            Rake.application.define_task self, :"#{name}?" do
                chosen_option = @@cache[name]
                if chosen_option.nil?
                    puts "#{name} not selected"
                else
                    puts "#{name}: #{chosen_option}"
                end
            end
        end

        private
        def self.prompt_for_options(name, options)
            number_length = options.count.to_s.length
            list_for_input_query = options.each_with_index.map do|option, index|
                index_text = (index + 1).to_s
                "#{index_text})#{' '*(number_length - index_text.length)} #{option}"
            end
            list_for_input_query.unshift("Chose #{name}:")
            chosen_option_number = VIM::evaluate("inputlist(#{list_for_input_query.to_vim})")
            if chosen_option_number < 1 or options.length < chosen_option_number
                return nil
            else
                return options[chosen_option_number - 1]
            end
        end
    end

    def self.option(name, *options)
        if 1 == options.length and options[0].is_a? Hash
            ChooseOptionTask::define_task name, options[0]
        else
            ChooseOptionTask::define_task name, options
        end
    end

    class PrepareWindowTask < Rake::Task
        def needed?
            return true
        end

        def self.define_task(*args,&block)
            tsk = Rake.application.define_task self, *args do|t, args|
                already_prepared_window = Integrake.environment.find_window_number -> do
                    VIM::evaluate('getwinvar(0, "integrake_preparedWindowForTask")').include? t.name
                end
                if already_prepared_window
                    t.pass_data VIM::Window[already_prepared_window - 1]
                else
                    Integrake.environment.do_and_return_to_this_window do
                        old_windows = VIM::Window.count.times.map{|i| VIM::Window[i]}
                        block.call t, args
                        if old_windows.include? VIM::Window.current
                            raise 'Window preparation command should create a new window'
                        end
                        t.pass_data VIM::Window.current
                        if 0 < VIM::evaluate('type([]) == getwinvar(0, "integrake_preparedWindowForTask")')
                            VIM::command "call add(w:integrake_preparedWindowForTask, #{t.name.to_vim})"
                        else
                            VIM::command "let w:integrake_preparedWindowForTask = [#{t.name.to_vim}]"
                        end
                    end
                end
            end
            tsk.locations << caller.select{|e|not e.start_with? __FILE__}.first
        end
    end

    def self.window(*args, &block)
        PrepareWindowTask::define_task *args, &block
    end

    def self.register_completer(name, &block)
        @@completers = {} unless defined? @@completers
        @@completers[name] = block
    end

    def self.get_completer(name)
        if defined? @@completers
            return @@completers[name]
        end
    end
end

filename_completer_creator = ->(root_path, dirs_only, for_arg_positions) do
    lambda do|parts|
        if for_arg_positions.nil? or for_arg_positions.include?(parts.length - 3)
            require 'shellwords'
            path_parts = split_all(parts.last)
            if parts.last.end_with? File::SEPARATOR or parts.last.end_with? '/'
                path_parts << ''
            end
            dir_parts = path_parts[0 .. -2]
            Dir.foreach(File.join(root_path, *dir_parts)).map do|filename|
                unless ['.', '..'].include? filename
                    if filename.start_with? path_parts.last
                        if File.directory? File.join(root_path, *dir_parts, filename)
                            File.join(*dir_parts, "#{Shellwords.escape(filename)}#{File::SEPARATOR}")
                        elsif not dirs_only
                            File.join(*dir_parts, Shellwords.escape(filename))
                        end
                    end
                end
            end.compact
        end
    end
end
Integrake.register_completer :file do|root_path = '.'|
    filename_completer_creator.call root_path, false, [0]
end
Integrake.register_completer :dir do|root_path = '.'|
    filename_completer_creator.call root_path, true, [0]
end
Integrake.register_completer :files do|root_path = '.'|
    filename_completer_creator.call root_path, false, nil
end
Integrake.register_completer :dirs do|root_path = '.'|
    filename_completer_creator.call root_path, true, nil
end
Integrake.register_completer :list do|items|
    lambda do|parts|
        parts.filter_completions(items)
    end
end
