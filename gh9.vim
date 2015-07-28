" gh9.vim - Ghq based Plugin Loader
" Version: 0.3.0
" Author: sgur <sgurrr@gmail.com>
" License: MIT License

scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

if exists('g:loaded_gh9') && g:loaded_gh9
  finish
endif
let g:loaded_gh9 = 1


" Interfaces {{{1
command! -nargs=0 GhqRepos call s:cmd_repo2stdout()
command! -nargs=0 Helptags  call s:cmd_helptags()
command! -nargs=0 GhqMessages  call s:message(s:INFO, 's:echo')
command! -complete=customlist,s:help_complete -nargs=* Help
      \ call s:cmd_help(<q-args>)
nnoremap <silent> K  :<C-u>call <SID>map_tryhelp("<C-r><C-w>")<CR>

function! gh9#begin(...) "{{{
  call s:cmd_init()
  command! -buffer -nargs=+ Ghq  call s:cmd_bundle(<args>)
  command! -buffer -nargs=1 -complete=dir GhqGlob  call s:cmd_globlocal(<args>)
endfunction "}}}

function! gh9#end(...) "{{{
  delcommand Ghq
  delcommand GhqGlob
  command! -nargs=1 Ghq  call s:cmd_force_bundle(<args>)
  command! -nargs=1 -complete=dir GhqGlob  call s:cmd_force_globlocal(<args>)
  call s:cmd_apply(a:0 ? a:1 : {})
endfunction "}}}

function! gh9#tap(bundle) "{{{
  if !has_key(s:repos, a:bundle)
    let msg = printf('no repository found on gh9#tap("%s")', a:bundle)
    if has('vim_starting')
      call s:log(s:WARNING, msg)
    else
      echohl WarningMsg | echomsg msg | echohl NONE
    endif
    return 0
  endif
  if !&loadplugins | return 0 | endif

  if isdirectory(s:get_path(a:bundle)) && get(s:repos[a:bundle], 'enabled', 1)
    return 1
  endif
  return 0
endfunction "}}}

function! gh9#repos(...) "{{{
  return deepcopy(a:0 > 0 ? s:repos[a:1] : s:repos)
endfunction "}}}

" Internals {{{1
" Commands {{{2
function! s:cmd_init() "{{{
  if !exists('s:rtp') | let s:rtp = &runtimepath | endif
  let s:ghq_root = exists('$GHQ_ROOT') && isdirectory(expand($GHQ_ROOT))
        \ ? expand($GHQ_ROOT) : s:find_ghq_root()
endfunction "}}}

function! s:cmd_bundle(bundle, ...) "{{{
  if empty(a:bundle) | return | endif
  let repo = !a:0 ? {} : (!empty(a:1) && type(a:1) == type({}) ? a:1 : {})
  let s:repos[a:bundle] = repo
  if get(repo, 'immediately', 0)
    let &runtimepath .= ',' . s:get_path(a:bundle)
  endif
endfunction "}}}

function! s:cmd_globlocal(dir) "{{{
  if !isdirectory(expand(a:dir))
    echohl WarningMsg | echomsg 'Not found:' a:dir | echohl NONE
    return
  endif
  call map(filter(s:globpath(a:dir, '*'), '!s:is_globskip(v:val)'), 'extend(s:repos, {v:val : {}})')
endfunction "}}}

function! s:cmd_apply(config) "{{{
  if !&loadplugins | return | endif

  let [dirs, ftdetects, plugins, commands] = s:parse_repos(a:config)
  call s:set_runtimepath(dirs)
  call map(ftdetects, 's:source_script(v:val)')
  call map(commands, 's:define_pseudo_commands(v:val[0], v:val[1])')

  augroup plugin_gh9
    autocmd!
    autocmd FileType *  call s:on_filetype(expand('<amatch>'))
    autocmd FuncUndefined *  call s:on_funcundefined(expand('<amatch>'))
    if !empty(plugins)
      let s:on_vimenter_plugins = plugins
      autocmd VimEnter *  call s:on_vimenter()
    endif
  augroup END
endfunction "}}}

function! s:cmd_helptags() "{{{
  let dirs = filter(map(keys(s:repos), 'expand(s:get_path(v:val) . "/doc")'), 'isdirectory(v:val)')
  echohl Title | echo 'helptags:' | echohl NONE
  for dir in filter(dirs, 'filewritable(v:val) == 2')
    echon ' ' . fnamemodify(dir, ':h:t')
    execute 'helptags' dir
  endfor
endfunction "}}}

function! s:cmd_repo2stdout() "{{{
  new
  setlocal buftype=nofile
  call append(0, keys(filter(deepcopy(s:repos), '!isdirectory(v:key) && !get(v:val, "pinned", 0)')))
  normal! Gdd
  execute '%print'
  bdelete
endfunction "}}}

function! s:cmd_help(term) "{{{
  let rtp = &rtp
  try
    let &rtp = join(map(values(s:repos), 'v:val.__path'),',')
    execute 'help' a:term
    source $VIMRUNTIME/syntax/help.vim " HACK: force enable syntax
  catch /^Vim\%((\a\+)\)\=:E149/
    echohl WarningMsg | echomsg 'gh9: Sorry, no help for ' . a:term | echohl NONE
  finally
    let &rtp = rtp
  endtry
endfunction "}}}

function! s:cmd_nop() "{{{
endfunction "}}}

function! s:map_tryhelp(word) "{{{
  try
    execute 'help' a:word
  catch /^Vim\%((\a\+)\)\=:E149/
    execute 'Help' a:word
  endtry
endfunction "}}}

function! s:cmd_force_bundle(bundle) "{{{
  if empty(a:bundle) | return | endif
  let s:repos[a:bundle] = {'__loaded': 1, '__temprorary': 1}
  call s:get_path(a:bundle)
  call s:inject_runtimepath([s:get_path(a:bundle)])
endfunction "}}}

function! s:cmd_force_globlocal(dir) "{{{
  if !isdirectory(expand(a:dir))
    echohl WarningMsg | echomsg 'Not found:' a:dir | echohl NONE
    return
  endif
  let dirs = filter(s:globpath(a:dir, '*'), '!s:is_globskip(v:val)')
  call s:inject_runtimepath(dirs)
  call map(dirs, 'extend(s:repos, {v:val : {}})')
endfunction "}}}

" Completion {{{2
function! s:help_complete(arglead, cmdline, cursorpos) "{{{
  let tags = &l:tags
  try
    if !exists('s:tagdirs')
      let s:tagdirs = join(filter(map(values(s:repos), 'v:val.__path . "/doc/tags"'), 'filereadable(v:val)'),',')
    endif
    let &l:tags = s:tagdirs
    return map(taglist(empty(a:arglead)? '.' : a:arglead), 'v:val.name')
  finally
    let &l:tags = tags
  endtry
endfunction "}}}

" Autocmd Events {{{2
function! s:on_vimenter() "{{{
  autocmd! plugin_gh9 VimEnter *
  call map(get(s:, 'on_vimenter_plugins', []), 's:source_script(v:val)')
  if !empty(s:log)
    call s:message(s:WARNING, 's:echomsg_warning')
  endif
endfunction "}}}

function! s:on_funcundefined(funcname) "{{{
  let dirs = []
  for [name, params] in items(s:repos)
    if !get(params, 'enabled', 1) || get(params, '__loaded', 0) || !has_key(params, 'autoload')
      continue
    endif
    if stridx(a:funcname , params.autoload) == 0
      call s:log(s:INFO, printf('loading %s on autoload[%s] (%s)', name, params.autoload, a:funcname))
      let dirs += [s:get_path(name)]
      let params.__loaded = 1
    endif
  endfor
  call s:inject_runtimepath(dirs)
endfunction "}}}

function! s:on_filetype(filetype) "{{{
  let dirs = []
  for [name, params] in items(s:repos)
    if !get(params, 'enabled', 1) || get(params, '__loaded', 0) || !has_key(params, 'filetype')
      continue
    endif
    if s:included(params.filetype, a:filetype)
      call s:log(s:INFO, printf('loading %s on filetype[%s]', name, a:filetype))
      let dirs += [s:get_path(name)]
      let params.__loaded = 1
    endif
  endfor
  call s:inject_runtimepath(dirs)
endfunction "}}}

" Repos {{{2
function! s:parse_repos(global) "{{{
  let [dirs, ftdetects, plugins, commands] = [[], [], [], []]
  for [name, params] in items(s:repos)
    call extend(params, a:global, 'keep')
    let path = has_key(params, 'rtp') ? join([path, params.rtp], '/') : s:get_path(name)
    if empty(path) || !get(params, 'enabled', 1)
      continue
    endif

    if has_key(params, 'filetype')
      let ftdetects += s:globpath(path, 'ftdetect/**/*.vim')
    endif

    let preload = has_key(params, 'preload') ? params.preload : 0
    let triggered = 0
    if has_key(params, 'filetype') || has_key(params, 'autoload')
      let plugins += preload ? s:get_preloads(path) : []
      let triggered = 1
    endif
    if has_key(params, 'command')
      let commands += [[params.command, name]]
      let triggered = 1
    endif
    if !triggered
      let dirs += [path]
      let params.__loaded = 1
    endif
  endfor
  return [dirs, ftdetects, plugins, commands]
endfunction "}}}

function! s:find_ghq_root() "{{{
  let gitconfig = readfile(expand('~/.gitconfig'))
  let ghq_root = filter(map(gitconfig, 'matchstr(v:val, ''root\s*=\s*\zs.*'')'), 'v:val isnot""')
  return !empty(ghq_root) ? ghq_root[0] : expand('~/.ghq')
endfunction "}}}

function! s:get_path(name) " {{{
  let repo = get(s:repos, a:name, {})
  if !has_key(repo, '__path')
    let repo.__path = s:find_path(a:name, get(repo, 'host', ''))
  endif
  return repo.__path
endfunction " }}}

function! s:find_path(name, prefix) "{{{
  if isdirectory(a:name)
    return a:name
  endif
  let repo_name = s:repo_url(a:name, a:prefix)
  let path = expand(join([s:ghq_root, repo_name], '/'))
  if isdirectory(path)
    return path
  endif
  call s:log(s:INFO, 'no directory found: ' . a:name)
  return ''
endfunction "}}}

function! s:repo_url(name, prefix) "{{{
  return printf("%s/%s", empty(a:prefix) ? 'github.com' : a:prefix, a:name)
endfunction "}}}

function! s:validate_repos() "{{{
  let validation_keys = ['filetype', 'enabled', 'immediately', 'autoload', 'rtp', 'pinned', '__path', '__loaded']
  for [name, params] in items(s:repos)
    for key in keys(params)
      if index(validation_keys, key) == -1
        echohl ErrorMsg | echomsg 'Invalid Key:' name key | echohl NONE
      endif
    endfor
  endfor
endfunction "}}}

" RTP {{{2
function! s:source_script(path) "{{{
  source `=a:path`
endfunction "}}}

function! s:inject_runtimepath(dirs) "{{{
  for d in a:dirs
    call s:log(s:INFO, printf('s:inject_runtimepath %s', d))
  endfor
  let &runtimepath = s:rtp_generate(a:dirs)
  for plugin_path in s:globpath(join(a:dirs,','), 'plugin/**/*.vim') + s:globpath(join(a:dirs,','), 'ftplugin/**/*.vim')
        \ + s:globpath(join(a:dirs,','), 'after/plugin/**/*.vim') + s:globpath(join(a:dirs,','), 'after/ftplugin/**/*.vim')
    execute 'source' plugin_path
  endfor
endfunction "}}}

function! s:set_runtimepath(dirs) "{{{
  if !exists('s:rtp')
    let s:rtp = &runtimepath
  endif
  let &runtimepath = s:rtp
  let &runtimepath = s:rtp_generate(a:dirs)
endfunction "}}}

function! s:rtp_generate(paths) "{{{
  let after_rtp = s:glob_after(join(a:paths, ','))
  let rtps = split(&runtimepath, ',')
  call extend(rtps, a:paths, 1)
  call extend(rtps, after_rtp, -1)
  return join(rtps, ',')
endfunction "}}}

function! s:glob_after(rtp) "{{{
  return s:globpath(a:rtp, 'after')
endfunction "}}}

function! s:get_preloads(name) "{{{
  let _ = []
  for plugin_path in s:globpath(a:name, 'plugin/**/*.vim')
    let _ += [plugin_path]
  endfor
  return _
endfunction "}}}

" Command {{{2
function! s:define_pseudo_commands(commands, name) "{{{
  let commands = type(a:commands) == type([]) ? a:commands : [a:commands]
  for command in commands
    let cmd = command.name
    if get(command, 'bang', 0)
      let bang = command.bang
    endif
    let attr = map(filter(copy(command), 'v:key isnot# "bang" && v:key isnot# "name"'), 'printf("-%s=%s", v:key, v:val)')
    execute 'command!' join(values(attr), ' ') (exists('bang') ? '-bang' : '') cmd
          \ printf('call s:pseudo_command(%s, %s, %s, %s)', string(a:name), string(cmd), "'<bang>'", "<q-args>")
  endfor
endfunction "}}}

function! s:pseudo_command(name, cmd, bang, args) "{{{
  execute 'delcommand' a:cmd
  call s:log(s:INFO, printf('loading %s on command[%s]', a:name, a:cmd))
  call s:inject_runtimepath([s:get_path(a:name)])
  execute a:cmd . a:bang a:args
endfunction "}}}

" Misc {{{2
function! s:is_globskip(dir) "{{{
  return has_key(s:repos, a:dir) || a:dir =~# '\~$'
endfunction "}}}

function! s:globpath(path, expr) "{{{
  return has('patch-7.4.279') ? globpath(a:path, a:expr, 0, 1) : split(globpath(a:path, a:expr, 1))
endfunction "}}}

function! s:systemlist(cmd) "{{{
  return exists('*systemlist') ? systemlist(a:cmd) : split(system(a:cmd), "\n")
endfunction "}}}

function! s:to_list(value) "{{{
  if type(a:value) == type([])
    return a:value
  else
    return [a:value]
  endif
endfunction "}}}

function! s:included(values, name) "{{{
  let values = type(a:values) == type([]) ? a:values : [a:values]
  return len(filter(split(a:name, '\.'), 'index(values, v:val) >= 0')) > 0
endfunction "}}}

function! s:log(level, msg) "{{{
  let s:log += [[a:level, localtime(), a:msg]]
endfunction "}}}

function! s:message(threshold, funcname) "{{{
  for [level, time, msg] in s:log
    if a:threshold >= level
      call call(a:funcname, [time, printf('[%s] %s', s:lvl2str(level), msg)])
    endif
  endfor
endfunction "}}}

function! s:echo(time, msg) "{{{
  execute 'echo' string(printf('%s| %s', strftime('%c', a:time), a:msg))
endfunction "}}}

function! s:echomsg_warning(time, msg) "{{{
  echohl WarningMsg | execute 'echomsg' string(a:msg) | echohl NONE
endfunction "}}}
" 2}}}

let s:levels = ['ERROR', 'WARNING', 'INFO']
let [s:ERROR, s:WARNING, s:INFO] = range(len(s:levels))
function! s:lvl2str(level) "{{{
  return s:levels[a:level]
endfunction "}}}

let s:repos = get(s:, 'repos', {})
let s:log = get(s:, 'log', [])
" 1}}}


let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et:
