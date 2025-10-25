# Dotfiles

モダンで宣言的なdotfile管理。Mac/Linux両対応。

## ✨ 特徴

- 🔄 **宣言的管理**: YAMLとテキストファイルで管理
- 🖥️ **クロスプラットフォーム**: Mac/Linux両対応
- 📦 **統一パッケージ管理**: Homebrew統一
- 🔧 **バージョンマネージャー統合**: pyenv, Volta, rbenv, goenv
- 🎨 **シェル環境**: zsh + sheldon + starship
- 🚀 **1コマンドセットアップ**: `make install`

## 📋 前提条件

- Git
- Make（通常プリインストール済み）

## 🚀 クイックスタート

```bash
git clone <your-repo-url> ~/dotfiles
cd ~/dotfiles
make install
```

セットアップ後、シェルを再起動：
```bash
exec zsh
```

## 📖 コマンド一覧

| コマンド | 説明 |
|---------|------|
| `make install` | 初回セットアップ（全自動） |
| `make link` | シンボリックリンク作成のみ |
| `make install-packages` | パッケージ再インストール |
| `make update` | 全パッケージ更新 |
| `make help` | ヘルプ表示 |

## 📦 管理ツール

### Volta（Node.js/npmバージョン管理）⭐

- **超高速**（Rust製、nvmの40倍）
- Node.js、npm、yarnを統一管理
- プロジェクトごとに自動バージョン切り替え
- `package.json`でチーム共有

### Rust（cargo）

- rustup経由でインストール
- cargoパッケージ: ripgrep, bat, fd-find, eza

### uv（Pythonパッケージマネージャー）⭐

- **超高速**（Rust製、pipの10-100倍）
- pip、poetry、pipx、virtualenvを1つに統合
- pipと完全互換
- pyenvと併用可能

### Homebrew（Mac/Linux共通）

バージョンマネージャー:
- pyenv - Pythonバージョン管理
- rbenv - Ruby
- goenv - Go

開発ツール:
- neovim
- tmux
- git
- curl
- uv - Pythonパッケージマネージャー

CLIツール:
- gh - GitHub CLI
- ghq - リポジトリ管理
- lazygit - Git TUI
- starship - シェルプロンプト

### npm（グローバルパッケージ）

- @anthropic-ai/claude-code
- @google/gemini-cli
- cz-git / czg - Conventional Commits

### sheldon（zshプラグイン管理）

詳細は `sheldon/plugins.toml` を参照。

## 🗂️ ディレクトリ構成

```
dotfiles/
├── Makefile              # タスクランナー
├── install               # dotbotブートストラップ
├── install.conf.yaml     # シンボリックリンク設定
├── .env.example          # 環境変数テンプレート
├── .envrc                # direnv設定
├── packages/             # パッケージリスト
│   ├── brew.txt         # Homebrew
│   ├── npm.txt          # npm
│   └── cargo.txt        # cargo
├── mcp/                  # MCP設定（Claude Code + Gemini CLI）
│   ├── conf.d/          # 設定ファイル（番号順にマージ）
│   │   ├── 00-common.json         # 共通設定（dotfiles管理）
│   │   ├── 50-work.json.example   # 社内PC用テンプレート
│   │   ├── 90-local.json.example  # ローカル用テンプレート
│   │   └── README.md              # MCP設定ガイド
│   ├── .gitignore       # 個人設定を除外
│   └── scripts/
│       └── sync-mcp.sh  # 同期スクリプト
├── zsh/                  # zsh設定
├── tmux/                 # tmux設定
├── sheldon/              # zshプラグイン管理
├── wezterm/              # ターミナル設定
├── git/                  # git設定
├── lazygit/              # lazygit設定
├── gh/                   # GitHub CLI設定
├── karabiner/            # Karabiner設定（Mac専用）
└── nvim/                 # Neovim設定（submodule）
```

## 🔧 カスタマイズ

### パッケージの追加/削除

1. 該当ファイルを編集:
   - `packages/brew.txt`
   - `packages/npm.txt`
   - `packages/cargo.txt`

2. 再インストール:
```bash
make install-packages
```

### zshプラグインの追加

`sheldon/plugins.toml` を編集後:
```bash
sheldon lock --update
```

### alias管理

aliasはカテゴリ別にファイル分割し、sheldonで管理しています。

#### ファイル構成

```
zsh/aliases/
├── common-tools.zsh      # 汎用ツール短縮形（g, lg, nv等）
├── common-commands.zsh   # 汎用コマンド拡張（ll, reload等）
├── navigation.zsh        # ディレクトリ移動（doc, des等）
├── mac.zsh               # Mac固有（arm, x64等）
└── local.zsh            # 環境固有（git管理外）
```

#### 環境固有aliasの追加

仕事用やマシン固有のaliasは `zsh/aliases/local.zsh` に追加します（git管理外）。

### MCP設定（Claude Code + Gemini CLI）

MCPサーバーの設定は`mcp/conf.d/`で管理します。

#### 初回セットアップ

```bash
make mcp-init              # 初期化
vim ~/.env                 # トークン設定（GITHUB_TOKEN等）
direnv allow               # direnv有効化
make mcp-sync              # Claude Code + Gemini CLIに反映
```

#### 社内PC設定の追加

```bash
cp ~/.config/mcp/conf.d/50-work.json{.example,}
vim ~/.env                 # 社内トークン追加
make mcp-sync              # 再同期
```

#### ローカルプロジェクト設定

```bash
cp ~/.config/mcp/conf.d/90-local.json{.example,}
vim ~/.config/mcp/conf.d/90-local.json
make mcp-sync
```

詳細は `mcp/conf.d/README.md` を参照。

## 🛠️ トラブルシューティング

### Linuxでbrewが見つからない

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

その後、シェル設定に追加:
```bash
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
```

### シンボリックリンクの問題

既存のファイルを削除してから:
```bash
make link
```

### tmuxプラグインがインストールされない

tmux起動後、以下のキーを押す:
```
prefix + I
```
（デフォルトのprefixは `Ctrl+b`）

### Rust/cargoがインストールされていない

```bash
make install-rust
```

### Volta/Node.jsがインストールされていない

```bash
make install-volta
make install-nodejs
```

## 📝 セットアップフロー

1. **Homebrewインストール**（未インストール時）
2. **Rust（rustup）インストール**
3. **Volta インストール**
4. **Node.js LTS（Volta経由）インストール**
5. **brewパッケージインストール**（pyenv, rbenv, goenv, neovim等）
6. **cargoパッケージインストール**（ripgrep, bat等、`--locked`フラグ付き）
7. **npmパッケージインストール**（claude-code, gemini-cli等）
8. **シンボリックリンク作成**（dotbot経由）

## 🔄 更新手順

定期的に以下を実行:
```bash
make update
```

## 📄 ライセンス

MIT

## 🤝 コントリビューション

Issue・PRお待ちしています！
