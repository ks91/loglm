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
    if brew_install_candidates "codex CLI" codex openai-codex; then
      say "codex CLI のインストールが完了しました。" \
          "codex CLI installed."
      exit 0
    fi
    say "Homebrew で codex CLI の提供パッケージが見つからなかったため npm にフォールバックします。" \
        "No Homebrew package was found for codex CLI; falling back to npm."
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
  say "エラー: codex CLI のインストールには npm が必要です。" \
      "Error: npm is required to install codex CLI." >&2
  say "Node.js + npm を入れてから loglm を再実行してください。" \
      "Install Node.js + npm first, then rerun loglm." >&2
  exit 1
fi

say "npm で codex CLI をインストールします..." \
    "Installing codex CLI with npm..."
if ! npm install -g @openai/codex; then
  say "エラー: codex CLI のインストールに失敗しました。" \
      "Error: failed to install codex CLI." >&2
  say "npm のグローバルパスに権限が必要な場合は管理者権限で再試行してください。" \
      "Try again with elevated privileges if your npm global prefix requires it." >&2
  exit 1
fi

say "codex CLI のインストールが完了しました。" \
    "codex CLI installed."
say "必要に応じて codex のドキュメントに従って認証情報を設定してください。" \
    "If needed, set your API credentials according to codex documentation."
