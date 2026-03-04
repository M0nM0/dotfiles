#!/usr/bin/env bash
# Hook: PreToolUse:Bash
# tmux/screen セッション内での実行を検出し警告する
set -euo pipefail

# stdin から tool input を読み取る
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [[ -z "$COMMAND" ]]; then
  exit 0
fi

# tmux/screen セッションの検出
if [[ -n "${TMUX:-}" ]] || [[ -n "${STY:-}" ]]; then
  echo "Warning: tmux/screen セッション内で実行しています。意図しないセッション操作に注意してください。"
fi

exit 0
