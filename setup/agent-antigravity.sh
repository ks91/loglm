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

install_with_official_script() {
  local installer tmp_installer
  installer="https://antigravity.google/cli/install.sh"
  tmp_installer="$(mktemp)"
  trap 'rm -f "$tmp_installer"' RETURN

  if command -v curl > /dev/null 2>&1; then
    curl -fsSL "$installer" > "$tmp_installer"
  elif command -v wget > /dev/null 2>&1; then
    wget -qO- "$installer" > "$tmp_installer"
  else
    say "エラー: Antigravity CLI 公式インストーラーの取得には curl または wget が必要です。" \
        "Error: curl or wget is required to fetch the official Antigravity CLI installer." >&2
    return 1
  fi

  say "公式インストーラーで Antigravity CLI をインストールします。" \
      "Installing Antigravity CLI with the official installer."
  bash "$tmp_installer"
  rm -f "$tmp_installer"
  trap - RETURN
  ensure_dir_on_path_now_and_profile "$HOME/.local/bin"
}

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

  if prompt_yes_no \
    "Homebrew でのインストールに失敗またはスキップされました。公式インストーラーを試しますか？" \
    "Homebrew installation failed or was skipped. Try the official installer?"; then
    install_with_official_script && exit 0
  fi
elif [[ "$PLATFORM" == "ubuntu" || "$PLATFORM" == "linux" || "$PLATFORM" == "raspberrypi" || "$PLATFORM" == "chromeos" || "$PLATFORM" == "wsl2" ]]; then
  if prompt_yes_no \
    "公式インストーラーで Antigravity CLI をインストールしますか？" \
    "Install Antigravity CLI with the official installer?"; then
    install_with_official_script && exit 0
  fi
fi

say "エラー: Antigravity CLI を自動インストールできませんでした。" \
    "Error: could not install Antigravity CLI automatically." >&2
say "公式インストーラーまたは Homebrew cask で antigravity-cli をインストールしてから再実行してください。" \
    "Install antigravity-cli with the official installer or Homebrew cask, then rerun loglm." >&2
say "macOS/Linux 公式例: curl -fsSL https://antigravity.google/cli/install.sh | bash" \
    "macOS/Linux official example: curl -fsSL https://antigravity.google/cli/install.sh | bash" >&2
say "macOS 例: brew install --cask antigravity-cli" \
    "macOS example: brew install --cask antigravity-cli" >&2
exit 1
