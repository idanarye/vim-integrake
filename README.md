REQUIREMENTS
============

 * Ruby installed on your computer(Tested with Ruby 1.9 and 2.0)
 * Vim compiled with ruby support(check with `:echo has('ruby')` from Vim)
 * Rake gem installed(install with `gem install rake` from the command line)

INTRODUCTION
============

Build systems were originally created to script the build process, but they
can do much more - they are actually a great way to organize and run all the
project-specific, development-related scripts. You can keep all the scripts
for running the project, running unit-tests, cleaning, deploying etc. as
different tasks(or targets) in a single build file, and easily run specific
tasks from the command-line.

Integrake takes this one step farther - it uses Vim's ruby interface and
the Rake API to load Rakefiles and run Rake tasks inside the Vim environment.
Integrake tasks, are written in Ruby - which means power, elegance and access
to any gem you want - and executed in the environment of the current Vim
instance - which means you can interact with the buffers, change settings,
modify global Vim variables and execute the commands of your Vim plugins.

Integrake also assists in creation and editing those Integrake tasks, and
allows you to easily copy project-type-general Integrake file that you made in
advance.

For example - you might always want a `:run` task that runs your project with
specific input(that you often change) and see if it behaves like you want.

 * If the project is a command line application - you will simply want execute it in
   a shell. Nothing fancy here.
 * If it's a web service, you want to send an HTTP request to it and
   display the result. Since Integrake is written with Ruby, you can use Ruby's
   default HTTP library - install an alternative, easier-to-use library using
   RubyGems - to easily send that request.
 * Some languages and frameworks are painful to run from the command line, but
   have a Vim plugin that helps running their projects. Since Integrake runs in
   the environment of the current Vim instance, you can use those plugins from
   inside the :run task.

Since you always use the same task name - `:run` - you can have a global key
mapping that runs your project in the appropriate way, no matter which type of
project it is. And since the task is defined in a file in the project's
directory, you can easily change the run arguments to test different things in
your project, without having to remap the key.


INTEGRAKE IS NOT A BUILD SYSTEM!
================================

Rake is a build system - an awesome build system! But Integrake is not a build
system. Integrake uses Rake, so you can use Integrake as a build system - but
you shouldn't.

One of the most important merits of using a build system is that it makes it
easier for new developers to join the project. You don't have to explain to
them how to configure their IDE(and force them to use the same IDE you use),
how to compile the files, how to do the post-compilation preparations(like
running source generators) and in which order. All they need to do is to get
the source, install build system, and run a few build system tasks.

Integrake's advantage over using Rake directly is it's access to Vim's
environment. If you access Vim tasks in your build tasks, you are forcing
other developers into using Vim(Vim is awesome, but there are enough
developers who don't want to use it). If you access plugin commands in your
build tasks, you are also forcing them to install the same plugins you have,
and possibly configure them the same way.

Luckily, access to the Vim environment is much more useful in the run-test
related Inegrake tasks, and provide very little value in the build tasks. That
means you can keep your build tasks clean of Vim interaction and plugin
commands. But if you do that - you might as well put them in a proper
Rakefile - so people can use Rake normally - and use `Integrake.load` to
import that Rakefile in your Integrake file. Alternatively, you can run the
Rake tasks as shell commands(using `sh`).



CONFIGURATION
=============

Integrake files are personal, so if two developers work on the same project,
they need two different Integrake files. To easily differentiate between the
Integrake files of different developers, each developer should set a prefix
using the `g:integrake_filePrefix` global variable. It's a good idea to use
your name the prefix - so other developers will know that file belongs to you -
and to start it with `.`, so it will be hidden by the operation system(unless
you use Windows) and by plugins like NERDTree.

Example:
```vim
let g:integrake_filePrefix = '.idanarye'
```
If you want to use `integrake-templates` - premade files that you can easily
grab for new projects - you need to set `g:integrake_grabDirs` to a
directory(or a list of directories) that contain those templates.

Example:
```vim
let g:integrake_grabDirs = [expand('<sfile>:p:h').'/my-configurations/integrake-templates']
```

CREATING TASKS
==============

Integrake tasks are written in the Integrake file. The Integrake file must be
at the current directory(=the root of the project) and it's name is the value
of `g:integrake_filePrefix` plus the `.integrake` suffix.

You can use the `IRedit` command to open your Integrake file for editing. You
can optionally supply a task name as an argument to jump directly to the
definition of an existing task, or to automatically create a new empty task.

`IRsedit` and `IRvedit` are work similarly, except they open the Integrake
buffer in a horizontally or vertically split window.

The syntax for the Integrake file is the same as a Rakefile syntax. You can
read more about Rake syntax at [http://rake.rubyforge.org/]


RUNNING TASKS
=============

Use the `IR` command to run tasks.

`IR` with no arguments displays a list of tasks. Selecting a task from the
list will prompt you to enter the arguments(if the task has any arguments) and
then run the tasks(with the supplied arguments).

`IR` with arguments runs a task directly. The first argument is the name of
the task to run. The other arguments are sent to the task as task arguments.

If `IR` is called with a range, the Integrake task will have access to that
range via the `$range` variable.


TEMPLATES
=========

Integrake has a very basic template system. Template files are static - if you
need dynamic templates you can use a proper templating plugin.

To use the template system, you first need to configure `g:integrake_grabDirs`.
Put the template files in the folders specified there. The template files
should be the description of that template file - usually the language or
framework that template file targets - followed by `.integrake`.

The `IRgrab` command displays your list of template files. When you choose a
file, it copies that file as is to be your Integrake file for the current
project. If you already have an Integrake file for the current project, you
will be prompted to override it.


RUBY HELPERS
============

the `system` and `sh` commands were change to delegate the execution to Vim.
Otherwise you could not use the input and output.

`cmd` is a wrapper around `VIM::command` and `evl` is a
wrapper around `VIM::evaluate`.

`curbuf` is a wrappwer around `VIM::Buffer.current` and `curwin` is a wrapper
around `VIM::Windows.current`.

`selection` returns the selected text, if `IR` is called with a range.

Any vim function can be called directly from Integrake by using the function's
name. Example:
```ruby
puts expand('%')
```
will print the name of the current file.

Any vim command can be called directly from Integrake by using the command's
full name. Example:
```ruby
edit 'foo.txt'
```
will edit the file `foo.txt`. The arguments are not escaped, so
```ruby
echo 'hello'
```
will not print `hello` - it will try to print a variable named `hello`. To
print the string `hello` with `echo`, use
```ruby
echo '"hello"'
```

`var` can be used like an hash to read and write variables. Example:
```ruby
var['g:foo'] = 12
cmd 'echo g:foo' #prints 12
cmd 'let g:foo = 14'
puts var['g:foo'] #prints 14
```

`to_vim` will turn any object into a VimScript literal. Ruby strings and
numbers are converted directly to Vim strings and numbers. Ruby arrays are
converted to Vim lists. Ruby hashes are converted to Vim dictionaries. Ruby
`nil` and `false` are converted to 0, and Ruby `true` is converted to 1.
Everything else is converted to a string.


`find_window_numbers` scans the window numbers and returns an ordered and
unique list of the window numbers(1-based, like in Vim's `window-functions`) of the
windows that fulfill the criterion specified in the argument:
 - If the argument is an integer, check that it is in the range of valid
   window numbers and return it.
 - If the argument is an array, return all window number that fulfill any one
   of the entries.
 - If the argument is a regular expression, return all window numbers that
   their buffer name matches that regex.
 - If the argument is a proc, use that proc as a predicate to determine which
   window numbers to return:
   - For argument-less procs, enter each window and run the predicate in the
     context of the window.
   - For procs with a single argument, remain in the current window and send
     the window number to the predicate.
   - For procs with two arguments, remain in the current window and send
     the window number and the VIM::Window object to the predicate.

`find_window_number` is like `find_window_numbers` but returns only the first
result(or nil for no matches)

`do_in_windows` runs `find_window_numbers` on it's argument and runs it's block
in the context of the returned windows. It returns an Hash where the keys are
the window numbers and the values are the results of the block ran in each
window.

`do_in_window` runs `find_window_number` on it's argument and runs it's block
in the context of the returned window. It returns the result of the block.

`input_list` is an improved version of Vim's `inputlist()`. It accepts two
arguments - `prompt` and `options` - where "prompt" is the text to put at the
top and "options" is the list of options to let the user choose from.
Improvements over Vim's `inputlist()`:
 - Option 0 is always the prompt - so we can tell the difference between
   user-chose-nothing and user-chose-the-first-option.
 - Selection numbers are displayed next to the selections, to let the user
   know what to type.
 - If there are too many options to fit in the screen, `input_list` displays
   only as much options as can be fit in the screen, with a `*MORE*` option
   for displaying the next bunch.
 - The returned value is not the number the user has typed, but the item from
   the list(or nil if the user chose nothing)


LOADING RUBY FILES
==================

To load a Ruby file that might change in Integrake use `Integrake.load`
instead of Ruby's `load`. this will ensure that if the file is changed it will
be reloaded.

You can also put \*.rb files in `integrake` directories in Vim's runtime path to
make Integrake load them automatically.


PASSING DATA FROM PREREQUISITES
===============================

Integrake has a mechanism for passing data from prerequisite tasks to the task
that called them. The data is passed only to task that has the passer as a
direct prerequisite(though task higher in the chain can add that prerequisite,
and it'll only be called once and pass the same data to all the tasks that
require it).

To pass data, from the prerequisite task call the `pass_data` method of the
task object(the first argument to the Ruby block defining the task). To use
that data in the caller task, use the subscript operator of the caller task
object with the name of the task that passed the data. So, if this is our
integrake file:
```ruby
task :data_passer do|t|
    t.pass_data 'some data'
end

task :data_user => [:data_passer] do|t|
    puts t[:data_passer]
end
```
Calling `:IR data_user` will print "some data".


OPTIONS CHOOSER TASKS
=====================

Integrake's options chooser tasks allows you to define options you can use in
your tasks, with a selection interface that remembers your decisions for
minimal interference with your workflow. To create such an option, use the
`Integrake.option` method, where the first argument is the name of the option
and the rest of the arguments are the options to choose from:
```ruby
Integrake.option :color, :red,:green,:blue

task :print_chosen_color => [:color] do|t|
    puts t[:color]
end
```
With this, when we first run `:IR print_chosen_color` we are prompted to
choose a color, and then that color name is printed. If we run it again - we
get the same color without being prompted! If we want to be prompted again, we
need to run `:IR color` directly.

You can also use hash arguments:
```ruby
Integrake.option :number,
    'ten' => 10,
    'twenty' => 20
```
With this, the keys will be displayed when you are prompted, but the data
you'll get with the subscript operator is the value of the chosen key.

When running the task directly, you can also pass the chosen option as an
argument.

Integrake.option will also create a task with the same name + a question
mark(e.g. `:color?` and `:number?`), which will print the currently chosen option.


WINDOW PREPARATION TASKS
========================

Sometimes you need a window to be there before you run a plugin. For example,
using the vimshell plugin, you might want to open a vimshell terminal and
run "make" in it. However, you don't want to open the terminal if it's alredy
open. So - you use the `Integrake.window` helper to build a window preparation
task:

```ruby
Integrake.window :'open-shell' do
    VimShellCreate '-split'
end

task :build => :'open-shell' do|t|
    VimShellSendString 'make'
end
```

With this, when we run `:IR build` it'll first call the "open-shell" task,
which will create the vimshell window, and then run "make" in it. If we call it
again, it'll recognize the window is already open and not create it again.  But
if we close the vimshell window and run it, it won't be able to find that
window and reopen it. That way the "build" task will always have a vimshell
window, be it a freshly created one or an already existing one.

A window preparation task will use the integrake `pass_data` mechanism to pass
the window object of that window.

A window preparation task must end when the active window is a new window. If
the active window already existed before the task the task will fail.


AUTO COMPLETION
===============

Integrake supports custom autocompletion for task arguments. To create a
custom completion call the "complete" method of the task object, and pass to
it a block that accepts the array of the command parts before the
cursor(including `IR` and the task name) and returns a list of completions.
Take note that Integrake does not filter your results to match the argument
you are trying to complete - but `parts` has the `filter_completions` method
that does just that.

The following example will add autocompletion for the colors "red", "green"
and "blue" to the task `print_color`:

```ruby
task :print_color, [:color] do|t, args|
    puts args[:color]
end.complete do|parts|
    parts.filter_completions(['red', 'green', 'blue'])
end
```


You can also use prepared autocompletion by passing the prepared
autocompletion name as the first argument to `complete`. For example, to
complete a single file use:

```ruby
task :file_size, [:filename] do|t, args|
    puts File.stat(args[:filename]).size
end.complete :file
```

The prepared autocompletion supplied with Integrake are:

 - `:file` - filename for the first argument. Accepts a second argument as the
   root for searching.
 - `:files` - filename for all arguments. Accepts a second argument as the root
   for searching.
 - `:dir` - directory for the first argument. Accepts a second argument as the
   root for searching.
 - `:dirs` - directory for all arguments. Accepts a second argument as the root
   for searching.
 - `:list` - items from a list for all arguments. Accepts a second argument as
   the list of completion possibilities.

To create your own prepared autocompletion, use
`Integrake.register_completer`. Pass to it as argument the name of the
completer, and it's block should accept completer arguments and return a
callable object that accepts the `parts` argument and will serve as the
completer itself. So, the `print_color` task from before could be created like
so:

```ruby
Integrake.register_completer :color do|*colors|
    lambda do|parts|
        parts.filter_completions(colors)
    end
end

task :print_color, [:color] do|t, args|
    puts args[:color]
end.complete :color, 'red', 'green', 'blue'
```
