############### Alias ###############
alias g="git"
alias lg='lazygit'
alias nv="nvim"
alias lg="lazygit"
alias tm="tmux"
alias py="python"
alias ve="virtualenv"
alias rb="ruby"
alias ra="rails"
alias tf="terraform"

alias ll="ls -la"

alias arm="exec arch -arch arm64e /bin/zsh --login"
alias x64="exec arch -arch x86_64 /bin/zsh --login"

alias reload='source ~/.zshrc'

############### User Specific Alias ###############
alias doc='cd "$HOME/Documents"'
alias des='cd "$HOME/Desktop"'
alias dbe="docker compose exec puma bundle exec"

# Editor
export EDITOR=nvim
export VISUAL="$EDITOR"

# Homebrew
export PATH=/opt/homebrew/bin:$PATH
export PATH=/opt/homebrew/sbin:$PATH
eval "$(/opt/homebrew/bin/brew shellenv)"

# Tex
export PATH=$PATH:/usr/local/texlive/2023/bin/universal-darwin

# zsh
eval "$(sheldon source)"
zstyle ':completion:*' completer _complete _prefix
bindkey -e

# autosuggestion
if type brew &>/dev/null; then
 FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
fi

# fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# starship
eval "$(starship init zsh)"
export PATH="$HOME/.cargo/bin:$PATH"

# exclude unneeded history
zshaddhistory() {
  local line="${1%%$'\n'}"
  [[ ! "$line" =~ "^(cd|jj?|lazygit|la|ll|ls|rm|rmdir)($| )" ]]
}

# pyenv
eval "$(pyenv init -)"
export PATH="$HOME/.nodenv/bin:$PATH"
eval "$(nodenv init -)"

# rbenv
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

# goenv
export GOENV_ROOT="$HOME/.goenv"
export PATH="$GOENV_ROOT/bin:$PATH"
eval "$(goenv init -)"
export PATH="$GOROOT/bin:$PATH"
export PATH="$PATH:$GOPATH/bin"

# color theme
export CLICOLOR=1
export TERM=xterm-256color

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
