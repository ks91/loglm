#!/usr/bin/env bash

set -euo pipefail

resolve_lang() {
  local lang="${LOGLM_LANG:-}"
  if [[ -z "$lang" ]]; then
    if [[ -n "${LC_ALL:-}" ]]; then
      lang="${LC_ALL}"
    elif [[ -n "${LC_MESSAGES:-}" ]]; then
      lang="${LC_MESSAGES}"
    else
      lang="${LANG:-en}"
    fi
  fi

  case "$lang" in
    ja|ja_*|ja-*)
      LOGLM_LANG_RESOLVED="ja"
      ;;
    both|bi|bilingual)
      LOGLM_LANG_RESOLVED="both"
      ;;
    *)
      LOGLM_LANG_RESOLVED="en"
      ;;
  esac
}

say() {
  local ja="$1"
  local en="$2"
  case "${LOGLM_LANG_RESOLVED:-en}" in
    ja)
      printf '%s\n' "$ja"
      ;;
    both)
      printf '%s\n' "$ja"
      printf '%s\n' "$en"
      ;;
    *)
      printf '%s\n' "$en"
      ;;
  esac
}

prompt_yes_no() {
  local ja="$1"
  local en="$2"
  local answer=""
  case "${LOGLM_LANG_RESOLVED:-en}" in
    ja)
      printf '%s [y/N]: ' "$ja"
      ;;
    both)
      printf '%s\n' "$ja"
      printf '%s [y/N]: ' "$en"
      ;;
    *)
      printf '%s [y/N]: ' "$en"
      ;;
  esac
  read -r answer
  case "${answer:-}" in
    y|Y|yes|YES)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

run_as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
    return
  fi
  if command -v sudo > /dev/null 2>&1; then
    sudo "$@"
    return
  fi
  say "この操作には管理者権限が必要です。'sudo' が見つかりません。" \
      "This action requires admin privileges, but 'sudo' was not found."
  return 1
}

ensure_homebrew() {
  if command -v brew > /dev/null 2>&1; then
    return 0
  fi

  if ! prompt_yes_no \
    "Homebrew が見つかりません。今インストールしますか？" \
    "Homebrew was not found. Install Homebrew now?"; then
    return 2
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

  if command -v brew > /dev/null 2>&1; then
    return 0
  fi

  return 1
}

brew_install_candidates() {
  local label="$1"
  shift
  local pkg

  for pkg in "$@"; do
    if brew info --formula "$pkg" > /dev/null 2>&1; then
      say "Homebrew (formula) で ${label} をインストールします: $pkg" \
          "Installing ${label} with Homebrew (formula): $pkg"
      brew install "$pkg"
      return 0
    fi
    if brew info --cask "$pkg" > /dev/null 2>&1; then
      say "Homebrew (cask) で ${label} をインストールします: $pkg" \
          "Installing ${label} with Homebrew (cask): $pkg"
      brew install --cask "$pkg"
      return 0
    fi
  done

  return 1
}
