#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/platform-detect.sh"

resolve_lang
PLATFORM="$(detect_platform)"
DDG_MCP_MARKER="${LOGLM_LOCAL_LLM_DDG_MCP_MARKER:-$PWD/.loglm_local_llm_ddg_mcp}"

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

install_uv_with_brew() {
  if ! command -v brew > /dev/null 2>&1; then
    return 1
  fi
  brew_install_candidates "uv / uvx" uv
}

install_uv_with_official_installer() {
  local installer tmp_installer
  installer="https://astral.sh/uv/install.sh"
  tmp_installer="$(mktemp)"
  trap 'rm -f "$tmp_installer"' RETURN

  if command -v curl > /dev/null 2>&1; then
    curl -LsSf "$installer" > "$tmp_installer"
  elif command -v wget > /dev/null 2>&1; then
    wget -qO- "$installer" > "$tmp_installer"
  else
    say "エラー: uv 公式インストーラーの取得には curl または wget が必要です。" \
        "Error: curl or wget is required to fetch the official uv installer." >&2
    return 1
  fi

  say "公式インストーラーで uv / uvx をインストールします。" \
      "Installing uv / uvx with the official installer."
  sh "$tmp_installer"
  rm -f "$tmp_installer"
  trap - RETURN
  ensure_dir_on_path_now_and_profile "$HOME/.local/bin"
}

ensure_uvx_for_duckduckgo() {
  if command -v uvx > /dev/null 2>&1; then
    return 0
  fi

  say "DuckDuckGo MCP には uvx が必要です。" \
      "DuckDuckGo MCP requires uvx."

  case "$PLATFORM" in
    macos)
      if ensure_homebrew; then
        install_uv_with_brew || true
      fi
      if ! command -v uvx > /dev/null 2>&1; then
        install_uv_with_official_installer || true
      fi
      ;;
    ubuntu|wsl2|raspberrypi|chromeos|linux)
      install_uv_with_official_installer || true
      ;;
    *)
      if command -v brew > /dev/null 2>&1; then
        install_uv_with_brew || true
      fi
      if ! command -v uvx > /dev/null 2>&1; then
        install_uv_with_official_installer || true
      fi
      ;;
  esac

  command -v uvx > /dev/null 2>&1
}

configure_duckduckgo_mcp() {
  local uvx_path

  if [[ -f "$DDG_MCP_MARKER" ]]; then
    return 0
  fi

  if ! prompt_yes_no \
    "local-llm 用に DuckDuckGo MCP web search をセットアップしますか？" \
    "Set up DuckDuckGo MCP web search for local-llm?"; then
    printf 'skipped\n' > "$DDG_MCP_MARKER" 2>/dev/null || true
    return 0
  fi

  if ! ensure_uvx_for_duckduckgo; then
    say "エラー: uvx を準備できなかったため DuckDuckGo MCP をセットアップできませんでした。" \
        "Error: could not prepare uvx, so DuckDuckGo MCP was not configured." >&2
    return 1
  fi

  uvx_path="$(command -v uvx)"
  say "Claude Code の local MCP server として DuckDuckGo を追加します: ddg-search" \
      "Adding DuckDuckGo as a local Claude Code MCP server: ddg-search"
  claude mcp add --scope local ddg-search -- "$uvx_path" duckduckgo-mcp-server
  printf 'configured\n' > "$DDG_MCP_MARKER" 2>/dev/null || true
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
if ! configure_duckduckgo_mcp; then
  say "警告: DuckDuckGo MCP のセットアップを完了できませんでした。local-llm は web search なしで続行できます。" \
      "Warning: DuckDuckGo MCP setup did not complete. local-llm can continue without web search." >&2
fi

say "local-llm サポートは experimental です。loglm は llama-server を起動しません。別ターミナルで起動してください。" \
    "local-llm support is experimental. loglm does not start llama-server; start it in another terminal."
say "推奨開始点: --ctx-size 32768（軽量環境では 8192、余裕があれば 65536 以上）。" \
    "Recommended starting point: --ctx-size 32768 (use 8192 on small machines, 65536+ if memory allows)."
