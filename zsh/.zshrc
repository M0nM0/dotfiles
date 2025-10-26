# XDG Base Directory仕様に準拠
# macOSでも~/.configを設定ディレクトリとして使用する
# これによりlazygit等のツールがLinuxと同じパスを参照する
export XDG_CONFIG_HOME="$HOME/.config"

# Editor
export EDITOR=nvim
export VISUAL="$EDITOR"

# Homebrew (Mac Apple Silicon / Linux 両対応)
if [[ -f "/opt/homebrew/bin/brew" ]]; then
  # Mac (Apple Silicon)
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
  # Linux
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# zsh
eval "$(sheldon source)"

# direnv (.envrc自動読み込み)
export DIRENV_LOG_FORMAT=""
if command -v direnv >/dev/null 2>&1; then
    eval "$(direnv hook zsh)"
fi

# color theme
export CLICOLOR=1
export TERM=xterm-256color

# zsh-vi-mode初期化後にfzf/starshipを初期化（競合回避）
function zvm_after_init() {
  # fzf
  [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

  # starship
  eval "$(starship init zsh)"

  # インサートモードでEmacsキーバインド（行内編集）
  bindkey -M viins '^A' beginning-of-line
  bindkey -M viins '^E' end-of-line
  bindkey -M viins '^K' kill-line
  bindkey -M viins '^U' backward-kill-line
  bindkey -M viins '^W' backward-kill-word
}

zstyle ':completion:*' completer _complete _prefix

# autosuggestion
if type brew &>/dev/null; then
 FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
fi

# cargo
export PATH="$HOME/.cargo/bin:$PATH"

# exclude unneeded history
zshaddhistory() {
  local line="${1%%$'\n'}"
  [[ ! "$line" =~ "^(cd|jj?|lazygit|la|ll|ls|rm|rmdir)($| )" ]]
}

# pyenv
eval "$(pyenv init -)"

# Volta (Node.js version manager)
export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"

# rbenv
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

# goenv
export GOENV_ROOT="$HOME/.goenv"
export PATH="$GOENV_ROOT/bin:$PATH"
eval "$(goenv init -)"
export PATH="$GOROOT/bin:$PATH"
export PATH="$PATH:$GOPATH/bin"

# Android Studio
export ANDROID_SDK_ROOT=/Users/visha/Library/Android/sdk
export PATH=$ANDROID_SDK_ROOT/platform-tools:$PATH
export PATH=$ANDROID_SDK_ROOT/emulator:$PATH

# opam configuration
test -r "$HOME/.opam/opam-init/init.zsh" && . "$HOME/.opam/opam-init/init.zsh" >/dev/null 2>/dev/null || true

### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
export PATH="$HOME/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)

# OpenJDK
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
export CPPFLAGS="-I/opt/homebrew/opt/openjdk/include"

autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C /opt/homebrew/bin/terraform terraform
