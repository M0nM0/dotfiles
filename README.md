# Dotfiles

モダンで宣言的なdotfile管理。Mac/Linux両対応。

## ✨ 特徴

- 🔄 **宣言的管理**: YAMLとテキストファイルで管理
- 🖥️ **クロスプラットフォーム**: Mac/Linux両対応
- 📦 **統一パッケージ管理**: Homebrew統一
- 🔧 **バージョンマネージャー統合**: pyenv, nodenv, rbenv, goenv
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

### Homebrew（Mac/Linux共通）

バージョンマネージャー:
- pyenv - Python
- nodenv - Node.js
- rbenv - Ruby
- goenv - Go

開発ツール:
- neovim
- tmux
- git
- curl

CLIツール:
- gh - GitHub CLI
- ghq - リポジトリ管理
- lazygit - Git TUI
- starship - シェルプロンプト

### npm（グローバルパッケージ）

- @anthropic-ai/claude-code
- @google/gemini-cli
- cz-git / czg - Conventional Commits

### cargo（Rustツール）

- ripgrep - 高速grep
- bat - catの改良版
- fd-find - findの改良版
- eza - lsの改良版

### sheldon（zshプラグイン管理）

詳細は `sheldon/plugins.toml` を参照。

## 🗂️ ディレクトリ構成

```
dotfiles/
├── Makefile              # タスクランナー
├── install               # dotbotブートストラップ
├── install.conf.yaml     # シンボリックリンク設定
├── packages/             # パッケージリスト
│   ├── brew.txt         # Homebrew
│   ├── npm.txt          # npm
│   └── cargo.txt        # cargo
├── zsh/                  # zsh設定
├── tmux/                 # tmux設定
├── sheldon/              # zshプラグイン管理
├── wezterm/              # ターミナル設定
└── ...
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

### cargoがインストールされていない

Rustをインストール:
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

## 📝 セットアップフロー

1. **Homebrewインストール**（未インストール時）
2. **brewパッケージインストール**（pyenv, nodenv, neovim等）
3. **cargoパッケージインストール**（ripgrep, bat等）
4. **npmパッケージインストール**（claude-code, gemini-cli等）
5. **シンボリックリンク作成**（dotbot経由）

## 🔄 更新手順

定期的に以下を実行:
```bash
make update
```

## 📄 ライセンス

MIT

## 🤝 コントリビューション

Issue・PRお待ちしています！
