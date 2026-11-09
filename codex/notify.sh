#!/usr/bin/env bash
# Codex passes a single JSON argument to notify; adapt it to the shared transport.
set -euo pipefail
INPUT=${1:-}
[[ -n "$INPUT" ]] || exit 0
EVENT=$(printf '%s' "$INPUT" | jq -r '.type // empty')
[[ "$EVENT" == "agent-turn-complete" ]] || exit 0

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
[[ -d "$CWD" ]] || CWD=$(pwd)
REPO_NAME=$(basename "$CWD")
BRANCH_NAME=$(git -C "$CWD" branch --show-current 2>/dev/null || true)
if [[ -n "$BRANCH_NAME" ]]; then
  CONTEXT="$REPO_NAME ($BRANCH_NAME)"
else
  CONTEXT="$REPO_NAME"
fi
MESSAGE=$(printf '%s' "$INPUT" | jq -r '
  (."last-assistant-message" // "")
  | if type == "string" then . else "" end
  | gsub("[[:space:]]+"; " ") | sub("^ +"; "") | .[0:240]')
[[ -n "$MESSAGE" ]] || MESSAGE="Response finished"
exec "${XDG_CONFIG_HOME:-$HOME/.config}/wezterm/bin/term-notify" \
  --title "Codex" -- "$CONTEXT - $MESSAGE"
