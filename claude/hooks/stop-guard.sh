#!/bin/bash
# stop-guard: 委任モード中の無駄停止を検出して続行させる Stop hook (fail-open)
set -uo pipefail

# 判定用の内側 claude 呼び出し (headless) でこの hook が再帰発火しないためのガード
[ -n "${STOP_GUARD_INNER:-}" ] && exit 0

input=$(cat)

# block 直後の再停止は素通し (無限ループ防止)
[ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ] && exit 0

# 委任系モードのみ対象。plan / default は止まって対話するのが正しいので判定しない
mode=$(printf '%s' "$input" | jq -r '.permission_mode // empty' 2>/dev/null)
case "$mode" in
  acceptEdits|bypassPermissions|dontAsk) ;;
  *) exit 0 ;;
esac

transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
[ -f "$transcript" ] || exit 0

command -v claude >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

# 最後の assistant メッセージ (テキストブロックのみ)
last_assistant=$(jq -rs '
  [.[] | select(.type == "assistant")] | last
  | .message.content // []
  | map(select(.type == "text") | .text)
  | join("\n")' "$transcript" 2>/dev/null | tail -c 4000)
[ -n "$last_assistant" ] || exit 0

# 最後の実ユーザー発話 (tool_result のみのエントリは除外)
last_user=$(jq -rs '
  [.[]
   | select(.type == "user")
   | .message.content
   | if type == "string" then . else ([.[]? | select(.type == "text") | .text] | join("\n")) end
   | select(. != "")]
  | last // ""' "$transcript" 2>/dev/null | tail -c 2000)

judge_prompt="AI アシスタントがターンを終了しようとしている。

# 直近のユーザー指示
${last_user}

# 終了直前の最終出力
${last_assistant}

# 判定
この出力の後にアシスタントが取るべき次の行動は、ユーザーからの
新しい判断・情報・承認なしに既に確定しているか。

- 確定しているのに止まっている → block
- ユーザーの入力なしに次が決まらない、またはタスク全体が完了している → approve
- 迷う場合 → approve

注: 「任せます」等の委任は、合意済み方針の範囲を実行することへの委任である。
方針に含まれない新しい設計判断・想定外の問題の提示は委任に含まれず approve。

# 出力形式 (この 1 行のみ)
approve
または
block: <確定している次の行動を 1 文>"

verdict=$(printf '%s' "$judge_prompt" | STOP_GUARD_INNER=1 claude -p --model haiku --strict-mcp-config 2>/dev/null)

case "$verdict" in
  block*|BLOCK*)
    next_action="${verdict#*:}"
    reason="無駄停止と判定された。確認を挟まず作業を続行すること。次の作業:${next_action}
ただしユーザーの判断・承認 (設計選択 / destructive / commit) が本当に必要な場面なら、確認語彙を使わず要点だけ提示して停止してよい。"
    jq -n --arg r "$reason" '{decision: "block", reason: $r}'
    ;;
esac
exit 0
