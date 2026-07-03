#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/platform-detect.sh"

resolve_lang
PLATFORM="$(detect_platform)"

ensure_claude_code() {
  if command -v claude > /dev/null 2>&1; then
    return 0
  fi

  say "local-llm は Claude Code を実行基盤として使います。" \
      "local-llm uses Claude Code as its runtime."
  "$SCRIPT_DIR/ensure-agent.sh" claude
}

install_llama_with_brew() {
  if ! command -v brew > /dev/null 2>&1; then
    return 1
  fi
  brew_install_candidates "llama.cpp / llama-server" llama.cpp
}

install_llama_with_apt() {
  if ! command -v apt-get > /dev/null 2>&1; then
    return 1
  fi
  if ! prompt_yes_no \
    "apt で llama.cpp を試しにインストールしますか？" \
    "Try installing llama.cpp with apt?"; then
    return 1
  fi
  run_as_root apt-get update
  run_as_root apt-get install -y llama.cpp
}

ensure_llama_server() {
  if command -v llama-server > /dev/null 2>&1; then
    return 0
  fi

  say "llama-server コマンドが見つかりません。" \
      "The llama-server command was not found."

  case "$PLATFORM" in
    macos)
      if ensure_homebrew; then
        install_llama_with_brew || true
      fi
      ;;
    ubuntu|wsl2|raspberrypi|chromeos)
      if command -v brew > /dev/null 2>&1; then
        install_llama_with_brew || true
      fi
      if ! command -v llama-server > /dev/null 2>&1; then
        install_llama_with_apt || true
      fi
      ;;
    *)
      if command -v brew > /dev/null 2>&1; then
        install_llama_with_brew || true
      fi
      ;;
  esac

  if command -v llama-server > /dev/null 2>&1; then
    return 0
  fi

  say "エラー: llama-server を自動インストールできませんでした。llama.cpp を導入して再実行してください。" \
      "Error: could not install llama-server automatically. Install llama.cpp and rerun loglm." >&2
  say "例: llama-server -m /path/to/model.gguf --ctx-size 32768 --host 127.0.0.1 --port 8080" \
      "Example: llama-server -m /path/to/model.gguf --ctx-size 32768 --host 127.0.0.1 --port 8080" >&2
  exit 1
}

ensure_claude_code
ensure_llama_server

say "local-llm サポートは experimental です。loglm は llama-server を起動しません。別ターミナルで起動してください。" \
    "local-llm support is experimental. loglm does not start llama-server; start it in another terminal."
say "推奨開始点: --ctx-size 32768（軽量環境では 8192、余裕があれば 65536 以上）。" \
    "Recommended starting point: --ctx-size 32768 (use 8192 on small machines, 65536+ if memory allows)."
