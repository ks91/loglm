#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/platform-detect.sh"

resolve_lang
PLATFORM="$(detect_platform)"

ensure_npm_for_fallback() {
  if command -v npm > /dev/null 2>&1 || activate_nvm_default_if_available; then
    return 0
  fi
  if ! prompt_yes_no \
    "npm が見つかりません。Node.js / npm を今インストールしますか？" \
    "npm was not found. Install Node.js / npm now?"; then
    return 1
  fi
  "$SCRIPT_DIR/install-node.sh"
  command -v npm > /dev/null 2>&1 || activate_nvm_default_if_available
}
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

if ! ensure_npm_for_fallback; then
  say "エラー: codex CLI のインストールには npm が必要です。" \
      "Error: npm is required to install codex CLI." >&2
  say "Node.js + npm を入れてから loglm を再実行してください。" \
      "Install Node.js + npm first, then rerun loglm." >&2
  exit 1
fi

if ! prepare_npm_user_prefix; then
  say "エラー: npm のユーザー領域設定に失敗しました。" \
      "Error: failed to configure npm user prefix." >&2
  exit 1
fi

say "npm で codex CLI をインストールします..." \
    "Installing codex CLI with npm..."
if ! npm install -g @openai/codex; then
  say "エラー: codex CLI のインストールに失敗しました。" \
      "Error: failed to install codex CLI." >&2
  say "npm 設定またはネットワーク接続を確認して再試行してください。" \
      "Please check your npm settings or network connectivity and retry." >&2
  exit 1
fi

say "codex CLI のインストールが完了しました。" \
    "codex CLI installed."
say "必要に応じて codex のドキュメントに従って認証情報を設定してください。" \
    "If needed, set your API credentials according to codex documentation."
