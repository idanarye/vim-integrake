function! integrake#runInShell(cmd)
    execute '!'.a:cmd
    return v:shell_error
endfunction

function! integrake#invoke(...)
    if a:0>0
        ruby Integrake.invoke(*VIM::evaluate('a:000'))
    else
        ruby Integrake.prompt_and_invoke
    endif
endfunction

function! integrake#complete(argLead,cmdLine,cursorPos)
    ruby Integrake.vim_return_value(Integrake.complete(*Integrake.vim_read_vars('a:argLead','a:cmdLine','a:cursorPos')))
endfunction

ruby load File.join(VIM::evaluate("expand('<sfile>:p:h')"),'integrake.rb')
