.PHONY: install link update help install-packages install-brew install-brew-packages install-npm install-cargo

UNAME := $(shell uname)

help:
	@echo "Available commands:"
	@echo "  make install           - 初回セットアップ（全自動）"
	@echo "  make link              - シンボリックリンク作成のみ"
	@echo "  make update            - 全パッケージ更新"
	@echo "  make install-packages  - パッケージ再インストール"

# 初回セットアップ
install: install-brew install-packages link
	@echo "✅ Setup complete!"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Restart your shell or run: exec zsh"
	@echo "  2. For tmux: Press prefix + I to install plugins"

# シンボリックリンク作成
link:
	@./install

# パッケージインストール
install-packages: install-brew-packages install-cargo install-npm
	@echo "✅ All packages installed"

# Homebrewインストール
install-brew:
	@if ! command -v brew >/dev/null 2>&1; then \
		echo "📦 Installing Homebrew..."; \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
		if [ "$(UNAME)" = "Linux" ]; then \
			echo 'eval "$$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc; \
			eval "$$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"; \
		fi; \
	else \
		echo "✅ Homebrew already installed"; \
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
				cargo install "$$package" || true; \
			fi; \
		done < packages/cargo.txt; \
		echo "✅ Cargo packages installed"; \
	else \
		echo "⚠️  cargo not found. Install Rust first: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"; \
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
		echo "⚠️  npm not found. Install Node.js with nodenv first."; \
	fi

# 全更新
update:
	@echo "🔄 Updating all packages..."
	@brew update && brew upgrade
	@if command -v cargo >/dev/null 2>&1; then \
		if ! command -v cargo-install-update >/dev/null 2>&1; then \
			cargo install cargo-update; \
		fi; \
		cargo install-update -a; \
	fi
	@if command -v npm >/dev/null 2>&1; then npm update -g; fi
	@git submodule update --remote --merge
	@echo "✅ All packages updated"
