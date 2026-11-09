#!/usr/bin/env bash
set -euo pipefail

# The stop guard's internal headless Claude must never notify the parent pane.
[[ -n "${STOP_GUARD_INNER:-}" ]] && exit 0

# Read hook data from stdin
INPUT=$(cat)

HOOK_EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty')
NOTIFICATION_TYPE=$(echo "$INPUT" | jq -r '.notification_type // empty')

# Do not forward subagents as if the main response had finished.
[[ "$(printf '%s' "$INPUT" | jq -r '.agent_id // empty')" != "" ]] && exit 0

NOTIFIER="${XDG_CONFIG_HOME:-$HOME/.config}/wezterm/bin/term-notify"
if [[ "$HOOK_EVENT" == "UserPromptSubmit" ]]; then
  if [[ -n "${WEZTERM_PANE:-}" || "${TERM_PROGRAM:-}" == "WezTerm" ]]; then
    "$NOTIFIER" --clear || true
  fi
  exit 0
fi

# Determine title
case "$NOTIFICATION_TYPE" in
  permission_prompt) TITLE="Permission Required" ;;
  idle_prompt)       TITLE="Idle" ;;
  auth_success)      TITLE="Auth Success" ;;
  elicitation_dialog) TITLE="Input Required" ;;
  *)
    case "$HOOK_EVENT" in
      Stop)         TITLE="Claude Code" ;;
      Notification) TITLE="Notification" ;;
      *)            TITLE="$HOOK_EVENT" ;;
    esac
    ;;
esac

# Get git info
REPO_NAME=""
BRANCH_NAME=""
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
[[ -d "$CWD" ]] || CWD=$(pwd)

if git -C "$CWD" rev-parse --is-inside-work-tree &>/dev/null; then
  REMOTE=$(git -C "$CWD" remote get-url origin 2>/dev/null || true)
  if [[ -n "$REMOTE" ]]; then
    # Strip trailing .git, then extract last path component
    REPO_NAME=$(echo "$REMOTE" | sed 's/\.git$//' | sed 's/.*[/:]//')
  fi
  [[ -z "$REPO_NAME" ]] && REPO_NAME=$(basename "$CWD")
  BRANCH_NAME=$(git -C "$CWD" branch --show-current 2>/dev/null || true)
else
  REPO_NAME=$(basename "$CWD")
fi

# Build subtitle
if [[ -n "$BRANCH_NAME" ]]; then
  SUBTITLE="$REPO_NAME ($BRANCH_NAME)"
else
  SUBTITLE="$REPO_NAME"
fi

# Determine message
if [[ "$HOOK_EVENT" == "Stop" ]]; then
  MESSAGE=$(printf '%s' "$INPUT" | jq -r '
    (.last_assistant_message // "")
    | if type == "string" then . else "" end
    | gsub("[[:space:]]+"; " ") | sub("^ +"; "") | .[0:240]')
  [[ -n "$MESSAGE" ]] || MESSAGE="Response finished"
  if [[ "$(printf '%s' "$INPUT" | jq '(.background_tasks // []) | length')" -gt 0 ]]; then
    MESSAGE="[Background work still running] $MESSAGE"
  fi
else
  MESSAGE=$(printf '%s' "$INPUT" | jq -r '
    (.message // "")
    | if type == "string" then . else "" end
    | gsub("[[:space:]]+"; " ") | sub("^ +"; "") | .[0:240]')
  [[ -n "$MESSAGE" ]] || MESSAGE="Action required"
fi

# Shared transport delivers to the terminal; no AppleScript notification process.
"$NOTIFIER" --title "$TITLE" -- "$SUBTITLE - $MESSAGE" || true
