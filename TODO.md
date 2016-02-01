TODO
====

- [ ] Inhibit loading if 'depends' are not satisfied
- [ ] JSON import
- [ ] Per FileType event is defined as GplFileType:{&filetype} event
  - [ ] Force load via 'doautocmd User GplFileType:{&filetype}'
- [x] 'plugin' option
  - [ ] global 'plugin' enbaled parameter
- [ ] Switch per-filetype rtp on FileType event
  - [ ] general rtp + filetype-specifiec rtp
- [ ] help file
- [x] lazy loading
  - [x] autoload event trigger (FuncUndefined event)
  - [x] command event trigger (pseudo command)
- [x] Insturctions
- [x] 'rtp' flag : add sub-directory to rtp
- [x] Interfaces as same as Vundle
  - [x] ...#tap() looks better than ...#enabled()
- [x] supporting ex-github repos (bitbucket)
- [x] ghq.root from ~/.gitconfig via vim script
- [x] override `K` with `:Help` command
