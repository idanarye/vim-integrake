command! -complete=customlist,integrake#complete -nargs=* IR call integrake#invoke(<f-args>)
command! -nargs=0 IRgrab call integrake#grabIntegrakeFile()
command! -complete=customlist,integrake#complete -nargs=? IRedit call integrake#editTask(<q-args>)
