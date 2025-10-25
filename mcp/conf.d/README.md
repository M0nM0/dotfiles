# MCP設定管理

このディレクトリは、Claude CodeとGemini CLI両方で使用するMCPサーバー設定を管理します。

## ディレクトリ構成

```
mcp/
├── conf.d/
│   ├── 00-common.json          # 共通MCP設定（dotfilesで管理）
│   ├── 50-work.json.example    # 社内PC用テンプレート
│   ├── 90-local.json.example   # ローカルプロジェクト用テンプレート
│   └── README.md               # このファイル
├── .gitignore                  # 個人設定を除外
└── scripts/
    └── sync-mcp.sh             # 同期スクリプト
```

## ファイルの役割

### 番号プレフィックスの意味

- `00-*.json` - 共通設定（dotfilesで管理、全環境で使用）
- `50-*.json` - 社内PC専用設定（.gitignoreで除外）
- `90-*.json` - ローカルプロジェクト固有設定（.gitignoreで除外）

数字順にマージされるため、優先順位の調整が可能です。

### 00-common.json

全員が使える共通MCPサーバー：
- github - GitHub操作
- memory - 記憶管理
- playwright - ブラウザ自動化
- serena - コード解析
- mcp-remote-github - Docker版GitHub MCP

### 50-work.json.example

社内PC専用MCPサーバーのテンプレート：
- atlassian - Atlassian SSE接続
- mcp-atlassian - Confluence/Jira操作

### 90-local.json.example

プロジェクト固有MCPサーバーのテンプレート：
- filesystem - ローカルファイルシステムアクセス

## セットアップ手順

### 初回セットアップ

```bash
# 1. MCPの初期化
make mcp-init

# 2. 環境変数の設定
vim ~/.env
# GITHUB_TOKEN等を設定

# 3. direnv有効化
direnv allow

# 4. MCP設定を同期
make mcp-sync
```

### 社内PC設定の追加

```bash
# 1. テンプレートをコピー
cp ~/.config/mcp/conf.d/50-work.json{.example,}

# 2. ~/.envに社内トークンを追加
vim ~/.env
# ATLASSIAN_TOKEN等を追加

# 3. 再同期
make mcp-sync
```

### ローカルプロジェクト設定の追加

```bash
# 1. テンプレートをコピー
cp ~/.config/mcp/conf.d/90-local.json{.example,}

# 2. プロジェクト固有設定を編集
vim ~/.config/mcp/conf.d/90-local.json

# 3. 再同期
make mcp-sync
```

## 環境変数

MCPサーバーの設定では、以下の環境変数が使えます（`~/.env`で管理）：

| 変数 | 説明 | 例 |
|------|------|-----|
| `GITHUB_TOKEN` | GitHub Personal Access Token | `ghp_xxx` |
| `MCP_PROJECT_PATH` | プロジェクトパス | `$(pwd)` |
| `ATLASSIAN_CONFLUENCE_URL` | Confluence URL | `https://company.atlassian.net/wiki` |
| `ATLASSIAN_USERNAME` | Atlassianユーザー名 | `user@company.com` |
| `ATLASSIAN_TOKEN` | Atlassianトークン | `ATATT...` |
| `JIRA_URL` | Jira URL | `https://company.atlassian.net` |
| `JIRA_USERNAME` | Jiraユーザー名 | `user@company.com` |
| `JIRA_TOKEN` | Jiraトークン | `ATATT...` |

## 新しいMCPサーバーの追加

### 共通サーバーの場合

`00-common.json`に直接追加：

```json
{
  "mcpServers": {
    "new-server": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@your/mcp-server"],
      "env": {}
    }
  }
}
```

### 個人用サーバーの場合

新しいファイルを作成（例: `90-personal.json`）：

```bash
cat > ~/.config/mcp/conf.d/90-personal.json <<EOF
{
  "mcpServers": {
    "my-server": {
      "type": "stdio",
      "command": "uvx",
      "args": ["my-mcp-server"],
      "env": {}
    }
  }
}
EOF

make mcp-sync
```

## トラブルシューティング

### 環境変数が展開されない

direnvが有効化されているか確認：

```bash
direnv status
direnv allow
```

### 同期エラー

必要なツールがインストールされているか確認：

```bash
make install-packages
```

### 設定が反映されない

conf.dのJSONが正しいか確認：

```bash
jq . ~/.config/mcp/conf.d/*.json
```
