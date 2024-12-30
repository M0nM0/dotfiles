# Alias
alias doc='cd /Users/visha/Documents'
alias des='cd /Users/visha/Desktop'
export OD=/Users/visha/'OneDrive - 筑波大学'
alias lab='cd "$OD/LABO"'

alias g="git"
alias nv="nvim"
alias py="python"
alias ve="virtualenv"
alias rb="ruby"
alias ra="rails"

alias ll="ls -l"
alias dbe="docker compose exec puma bundle exec"

alias arm="exec arch -arch arm64e /bin/zsh --login"
alias x64="exec arch -arch x86_64 /bin/zsh --login"

alias reload='source ~/.zshrc'

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
EDITOR='nvim sheldon edit'

source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh-completions:$FPATH

  autoload -Uz compinit
  compinit
fi

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
test -r /Users/visha/.opam/opam-init/init.zsh && . /Users/visha/.opam/opam-init/init.zsh >/dev/null 2>/dev/null || true

# fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# starship
eval "$(starship init zsh)"
export PATH="$HOME/.cargo/bin:$PATH"
