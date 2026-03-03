#!/usr/bin/env bash
set -euo pipefail

# Read hook data from stdin
INPUT=$(cat)

HOOK_EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty')
NOTIFICATION_TYPE=$(echo "$INPUT" | jq -r '.notification_type // empty')

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
CWD=$(pwd)

if git rev-parse --is-inside-work-tree &>/dev/null; then
  REMOTE=$(git remote get-url origin 2>/dev/null || true)
  if [[ -n "$REMOTE" ]]; then
    # Strip trailing .git, then extract last path component
    REPO_NAME=$(echo "$REMOTE" | sed 's/\.git$//' | sed 's/.*[/:]//')
  fi
  [[ -z "$REPO_NAME" ]] && REPO_NAME=$(basename "$CWD")
  BRANCH_NAME=$(git branch --show-current 2>/dev/null || true)
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
  MESSAGE="Task completed"
else
  MESSAGE="Action required"
fi

# Send notification via osascript
osascript -e "display notification \"${SUBTITLE} - ${MESSAGE}\" with title \"${TITLE}\" sound name \"default\"" &>/dev/null || true

echo '{"success": true}'
