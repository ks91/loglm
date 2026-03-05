#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/platform-detect.sh"

resolve_lang

AGENT="${1:-}"
PLATFORM="$(detect_platform)"
PLATFORM_NAME="$(platform_label "$PLATFORM")"

say "実行環境: $PLATFORM_NAME" "Platform: $PLATFORM_NAME"

if ! command -v script > /dev/null 2>&1; then
  say "'script' コマンドが見つかりません。util-linux（または BSD script）を入れてください。" \
      "The 'script' command is missing. Install util-linux (or BSD script)."
  exit 1
fi

if command -v node > /dev/null 2>&1 && command -v npm > /dev/null 2>&1; then
  say "Node.js / npm は利用可能です。" "Node.js / npm is available."
else
  if prompt_yes_no \
    "Node.js / npm が見つかりません。今インストールしますか？" \
    "Node.js / npm was not found. Install now?"; then
    "$SCRIPT_DIR/install-node.sh"
  else
    say "Node.js / npm が必要です。セットアップを中止しました。" \
        "Node.js / npm is required. Setup was cancelled."
    exit 1
  fi
fi

if [[ "$AGENT" == "claude" ]]; then
  say "注意: Claude Code は環境によってネイティブインストール推奨の場合があります。" \
      "Note: Claude Code may recommend native installation on some environments."
fi
