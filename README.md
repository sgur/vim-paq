vim-gh9
========

Ghq ベースの Vim プラグインローダーです。

Description
-----------

[ghq](https://github.com/motemen/ghq) で利用される[ディレクトリ構造](https://github.com/motemen/ghq#directory-structures)に基いて、プラグインをロードします。

Requirement
-----------

- [ghq](https://github.com/motemen/ghq) (for installing/updating plugins)

Install
-------

### Locate under \[ghq.root\]

```sh
ghq get -u --shallow sgur/vim-gh9
```

### Git clone to ~/.vim

```sh
cd ~/.vim
git clone https://github.com/sgur/vim-gh9
```

### vimrc example

```vim
source ~/.vim/vim-gh9/gh9.vim

call gh9#begin()

" ...

call gh9#end()
```

### Detailed vimrc example

```vim
filetype off                  " required

source /path/to/gh9.vim

call gh9#begin()

" Let vim-gh9 manage oneself
Ghq 'sgur/vim-gh9'

" Plugin on github
Ghq 'tpope/vim-fugitive'

" Plugin on bitbucket
Ghq 'http://bitbucket.org/sjl/gundo.vim'
" or specify repo
"Ghq 'sjl/gundo.vim', {'host': 'bitbucket.org'}

" Determine whether the plugin will load or not via 'enabled' flag.
Ghq 'davidhalter/jedi-vim', {'enabled': has('python') || has('python3')}

" Add path to &rtp before ghql#end()
" Useful for start plugins via function call
Ghq 'thinca/vim-singleton', {'immediately': 1}
call singleton#enable()

" Lazy loading for specified prefix of autoload functions
Ghq 'vim-jp/autofmt', {'autoload': 'autofmt'}

" 'filtype' flag enables lazy-loading on FileType events
Ghq 'vim-jp/vim-go-extra', {'filetype': 'go'}
Ghq 'othree/html5.vim', {'filetype': ['html', 'javascript']}

" The sparkup vim script is in a subdirectory of this repo called vim.
" Pass the path to set the runtimepath properly.
Ghq 'rstacruz/sparkup', {'rtp': 'vim/'}

" Define pseudo command
Ghq 'AndrewRadev/inline_edit.vim', {'command' : {'name': 'InlineEdit', 'nargs': '*'}}

" Disable update by 'pinned' flag (Only enabled for ':GhqUpdate' command)
Ghq 'Shougo/vimproc.vim', {'pinned': 1}

" All of your Plugins must be added before the following line
call gh9#end()            " required
filetype plugin indent on    " required
" To ignore plugin indent changes, instead use:
"filetype plugin on
```

Usage
-----

### Update plugins with ghq

`:GhqInstall` により、`ghq import` プラグインのアップデートを実施します。

`:GhqInstall!` もしくは `:GhqUpdate` を実行した場合、既にインストールされているプラグインのみを更新します。

`:GhqRepos` コマンドを利用することにより、標準出力に管理しているプラグインのリストを出力することができます。

### ghq import subcommand

ghq の subcommand を利用する場合、`.gitconfig` に以下のエントリを追加してください。

```
[ghq "import"]
	vim = /path/to/vim-gh9/macros/gh9.sh
```
(※ windows の場合、環境変数`%PATH%`に`sh.exe`があるパスを追加してください 例: `c:/Program Files/Git/bin` 等)

その後、以下のコマンドを実行します。

```sh
ghq import vim -u --shallow
```

git submodule を利用しているプラグインがある場合は、以下のように `fetch.recurseSubmodules` を有効にしておくと、submodule の更新も同時にしてくれるので便利です。

* グローバルに設定する場合

  ```sh
  git config --global fetch.recurseSubmodules true
  ```

* リポジトリ毎に設定する場合

  ```sh
  cd /path/to/repo
  git config --local fetch.recurseSubmodules true
  ```

License
-------

MIT License

Author
------

sgur <sgurrr@gmail.com>
