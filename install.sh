#!/usr/bin/env bash

set -euo pipefail

REPO_RAW_BASE="${REPO_RAW_BASE:-https://raw.githubusercontent.com/ks91/loglm/main}"
INSTALL_DIR="${LOGLM_INSTALL_DIR:-$HOME/.local/bin}"
TARGET="$INSTALL_DIR/loglm"

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

mkdir -p "$INSTALL_DIR"
download_to_stdout "$REPO_RAW_BASE/loglm" > "$TARGET"
chmod +x "$TARGET"

echo "Installed: $TARGET"
if ! command -v loglm > /dev/null 2>&1; then
  cat <<EOF
Note: '$INSTALL_DIR' is not in PATH.
Add this to your shell profile:
  export PATH="$INSTALL_DIR:\$PATH"
EOF
fi
