#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib.sh"

resolve_lang

say "注意: Claude Code は環境によってネイティブインストール推奨の場合があります。" \
    "Note: Claude Code may recommend native installation on some environments."

if ! prompt_yes_no \
  "npm ベースのクイックインストールを実行しますか？" \
  "Run npm-based quick install now?"; then
  say "スキップしました。Claude Code の公式手順でインストールしてください。" \
      "Skipped. Please install Claude Code using official instructions."
  exit 1
fi

if ! command -v npm > /dev/null 2>&1; then
  say "エラー: Claude Code CLI のインストールには npm が必要です。" \
      "Error: npm is required to install Claude Code CLI." >&2
  say "Node.js + npm を入れてから loglm を再実行してください。" \
      "Install Node.js + npm first, then rerun loglm." >&2
  exit 1
fi

say "npm で Claude Code CLI をインストールします..." \
    "Installing Claude Code CLI with npm..."
if ! npm install -g @anthropic-ai/claude-code; then
  say "エラー: Claude Code CLI のインストールに失敗しました。" \
      "Error: failed to install Claude Code CLI." >&2
  say "npm のグローバルパスに権限が必要な場合は管理者権限で再試行してください。" \
      "Try again with elevated privileges if your npm global prefix requires it." >&2
  exit 1
fi

say "Claude Code CLI のインストールが完了しました。" \
    "Claude Code CLI installed."
say "必要に応じて Claude Code のドキュメントに従って認証情報を設定してください。" \
    "If needed, set your API credentials according to Claude Code documentation."
