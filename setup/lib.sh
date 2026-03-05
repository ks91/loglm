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

detect_profile_file() {
  local shell_name
  shell_name="$(basename "${SHELL:-}")"

  case "$shell_name" in
    zsh)
      printf '%s\n' "$HOME/.zshrc"
      ;;
    bash)
      if [[ -f "$HOME/.bashrc" ]]; then
        printf '%s\n' "$HOME/.bashrc"
      elif [[ -f "$HOME/.bash_profile" ]]; then
        printf '%s\n' "$HOME/.bash_profile"
      else
        printf '%s\n' "$HOME/.bashrc"
      fi
      ;;
    fish)
      printf '%s\n' "$HOME/.config/fish/config.fish"
      ;;
    *)
      printf '%s\n' "$HOME/.profile"
      ;;
  esac
}

ensure_dir_on_path_now_and_profile() {
  local dir="$1"
  local profile line

  case ":$PATH:" in
    *":$dir:"*) ;;
    *) export PATH="$dir:$PATH" ;;
  esac

  profile="$(detect_profile_file)"
  mkdir -p "$(dirname "$profile")"
  touch "$profile"

  if [[ "$(basename "$profile")" == "config.fish" ]]; then
    line="fish_add_path -m \"$dir\""
  else
    line="export PATH=\"$dir:\$PATH\""
  fi

  if ! grep -Fqx "$line" "$profile"; then
    {
      printf '\n# Added by loglm setup\n'
      printf '%s\n' "$line"
    } >> "$profile"
    say "PATH 設定を更新しました: $profile" \
        "Updated PATH settings in: $profile"
  fi
}

prepare_npm_user_prefix() {
  local prefix npm_bin
  if ! command -v npm > /dev/null 2>&1; then
    return 1
  fi

  prefix="$HOME/.local"
  npm_bin="$prefix/bin"
  mkdir -p "$npm_bin"
  npm config set prefix "$prefix" > /dev/null
  ensure_dir_on_path_now_and_profile "$npm_bin"
}
