#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib.sh"

resolve_lang

if (($# != 1)); then
  say "使い方: $0 <codex|claude|antigravity|openclaw|hermes|local-llm>" \
      "Usage: $0 <codex|claude|antigravity|openclaw|hermes|local-llm>" >&2
  exit 2
fi

AGENT="$1"
case "$AGENT" in
  codex|claude|antigravity|openclaw|hermes|local-llm) ;;
  *)
    say "エラー: 未対応のエージェントです: $AGENT" \
        "Error: unsupported agent: $AGENT" >&2
    exit 2
    ;;
esac

if [[ "$AGENT" == "local-llm" ]]; then
  if command -v claude > /dev/null 2>&1 && command -v llama-server > /dev/null 2>&1; then
    exit 0
  fi
elif [[ "$AGENT" == "antigravity" ]]; then
  if command -v agy > /dev/null 2>&1 || command -v antigravity > /dev/null 2>&1; then
    exit 0
  fi
elif command -v "$AGENT" > /dev/null 2>&1; then
  exit 0
fi

"$SCRIPT_DIR/doctor.sh" "$AGENT"

if [[ "$AGENT" == "local-llm" ]]; then
  say "local-llm に必要なコマンドが未インストールです（claude / llama-server）。" \
      "Commands required by local-llm are not installed (claude / llama-server)."
elif [[ "$AGENT" == "antigravity" ]]; then
  say "Antigravity CLI が未インストールです（agy / antigravity）。" \
      "Antigravity CLI is not installed (agy / antigravity)."
else
  say "'$AGENT' コマンドが未インストールです。" \
      "The '$AGENT' command is not installed."
fi

if prompt_yes_no \
  "$AGENT を今インストールしますか？" \
  "Install $AGENT now?"; then
  "$SCRIPT_DIR/agent-$AGENT.sh"
else
  say "インストールを中止しました。'$AGENT' を導入して再実行してください。" \
      "Install cancelled. Please install '$AGENT' and retry." >&2
  exit 1
fi

if [[ "$AGENT" == "local-llm" ]]; then
  if command -v claude > /dev/null 2>&1 && command -v llama-server > /dev/null 2>&1; then
    exit 0
  fi
elif [[ "$AGENT" == "antigravity" ]]; then
  if command -v agy > /dev/null 2>&1 || command -v antigravity > /dev/null 2>&1; then
    exit 0
  fi
elif command -v "$AGENT" > /dev/null 2>&1; then
  exit 0
fi

if [[ "$AGENT" == "local-llm" ]]; then
  say "エラー: インストール後も claude または llama-server が PATH に見つかりません。" \
      "Error: installation finished but claude or llama-server is still not available in PATH." >&2
elif [[ "$AGENT" == "antigravity" ]]; then
  say "エラー: インストール後も agy または antigravity が PATH に見つかりません。" \
      "Error: installation finished but agy or antigravity is still not available in PATH." >&2
else
  say "エラー: インストール後も '$AGENT' が PATH に見つかりません。" \
      "Error: installation finished but '$AGENT' is still not available in PATH." >&2
fi
say "新しいシェルを開いて再実行するか、PATH 設定を確認してください。" \
    "Open a new shell and retry, or verify your PATH settings." >&2
exit 1
