#!/usr/bin/env bash

set -euo pipefail

REPO_RAW_BASE="${REPO_RAW_BASE:-https://raw.githubusercontent.com/ks91/loglm/main}"
BIN_DIR="${LOGLM_INSTALL_DIR:-$HOME/.local/bin}"
LOGLM_HOME="${LOGLM_HOME:-$HOME/.local/share/loglm}"
SETUP_DIR="$LOGLM_HOME/setup"

download_to_stdout() {
  local url="$1"
  if command -v curl > /dev/null 2>&1; then
    curl -fsSL "$url"
    return
  fi
  if command -v wget > /dev/null 2>&1; then
    wget -qO- "$url"
    return
  fi
  echo "Error: curl or wget is required." >&2
  exit 1
}

install_executable() {
  local src="$1"
  local dst="$2"
  download_to_stdout "$REPO_RAW_BASE/$src" > "$dst"
  chmod +x "$dst"
}

path_contains_dir() {
  local dir="$1"
  case ":$PATH:" in
    *":$dir:"*) return 0 ;;
    *) return 1 ;;
  esac
}

detect_profile_file() {
  local shell_name
  shell_name="$(basename "${SHELL:-}")"

  case "$shell_name" in
    zsh)
      if [[ -f "$HOME/.zshrc" ]]; then
        printf '%s\n' "$HOME/.zshrc"
      else
        printf '%s\n' "$HOME/.zshrc"
      fi
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
      if [[ -f "$HOME/.profile" ]]; then
        printf '%s\n' "$HOME/.profile"
      else
        printf '%s\n' "$HOME/.profile"
      fi
      ;;
  esac
}

append_path_to_profile_if_needed() {
  local profile line
  if path_contains_dir "$BIN_DIR"; then
    return 0
  fi

  profile="$(detect_profile_file)"
  mkdir -p "$(dirname "$profile")"
  touch "$profile"

  if [[ "$(basename "$profile")" == "config.fish" ]]; then
    line="fish_add_path -m \"$BIN_DIR\""
  else
    line="export PATH=\"$BIN_DIR:\$PATH\""
  fi

  if grep -Fqx "$line" "$profile"; then
    return 0
  fi

  {
    printf '\n# Added by loglm installer\n'
    printf '%s\n' "$line"
  } >> "$profile"

  echo "Updated shell profile: $profile"
}

mkdir -p "$BIN_DIR" "$SETUP_DIR"

install_executable "loglm" "$BIN_DIR/loglm"
install_executable "loglm-decode" "$BIN_DIR/loglm-decode"
install_executable "setup/lib.sh" "$SETUP_DIR/lib.sh"
install_executable "setup/platform-detect.sh" "$SETUP_DIR/platform-detect.sh"
install_executable "setup/install-node.sh" "$SETUP_DIR/install-node.sh"
install_executable "setup/doctor.sh" "$SETUP_DIR/doctor.sh"
install_executable "setup/ensure-agent.sh" "$SETUP_DIR/ensure-agent.sh"
install_executable "setup/agent-codex.sh" "$SETUP_DIR/agent-codex.sh"
install_executable "setup/agent-claude.sh" "$SETUP_DIR/agent-claude.sh"
install_executable "setup/agent-gemini.sh" "$SETUP_DIR/agent-gemini.sh"

echo "Installed: $BIN_DIR/loglm"
echo "Installed: $BIN_DIR/loglm-decode"
echo "Setup scripts: $SETUP_DIR"

append_path_to_profile_if_needed

if ! command -v loglm > /dev/null 2>&1; then
  echo "Open a new shell (or run 'source' on your profile) to use 'loglm'."
fi
