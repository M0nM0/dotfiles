#!/bin/bash

# DOTFILESのパスを設定
DOT="$HOME/dotfiles"

# ホームディレクトリの設定ファイル
create_symlink() {
    src=$1
    dest=$2

    # 既存のファイルやリンクを確認して削除
    if [ -L "$dest" ] || [ -e "$dest" ]; then
        rm -rf "$dest"
    fi

    # シンボリックリンクを作成
    ln -fs "$src" "$dest"
}

# ホームディレクトリの設定
create_symlink "$DOT/zsh/.zshrc" "$HOME/.zshrc"
create_symlink "$DOT/.tmux" "$HOME/.tmux"
create_symlink "$DOT/.tmux/.tmux.conf" "$HOME/.tmux.conf"
create_symlink "$DOT/fzf/.fzf.zsh" "$HOME/.fzf.zsh"
create_symlink "$DOT/.gitconfig" "$HOME/.gitconfig"

# .configディレクトリの設定ファイル
CONF="$HOME/.config"

# .configディレクトリが存在しない場合は作成
mkdir -p "$CONF"

create_symlink "$DOT/sheldon" "$CONF/sheldon"
create_symlink "$DOT/wezterm" "$CONF/wezterm"
create_symlink "$DOT/starship.toml" "$CONF/starship.toml"
