.PHONY: install link update help install-packages install-brew install-rust install-volta install-nodejs install-brew-packages install-npm install-cargo install-go

UNAME := $(shell uname)
VOLTA_HOME := $(HOME)/.volta
CARGO_HOME := $(HOME)/.cargo
SHELL_PATH := $(VOLTA_HOME)/bin:$(CARGO_HOME)/bin:$(PATH)

# PATH設定（make実行中に有効）
# Mac/Linuxのbrewパスを追加（存在しないパスは自動的に無視される）
export PATH := /opt/homebrew/bin:/home/linuxbrew/.linuxbrew/bin:$(HOME)/.cargo/bin:$(HOME)/.volta/bin:$(PATH)

help:
	@echo "Available commands:"
	@echo "  make install           - 初回セットアップ（全自動）"
	@echo "  make link              - シンボリックリンク作成のみ"
	@echo "  make update            - 全パッケージ更新"
	@echo "  make install-packages  - パッケージ再インストール"

# 初回セットアップ
install: link install-brew install-rust install-volta install-nodejs install-packages setup-env
	@echo "✅ Setup complete!"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Restart your shell or run: exec zsh"

# シンボリックリンク作成
link:
	@./install

# パッケージインストール
install-packages: install-brew-packages install-tmux-plugins install-cargo install-npm install-go
	@echo "✅ All packages installed"

# Homebrewインストール
install-brew:
	@if [ "$(UNAME)" = "Linux" ]; then \
		if ! command -v brew >/dev/null 2>&1; then \
			echo "📦 Installing Homebrew to /home/linuxbrew/.linuxbrew..."; \
			echo "⚠️  sudo権限が必要です。パスワード入力を求められます。"; \
			/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
			echo "✅ Homebrew installed"; \
		else \
			echo "✅ Homebrew already installed"; \
		fi; \
	else \
		if ! command -v brew >/dev/null 2>&1; then \
			echo "📦 Installing Homebrew..."; \
			/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
			echo "✅ Homebrew installed"; \
		else \
			echo "✅ Homebrew already installed"; \
		fi; \
	fi

# Rustインストール（rustup経由）
install-rust:
	@if ! command -v cargo >/dev/null 2>&1; then \
		echo "📦 Installing Rust (rustup)..."; \
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; \
		export PATH="$$HOME/.cargo/bin:$$PATH"; \
		echo "✅ Rust installed"; \
	else \
		echo "✅ Rust already installed"; \
	fi

# Voltaインストール
install-volta:
	@if ! command -v volta >/dev/null 2>&1; then \
		echo "📦 Installing Volta..."; \
		curl https://get.volta.sh | bash; \
		export VOLTA_HOME="$$HOME/.volta"; \
		export PATH="$$VOLTA_HOME/bin:$$PATH"; \
		echo "✅ Volta installed"; \
	else \
		echo "✅ Volta already installed"; \
	fi

# Node.js LTSインストール（Volta経由）
install-nodejs:
	@export PATH="$(SHELL_PATH)"; \
	if ! command -v volta >/dev/null 2>&1; then \
		echo "⚠️  Volta not found. Run: make install-volta"; \
		exit 1; \
	fi; \
	if ! command -v node >/dev/null 2>&1; then \
		echo "📦 Installing Node.js LTS with Volta..."; \
		volta install node; \
		volta install npm; \
		volta install yarn; \
		echo "✅ Node.js LTS installed"; \
	else \
		echo "✅ Node.js already installed ($$(node --version))"; \
	fi

# Homebrewパッケージインストール（冪等性保証）
install-brew-packages:
	@echo "📦 Installing Homebrew packages..."
	@while IFS= read -r package; do \
		[ -z "$$package" ] && continue; \
		echo "$$package" | grep -q '^#' && continue; \
		if brew list --formula | grep -q "^$$package$$"; then \
			echo "  ✓ $$package (already installed)"; \
		else \
			echo "  + Installing $$package..."; \
			brew install "$$package" || true; \
		fi; \
	done < packages/brew.txt
	@echo "✅ Homebrew packages installed"

# tmuxプラグインインストール（tpm経由）
install-tmux-plugins:
	@echo "📦 Setting up tmux plugins..."
	@if ! command -v tmux >/dev/null 2>&1; then \
		echo "⚠️  tmux not found. Run: make install-brew-packages"; \
		exit 1; \
	fi
	@if [ ! -L ~/.tmux ]; then \
		echo "⚠️  ~/.tmux symlink not found. Run: ./install first"; \
		exit 1; \
	fi
	@if [ ! -d ~/.tmux/plugins/tpm ]; then \
		echo "  + Cloning tpm..."; \
		git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm; \
		echo "  ✓ tpm cloned"; \
	else \
		echo "  ✓ tpm already exists"; \
	fi
	@echo "  + Installing tmux plugins..."
	@~/.tmux/plugins/tpm/bin/install_plugins
	@echo "✅ Tmux plugins installed"

# cargoパッケージインストール（冪等性保証）
install-cargo:
	@echo "📦 Installing cargo packages..."
	@if command -v cargo >/dev/null 2>&1; then \
		while IFS= read -r package; do \
			[ -z "$$package" ] && continue; \
			echo "$$package" | grep -q '^#' && continue; \
			if cargo install --list | grep -q "^$$package "; then \
				echo "  ✓ $$package (already installed)"; \
			else \
				echo "  + Installing $$package..."; \
				cargo install --locked "$$package" || true; \
			fi; \
		done < packages/cargo.txt; \
		echo "✅ Cargo packages installed"; \
	else \
		echo "⚠️  cargo not found. Run: make install-rust"; \
	fi

# npmグローバルパッケージインストール（冪等性保証）
install-npm:
	@echo "📦 Installing npm global packages..."
	@if command -v npm >/dev/null 2>&1; then \
		while IFS= read -r package; do \
			[ -z "$$package" ] && continue; \
			echo "$$package" | grep -q '^#' && continue; \
			if npm list -g "$$package" >/dev/null 2>&1; then \
				echo "  ✓ $$package (already installed)"; \
			else \
				echo "  + Installing $$package..."; \
				npm install -g "$$package" || true; \
			fi; \
		done < packages/npm.txt; \
		echo "✅ npm packages installed"; \
	else \
		echo "⚠️  npm not found. Run: make install-volta && make install-nodejs"; \
	fi

# Goパッケージインストール（冪等性保証）
install-go:
	@echo "📦 Installing go packages..."
	@if command -v go >/dev/null 2>&1; then \
		while IFS= read -r package; do \
			[ -z "$$package" ] && continue; \
			echo "$$package" | grep -q '^#' && continue; \
			if go list -m "$${package%%@*}" >/dev/null 2>&1; then \
				echo "  ✓ $$package (already installed)"; \
			else \
				echo "  + Installing $$package..."; \
				go install "$$package" || true; \
			fi; \
		done < packages/go.txt; \
		echo "✅ Go packages installed"; \
	else \
		echo "⚠️  go not found. Run: make install-golang"; \
	fi

# 全更新
update:
	@echo "🔄 Updating all packages..."
	@brew update && brew upgrade
	@if command -v cargo >/dev/null 2>&1; then cargo install-update -a; fi
	@if command -v npm >/dev/null 2>&1; then npm update -g; fi
	@if command -v go >/dev/null 2>&1; then $(MAKE) install-go; fi
	@git submodule update --remote --merge && git -C nvim checkout main
	@echo "✅ All packages updated"

# 環境変数セットアップ（.env + direnv）
setup-env:
	@echo "🔧 Setting up environment..."
	@if [ ! -f ~/.env ]; then \
		cp $(PWD)/.env.example ~/.env; \
		echo "✅ Created ~/.env from .env.example"; \
		echo "📝 Please edit ~/.env with your tokens: vim ~/.env"; \
	else \
		echo "✅ ~/.env already exists (skipped)"; \
	fi
	@if command -v direnv >/dev/null 2>&1; then \
		cd $(PWD) && direnv allow; \
		echo "✅ direnv allow executed"; \
	else \
		echo "⚠️  direnv not found. Install it with: brew install direnv"; \
	fi

# MCP設定の初期化
mcp-init:
	@echo "🔧 Initializing MCP configuration..."
	@mkdir -p ~/.config/mcp/conf.d
	@if [ ! -f ~/.env ]; then \
		cp $(PWD)/.env.example ~/.env; \
		echo "📝 Created ~/.env - Please edit with your tokens"; \
		echo "   vim ~/.env"; \
	else \
		echo "✅ ~/.env already exists"; \
	fi
	@ln -sf $(PWD)/mcp/conf.d/00-common.json ~/.config/mcp/conf.d/00-common.json
	@echo "✅ MCP initialized"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Edit ~/.env with your tokens: vim ~/.env"
	@echo "  2. Allow direnv: direnv allow"
	@echo "  3. Sync MCP config: make mcp-sync"

# MCP設定の同期
mcp-sync:
	@./mcp/scripts/sync-mcp.sh
