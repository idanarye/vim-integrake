function! integrake#runInShell(cmd)
    execute '!'.a:cmd
    return v:shell_error
endfunction

function! integrake#invoke(line1, line2, count, ...)
    if a:0 > 0
        ruby Integrake.invoke(*Integrake.vim_read_vars('a:line1', 'a:line2', 'a:count'), *VIM::evaluate('a:000'))
    else
        ruby Integrake.prompt_and_invoke(*Integrake.vim_read_vars('a:line1', 'a:line2', 'a:count'))
    endif
endfunction

function! integrake#grabIntegrakeFile()
    ruby Integrake.prompt_to_grab
endfunction

function! integrake#editTask(task)
    ruby Integrake.edit_task(VIM::evaluate('a:task'))
endfunction

function! integrake#editTask_split(task)
    split
    ruby Integrake.edit_task(VIM::evaluate('a:task'))
endfunction

function! integrake#editTask_vsplit(task)
    vsplit
    ruby Integrake.edit_task(VIM::evaluate('a:task'))
endfunction

function! integrake#complete(argLead, cmdLine, cursorPos)
    ruby Integrake.vim_return_value(Integrake.complete(*Integrake.vim_read_vars('a:argLead', 'a:cmdLine', 'a:cursorPos'), false))
endfunction

function! integrake#completeIncludeTaskArgs(argLead, cmdLine, cursorPos)
    ruby Integrake.vim_return_value(Integrake.complete(*Integrake.vim_read_vars('a:argLead', 'a:cmdLine', 'a:cursorPos'), true))
endfunction

ruby load File.join(VIM::evaluate("expand('<sfile>:p:h')"), 'integrake.rb')
