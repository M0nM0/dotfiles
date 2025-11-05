# Common command extensions

# ls系 - ファイル一覧
alias ll="ls -la"
alias l='ls -lh'
alias la='ls -lAh'
alias lt='ls -lth'
alias ltr='ls -ltrh'

# cd系 - ディレクトリ移動
alias ..='cd ..'

# mkdir - 親ディレクトリも作成
alias mkdir='mkdir -pv'

# ファイル操作 - 確認付き
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# grep系 - カラー表示
alias gr='grep --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# ディスク使用量
alias df='df -h'
alias du='du -h'
alias dus='du -sh'

# その他
alias pc='pbcopy'
alias mant='tldr'
alias path='echo -e ${PATH//:/\\n}'
alias now='date +"%Y-%m-%d %H:%M:%S"'
alias week='date +%V'
