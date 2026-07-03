#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/platform-detect.sh"

resolve_lang
PLATFORM="$(detect_platform)"

if command -v agy > /dev/null 2>&1 || command -v antigravity > /dev/null 2>&1; then
  exit 0
fi

say "注意: Gemini CLI は個人向け環境で Antigravity への移行が必要になる場合があります。" \
    "Note: Gemini CLI may require migration to Antigravity for individual accounts."
say "loglm は Google 系エージェントとして Antigravity CLI を使います（experimental）。" \
    "loglm uses Antigravity CLI as the Google-family agent (experimental)."

if [[ "$PLATFORM" == "macos" ]]; then
  if ensure_homebrew; then
    say "Homebrew cask で Antigravity CLI をインストールします: antigravity-cli" \
        "Installing Antigravity CLI with Homebrew cask: antigravity-cli"
    if brew install --cask antigravity-cli; then
      say "Antigravity CLI のインストールが完了しました。" \
          "Antigravity CLI installed."
      exit 0
    fi
  fi
fi

say "エラー: Antigravity CLI を自動インストールできませんでした。" \
    "Error: could not install Antigravity CLI automatically." >&2
say "公式サイトまたは Homebrew cask で antigravity-cli をインストールしてから再実行してください。" \
    "Install antigravity-cli from the official site or Homebrew cask, then rerun loglm." >&2
say "macOS 例: brew install --cask antigravity-cli" \
    "macOS example: brew install --cask antigravity-cli" >&2
exit 1
