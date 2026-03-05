#!/usr/bin/env bash

set -euo pipefail

BIN_DIR="${LOGLM_INSTALL_DIR:-$HOME/.local/bin}"
LOGLM_HOME="${LOGLM_HOME:-$HOME/.local/share/loglm}"
SETUP_DIR="$LOGLM_HOME/setup"

TARGETS=(
  "$BIN_DIR/loglm"
  "$BIN_DIR/loglm-decode"
  "$SETUP_DIR/lib.sh"
  "$SETUP_DIR/platform-detect.sh"
  "$SETUP_DIR/install-node.sh"
  "$SETUP_DIR/doctor.sh"
  "$SETUP_DIR/ensure-agent.sh"
  "$SETUP_DIR/agent-codex.sh"
  "$SETUP_DIR/agent-claude.sh"
  "$SETUP_DIR/agent-gemini.sh"
)

removed=0
missing=0

for path in "${TARGETS[@]}"; do
  if [[ -e "$path" ]]; then
    rm -f "$path"
    echo "Removed: $path"
    removed=$((removed + 1))
  else
    echo "Not found (skip): $path"
    missing=$((missing + 1))
  fi
done

# Remove empty directories only.
rmdir "$SETUP_DIR" 2>/dev/null || true
rmdir "$LOGLM_HOME" 2>/dev/null || true
rmdir "$BIN_DIR" 2>/dev/null || true

echo "Done. removed=$removed skipped=$missing"
