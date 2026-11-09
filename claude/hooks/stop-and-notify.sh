#!/usr/bin/env bash
# Run the existing stop guard before notifying, so a blocked stop stays silent.
set -uo pipefail
[[ -n "${STOP_GUARD_INNER:-}" ]] && exit 0
INPUT=$(cat)
HOOK_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
RESULT=$(printf '%s' "$INPUT" | "$HOOK_DIR/stop-guard.sh")
STATUS=$?
[[ -n "$RESULT" ]] && printf '%s\n' "$RESULT"
[[ "$STATUS" -ne 0 ]] && exit "$STATUS"
if ! printf '%s' "$RESULT" | jq -e '.decision == "block"' >/dev/null 2>&1; then
  printf '%s' "$INPUT" | "$HOOK_DIR/notify.sh"
fi
exit 0
