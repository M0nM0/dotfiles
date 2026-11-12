# zellij のタブ名を作業ディレクトリ (~ で省略した形) にする
# rename-tab は既定でフォーカス中のタブを変えるため、自分の pane が属するタブを --tab-id で指定する
# 手動で付けた名前は残すため、既定の "Tab #N" かパスの名前のときだけ書き換える
# 古いサーバーでは list-panes が遅いので、cd を待たせないよう裏で実行する
[[ -n $ZELLIJ ]] || return 0

_zellij_tab_name() {
  {
    local tab
    tab=$(command zellij action list-panes -j 2>/dev/null |
      command jq -r --argjson id "$ZELLIJ_PANE_ID" \
        'first(.[] | select((.is_plugin | not) and .id == $id)) | select(.tab_name | test("^(Tab #[0-9]+$|[~/])")) | .tab_id')
    [[ -n $tab ]] && command zellij action rename-tab -t "$tab" "${(D)PWD}"
  } &>/dev/null &!
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd _zellij_tab_name
_zellij_tab_name
