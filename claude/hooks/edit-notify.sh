#!/usr/bin/env bash
# Hook: PostToolUse:Edit|Write
# ファイル編集完了を通知する
set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // empty')

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

FILENAME=$(basename "$FILE_PATH")
echo "File updated: $FILENAME"

exit 0
