#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/platform-detect.sh"

resolve_lang
PLATFORM="$(detect_platform)"

install_node_with_apt() {
  if ! command -v apt-get > /dev/null 2>&1; then
    say "この環境では apt-get が見つかりません。Node.js を手動でインストールしてください。" \
        "apt-get was not found on this system. Please install Node.js manually."
    return 1
  fi

  say "apt-get で Node.js と npm をインストールします。" \
      "Installing Node.js and npm using apt-get."
  run_as_root apt-get update
  run_as_root apt-get install -y nodejs npm
}

install_homebrew() {
  if command -v brew > /dev/null 2>&1; then
    return 0
  fi

  if ! prompt_yes_no \
    "Homebrew が見つかりません。Homebrew をインストールしますか？" \
    "Homebrew was not found. Install Homebrew now?"; then
    return 1
  fi

  if ! command -v curl > /dev/null 2>&1; then
    say "Homebrew のインストールには curl が必要です。" \
        "curl is required to install Homebrew."
    return 1
  fi

  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

case "$PLATFORM" in
  macos)
    if ! install_homebrew; then
      say "Homebrew のセットアップをスキップしました。" \
          "Skipped Homebrew setup."
      exit 1
    fi
    say "Homebrew で Node.js をインストールします。" \
        "Installing Node.js with Homebrew."
    brew update
    brew install node
    ;;
  ubuntu|wsl2|raspberrypi|chromeos|linux)
    install_node_with_apt
    ;;
  *)
    say "未対応の OS です。Node.js を手動でインストールしてください。" \
        "Unsupported OS. Please install Node.js manually."
    exit 1
    ;;
esac

if command -v node > /dev/null 2>&1 && command -v npm > /dev/null 2>&1; then
  say "Node.js / npm の準備が完了しました。" \
      "Node.js / npm is ready."
  exit 0
fi

say "Node.js / npm のインストール確認に失敗しました。手動で確認してください。" \
    "Node.js / npm installation check failed. Please verify manually."
exit 1
