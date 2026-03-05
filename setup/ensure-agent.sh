#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib.sh"

resolve_lang

if (($# != 1)); then
  say "使い方: $0 <codex|claude|gemini>" \
      "Usage: $0 <codex|claude|gemini>" >&2
  exit 2
fi

AGENT="$1"
case "$AGENT" in
  codex|claude|gemini) ;;
  *)
    say "エラー: 未対応のエージェントです: $AGENT" \
        "Error: unsupported agent: $AGENT" >&2
    exit 2
    ;;
esac

if command -v "$AGENT" > /dev/null 2>&1; then
  exit 0
fi

"$SCRIPT_DIR/doctor.sh" "$AGENT"

say "'$AGENT' コマンドが未インストールです。" \
    "The '$AGENT' command is not installed."

if prompt_yes_no \
  "$AGENT を今インストールしますか？" \
  "Install $AGENT now?"; then
  "$SCRIPT_DIR/agent-$AGENT.sh"
else
  say "インストールを中止しました。'$AGENT' を導入して再実行してください。" \
      "Install cancelled. Please install '$AGENT' and retry." >&2
  exit 1
fi

if ! command -v "$AGENT" > /dev/null 2>&1; then
  say "エラー: インストール後も '$AGENT' が PATH に見つかりません。" \
      "Error: installation finished but '$AGENT' is still not available in PATH." >&2
  say "新しいシェルを開いて再実行するか、PATH 設定を確認してください。" \
      "Open a new shell and retry, or verify your PATH settings." >&2
  exit 1
fi
