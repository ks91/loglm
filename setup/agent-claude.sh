#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/platform-detect.sh"

resolve_lang
PLATFORM="$(detect_platform)"

say "注意: Claude Code は環境によってネイティブインストール推奨の場合があります。" \
    "Note: Claude Code may recommend native installation on some environments."

if [[ "$PLATFORM" == "macos" ]]; then
  if ensure_homebrew; then
    if prompt_yes_no \
      "Homebrew 版の Claude Code CLI を試しますか？" \
      "Try installing Claude Code CLI via Homebrew?"; then
      if brew_install_candidates "Claude Code CLI" claude-code anthropic-claude-code; then
        say "Claude Code CLI のインストールが完了しました。" \
            "Claude Code CLI installed."
        exit 0
      fi
      say "Homebrew で Claude Code CLI の提供パッケージが見つからなかったため npm にフォールバックします。" \
          "No Homebrew package was found for Claude Code CLI; falling back to npm."
    else
      say "Homebrew インストールをスキップしました。" \
          "Skipped Homebrew installation."
    fi
  else
    case "$?" in
      2)
        say "Homebrew セットアップをスキップしたため npm でインストールします。" \
            "Homebrew setup was skipped; installing with npm."
        ;;
      *)
        say "Homebrew セットアップに失敗したため npm でインストールします。" \
            "Homebrew setup failed; installing with npm."
        ;;
    esac
  fi
fi

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
