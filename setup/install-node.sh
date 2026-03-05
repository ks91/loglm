#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/platform-detect.sh"

resolve_lang
PLATFORM="$(detect_platform)"
NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

ensure_nvm_profile_init() {
  local profile
  local line1='export NVM_DIR="$HOME/.nvm"'
  local line2='[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"'

  profile="$(detect_profile_file)"
  mkdir -p "$(dirname "$profile")"
  touch "$profile"

  if ! grep -Fqx "$line1" "$profile"; then
    {
      printf '\n# Added by loglm setup (nvm)\n'
      printf '%s\n' "$line1"
    } >> "$profile"
  fi
  if ! grep -Fqx "$line2" "$profile"; then
    printf '%s\n' "$line2" >> "$profile"
  fi
}

source_nvm() {
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    # shellcheck disable=SC1090
    . "$NVM_DIR/nvm.sh"
    return 0
  fi
  return 1
}

ensure_download_tool_for_nvm() {
  if command -v curl > /dev/null 2>&1; then
    return 0
  fi

  if command -v wget > /dev/null 2>&1; then
    return 0
  fi

  if command -v apt-get > /dev/null 2>&1; then
    say "curl / wget が見つからないため、curl をインストールします..." \
        "curl/wget not found; installing curl..."
    run_as_root apt-get update
    run_as_root apt-get install -y curl
    if command -v curl > /dev/null 2>&1; then
      return 0
    fi
  fi

  say "nvm のインストールには curl または wget が必要です。" \
      "curl or wget is required to install nvm."
  return 1
}

ensure_nvm_installed() {
  if source_nvm; then
    return 0
  fi

  if ! ensure_download_tool_for_nvm; then
    return 1
  fi

  say "nvm をインストールします..." \
      "Installing nvm..."
  if command -v curl > /dev/null 2>&1; then
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
  else
    wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
  fi
  ensure_nvm_profile_init
  source_nvm
}

install_node_with_nvm_lts() {
  if ! ensure_nvm_installed; then
    return 1
  fi

  if [[ -f "$HOME/.npmrc" ]]; then
    # nvm and fixed npm prefix/globalconfig in ~/.npmrc are incompatible.
    sed -i.bak '/^[[:space:]]*prefix[[:space:]]*=.*/d;/^[[:space:]]*globalconfig[[:space:]]*=.*/d' "$HOME/.npmrc" 2>/dev/null || true
    rm -f "$HOME/.npmrc.bak"
  fi

  say "nvm で最新LTSの Node.js をインストールします..." \
      "Installing latest LTS Node.js with nvm..."
  nvm install --delete-prefix --lts
  nvm alias default 'lts/*'
  nvm use --delete-prefix default
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
    install_node_with_nvm_lts
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
