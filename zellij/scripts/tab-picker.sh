#!/usr/bin/env bash
# 現在のセッションのタブを fzf で選んで移動する。プレビューには各タブで focus 中の pane の画面を出す
set -euo pipefail

list_tabs() {
  local tabs panes
  tabs=$(zellij action list-tabs -j -s)
  panes=$(zellij action list-panes -j -a)
  jq -r --argjson panes "$panes" '
    .[] | select(.active | not) | . as $tab
    | ([$panes[] | select(.tab_id == $tab.tab_id and (.is_plugin | not) and .is_focused)][0]) as $pane
    | "\($tab.tab_id)\t\($pane.id // "")\t\($tab.position + 1): \($tab.name)  \($pane.title // "")"
  ' <<<"$tabs"
}

if [[ "${1:-}" == "list" ]]; then
  list_tabs
  exit
fi

selected=$(list_tabs | fzf \
  --height=100% \
  --delimiter='\t' --with-nth=3 \
  --header='Enter: switch | Ctrl-X: close tab' \
  --preview='[ -n {2} ] && zellij action dump-screen --ansi -p terminal_{2}' \
  --preview-window='right:70%:wrap' \
  --bind="ctrl-x:execute-silent(zellij action close-tab-by-id {1})+reload($0 list)") || exit 0

zellij action go-to-tab-by-id "$(cut -f1 <<<"$selected")"
