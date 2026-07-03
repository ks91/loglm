#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/platform-detect.sh"

resolve_lang

AGENT="${1:-}"
PLATFORM="$(detect_platform)"
PLATFORM_NAME="$(platform_label "$PLATFORM")"

say "実行環境: $PLATFORM_NAME" "Platform: $PLATFORM_NAME"

if ! command -v script > /dev/null 2>&1; then
  say "'script' コマンドが見つかりません。util-linux（または BSD script）を入れてください。" \
      "The 'script' command is missing. Install util-linux (or BSD script)."
  exit 1
fi

say "基本チェック: script コマンド OK" \
    "Base check: script command OK"

if [[ "$AGENT" == "claude" ]]; then
  say "注意: Claude Code は環境によってネイティブインストール推奨の場合があります。" \
      "Note: Claude Code may recommend native installation on some environments."
fi

if [[ "$AGENT" == "openclaw" || "$AGENT" == "antigravity" || "$AGENT" == "hermes" || "$AGENT" == "local-llm" ]]; then
  say "注意: $AGENT の loglm サポートは experimental です。" \
      "Note: loglm support for $AGENT is experimental."
fi

if [[ "$AGENT" == "antigravity" ]]; then
  say "注意: loglm は Google 系エージェントとして Antigravity CLI を使います。Gemini CLI は個人向け環境で利用できない場合があります。" \
      "Note: loglm uses Antigravity CLI as the Google-family agent. Gemini CLI may no longer work for individual accounts."
fi

if [[ "$AGENT" == "local-llm" ]]; then
  say "local-llm は Claude Code と Anthropic 互換のローカル gateway を使います。" \
      "local-llm uses Claude Code and a local Anthropic-compatible gateway."
fi
