#!/bin/bash

# DOTFILESのパスを設定
DOT="$HOME/dotfiles"

# ホームディレクトリの設定ファイル
ln -fs "$DOT/zsh/.zshrc" "$HOME/.zshrc"
ln -fs "$DOT/tmux/.tmux" "$HOME/.tmux"
ln -fs "$DOT/tmux/.tmux.conf" "$HOME/.tmux.conf"
ln -fs "$DOT/fzf/.fzf.zsh" "$HOME/.fzf.zsh"
ln -fs "$DOT/.gitconfig" "$HOME/.gitconfig"

# .configディレクトリの設定ファイル
CONF="$HOME/.config"

# .configディレクトリが存在しない場合は作成
mkdir -p "$CONF"

ln -fs "$DOT/nvim" "$CONF/nvim"
ln -fs "$DOT/sheldon" "$CONF/sheldon"
ln -fs "$DOT/wezterm" "$CONF/wezterm"
ln -fs "$DOT/starship.toml" "$CONF/starship.toml"

