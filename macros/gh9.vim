scriptencoding utf-8

if exists('g:loaded_gh9_util') && g:loaded_gh9_util
  finish
endif
let g:loaded_gh9_util = 1

" Interfaces {{{1
let g:gh9_create_shallow_clone= get(g:, 'gh9_create_shallow_clone', 1)

command! -complete=customlist,s:import_complete -nargs=* -bang GhqInstall
      \ call s:cmd_import(<bang>0, <f-args>)

command! -complete=customlist,s:update_complete -nargs=* GhqUpdate
      \ call s:cmd_import(1, <f-args>)


" Internals {{{1
" Commands {{{2
function! s:cmd_import(update, ...) "{{{
  let list = a:0 > 0 ? copy(a:000) : filter(keys(gh9#repos()), '!isdirectory(v:val)')
  let more = &more
  try
    set nomore
    if a:update
      call filter(list, 's:has_path(v:val)')
    endif
    call filter(list, '!get(gh9#repos(v:val), "pinned", 0)')
    echohl Title | echo 'ghq import:' | echohl NONE
    call s:invoke_ghq_import(copy(list))
    echohl Title | echo 'git submodule update:' | echohl NONE
    call s:update_submodules(map(copy(list), 's:get_path(v:val)'))
  finally
    let &more = more
  endtry
endfunction "}}}

" Completion {{{2
function! s:import_complete(arglead, cmdline, cursorpos) "{{{
  return filter(keys(gh9#repos()), 'stridx(v:val, a:arglead) > -1 && !isdirectory(v:val)')
endfunction "}}}

function! s:update_complete(arglead, cmdline, cursorpos) "{{{
  return filter(keys(gh9#repos()), 'stridx(v:val, a:arglead) > -1 && !isdirectory(v:val) && s:has_path(v:val)')
endfunction "}}}

" Invoking {{{2
function! s:invoke_ghq_import(dirs) "{{{
  for dir in a:dirs
    let cmd = printf('ghq get -u %s %s'
          \ , g:gh9_create_shallow_clone ? '--shallow' : '', dir)
    for line in split(iconv(system(cmd), &termencoding, &encoding), "\n")
      echomsg line
    endfor
  endfor
endfunction "}}}

function! s:update_submodules(dirs) "{{{
  let cwd = getcwd()
  try
    for dir in a:dirs
      if !filereadable(expand(dir . '/.gitmodules' ))
        continue
      endif
      lcd `=dir`
      for line in split(iconv(system('git submodule update --init'), &termencoding, &encoding), "\n")
        echomsg line
      endfor
    endfor
  finally
    lcd `=cwd`
  endtry
endfunction "}}}

" Repos {{{2
function! s:has_path(name)
  let repo = gh9#repos(a:name)
  return has_key(repo, '__path') && !empty(repo.__path)
endfunction

function! s:get_path(name) " {{{
  return gh9#repos(a:name).__path
endfunction " }}}

" 2}}}
" 1}}}
