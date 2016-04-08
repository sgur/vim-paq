scriptencoding utf-8



" Internal {{{1

" Commands {{{2
function! s:cmd_bundle(bundle, param) "{{{
  let s:repos[a:bundle] = a:param
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

  call s:setup_repos(a:config)

  augroup plugin_paq
    autocmd!
    autocmd BufNew *
          \   augroup filetypedetect
          \ |   call map(s:find_ftdetects(), 's:source_script(v:val)')
          \ | augroup END
          \ | autocmd! plugin_paq BufNew
    autocmd FuncUndefined *  nested call s:on_funcundefined(expand('<amatch>'))
    autocmd FileType *  call s:on_filetype(expand('<amatch>'))
    autocmd FileType help  nested nnoremap <silent> <buffer> <C-]>  :<C-u>call <SID>map_tag(v:count)<CR>
    autocmd FileType vim,help  nested nnoremap <silent> <buffer> K  :<C-u>call <SID>map_lookup(v:count)<CR>
    autocmd VimEnter *  call s:on_vimenter()
  augroup END
endfunction "}}}

function! s:cmd_nop() "{{{
endfunction "}}}

function! s:cmd_force_bundle(bundle, param) "{{{
  let s:repos[a:bundle] = extend({'__loaded': 1}, a:param)
  call s:inject_runtimepath([s:get_path(a:bundle)])
  call s:log(s:INFO, printf('loading %s after startup', s:get_path(a:bundle)))
endfunction "}}}

function! s:cmd_force_globlocal(dir) "{{{
  if !isdirectory(expand(a:dir))
    echohl WarningMsg | echomsg 'Not found:' a:dir | echohl NONE
    return
  endif
  let dirs = filter(s:globpath(a:dir, '*'), '!(s:is_globskip(v:val) || has_key(s:repos, v:val))')
  call s:inject_runtimepath(dirs)
  call map(copy(dirs), 'extend(s:repos, {v:val : {"__loaded": 1}})')
  call map(copy(dirs), 's:log(s:INFO, printf("loading %s after startup", v:val))')
endfunction "}}}

" Map {{{2
function! s:map_lookup(count) "{{{
  if &l:keywordprg =~# '^man'
    execute 'normal! ' a:count . 'K'
    return
  elseif &l:keywordprg isnot# ':help' && !empty(&l:keywordprg)
    execute 'normal! K'
    return
  endif
  let cmd = 'help ' . matchstr(getline('.'), '\k*\%' . col('.') . 'c\k*')
  try
    execute cmd
  catch /^Vim\%((\a\+)\)\=:E\%(149\)/
    call s:try_with_repo_rtps(cmd, v:exception)
  endtry
endfunction "}}}

function! s:map_tag(count) "{{{
  let cmd = printf("%dtag %s", a:count, expand('<cword>'))
  try
    execute cmd
  catch /^Vim\%((\a\+)\)\=:E\%(426\|257\)/
    call s:try_with_repo_rtps(cmd, v:exception)
  endtry
endfunction "}}}

" Completion {{{2
function! s:help_complete(term) "{{{
  let tags = &l:tags
  try
    if !exists('s:tagdirs')
      let s:tagdirs = join(filter(map(keys(s:repos), 's:get_path(v:val) . "/doc/tags"'), 'filereadable(v:val)'),',')
    endif
    let &l:tags = s:tagdirs
    return map(taglist(empty(a:term)? '.' : a:term), 'v:val.name')
  finally
    let &l:tags = tags
  endtry
endfunction "}}}

function! s:list_complete(term) "{{{
  return filter(keys(s:repos), '!get(s:repos[v:val], "__loaded", 0) && v:val =~ a:term')
endfunction "}}}

" Autocmd Events {{{2
function! s:on_vimenter() "{{{
  autocmd! plugin_paq VimEnter *
  call map(get(s:, 'on_vimenter_plugins', []), 's:source_script(v:val)')
  call map(get(s:, 'on_vimenter_after_plugins', []), 's:source_script(v:val)')
  if !empty(s:log)
    call s:message(s:WARNING, 's:echomsg_warning')
  endif
endfunction "}}}

function! s:on_funcundefined(funcname) "{{{
  let dirs = []
  let bundles = []
  for [name, params] in filter(items(s:repos), "has_key(v:val[1], 'autoload') && !get(v:val[1], '__loaded', 0) && get(v:val[1], 'enabled', 1)")
    for prefix in type(params.autoload) == type([]) ? params.autoload : [params.autoload]
      if stridx(a:funcname, prefix) == 0
        call s:log(s:INFO, printf('loading %s on autoload[%s] (%s)', name, prefix, a:funcname))
        let dirs += s:depends(get(params, 'depends', []))
        let dirs += [s:get_path(name)]
        let bundles += [name]
        let params.__loaded = 1
        break
      endif
    endfor
  endfor
  call s:inject_runtimepath(dirs)
  for bundle in bundles
    call s:do_user_post_hook(bundle)
  endfor
endfunction "}}}

function! s:on_filetype(filetype) "{{{
  let dirs = []
  let bundles = []
  for [name, params] in filter(items(s:repos), "has_key(v:val[1], 'filetype') && !get(v:val[1], '__loaded', 0) && get(v:val[1], 'enabled', 1)")
    if s:included(params.filetype, a:filetype)
      call s:log(s:INFO, printf('loading %s on filetype[%s]', name, a:filetype))
      let dirs += s:depends(get(params, 'depends', []))
      let dirs += [s:get_path(name)]
      let bundles += [name]
      let params.__loaded = 1
    endif
  endfor
  call s:inject_runtimepath(dirs, a:filetype)
  for bundle in bundles
    call s:do_user_post_hook(bundle)
  endfor
endfunction "}}}

" Repos {{{2
function! s:backup_original_rtp() "{{{
  if !exists('s:rtp') | let s:rtp = &runtimepath | endif
endfunction "}}}

function! s:depends(bundles) "{{{
  if empty(a:bundles)
    return []
  endif
  let depends = type(a:bundles) == type([]) ? a:bundles : [a:bundles]
  let _ = []
  for depend in depends
    if !get(s:repos[depend], '__loaded', 0)
      let _ += [s:get_path(depend)]
      let s:repos[depend].__loaded = 1
    endif
  endfor
  return _
endfunction "}}}

function! s:setup_repos(global) "{{{
  let [dirs, plugins, afters] = [[], [], []]
  for [name, params] in items(s:repos)
    call extend(params, a:global, 'keep')
    if !get(params, 'enabled', 1)
      continue
    endif

    let path = s:get_path(name)
    if empty(path)
      continue
    endif
    let triggered = 0
    if get(params, 'plugin', 0)
      let plugins += s:glob_scripts(path, 'plugin')
      let afters += s:glob_scripts(path, 'after/plugin')
      let triggered = 1
    endif
    if has_key(params, 'command')
      call s:define_pseudo_commands(params.command, name)
      let triggered = 1
    endif
    if has_key(params, 'map')
      call s:define_pseudo_maps(params.map, name)
      let triggered = 1
    endif
    if !triggered && !(has_key(params, 'filetype') || has_key(params, 'autoload'))
      let dirs += [path]
      let params.__loaded = 1
    endif
  endfor
  call s:rtp_generate(s:rtp, dirs)
  let s:on_vimenter_plugins = plugins
  let s:on_vimenter_after_plugins = afters
endfunction "}}}

function! s:find_ftdetects() abort "{{{
  let _ = []
  call map(filter(keys(s:repos), 'has_key(s:repos[v:val], "filetype") || has_key(s:repos[v:val], "autoload")')
        \, 'extend(_, s:glob_scripts(s:get_path(v:val), "ftdetect"))')
  return _
endfunction "}}}

function! s:find_ghq_root() "{{{
  let gitconfig = readfile(expand('~/.gitconfig'))
  let ghq_root = filter(map(gitconfig, 'matchstr(v:val, ''root\s*=\s*\zs.*'')'), '!empty(v:val)')
  return !empty(ghq_root) ? ghq_root[0] : expand('~/.ghq')
endfunction "}}}

function! s:get_path(name) " {{{
  let repo = get(s:repos, a:name, {})
  if !has_key(repo, '__path')
    let repo.__path = s:find_path(a:name, get(repo, 'host', ''))
    if has_key(repo, 'rtp')
      let repo.__path .= '/' . repo.rtp
    endif
  endif
  return repo.__path
endfunction " }}}

function! s:find_path(name, prefix) "{{{
  if isdirectory(a:name)
    return a:name
  endif
  return expand(s:ghq_root . '/' . s:repo_url(a:name, a:prefix))
endfunction "}}}

function! s:repo_url(name, prefix) "{{{
  return !stridx(a:name, 'http')
        \ ? substitute(a:name, '^https\?://', '', '')
        \ : (empty(a:prefix) ? 'github.com' : a:prefix) . '/' . a:name
endfunction "}}}

" RTP {{{2
function! s:source_script(path) "{{{
  execute 'source' a:path
endfunction "}}}

function! s:inject_runtimepath(dirs, ...) "{{{
  call s:rtp_generate(&runtimepath, a:dirs)
  if has('vim_starting') | return | endif
  let dirs = join(a:dirs,',')
  let scripts = s:globpath(dirs, 'plugin/**/*.vim') + s:globpath(dirs, 'after/plugin/**/*.vim')
  if a:0
    let scripts += s:globpath(dirs, 'ftplugin/' . a:1 . '/*.vim') + s:globpath(dirs, 'ftplugin/' . a:1 . '_*.vim')
    let scripts += s:globpath(dirs, 'after/ftplugin/' . a:1 . '/*.vim') + s:globpath(dirs, 'after/ftplugin/' . a:1 . '_*.vim')
  endif
  call map(scripts, 's:source_script(v:val)')
endfunction "}}}

function! s:rtp_generate(rtp, paths) "{{{
  let after_rtp = s:globpath(join(a:paths, ','), 'after')
  let rtps = split(a:rtp, ',')
  call extend(rtps, a:paths, 1)
  call extend(rtps, after_rtp, -1)
  let &runtimepath = join(rtps, ',')
endfunction "}}}

function! s:glob_scripts(name, path) abort "{{{
  return s:globpath(a:name, a:path . '/**/*.vim')
endfunction "}}}

" Command {{{2
function! s:define_pseudo_maps(maps, name) " {{{
  for map in type(a:maps) == type([]) ? a:maps : [a:maps]
    if !empty(mapcheck(map)) | continue | endif
    for [mode, map_prefix, key_prefix] in
          \ [['i', '<C-o>', ''], ['n', '', ''], ['v', '', 'gv'], ['x', '', 'gv'], ['o', '', '']]
      execute printf(
            \ '%snoremap <silent> %s %s:<C-u>call <SID>pseudo_map(%s, %s, "%s")<CR>',
            \ mode, map, map_prefix, string(map), string(a:name), key_prefix)
    endfor
  endfor
endfunction " }}}

function! s:pseudo_map(map, name, prefix) abort "{{{
  call s:log(s:INFO, printf('loading %s on map[%s]', a:name, a:map))
  execute 'silent! unmap' a:map
  execute 'silent! xunmap' a:map
  call s:inject_runtimepath([s:get_path(a:name)])
  call s:do_user_post_hook(a:name)
  call feedkeys(a:prefix . substitute(a:map, '^<Plug>', "\<Plug>", '') . s:get_extra_keys())
endfunction "}}}

function! s:get_extra_keys() abort "{{{
  let seq = ''
  while 1
    let ch = getchar(0)
    if ch == 0
      break
    endif
    let seq .= nr2char(ch)
  endwhile
  return seq
endfunction "}}}

function! s:define_pseudo_commands(commands, name) "{{{
  let commands = type(a:commands) == type([]) ? a:commands : [a:commands]
  for command in commands
    let cmd = command.name
    if get(command, 'bang', 0)
      let bang = command.bang
    endif
    if has_key(command, 'range')
      let range = command.range == 1 ? '-range' : '-range=' . command.range
    endif
    let attr = map(filter(copy(command), 'index(["bang", "name", "range"], v:key) == -1'), 'printf("-%s=%s", v:key, v:val)')
    execute 'command!' join(values(attr), ' ') (exists('bang') ? '-bang' : '') (exists('range') ? range : '') cmd
          \ printf('call s:pseudo_command(''%s'', ''%s'', ''<bang>'', <q-args>)', a:name, cmd)
  endfor
endfunction "}}}

function! s:pseudo_command(name, cmd, bang, args) "{{{
  execute 'delcommand' a:cmd
  call s:log(s:INFO, printf('loading %s on command[%s]', a:name, a:cmd))
  call s:inject_runtimepath([s:get_path(a:name)])
  execute a:cmd . a:bang a:args
  call s:do_user_post_hook(a:name)
endfunction "}}}

" Misc {{{2
function! s:do_user_post_hook(bundle) abort "{{{
  call s:do_user_hook(a:bundle, [a:bundle, a:bundle . ':post'])
endfunction "}}}

function! s:do_user_pre_hook(bundle) abort "{{{
  call s:do_user_hook(a:bundle, [a:bundle . ':pre'])
endfunction "}}}

function! s:do_user_hook(bundle, events) abort "{{{
  for event in a:events
    if exists('#User#' . event)
      execute 'doautocmd User' event
    endif
  endfor
endfunction "}}}

function! s:normalize_name(bundle) abort "{{{
  let matches = matchlist(a:bundle, '/\(vim-\)\?\([^.-]\+\)\([.-]vim\)\?$')
  if empty(matches)
    return a:bundle
  endif
  return matches[2]
endfunction "}}}

function! s:is_globskip(dir) "{{{
  return has_key(s:repos, a:dir) || a:dir =~# '\~$'
endfunction "}}}

function! s:globpath(path, expr) "{{{
  return has('patch-7.4.279') ? globpath(a:path, a:expr, 1, 1) : split(globpath(a:path, a:expr, 1))
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

function! s:try_with_repo_rtps(cmd, exception) "{{{
    let rtp = &rtp
    try
      let &rtp = join(map(keys(s:repos), 's:get_path(v:val)'),',')
      execute a:cmd
      source $VIMRUNTIME/syntax/help.vim " HACK: force enable syntax
    catch /^Vim\%((\a\+)\)\=:E\%(149\|426\|429\|257\|716\)/
      echohl ErrorMsg | echomsg matchstr(a:exception, '^[^:]*:\zs.\+') | echohl None
    finally
      let &rtp = rtp
    endtry
endfunction "}}}

function! s:lvl2str(level) "{{{
  return s:levels[a:level]
endfunction "}}}


" Interface {{{1

function! paq#add(immidiate, bundle, ...) abort
  if empty(a:bundle) | return | endif
  let param = !a:0 ? {} : (!empty(a:1) && type(a:1) == type({}) ? a:1 : {})
  if !a:immidiate
    call s:cmd_bundle(a:bundle, param)
  else
    call s:cmd_force_bundle(a:bundle, param)
  endif
endfunction

function! paq#glob(immidiate, dir) abort
  if !a:immidiate
    call s:cmd_globlocal(a:dir)
  else
    call s:cmd_force_globlocal(a:dir)
  endif
endfunction

function! paq#apply(...) abort
  call s:cmd_apply(a:0 ? a:1 : {})
endfunction

function! paq#available(bundle) abort
  if !&loadplugins | return 0 | endif
  if has_key(s:repos, a:bundle)
    return get(s:repos[a:bundle], 'enabled', 1) && isdirectory(s:get_path(a:bundle))
  endif

  let msg = printf('no repository found on paq#available("%s")', a:bundle)
  call s:log(s:WARNING, msg)
  return 0
endfunction

function! paq#repos(...) abort
  return deepcopy(a:0 > 0 ? s:repos[a:1] : s:repos)
endfunction

function! paq#helptags() abort
  let dirs = filter(map(keys(s:repos), 'expand(s:get_path(v:val) . "/doc")'), 'isdirectory(v:val)')
  echohl Title | echo 'helptags:' | echohl NONE
  for dir in filter(dirs, 'filewritable(v:val) == 2')
    echon ' ' . fnamemodify(dir, ':h:t')
    execute 'helptags' dir
  endfor
  if filewritable(expand('$VIMRUNTIME/doc')) == 2 && filewritable(expand('$VIMRUNTIME/doc/tags')) == 1
    echon ' $VIMRUNTIME/doc'
    helptags $VIMRUNTIME/doc
  endif
endfunction

function! paq#help(term) abort
  let cmd = printf("help %s", a:term)
  try
    execute cmd
  catch /^Vim\%((\a\+)\)\=:E\%(149\|426\|257\)/
    call s:try_with_repo_rtps(cmd, v:exception)
  endtry
endfunction

function! paq#enable(bundle) abort
  if has_key(s:repos, a:bundle) && !get(s:repos[a:bundle], '__loaded', 0) && !get(s:repos[a:bundle], 'enabled', 0)
    call s:inject_runtimepath([s:get_path(a:bundle)])
    let s:repos[a:bundle].enabled = 1
    let s:repos[a:bundle].__loaded = 1
    if exists('#User#' . a:bundle)
      execute 'doautocmd User' a:bundle
    endif
  endif
endfunction

function! paq#message() abort
  call s:message(s:INFO, 's:echo')
endfunction

function! paq#enumerate() abort
  new
  setlocal buftype=nofile
  let repos = filter(deepcopy(s:repos), '!isdirectory(v:key)')
  let repo_names = map(items(repos), 'has_key(v:val[1], "host") ? "https://" . s:repo_url(v:val[0], v:val[1].host) : v:val[0]')
  call append(0, sort(repo_names))
  normal! Gdd
  execute '%print'
  bdelete
endfunction

function! paq#help_complete(arglead, cmdline, cursorpos) abort
  return s:help_complete(a:arglead)
endfunction

function! paq#list_complete(arglead, cmdline, cursorpos) abort
  return s:list_complete(a:arglead)
endfunction

" Initialization {{{1

let s:ghq_root = exists('$GHQ_ROOT') && isdirectory(expand($GHQ_ROOT))
      \ ? expand($GHQ_ROOT) : s:find_ghq_root()
let s:levels = ['ERROR', 'WARNING', 'INFO']
let [s:ERROR, s:WARNING, s:INFO] = range(len(s:levels))

let s:repos = get(s:, 'repos', {})
let s:log = get(s:, 'log', [])

call s:backup_original_rtp()



" 1}}}
