if exists('g:loaded_tscwatch') | finish | endif " prevent loading file twice

let s:save_cpo = &cpo " save user coptions
set cpo&vim " reset them to defaults

" command to run our plugin
command! TscWatch lua require'tscwatch'.tscwatch()

let &cpo = s:save_cpo " and restore after
unlet s:save_cpo

let g:loaded_tscwatch = 1
