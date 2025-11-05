#!/usr/bin/env bash
set -euo pipefail

echo "🔧 Syncing MCP configuration..."

# ツールチェック
for cmd in jq envsubst; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "❌ $cmd not found. Run: make install-packages"
        exit 1
    fi
done

# conf.dディレクトリの存在確認
if [ ! -d ~/.config/mcp/conf.d ]; then
    echo "❌ ~/.config/mcp/conf.d not found. Run: make mcp-init"
    exit 1
fi

# conf.dのJSONファイルが存在するか確認
if ! ls ~/.config/mcp/conf.d/*.json >/dev/null 2>&1; then
    echo "❌ No JSON files found in ~/.config/mcp/conf.d"
    exit 1
fi

# direnvで環境変数は既に読み込まれている前提
# conf.dをマージして環境変数展開（envsubstで${VAR}を展開）
MERGED=$(jq -s 'reduce .[] as $item ({}; .mcpServers += $item.mcpServers)' \
    ~/.config/mcp/conf.d/*.json 2>/dev/null | envsubst)

# Claude Code用（~/.mcp.json）
echo "$MERGED" > ~/.mcp.json
echo "✅ ~/.mcp.json (Claude Code)"

# Gemini CLI用（~/.gemini/settings.json）
if [ -f ~/.gemini/settings.json ]; then
    # 既存のsettings.jsonのmcpServersセクションのみ置き換え
    echo "$MERGED" | jq '.mcpServers = input.mcpServers' \
        ~/.gemini/settings.json - > ~/.gemini/settings.json.tmp
    mv ~/.gemini/settings.json.tmp ~/.gemini/settings.json
    echo "✅ ~/.gemini/settings.json (Gemini CLI)"
else
    echo "⚠️  ~/.gemini/settings.json not found, skipping Gemini CLI sync"
fi

echo "✅ MCP sync complete"
