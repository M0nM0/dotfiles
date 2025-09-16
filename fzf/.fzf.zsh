# Setup fzf

export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!**/.git/*"'
export FZF_DEFAULT_OPTS="
    --height 40% --reverse --border=sharp --margin=0,1
    --prompt=' ' --color=light
"

# for finding files in current directories
export FZF_CTRL_T_COMMAND='rg --files --hidden --follow --glob "!**/.git/*"'
export FZF_CTRL_T_OPTS="
    --preview 'bat  --color=always --style=header,grid {}'
    --preview-window=right:60%
"

# Ref: https://wonderwall.hatenablog.com/entry/2017/10/06/063000
# コマンドが長すぎる時に?を押すと，全コマンドが見れる
export FZF_CTRL_R_OPTS="
    --preview 'echo {}' --preview-window down:3:hidden:wrap --bind '?:toggle-preview'
"

# fgc (git checkout) - checkout git branch including remote branches
# ref: https://qiita.com/kamykn/items/aa9920f07487559c0c7e
fgc() {
  local branches branch
  branches=$(git branch --all | grep -v HEAD) &&
  branch=$(echo "$branches" |
           fzf-tmux -d $(( 2 + $(wc -l <<< "$branches") )) +m) &&
  git checkout $(echo "$branch" | sed "s/.* //" | sed "s#remotes/[^/]*/##")
}

# flog - git commit browser
# ref: https://qiita.com/kamykn/items/aa9920f07487559c0c7e
flog() {
  git log --graph --color=always \
      --format="%C(auto)%h%d %s %C(#C0C0C0)%C(bold)%cr" "$@" |
  fzf --ansi --no-sort --reverse --tiebreak=index --bind=ctrl-s:toggle-sort \
      --bind "ctrl-m:execute:
              (grep -o '[a-f0-9]\{7\}' | head -1 |
              xargs -I % sh -c 'git show --color=always % | less -R') << 'FZF-EOF'
              {}
              FZF-EOF
             "
}

# fd - cd to selected directory
# https://qiita.com/kamykn/items/aa9920f07487559c0c7e
fcd() {
  local dir
  dir=$(find ${1:-.} -path '*/\.*' -prune \
                  -o -type d -print 2> /dev/null | fzf +m) &&
  cd "$dir"
}

# fadd: git add / diff をインタラクティブに．Ctrl-d で diff, Enter で add
# https://qiita.com/reviry/items/e798da034955c2af84c5
fadd() {
  local out q n addfiles
  while out=$(
      git status --short |
      awk '{if (substr($0,2,1) !~ / /) print $2}' |
      fzf-tmux --multi --exit-0 --expect=ctrl-d); do
    q=$(head -1 <<< "$out")
    n=$[$(wc -l <<< "$out") - 1]
    addfiles=(`echo $(tail "-$n" <<< "$out")`)
    [[ -z "$addfiles" ]] && continue
    if [ "$q" = ctrl-d ]; then
      git diff --color=always $addfiles | less -R
    else
      git add $addfiles
    fi
  done
}

# fvim: ファイル名検索+Vimで開くファイルをカレントディレクトリからfzfで検索可能に
# ref: https://momozo.tech/2021/03/10/fzf%E3%81%A7zsh%E3%82%BF%E3%83%BC%E3%83%9F%E3%83%8A%E3%83%AB%E4%BD%9C%E6%A5%AD%E3%82%92%E5%8A%B9%E7%8E%87%E5%8C%96/
fvim() {
  local file
  file=$(
         rg --files --hidden --follow --glob "!**/.git/*" | fzf \
             --preview 'bat  --color=always --style=header,grid {}' --preview-window=right:60%
     )
  nvim "$file"
}
alias fv="fvim"


# かつていたことのあるディレクトリに移動する
# https://qiita.com/kamykn/items/aa9920f07487559c0c7e
fzf-z-search() {
    local res=$(z | sort -rn | cut -c 12- | fzf --preview 'tree -C {} 2>/dev/null || ls -lh {}')
    if [ -n "$res" ]; then
        BUFFER+="cd $res"
        zle accept-line
    else
        return 1
    fi
}

zle -N fzf-z-search
bindkey '^f' fzf-z-search

# fzf履歴検索
fzf-history-search() {
    local selected
    selected=$(fc -rl 1 | awk '{$1=""; print substr($0,2)}' | fzf --height 40% --reverse --border)
    if [ -n "$selected" ]; then
        BUFFER="$selected"
        CURSOR=$#BUFFER
        zle redisplay
    fi
}
zle -N fzf-history-search
bindkey '^R' fzf-history-search

# プロセスをkill
fkill() {
  local pid
  pid=$(ps -ef | sed 1d | fzf -m | awk '{print $2}')

  if [ "x$pid" != "x" ]
  then
    echo $pid | xargs kill -${1:-9}
  fi
}

# fzfでdockerコンテナに入る
# ref: https://momozo.tech/2021/03/10/fzf%E3%81%A7zsh%E3%82%BF%E3%83%BC%E3%83%9F%E3%83%8A%E3%83%AB%E4%BD%9C%E6%A5%AD%E3%82%92%E5%8A%B9%E7%8E%87%E5%8C%96/
fdcnte() {
  local cid
  cid=$(docker ps | sed 1d | fzf -q "$1" | awk '{print $1}')
  [ -n "$cid" ] && docker exec -it "$cid" /bin/bash
}

# fzfでdockerのログを取得
# ref: https://momozo.tech/2021/03/10/fzf%E3%81%A7zsh%E3%82%BF%E3%83%BC%E3%83%9F%E3%83%8A%E3%83%AB%E4%BD%9C%E6%A5%AD%E3%82%92%E5%8A%B9%E7%8E%87%E5%8C%96/
fdl() {
  local cid
  cid=$(docker ps -a | sed 1d | fzf -q "$1" | awk '{print $1}')
  [ -n "$cid" ] && docker logs -f --tail=200 "$cid"
}

# fzfでDockerコンテナ再起動
# ref: https://momozo.tech/2021/03/10/fzf%E3%81%A7zsh%E3%82%BF%E3%83%BC%E3%83%9F%E3%83%8A%E3%83%AB%E4%BD%9C%E6%A5%AD%E3%82%92%E5%8A%B9%E7%8E%87%E5%8C%96/
fdcntre() {
  local cid
  cid=$(docker ps -a | sed 1d | fzf -m -q "$1" | awk '{print $1}')
  [ -n "$cid" ] && echo $cid | xargs docker container restart
}

# docker container rm
# ref: https://momozo.tech/2021/03/10/fzf%E3%81%A7zsh%E3%82%BF%E3%83%BC%E3%83%9F%E3%83%8A%E3%83%AB%E4%BD%9C%E6%A5%AD%E3%82%92%E5%8A%B9%E7%8E%87%E5%8C%96/
fdcntrm() {
  local cid
  cid=$(docker ps -a | sed 1d | fzf -m -q "$1" | awk '{print $1}')
  [ -n "$cid" ] && echo $cid | xargs docker container rm -f
}

# docker image rm
fdimgrm() {
  local cid
  cid=$(docker image ls -a | sed 1d | fzf -m -q "$1" | awk '{print $1}')
  [ -n "$cid" ] && echo $cid | xargs docker image rm -f
}


