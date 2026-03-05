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
if ! command -v loglm > /dev/null 2>&1; then
  cat <<EOF
Note: '$BIN_DIR' is not in PATH.
Add this to your shell profile:
  export PATH="$BIN_DIR:\$PATH"
EOF
fi
