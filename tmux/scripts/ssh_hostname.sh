#!/usr/bin/env bash

# SSH接続を検出してhostnameを表示するスクリプト
# SSH接続時のみ[hostname] 形式で返し、それ以外は空文字を返す

if [ -n "$SSH_CONNECTION" ] || [ -n "$SSH_CLIENT" ]; then
    echo "[$(hostname -s)] "
fi
