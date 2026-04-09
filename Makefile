.PHONY: install link update help install-packages install-brew install-languages install-brew-packages install-pnpm install-cargo install-go setup-git claude-setup

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
install: link install-brew install-brew-packages install-languages install-npm install-cargo install-go install-pipx setup-env claude-setup setup-git
	@echo "✅ Setup complete!"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Restart your shell or run: exec zsh"

# シンボリックリンク作成
link:
	@./install

# パッケージインストール
install-packages: install-brew-packages install-cargo install-pnpm install-go install-pipx
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

# 言語ランタイムのインストール（mise経由）
install-languages:
	@if ! command -v mise >/dev/null 2>&1; then \
		echo "⚠️  mise not found. Run: make install-brew-packages"; \
		exit 1; \
	fi
	@echo "📦 Installing language runtimes via mise..."
	@mise install
	@echo "✅ Language runtimes installed"

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
	@npm install -g $$(cat packages/npm.txt | grep -v '^$$' | sed 's/$$/@latest/' | tr '\n' ' ')
	@echo "✅ npm global packages installed"

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

# pipxパッケージインストール（冪等性保証）
install-pipx:
	@echo "📦 Installing pipx packages..."
	@if command -v pipx >/dev/null 2>&1; then \
		while IFS= read -r package; do \
			[ -z "$$package" ] && continue; \
			echo "$$package" | grep -q '^#' && continue; \
			if pipx list | grep -q "package $$package"; then \
				echo "  ✓ $$package (already installed)"; \
			else \
				echo "  + Installing $$package..."; \
				pipx install "$$package" || true; \
			fi; \
		done < packages/pipx.txt; \
		echo "✅ Pipx packages installed"; \
	else \
		echo "⚠️  pipx not found. Run: make install-brew-packages"; \
	fi

# 全更新
update:
	@echo "🔄 Updating all packages..."
	@mise upgrade
	@brew update && brew upgrade
	@if command -v cargo >/dev/null 2>&1; then cargo install-update -a; fi
	@if command -v npm >/dev/null 2>&1; then npm update -g; fi
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

# Claude Code設定セットアップ
claude-setup:
	@echo "🔧 Setting up Claude Code..."
	@find $(PWD)/claude -type f \( -name '*.sh' -o -name '*.ts' \) -exec chmod +x {} +
	@echo "✅ Claude Code setup complete"

# Git個人設定
setup-git:
	@if [ ! -f ~/.gitconfig ]; then \
		cp $(PWD)/.gitconfig.template ~/.gitconfig; \
		echo "✅ Created ~/.gitconfig"; \
		echo ""; \
		echo "📝 Set your git config:"; \
		echo "   git config --global user.name 'Your Name'"; \
		echo "   git config --global user.email 'your@email.com'"; \
	else \
		echo "✅ ~/.gitconfig already exists (skipped)"; \
	fi
