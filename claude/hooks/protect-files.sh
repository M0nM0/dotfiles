#!/usr/bin/env bash
# Hook: PreToolUse:Edit|Write
# .env, lockファイル, .git/ への書込みをブロックする
set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // empty')

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# 保護対象ファイルのチェック
case "$FILE_PATH" in
  *.env|*.env.*|*/.env|*/.env.*)
    echo "BLOCKED: .env ファイルへの書込みは禁止されています: $FILE_PATH"
    exit 2
    ;;
  *.lock|*/Gemfile.lock|*/yarn.lock|*/package-lock.json|*/pnpm-lock.yaml)
    echo "BLOCKED: lock ファイルへの書込みは禁止されています: $FILE_PATH"
    exit 2
    ;;
  */.git/*|*/.git)
    echo "BLOCKED: .git/ への書込みは禁止されています: $FILE_PATH"
    exit 2
    ;;
  */credentials.yml.enc|*/credentials.yml|*/master.key)
    echo "BLOCKED: 秘匿情報ファイルへの書込みは禁止されています: $FILE_PATH"
    exit 2
    ;;
esac

exit 0
