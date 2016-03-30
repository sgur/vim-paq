" paq.vim - Ghq based Plugin Loader
" Version: 0.5.0
" Author: sgur <sgurrr@gmail.com>
" License: MIT License

scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

if exists('g:loaded_paq') && g:loaded_paq
  finish
endif
let g:loaded_paq = 1


let s:sep_idx = stridx(&rtp, ',')
let &rtp = &rtp[: s:sep_idx] . expand('<sfile>:h') . &rtp[s:sep_idx :]


" Interfaces {{{1
command! -buffer -nargs=+ Paq  call paq#add(<args>)
command! -buffer -nargs=1 -complete=dir PaqGlob  call paq#glob(<args>)


command! -nargs=0 Helptags  call paq#helptags()
command! -complete=customlist,paq#help_complete -nargs=* Help  call paq#help(<q-args>)

command! -nargs=0 PaqRepos call paq#repos()
command! -nargs=0 PaqMessages  call paq#message()
command! -nargs=1 -complete=customlist,s:list_complete -bar PaqEnable
      \ call paq#enable(<q-args>)
" 1}}}


let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et:
