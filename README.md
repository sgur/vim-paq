vim-paq
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

### via ghq

- command-line

  ```sh
  ghq get -u --shallow sgur/vim-paq
  ```

- .vimrc

  ```vim
  source ~/Src/github.com/sgur/vim-paq/paq.vim
  ```

### via git clone

- command-line

  ```sh
  cd ~/.vim
  git clone https://github.com/sgur/vim-paq
  ```
- .vimrc

  ```vim
  source ~/.vim/vim-paq/paq.vim
  ```

### Detailed vimrc example


Usage
-----

ghq の subcommand を利用する場合、`.gitconfig` に以下のエントリを追加してください。

```
[ghq "import"]
	vim = /path/to/vim-paq/import/vim.sh
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
