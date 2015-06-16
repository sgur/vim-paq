vim-ghqp
========

Ghq ベースの Vim プラグインローダーです。

Description
-----------

[ghq](https://github.com/motemen/ghq) で利用される[ディレクトリ構造](https://github.com/motemen/ghq#directory-structures)に基いて、プラグインをロードします。

[Vundle](https://github.com/gmarik/Vundle.vim) にできるだけ近いコマンド体系となっています。

Requirement
-----------

- [ghq](https://github.com/motemen/ghq) (for installing/updating plugins)

Install
-------

```sh
ghq get sgur/vim-gh9
```

```vim
source /path/to/gh9.vim

call gh9#begin()

" Enable some convenient commands
Ghq 'sgur/vim-ghqp
" Or
" Use only basic commands
Ghq 'sgur/vim-gh9', {'enabled': 0}

" ...

call gh9#end()
```

Usage
-----

### Detailed vimrc example

```vim
set nocompatible              " be iMproved, required
filetype off                  " required

source /path/to/gh9.vim

call gh9#begin()
" alternatively, pass a path where Vundle should install plugins
"call gh9#begin('~/some/path/here')

" let gh9 manage gh9
Ghq 'sgur/vim-gh9'

" plugin on GitHub repo
Ghq 'tpope/vim-fugitive'

" Determine whether the plugin will load or not via 'enabled' flag.
Ghq 'sjl/gundo.vim', {'enabled': has('python')}

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

" Disable update by 'pinned' flag
Ghq 'Shougo/vimproc.vim', {'pinned': 1}

" All of your Plugins must be added before the following line
call gh9#end()            " required
filetype plugin indent on    " required
" To ignore plugin indent changes, instead use:
"filetype plugin on
```

### Update plugins with ghq

`GhqInstall` により、`ghq import` プラグインのアップデートを実施します。

`GhqInstall!` もしくは `GhqUpdate` を実行した場合、既にインストールされているプラグインのみを更新します。

`GhqRepos` コマンドを利用することにより、標準出力に管理しているプラグインのリストを出力することができます。

```
vim -e -s -S ~/.vimrc +GhqReps +qall! | ghq import -u --shallow
```

vim のオプションが複雑なので、バッチファイルを用意しています。

```
subcommand\gh9.bat | ghq import -u --shallow (windows)
subcommand\gh9.sh | ghq import -u --shallow (linux)
```

ghq の subcommand を利用する場合、`.gitconfig` に以下のエントリを追加してください。

```
[ghq "import"]
	gh9 = /path/to/vim-gh9/subcommand/gh9.sh
```
(※ windows の場合、環境変数`%PATH%`に`sh.exe`があるパスを追加してください)

その後、以下のコマンドを実行します。

```
ghq import gh9 -u --shallow
```


License
-------

MIT License

Author
------

sgur <sgurrr@gmail.com>
