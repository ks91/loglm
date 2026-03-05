#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/platform-detect.sh"

resolve_lang
PLATFORM="$(detect_platform)"
if [[ "$PLATFORM" == "macos" ]]; then
  if ensure_homebrew; then
    if brew_install_candidates "Gemini CLI" gemini-cli google-gemini-cli; then
      say "Gemini CLI のインストールが完了しました。" \
          "Gemini CLI installed."
      exit 0
    fi
    say "Homebrew で Gemini CLI の提供パッケージが見つからなかったため npm にフォールバックします。" \
        "No Homebrew package was found for Gemini CLI; falling back to npm."
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

if ! command -v npm > /dev/null 2>&1; then
  say "エラー: Gemini CLI のインストールには npm が必要です。" \
      "Error: npm is required to install Gemini CLI." >&2
  say "Node.js + npm を入れてから loglm を再実行してください。" \
      "Install Node.js + npm first, then rerun loglm." >&2
  exit 1
fi

say "npm で Gemini CLI をインストールします..." \
    "Installing Gemini CLI with npm..."
if ! npm install -g @google/gemini-cli; then
  say "エラー: Gemini CLI のインストールに失敗しました。" \
      "Error: failed to install Gemini CLI." >&2
  say "npm のグローバルパスに権限が必要な場合は管理者権限で再試行してください。" \
      "Try again with elevated privileges if your npm global prefix requires it." >&2
  exit 1
fi

say "Gemini CLI のインストールが完了しました。" \
    "Gemini CLI installed."
say "必要に応じて Gemini CLI のドキュメントに従って認証情報を設定してください。" \
    "If needed, set your API credentials according to Gemini CLI documentation."
