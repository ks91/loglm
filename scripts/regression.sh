#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="${TMPDIR:-/tmp}/loglm-regression-$(date +%Y%m%d-%H%M%S).log"
RUN_E2E=0
E2E_REPO="${E2E_REPO:-ks91/gamer-pat}"
E2E_AGENT="${E2E_AGENT:-codex}"
TMP_WORK=""
NODE_TMP=""
DECODE_TMP=""
CLAUDE_TMP=""
EXPERIMENTAL_TMP=""
E2E_DIR=""

usage() {
  cat <<'EOF'
Usage:
  bash scripts/regression.sh [--e2e] [--repo <owner/repo>] [--agent codex|claude|antigravity|openclaw|hermes|local-llm|all]

Options:
  --e2e                Run network E2E checks (install/list/update/remove).
  --repo <owner/repo>  Repository used in E2E checks (default: ks91/gamer-pat).
  --agent <name>       Agent scope for E2E checks (default: codex).
  -h, --help           Show this help.
EOF
}

pass() {
  printf 'PASS: %s\n' "$*" | tee -a "$LOG_FILE"
}

fail() {
  printf 'FAIL: %s\n' "$*" | tee -a "$LOG_FILE" >&2
  exit 1
}

run_cmd() {
  "$@" >> "$LOG_FILE" 2>&1
}

assert_exit_code() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  [[ "$actual" -eq "$expected" ]] || fail "$label (expected exit $expected, got $actual)"
}

while (($# > 0)); do
  case "$1" in
    --e2e)
      RUN_E2E=1
      shift
      ;;
    --repo)
      if (($# < 2)); then
        echo "missing value for --repo" >&2
        exit 2
      fi
      E2E_REPO="$2"
      shift 2
      ;;
    --agent)
      if (($# < 2)); then
        echo "missing value for --agent" >&2
        exit 2
      fi
      E2E_AGENT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$E2E_AGENT" in
  codex|claude|antigravity|openclaw|hermes|local-llm|all) ;;
  *)
    echo "invalid --agent: $E2E_AGENT" >&2
    exit 2
    ;;
esac

printf 'loglm regression start: %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')" | tee -a "$LOG_FILE"

# 1) Syntax checks
run_cmd bash -n \
  "$ROOT_DIR/loglm" \
  "$ROOT_DIR/loglm-decode" \
  "$ROOT_DIR/install.sh" \
  "$ROOT_DIR/uninstall.sh" \
  "$ROOT_DIR/setup/install-node.sh" \
  "$ROOT_DIR/setup/agent-install.sh"
run_cmd bash -n \
  "$ROOT_DIR/setup/agent-codex.sh" \
  "$ROOT_DIR/setup/agent-claude.sh" \
  "$ROOT_DIR/setup/agent-antigravity.sh" \
  "$ROOT_DIR/setup/agent-openclaw.sh" \
  "$ROOT_DIR/setup/agent-hermes.sh" \
  "$ROOT_DIR/setup/agent-local-llm.sh"
pass "shell syntax checks"

# 2) Help output
run_cmd "$ROOT_DIR/loglm" --help
run_cmd "$ROOT_DIR/loglm" agent install --help
run_cmd "$ROOT_DIR/loglm-timeline" --help
pass "help output"

"$ROOT_DIR/loglm" --version > /tmp/loglm-test-version.out 2>/tmp/loglm-test-version.err
rg -q '^loglm [0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$' /tmp/loglm-test-version.out || fail "version output format"
pass "version output"

# 3) loglm-decode overlap trimming
DECODE_TMP="$(/usr/bin/mktemp -d)"
trap 'rm -rf "$TMP_WORK" "$NODE_TMP" "$DECODE_TMP" "$CLAUDE_TMP" "$EXPERIMENTAL_TMP"' EXIT
cat > "$DECODE_TMP/loglm-codex-log-20260403-010000-pid1.txt" <<'EOF'
===== loglm start [codex]: 2026-04-03 01:00:00 +0900 =====

› old prompt
• alpha
• beta
• gamma
• delta
• epsilon
• zeta
EOF
cat > "$DECODE_TMP/loglm-codex-log-20260403-020000-pid2.txt" <<'EOF'
===== loglm start [codex]: 2026-04-03 02:00:00 +0900 =====

update banner
another banner line

› old prompt
• alpha
• beta
• gamma
• delta
• epsilon
• zeta
› new prompt
• eta
• theta
EOF

run_cmd "$ROOT_DIR/loglm-decode" "$DECODE_TMP/loglm-codex-log-20260403-010000-pid1.txt"
run_cmd env LOGLM_DECODE_MIN_OVERLAP_LINES=4 LOGLM_DECODE_MIN_OVERLAP_CHARS=10 \
  "$ROOT_DIR/loglm-decode" "$DECODE_TMP/loglm-codex-log-20260403-020000-pid2.txt"
sed -n '1,6p' "$DECODE_TMP/loglm-codex-log-20260403-020000-pid2.decoded.txt" > /tmp/loglm-test-decode-prefix.out
rg -q '^===== loglm start \[codex\]:' /tmp/loglm-test-decode-prefix.out || fail "decode overlap trimming should preserve log start header"
rg -q '^› new prompt$' "$DECODE_TMP/loglm-codex-log-20260403-020000-pid2.decoded.txt" || fail "decode overlap trimming should align to a new message boundary"
! rg -q '^› old prompt$' "$DECODE_TMP/loglm-codex-log-20260403-020000-pid2.decoded.txt" || fail "decode overlap trimming should drop repeated leading context"
pass "decode overlap trimming"

cat > "$DECODE_TMP/loglm-codex-log-20260403-021000-pid21.txt" <<'EOF'
===== loglm start [codex]: 2026-04-03 02:10:00 +0900 =====

› long prompt
• this is a wrapped response that
  spans two lines in the previous log.
• next repeated paragraph
  also wraps across two lines.
EOF
cat > "$DECODE_TMP/loglm-codex-log-20260403-022000-pid22.txt" <<'EOF'
===== loglm start [codex]: 2026-04-03 02:20:00 +0900 =====

› long prompt
• this is a wrapped response that spans
  two lines in the previous log.
• next repeated paragraph also wraps
  across two lines.

› fresh prompt
• fresh response
EOF

run_cmd "$ROOT_DIR/loglm-decode" "$DECODE_TMP/loglm-codex-log-20260403-021000-pid21.txt"
run_cmd env LOGLM_DECODE_MIN_OVERLAP_LINES=2 LOGLM_DECODE_MIN_OVERLAP_CHARS=40 \
  "$ROOT_DIR/loglm-decode" "$DECODE_TMP/loglm-codex-log-20260403-022000-pid22.txt"
rg -q '^› fresh prompt$' "$DECODE_TMP/loglm-codex-log-20260403-022000-pid22.decoded.txt" || fail "decode overlap trimming should handle Codex resume blocks with different wrapping"
! rg -q '^› long prompt$' "$DECODE_TMP/loglm-codex-log-20260403-022000-pid22.decoded.txt" || fail "decode overlap trimming should drop Codex resume blocks when wrapping changes"
pass "decode overlap trimming for Codex wrapped resume blocks"

cat > "$DECODE_TMP/loglm-codex-log-20260403-023000-pid23.txt" <<'EOF'
===== loglm start [codex]: 2026-04-03 02:30:00 +0900 =====

› replayed prompt
• replayed answer
• Context compacted
› actually new prompt
• Ran test-command
EOF

run_cmd env LOGLM_DECODE_MIN_OVERLAP_LINES=99 LOGLM_DECODE_MIN_OVERLAP_CHARS=9999 \
  "$ROOT_DIR/loglm-decode" "$DECODE_TMP/loglm-codex-log-20260403-023000-pid23.txt"
rg -q '^› actually new prompt$' "$DECODE_TMP/loglm-codex-log-20260403-023000-pid23.decoded.txt" || fail "decode should keep Codex content after leading context compaction replay"
! rg -q '^› replayed prompt$' "$DECODE_TMP/loglm-codex-log-20260403-023000-pid23.decoded.txt" || fail "decode should drop Codex leading replay before context compaction when no actions occurred"
pass "decode trims Codex leading replay before context compaction"

cat > "$DECODE_TMP/loglm-claude-log-20260403-030000-pid3.txt" <<'EOF'
===== loglm start [claude]: 2026-04-03 03:00:00 +0900 =====

╭─── Claude Code v2.1.89 ──────────────────────────────────────────────────────╮
(status)
❯ old prompt
⏺ first response
EOF
cat > "$DECODE_TMP/loglm-claude-log-20260403-040000-pid4.txt" <<'EOF'
===== loglm start [claude]: 2026-04-03 04:00:00 +0900 =====

╭─── Claude Code v2.1.89 ──────────────────────────────────────────────────────╮
(status)
❯ old prompt
⏺ first response
(status)
❯ new prompt
⏺ second response
EOF

run_cmd "$ROOT_DIR/loglm-decode" "$DECODE_TMP/loglm-claude-log-20260403-030000-pid3.txt"
run_cmd env LOGLM_DECODE_MIN_OVERLAP_LINES=3 LOGLM_DECODE_MIN_OVERLAP_CHARS=10 \
  "$ROOT_DIR/loglm-decode" "$DECODE_TMP/loglm-claude-log-20260403-040000-pid4.txt"
rg -q '^❯ new prompt$' "$DECODE_TMP/loglm-claude-log-20260403-040000-pid4.decoded.txt" || fail "decode overlap trimming should preserve Claude-style new prompt boundaries"
! rg -q '^❯ old prompt$' "$DECODE_TMP/loglm-claude-log-20260403-040000-pid4.decoded.txt" || fail "decode overlap trimming should drop repeated Claude-style leading context"
pass "decode overlap trimming for Claude-style prompts"

{
  printf '===== loglm start [claude]: 2026-05-01 14:30:19 +0900 =====\n\n'
  printf 'oglmって知ってる？\n'
  printf '\033[48;2;240;240;240m\033[38;2;175;175;175m❯ \033[38;2;0;0;0mloglm って知ってる？\033[39m\r\033[1B\n'
  printf '⏺ はい。\n'
} > "$DECODE_TMP/loglm-claude-log-20260501-143017-pid29336.txt"

run_cmd "$ROOT_DIR/loglm-decode" "$DECODE_TMP/loglm-claude-log-20260501-143017-pid29336.txt"
rg -q '^❯ loglm って知ってる？$' "$DECODE_TMP/loglm-claude-log-20260501-143017-pid29336.decoded.txt" || fail "decode should keep complete Claude prompt redraw after CR cursor movement"
! rg -q '^oglmって知ってる？$' "$DECODE_TMP/loglm-claude-log-20260501-143017-pid29336.decoded.txt" || fail "decode should drop partial Claude prompt echo when complete redraw exists"
pass "decode Claude prompt redraw after CR cursor movement"

{
  printf '===== loglm start [claude]: 2026-05-01 14:35:00 +0900 =====\n\n'
  printf '\r\033[4A\033[48;2;240;240;240m\033[38;2;175;175;175m❯ \033[38;2;0;0;0mJust checking again.\033[39m                                                          \r\033[1B\033[49m\033[K\r\033[1B\033[38;2;215;119;87m✽\033[39m \033[38;2;215;119;87mMoseying… \033[39m\033[K\r\033[2C\033[1B\033[K\r\r\n'
} > "$DECODE_TMP/loglm-claude-log-20260501-143500-pid29338.txt"

run_cmd "$ROOT_DIR/loglm-decode" "$DECODE_TMP/loglm-claude-log-20260501-143500-pid29338.txt"
rg -q '^❯ Just checking again\.$' "$DECODE_TMP/loglm-claude-log-20260501-143500-pid29338.decoded.txt" || fail "decode should keep Claude prompt lines containing ing words"
! rg -q '^\(status\)$' "$DECODE_TMP/loglm-claude-log-20260501-143500-pid29338.decoded.txt" || fail "decode should not collapse prompt lines containing ing words into status"
pass "decode keeps Claude prompt lines containing ing words"

{
  printf '===== loglm start [claude]: 2026-05-01 14:40:00 +0900 =====\n\n'
  printf '\033[38;2;102;102;102mThinking for \033[1m16s\033[22m… \033[38;2;102;102;102m(ctrl+o to expand)\n'
  printf '  ⎿  \033[39m\033[2m\033[3mThe user is asking about a Japanese proverb\n'
  printf '\033[6G\033[2m\033[3mhave\033[11Gthe\033[15Gcapacity\033[24Gto\033[27Gunderstand\033[38Git.\033[42GWait,\033[48Glet\033[52Gme\033[55Greconsider.\033[67GThe\033[71Guser\033[23m\033[22m\n'
  printf '\033[6G\033[2m\033[3msomething.\033[17GThere'"'"'s\033[25Ga\033[27GJapanese\033[36Gproverb:\033[45G「猫に小僧」(neko\033[63Gni\033[66Gkozō)\033[72G-\033[74Gtelling\033[23m\033[22m\n'
  printf '⏺ response after thinking\n'
} > "$DECODE_TMP/loglm-claude-log-20260501-144000-pid29337.txt"

run_cmd "$ROOT_DIR/loglm-decode" "$DECODE_TMP/loglm-claude-log-20260501-144000-pid29337.txt"
rg -q 'have the capacity to understand it\. Wait, let me reconsider\. The user' "$DECODE_TMP/loglm-claude-log-20260501-144000-pid29337.decoded.txt" || fail "decode should preserve spaces in Claude expanded thinking blocks with ESC[nG"
rg -q "something\\. There's a Japanese proverb: *「猫に小僧」\\(neko ni kozō\\) - telling" "$DECODE_TMP/loglm-claude-log-20260501-144000-pid29337.decoded.txt" || fail "decode should preserve Japanese/English thinking line spacing"
pass "decode Claude expanded thinking block column spacing"

cat > "$DECODE_TMP/loglm-claude-log-20260501-050000-pid5.txt" <<'EOF'
===== loglm start [claude]: 2026-05-01 05:00:00 +0900 =====

❯ previous prompt
⏺ previous answer
tail 01
tail 02
tail 03
tail 04
tail 05
tail 06
tail 07
tail 08
tail 09
tail 10
EOF
cat > "$DECODE_TMP/loglm-claude-log-20260501-051000-pid6.txt" <<'EOF'
===== loglm start [claude]: 2026-05-01 05:10:00 +0900 =====

❯ new prompt
new answer body that should remain after tail overlap
tail 01
tail 02
tail 03
tail 04
tail 05
tail 06
tail 07
tail 08
tail 09
tail 10
EOF

run_cmd "$ROOT_DIR/loglm-decode" "$DECODE_TMP/loglm-claude-log-20260501-050000-pid5.txt"
run_cmd env LOGLM_DECODE_MIN_OVERLAP_LINES=4 LOGLM_DECODE_MIN_OVERLAP_CHARS=20 \
  "$ROOT_DIR/loglm-decode" "$DECODE_TMP/loglm-claude-log-20260501-051000-pid6.txt"
rg -q '^❯ new prompt$' "$DECODE_TMP/loglm-claude-log-20260501-051000-pid6.decoded.txt" || fail "decode should not discard Claude session content for tail-only overlap"
rg -q '^new answer body that should remain after tail overlap$' "$DECODE_TMP/loglm-claude-log-20260501-051000-pid6.decoded.txt" || fail "decode should keep Claude session body for tail-only overlap"
pass "decode ignores Claude tail-only overlap"

cat > "$DECODE_TMP/loglm-claude-log-20260501-052000-pid7.txt" <<'EOF'
===== loglm start [claude]: 2026-05-01 05:20:00 +0900 =====

❯ しりとりしよう
⏺ いいよ！じゃあ始めよう。
しりとり
「り」からどうぞ！
❯ 倫理
⏺ 倫理（りんり）
「り」から！
❯ ごま
⏺ ごま（胡麻）
「ま」から！
❯ はじめよう
⏺ 環境チェック完了！
今回書く論文は何のためのもの？

Resume this session with:
claude --resume 11111111-1111-1111-1111-111111111111
EOF
cat > "$DECODE_TMP/loglm-claude-log-20260501-053000-pid8.txt" <<'EOF'
===== loglm start [claude]: 2026-05-01 05:30:00 +0900 =====

Claude Code v2.1.126
❯ しりとりしよう
⏺ いいよ！じゃあ始めよう。
しりとり
「り」からどうぞ！
❯ 倫理
⏺ 倫理（りんり）
「り」から！
❯ ごま
⏺ ごま（胡麻）
「ま」から！
Read 1 file (ctrl+o to expand)
❯ はじめよう
extra redraw line not present in previous log
⏺ 環境チェック完了！
今回書く論文は何のためのもの？
❯ /exit
❯ Plonky

Resume this session with:
claude --resume 11111111-1111-1111-1111-111111111111
EOF

run_cmd "$ROOT_DIR/loglm-decode" "$DECODE_TMP/loglm-claude-log-20260501-052000-pid7.txt"
run_cmd env LOGLM_DECODE_MIN_OVERLAP_LINES=4 LOGLM_DECODE_MIN_OVERLAP_CHARS=60 \
  "$ROOT_DIR/loglm-decode" "$DECODE_TMP/loglm-claude-log-20260501-053000-pid8.txt"
! rg -q '^❯ しりとりしよう$' "$DECODE_TMP/loglm-claude-log-20260501-053000-pid8.decoded.txt" || fail "decode should trim Claude leading replay with redraw variations"
rg -q '^❯ /exit$' "$DECODE_TMP/loglm-claude-log-20260501-053000-pid8.decoded.txt" || fail "decode should keep first new Claude prompt after replay"
rg -q '^❯ Plonky$' "$DECODE_TMP/loglm-claude-log-20260501-053000-pid8.decoded.txt" || fail "decode should keep later new Claude prompts after replay"
pass "decode trims Claude leading replay with redraw variations"

cat > "$DECODE_TMP/loglm-claude-log-20260501-054000-pid9.txt" <<'EOF'
===== loglm start [claude]: 2026-05-01 05:40:00 +0900 =====

❯ unrelated prompt
⏺ unrelated response

Resume this session with:
claude --resume 22222222-2222-2222-2222-222222222222
EOF
cat > "$DECODE_TMP/loglm-claude-log-20260501-055000-pid10.txt" <<'EOF'
===== loglm start [claude]: 2026-05-01 05:50:00 +0900 =====

Claude Code v2.1.126
❯ しりとりしよう
⏺ いいよ！じゃあ始めよう。
しりとり
「り」からどうぞ！
❯ 倫理
⏺ 倫理（りんり）
「り」から！
❯ ごま
⏺ ごま（胡麻）
「ま」から！
❯ はじめよう
⏺ 環境チェック完了！
今回書く論文は何のためのもの？
❯ same session continued
⏺ continued response

Resume this session with:
claude --resume 11111111-1111-1111-1111-111111111111
EOF

run_cmd "$ROOT_DIR/loglm-decode" "$DECODE_TMP/loglm-claude-log-20260501-054000-pid9.txt"
run_cmd env LOGLM_DECODE_MIN_OVERLAP_LINES=4 LOGLM_DECODE_MIN_OVERLAP_CHARS=60 \
  "$ROOT_DIR/loglm-decode" "$DECODE_TMP/loglm-claude-log-20260501-055000-pid10.txt"
! rg -q '^❯ しりとりしよう$' "$DECODE_TMP/loglm-claude-log-20260501-055000-pid10.decoded.txt" || fail "decode should use Claude session ID to trim replay across intervening logs"
rg -q '^❯ same session continued$' "$DECODE_TMP/loglm-claude-log-20260501-055000-pid10.decoded.txt" || fail "decode should keep new content after same-session replay"
pass "decode prefers matching Claude session ID over intervening logs"

cat > "$DECODE_TMP/loglm-gemini-log-20260403-223849-pid84024.txt" <<'EOF'
===== loglm start [gemini]: 2026-04-03 22:38:49 +0900 =====
 ▝▜▄    Gemini CLI v0.36.0
   ▗▟▀  Signed in with Google: ks91020@gmail.com /auth
 ▗▟▀    Plan: Gemini Code Assist in Google One AI Pro /upgrade
We're making changes to Gemini CLI that may impact your workflow.
What's Changing: We are adding more robust detection of policy-violating use
How it affects you: This may result in higher capacity-related errors.
Read more: https://goo.gle/geminicli-updates
                                                                ? for shortcuts
 Shift+Tab to accept edits
 >   Type your message or @path/to/file
 workspace (/directory)                   sandbox                        /model
 ~/Programs/test/loglm-gemini             no sandbox            Auto (Gemini 3)
 > これまでは
 workspace (/directory)                   sandbox                        /model
 ~/Programs/test/loglm-gemini             no sandbox            Auto (Gemini 3)
 Shift+Tab to accept edits
 > これまでは何を
 workspace (/directory)                   sandbox                        /model
 ~/Programs/test/loglm-gemini             no sandbox            Auto (Gemini 3)
 Shift+Tab to accept edits
 > これまでは何をしてきたっけ。
✦ 要約します。
EOF

run_cmd "$ROOT_DIR/loglm-decode" "$DECODE_TMP/loglm-gemini-log-20260403-223849-pid84024.txt"
! rg -q 'Shift\+Tab to accept edits' "$DECODE_TMP/loglm-gemini-log-20260403-223849-pid84024.decoded.txt" || fail "decode should drop Gemini editor hint noise"
! rg -q 'workspace (/directory)' "$DECODE_TMP/loglm-gemini-log-20260403-223849-pid84024.decoded.txt" || fail "decode should drop Gemini workspace header noise"
! rg -q 'Gemini CLI v0\.36\.0' "$DECODE_TMP/loglm-gemini-log-20260403-223849-pid84024.decoded.txt" || fail "decode should drop repeated Gemini startup banner noise"
! rg -q 'Thinking\.\.\.|Recapping the Steps Taken|Revisiting Prior Actions' "$DECODE_TMP/loglm-gemini-log-20260403-223849-pid84024.decoded.txt" || fail "decode should drop Gemini spinner progress noise"
rg -q '^> これまでは何をしてきたっけ。$' "$DECODE_TMP/loglm-gemini-log-20260403-223849-pid84024.decoded.txt" || fail "decode should keep the final Gemini prompt text"
rg -q '^✦ 要約します。$' "$DECODE_TMP/loglm-gemini-log-20260403-223849-pid84024.decoded.txt" || fail "decode should keep Gemini response text"
pass "decode Gemini v0.36 UI noise"

cat > "$DECODE_TMP/loglm-gemini-log-20260403-223900-pid84025.txt" <<'EOF'
===== loglm start [gemini]: 2026-04-03 22:39:00 +0900 =====
 ⠏ Evaluating Daily Tasks (esc to cancel, 4s)                   ? for shortcuts
 > /ei
 editor           Set external editor preference
 extensions       Manage extensions
 quit             Exit the cli
 ▼
 (1/23)
 > /ex
 extensions   Manage extensions
 quit         Exit the cli
 > /quit
 Agent powering down. Goodbye!
EOF

run_cmd "$ROOT_DIR/loglm-decode" "$DECODE_TMP/loglm-gemini-log-20260403-223900-pid84025.txt"
! rg -q 'Evaluating Daily Tasks' "$DECODE_TMP/loglm-gemini-log-20260403-223900-pid84025.decoded.txt" || fail "decode should drop Gemini alternate spinner labels"
! rg -q '^> /ei$|^> /ex$|^editor +Set external editor preference$|^\(1/23\)$' "$DECODE_TMP/loglm-gemini-log-20260403-223900-pid84025.decoded.txt" || fail "decode should drop Gemini slash-command menu noise"
rg -q '^> /quit$' "$DECODE_TMP/loglm-gemini-log-20260403-223900-pid84025.decoded.txt" || fail "decode should keep actual Gemini slash commands"
rg -q 'Agent powering down\. Goodbye!' "$DECODE_TMP/loglm-gemini-log-20260403-223900-pid84025.decoded.txt" || fail "decode should keep Gemini slash command results"
pass "decode Gemini slash menu noise"

cat > "$DECODE_TMP/loglm-openclaw-log-20260531-010000-pid31.txt" <<'EOF'
===== loglm start [openclaw]: 2026-05-31 01:00:00 +0900 =====

OpenClaw v0.0.0
────────────────────────────────
? for shortcuts
local ready | idle
agent main | session loglm-20260531-010000-pid31 | openai/gpt-5.5 | tokens 1k/200k
loglm-20260531-010000-pid31
?/200k
> w
> wr
> write tests
Thinking...
I will inspect the project.
EOF
run_cmd "$ROOT_DIR/loglm-decode" "$DECODE_TMP/loglm-openclaw-log-20260531-010000-pid31.txt"
! rg -q 'OpenClaw v0\.0\.0|\\? for shortcuts|Thinking|local ready|agent main|\\?/200k|loglm-20260531' "$DECODE_TMP/loglm-openclaw-log-20260531-010000-pid31.decoded.txt" || fail "decode should drop OpenClaw TUI noise"
rg -q '^> write tests$' "$DECODE_TMP/loglm-openclaw-log-20260531-010000-pid31.decoded.txt" || fail "decode should keep final OpenClaw prompt"
rg -q '^I will inspect the project\.$' "$DECODE_TMP/loglm-openclaw-log-20260531-010000-pid31.decoded.txt" || fail "decode should keep OpenClaw response text"
pass "decode OpenClaw UI noise"

cat > "$DECODE_TMP/loglm-hermes-log-20260531-011000-pid32.txt" <<'EOF'
===== loglm start [hermes]: 2026-05-31 01:10:00 +0900 =====

Hermes Agent v0.0.0
────────────────────────────────
? for shortcuts
Available Tools
browser: browser_back
29 tools · 87 skills · /help for commands
Welcome to Hermes Agent! Type your message or /help for commands.
su
mmarize logs
● summarize logs
⚕ gpt-5.5 │ ctx -- │ [░░░░░░░░░░] -- │ 1s │ ⏲ 0s
⚕ ❯ msg=interrupt · /queue · /bg · /steer · Ctrl+C cancel
> s
> su
> summarize logs
Running...
Summary follows.
EOF
run_cmd "$ROOT_DIR/loglm-decode" "$DECODE_TMP/loglm-hermes-log-20260531-011000-pid32.txt"
! rg -q 'Hermes Agent v0\.0\.0|\\? for shortcuts|Running|Available Tools|Welcome to Hermes|ctx --|msg=interrupt|^mmarize logs$' "$DECODE_TMP/loglm-hermes-log-20260531-011000-pid32.decoded.txt" || fail "decode should drop Hermes TUI noise"
rg -q '^> summarize logs$' "$DECODE_TMP/loglm-hermes-log-20260531-011000-pid32.decoded.txt" || fail "decode should keep final Hermes prompt"
rg -q '^● summarize logs$' "$DECODE_TMP/loglm-hermes-log-20260531-011000-pid32.decoded.txt" || fail "decode should keep final Hermes confirmed prompt"
rg -q '^Summary follows\.$' "$DECODE_TMP/loglm-hermes-log-20260531-011000-pid32.decoded.txt" || fail "decode should keep Hermes response text"
pass "decode Hermes UI noise"

cat > "$DECODE_TMP/timeline-a.decoded.txt" <<'EOF'
===== loglm start [codex]: 2026-04-04 10:31:51 +0900 =====

› 専門職学位論文のデモ原稿を作りたい。
• PATとしてワークフローを開始します。
• Ran ls -1 *.xlsx interview*-log*.txt
• Edited 2 files (+282 -0)
✓  Shell platex -interaction=nonstopmode degree-demo-saito.tex
■ Conversation interrupted - tell the model what to do differently.
› いきなり 30,000文字以上を目指さなくてよいので、骨組みから作ろう。
EOF

cat > "$DECODE_TMP/timeline-b.decoded.txt" <<'EOF'
===== loglm start [claude]: 2026-04-04 17:05:23 +0900 =====

❯ 参考文献のコメントを反映して。
⏺ Update(degree-demo-saito.bib)
⏺ Bash(bibtex degree-demo-saito)
EOF

"$ROOT_DIR/loglm-timeline" "$DECODE_TMP/timeline-a.decoded.txt" "$DECODE_TMP/timeline-b.decoded.txt" > /tmp/loglm-test-timeline.out 2> /tmp/loglm-test-timeline.err
rg -q '^===== timeline-a\.decoded\.txt$' /tmp/loglm-test-timeline.out || fail "timeline should print the session file name"
rg -q '^agent: codex$' /tmp/loglm-test-timeline.out || fail "timeline should print agent"
rg -q '^opening: 専門職学位論文のデモ原稿を作りたい。$' /tmp/loglm-test-timeline.out || fail "timeline should capture opening user request"
rg -q '^- workflow started$' /tmp/loglm-test-timeline.out || fail "timeline should capture workflow-start events"
rg -q '^- ran: ls -1 \*\.xlsx interview\*-log\*\.txt$' /tmp/loglm-test-timeline.out || fail "timeline should capture ran events"
rg -q '^- shell: platex -interaction=nonstopmode degree-demo-saito\.tex$' /tmp/loglm-test-timeline.out || fail "timeline should capture shell events"
rg -q '^- conversation interrupted$' /tmp/loglm-test-timeline.out || fail "timeline should capture interruptions"
rg -q '^- いきなり 30,000文字以上を目指さなくてよいので、骨組みから作ろう。$' /tmp/loglm-test-timeline.out || fail "timeline should capture later user turns"
rg -q '^- update: degree-demo-saito\.bib$' /tmp/loglm-test-timeline.out || fail "timeline should capture Claude update events"
rg -q '^- bash: bibtex degree-demo-saito$' /tmp/loglm-test-timeline.out || fail "timeline should capture Claude bash events"

cat > "$DECODE_TMP/timeline-c.decoded.txt" <<'EOF'
===== loglm start [codex]: 2026-04-04 09:00:00 +0900 =====

› 朝の作業
EOF

"$ROOT_DIR/loglm-timeline" "$DECODE_TMP/timeline-b.decoded.txt" "$DECODE_TMP/timeline-c.decoded.txt" > /tmp/loglm-test-timeline-sorted.out 2> /tmp/loglm-test-timeline-sorted.err
first_session="$(rg '^===== ' /tmp/loglm-test-timeline-sorted.out | sed -n '1p')"
[[ "$first_session" == '===== timeline-c.decoded.txt' ]] || fail "timeline should sort sessions by header time instead of input order"
pass "timeline extraction"

cat > "$DECODE_TMP/sample.decoded.txt" <<'EOF'
Contact: ks91@example.com
Name: Kenji Saito
Greeting: Welcome back Kenji!
Colleague: Natsume Soseki
EOF
cat > "$DECODE_TMP/pii-candidates.txt" <<'EOF'
# first person
Kenji Saito
Kenji
Saito
ks91
ks91@example.com

# second person
Natsume Soseki
Natsume
Soseki
EOF

printf 'y\ny\n' | "$ROOT_DIR/loglm-decode" --review-pii "$DECODE_TMP/pii-candidates.txt" "$DECODE_TMP/sample.decoded.txt" > /tmp/loglm-test-pii-review.out 2> /tmp/loglm-test-pii-review.err
[[ -f "$DECODE_TMP/sample.redacted.txt" ]] || fail "pii review should create .redacted.txt from decoded input"
rg -Fq '[1/2] pii_group (6 hits): ***1*' /tmp/loglm-test-pii-review.out || fail "pii review should number the first candidate group"
rg -Fq '[2/2] pii_group (3 hits): ***2*' /tmp/loglm-test-pii-review.out || fail "pii review should number the second candidate group"
rg -Fq 'aliases: ks91@example.com,Kenji Saito,Kenji,Saito,ks91' /tmp/loglm-test-pii-review.out || fail "pii review should show group aliases"
rg -q 'line 1: Contact: ks91@example.com' /tmp/loglm-test-pii-review.out || fail "pii review should show line context for first match"
rg -q 'Contact: \*\*\*1\*' "$DECODE_TMP/sample.redacted.txt" || fail "pii review should replace first-group identifiers with ***1*"
rg -q 'Name: \*\*\*1\*' "$DECODE_TMP/sample.redacted.txt" || fail "pii review should replace full names with ***1*"
rg -q 'Greeting: Welcome back \*\*\*1\*!' "$DECODE_TMP/sample.redacted.txt" || fail "pii review should replace given-name aliases with ***1*"
rg -q 'Colleague: \*\*\*2\*' "$DECODE_TMP/sample.redacted.txt" || fail "pii review should replace second-group identifiers with ***2*"
pass "pii review on grouped candidate input"

cat > "$DECODE_TMP/bulk.decoded.txt" <<'EOF'
Lead: Kenji Saito
Login: ks91
Partner: Natsume Soseki
EOF

"$ROOT_DIR/loglm-decode" --review-pii --replace-all "$DECODE_TMP/pii-candidates.txt" "$DECODE_TMP/bulk.decoded.txt" > /tmp/loglm-test-pii-replace-all.out 2> /tmp/loglm-test-pii-replace-all.err
rg -q 'Lead: \*\*\*1\*' "$DECODE_TMP/bulk.redacted.txt" || fail "replace-all should redact first-group candidates without prompting"
rg -q 'Login: \*\*\*1\*' "$DECODE_TMP/bulk.redacted.txt" || fail "replace-all should redact every matched alias in a group"
rg -q 'Partner: \*\*\*2\*' "$DECODE_TMP/bulk.redacted.txt" || fail "replace-all should redact second-group candidates without prompting"
pass "pii replace-all on grouped candidate input"

cat > "$DECODE_TMP/pii-exclude.decoded.txt" <<'EOF'
Nickname: いし
Polite phrase: お願いします
EOF
cat > "$DECODE_TMP/pii-exclude-candidates.txt" <<'EOF'
いし
-願いし
EOF

"$ROOT_DIR/loglm-decode" --review-pii --replace-all "$DECODE_TMP/pii-exclude-candidates.txt" "$DECODE_TMP/pii-exclude.decoded.txt" > /tmp/loglm-test-pii-exclude.out 2> /tmp/loglm-test-pii-exclude.err
rg -q 'Nickname: \*\*\*1\*' "$DECODE_TMP/pii-exclude.redacted.txt" || fail "pii exclude should still redact standalone candidate values"
rg -q 'Polite phrase: お願いします' "$DECODE_TMP/pii-exclude.redacted.txt" || fail "pii exclude should keep candidate values inside excluded strings"
rg -Fq 'excludes: 願いし' /tmp/loglm-test-pii-exclude.out || fail "pii review should show group exclusions"
pass "pii group exclusions"

cat > "$DECODE_TMP/loglm-claude-log-20260501-060000-pid12.decoded.txt" <<'EOF'
===== loglm start [claude]: 2026-05-01 06:00:00 +0900 =====
Name: Kenji Saito
Content: this decoded source should win
EOF
cat > "$DECODE_TMP/loglm-claude-log-20260501-060000-pid12.redacted.txt" <<'EOF'
stale redacted file
EOF
cat > "$DECODE_TMP/loglm-claude-log-20260501-060000-pid12.txt" <<'EOF'
raw source should not overwrite decoded redaction
EOF

"$ROOT_DIR/loglm-decode" --review-pii --replace-all "$DECODE_TMP/pii-candidates.txt" \
  "$DECODE_TMP/loglm-claude-log-20260501-060000-pid12.decoded.txt" \
  "$DECODE_TMP/loglm-claude-log-20260501-060000-pid12.redacted.txt" \
  "$DECODE_TMP/loglm-claude-log-20260501-060000-pid12.txt" > /tmp/loglm-test-pii-dedup.out 2> /tmp/loglm-test-pii-dedup.err
rg -q 'Name: \*\*\*1\*' "$DECODE_TMP/loglm-claude-log-20260501-060000-pid12.redacted.txt" || fail "pii review should redact from decoded source when duplicate outputs are present"
rg -q 'Content: this decoded source should win' "$DECODE_TMP/loglm-claude-log-20260501-060000-pid12.redacted.txt" || fail "pii review should not overwrite decoded redaction with raw input"
! rg -q 'stale redacted file|raw source should not overwrite' "$DECODE_TMP/loglm-claude-log-20260501-060000-pid12.redacted.txt" || fail "pii review should skip duplicate redacted/raw inputs for the same output"
pass "pii review deduplicates mixed input variants"

# 4) install-node runtime behavior for missing NVM_DIR
NODE_TMP="$(/usr/bin/mktemp -d)"
trap 'rm -rf "$TMP_WORK" "$NODE_TMP" "$DECODE_TMP" "$CLAUDE_TMP" "$EXPERIMENTAL_TMP"' EXIT
mkdir -p "$NODE_TMP/home" "$NODE_TMP/bin"

cat > "$NODE_TMP/bin/curl" <<'EOF'
#!/usr/bin/env bash
cat <<'SCRIPT'
#!/usr/bin/env bash
mkdir -p "$NVM_DIR"
cat > "$NVM_DIR/nvm.sh" <<'EOS'
nvm() {
  return 0
}
EOS
SCRIPT
EOF
chmod +x "$NODE_TMP/bin/curl"

cat > "$NODE_TMP/bin/node" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$NODE_TMP/bin/node"

cat > "$NODE_TMP/bin/npm" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$NODE_TMP/bin/npm"

cat > "$NODE_TMP/home/.profile" <<'EOF'
# regression test profile
EOF

run_cmd env \
  HOME="$NODE_TMP/home" \
  PATH="$NODE_TMP/bin:$PATH" \
  LOGLM_PLATFORM=chromeos \
  LOGLM_LANG=en \
  NVM_DIR="$NODE_TMP/home/custom-nvm" \
  bash "$ROOT_DIR/setup/install-node.sh"
[[ -d "$NODE_TMP/home/custom-nvm" ]] || fail "install-node should create missing NVM_DIR"
[[ -f "$NODE_TMP/home/custom-nvm/nvm.sh" ]] || fail "install-node should create nvm.sh in NVM_DIR"
pass "install-node handles missing NVM_DIR"

# 5) Existing option conflict behavior
set +e
"$ROOT_DIR/loglm" --new --resume > /tmp/loglm-test-conflict.out 2> /tmp/loglm-test-conflict.err
st=$?
set -e
assert_exit_code 2 "$st" "--new/--resume conflict"
rg -q "cannot be used together" /tmp/loglm-test-conflict.err || fail "missing conflict message"
pass "option conflict check"

# 6) Invalid repo validation
set +e
LOGLM_AGENT_INSTALL_NO_LAUNCH=1 LOGLM_CODING_AGENT=codex "$ROOT_DIR/loglm" agent install not-a-repo > /tmp/loglm-test-invalid.out 2> /tmp/loglm-test-invalid.err
st=$?
set -e
assert_exit_code 2 "$st" "invalid repo validation"
rg -q "Invalid source spec" /tmp/loglm-test-invalid.err || fail "missing invalid source message"
pass "invalid repo check"

# 7) Claude resume detection with Claude Code project path encoding
CLAUDE_TMP="$(/usr/bin/mktemp -d)"
trap 'rm -rf "$TMP_WORK" "$NODE_TMP" "$DECODE_TMP" "$CLAUDE_TMP" "$EXPERIMENTAL_TMP"' EXIT
CLAUDE_WORK="$CLAUDE_TMP/Mobile Documents/早稲田大学/iCloud~com~omz-software~Pythonista3/Documents"
mkdir -p "$CLAUDE_WORK" "$CLAUDE_TMP/home" "$CLAUDE_TMP/bin"
printf 'claude\n' > "$CLAUDE_WORK/.loglm_agent"
claude_project_path="$(cd "$CLAUDE_WORK" && pwd -P)"
claude_project_key="$(perl -MEncode=decode -e 'my $s = decode("UTF-8", shift); $s =~ s/[^A-Za-z0-9._-]/-/g; print $s' "$claude_project_path")"
mkdir -p "$CLAUDE_TMP/home/.claude/projects/$claude_project_key"
printf '{}\n' > "$CLAUDE_TMP/home/.claude/projects/$claude_project_key/session.jsonl"

cat > "$CLAUDE_TMP/bin/claude" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$CLAUDE_TMP/bin/claude"

cat > "$CLAUDE_TMP/bin/script" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-h" ]]; then
  printf 'usage: script [-q] [-a] [-F] -c command file\n'
  exit 0
fi
printf '%s\n' "$*" > "$LOGLM_TEST_SCRIPT_ARGS"
exit 0
EOF
chmod +x "$CLAUDE_TMP/bin/script"

(
  cd "$CLAUDE_WORK"
  HOME="$CLAUDE_TMP/home" \
    PATH="$CLAUDE_TMP/bin:$PATH" \
    LOGLM_LANG=en \
    LOGLM_TEST_SCRIPT_ARGS="$CLAUDE_TMP/script-args.out" \
    "$ROOT_DIR/loglm" >/tmp/loglm-test-claude-resume.out 2>/tmp/loglm-test-claude-resume.err
)
rg -q 'claude --continue' "$CLAUDE_TMP/script-args.out" || fail "claude should resume when Claude Code history exists for encoded Unicode project path"
[[ -f "$CLAUDE_WORK/CLAUDE.md" ]] || fail "loglm should create CLAUDE.md runtime notes on Claude launch"
rg -q 'loglm Platform Notes' "$CLAUDE_WORK/CLAUDE.md" || fail "CLAUDE.md should include loglm platform notes"
rg -q '`loglm` is a wrapper command that launches coding agents' "$CLAUDE_WORK/CLAUDE.md" || fail "CLAUDE.md should explain what loglm is"
rg -q 'Decode raw logs with: `loglm-decode logs/\*`' "$CLAUDE_WORK/CLAUDE.md" || fail "CLAUDE.md should tell Claude how to decode loglm logs"
rg -q 'Build a chronological overview with: `loglm-timeline logs/\*\.decoded\.txt`' "$CLAUDE_WORK/CLAUDE.md" || fail "CLAUDE.md should mention loglm-timeline"
pass "claude resume detection handles spaces, tildes, and Unicode in project path"

# 7b) Experimental agent launch commands
EXPERIMENTAL_TMP="$(/usr/bin/mktemp -d)"
trap 'rm -rf "$TMP_WORK" "$NODE_TMP" "$DECODE_TMP" "$CLAUDE_TMP" "$EXPERIMENTAL_TMP"' EXIT
EXPERIMENTAL_WORK="$EXPERIMENTAL_TMP/work"
mkdir -p "$EXPERIMENTAL_WORK" "$EXPERIMENTAL_TMP/home" "$EXPERIMENTAL_TMP/bin"

cat > "$EXPERIMENTAL_TMP/bin/script" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$LOGLM_TEST_SCRIPT_ARGS"
exit 0
EOF
chmod +x "$EXPERIMENTAL_TMP/bin/script"

cat > "$EXPERIMENTAL_TMP/bin/openclaw" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$EXPERIMENTAL_TMP/bin/openclaw"

cat > "$EXPERIMENTAL_TMP/bin/agy" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$EXPERIMENTAL_TMP/bin/agy"

cat > "$EXPERIMENTAL_TMP/bin/hermes" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$EXPERIMENTAL_TMP/bin/hermes"

cat > "$EXPERIMENTAL_TMP/bin/claude" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$EXPERIMENTAL_TMP/bin/claude"

cat > "$EXPERIMENTAL_TMP/bin/llama-server" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$EXPERIMENTAL_TMP/bin/llama-server"

cat > "$EXPERIMENTAL_TMP/bin/curl" <<'EOF'
#!/usr/bin/env bash
last="${@: -1}"
if [[ "$last" == */v1/models ]]; then
  printf '%s\n' '{"object":"list","data":[{"id":"qwen3.5:35b","object":"model"}]}'
fi
exit 0
EOF
chmod +x "$EXPERIMENTAL_TMP/bin/curl"

(
  cd "$EXPERIMENTAL_WORK"
  printf 'antigravity\n' > .loglm_agent
  HOME="$EXPERIMENTAL_TMP/home" \
    PATH="$EXPERIMENTAL_TMP/bin:$PATH" \
    LOGLM_TEST_SCRIPT_ARGS="$EXPERIMENTAL_TMP/antigravity-script-args.out" \
    "$ROOT_DIR/loglm" >/tmp/loglm-test-antigravity-launch.out 2>/tmp/loglm-test-antigravity-launch.err
)
rg -q '^.*agy -c$' "$EXPERIMENTAL_TMP/antigravity-script-args.out" || fail "Antigravity default launch should continue with agy -c"
rg -q 'loglm Platform Notes' "$EXPERIMENTAL_WORK/AGENTS.md" || fail "Antigravity launch should create AGENTS.md runtime notes"

(
  cd "$EXPERIMENTAL_WORK"
  printf 'openclaw\n' > .loglm_agent
  HOME="$EXPERIMENTAL_TMP/home" \
    PATH="$EXPERIMENTAL_TMP/bin:$PATH" \
    LOGLM_TEST_SCRIPT_ARGS="$EXPERIMENTAL_TMP/openclaw-script-args.out" \
    "$ROOT_DIR/loglm" --new >/tmp/loglm-test-openclaw-launch.out 2>/tmp/loglm-test-openclaw-launch.err
)
rg -q 'openclaw tui --local --session loglm-' "$EXPERIMENTAL_TMP/openclaw-script-args.out" || fail "OpenClaw launch should use TUI local mode and a new session key"
rg -q 'loglm Platform Notes' "$EXPERIMENTAL_WORK/AGENTS.md" || fail "OpenClaw launch should create AGENTS.md runtime notes"

(
  cd "$EXPERIMENTAL_WORK"
  printf 'hermes\n' > .loglm_agent
  HOME="$EXPERIMENTAL_TMP/home" \
    PATH="$EXPERIMENTAL_TMP/bin:$PATH" \
    LOGLM_TEST_SCRIPT_ARGS="$EXPERIMENTAL_TMP/hermes-script-args.out" \
    "$ROOT_DIR/loglm" >/tmp/loglm-test-hermes-launch.out 2>/tmp/loglm-test-hermes-launch.err
)
rg -q '^.*hermes$' "$EXPERIMENTAL_TMP/hermes-script-args.out" || fail "Hermes launch should start normally when no previous session exists"
! rg -q 'hermes --continue' "$EXPERIMENTAL_TMP/hermes-script-args.out" || fail "Hermes launch should not continue when no previous session exists"

mkdir -p "$EXPERIMENTAL_TMP/home/.hermes/sessions"
touch "$EXPERIMENTAL_TMP/home/.hermes/sessions/20260531_191136_d1cd26"
(
  cd "$EXPERIMENTAL_WORK"
  printf 'hermes\n' > .loglm_agent
  HOME="$EXPERIMENTAL_TMP/home" \
    PATH="$EXPERIMENTAL_TMP/bin:$PATH" \
    LOGLM_TEST_SCRIPT_ARGS="$EXPERIMENTAL_TMP/hermes-script-args.out" \
    "$ROOT_DIR/loglm" >/tmp/loglm-test-hermes-launch-resume.out 2>/tmp/loglm-test-hermes-launch-resume.err
)
rg -q 'hermes --continue' "$EXPERIMENTAL_TMP/hermes-script-args.out" || fail "Hermes launch should resume when a previous session exists"

LOCAL_LLM_WORK="$EXPERIMENTAL_TMP/local-llm-work"
mkdir -p "$LOCAL_LLM_WORK"
(
  cd "$LOCAL_LLM_WORK"
  printf 'local-llm\n' > .loglm_agent
  HOME="$EXPERIMENTAL_TMP/home" \
    PATH="$EXPERIMENTAL_TMP/bin:$PATH" \
    LOGLM_TEST_SCRIPT_ARGS="$EXPERIMENTAL_TMP/local-llm-script-args.out" \
    "$ROOT_DIR/loglm" --local-llm-url http://127.0.0.1:18080 >/tmp/loglm-test-local-llm-launch.out 2>/tmp/loglm-test-local-llm-launch.err
)
rg -q 'ANTHROPIC_BASE_URL=http://127.0.0.1:18080' "$EXPERIMENTAL_TMP/local-llm-script-args.out" || fail "local-llm launch should set ANTHROPIC_BASE_URL"
rg -q 'ANTHROPIC_AUTH_TOKEN=loglm-local-llm' "$EXPERIMENTAL_TMP/local-llm-script-args.out" || fail "local-llm launch should set a local auth token"
rg -q 'CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1' "$EXPERIMENTAL_TMP/local-llm-script-args.out" || fail "local-llm launch should disable experimental betas for gateway compatibility"
rg -q 'claude --model qwen3.5:35b' "$EXPERIMENTAL_TMP/local-llm-script-args.out" || fail "local-llm launch should run Claude Code with requested model"
rg -q '^http://127.0.0.1:18080$' "$LOCAL_LLM_WORK/.loglm_local_llm" || fail "local-llm URL should be saved in project config"
rg -q '^qwen3.5:35b$' "$LOCAL_LLM_WORK/.loglm_local_llm_model" || fail "local-llm model should be detected and saved in project config"
[[ -f "$LOCAL_LLM_WORK/CLAUDE.md" ]] || fail "local-llm launch should create CLAUDE.md runtime notes"
rg -q '"CLAUDE_CODE_ATTRIBUTION_HEADER" : "0"' "$LOCAL_LLM_WORK/.claude/settings.local.json" || fail "local-llm launch should disable Claude Code attribution header in local settings"
pass "experimental agent launch commands"

# 8) Managed block list/remove behavior
TMP_WORK="$(/usr/bin/mktemp -d)"
trap 'rm -rf "$TMP_WORK" "$NODE_TMP" "$DECODE_TMP" "$CLAUDE_TMP" "$EXPERIMENTAL_TMP"' EXIT
cd "$TMP_WORK"

cat > AGENTS.md <<'EOF'
# Existing content

<!-- loglm:begin platform -->
# loglm Platform Notes (managed)
- Runtime: test
<!-- loglm:end platform -->

<!-- loglm:begin repo=gh:ks91/gamer-pat agent=codex source=AGENTS.md -->
repo block body
<!-- loglm:end repo=gh:ks91/gamer-pat agent=codex -->
EOF

run_cmd "$ROOT_DIR/loglm" agent list
"$ROOT_DIR/loglm" agent list > /tmp/loglm-test-list1.out 2>/tmp/loglm-test-list1.err
rg -q "repo=gh:ks91/gamer-pat agent=codex source=AGENTS.md" /tmp/loglm-test-list1.out || fail "agent list should show installed block"
pass "agent list shows managed repo block"

run_cmd "$ROOT_DIR/loglm" agent remove ks91/gamer-pat --agent codex
! rg -q "repo=gh:ks91/gamer-pat" AGENTS.md || fail "repo block should be removed"
rg -q "loglm:begin platform" AGENTS.md || fail "platform block should remain"
rg -q "Existing content" AGENTS.md || fail "existing content should remain"
pass "agent remove removes only target block"

"$ROOT_DIR/loglm" agent list > /tmp/loglm-test-list2.out 2>/tmp/loglm-test-list2.err
rg -q "No installed prompt agents found" /tmp/loglm-test-list2.out || fail "agent list should be empty after remove"
pass "agent list empty after remove"

# 8) Local repository install behavior
LOCAL_REPO="$TMP_WORK/local-agent-src"
mkdir -p "$LOCAL_REPO"
cat > "$LOCAL_REPO/AGENT_INSTALL.md" <<'EOF'
<!-- prompt-agent-version: 9.9.9 -->
# Local Prompt

## Non-Negotiable Rules
- Test local install path support.
EOF

run_cmd env LOGLM_AGENT_INSTALL_NO_LAUNCH=1 LOGLM_CODING_AGENT=codex "$ROOT_DIR/loglm" agent install "$LOCAL_REPO" --agent codex --force
rg -q "Prompt Agent:" AGENTS.md || fail "managed heading should exist after local install"
rg -q "LOCAL-AGENT-SRC.md" AGENTS.md || fail "local prompt filename reference should exist"
rg -q 'You MUST follow `LOCAL-AGENT-SRC.md` as the primary project instruction set' AGENTS.md || fail "Codex prompt-agent block should keep primary instruction wording"
[[ -f LOCAL-AGENT-SRC.md ]] || fail "local prompt file should be created"
pass "local source install works"

"$ROOT_DIR/loglm" agent list --agent codex --verbose > /tmp/loglm-test-list-verbose.out 2>/tmp/loglm-test-list-verbose.err
rg -q "prompt_agent_version: 9.9.9" /tmp/loglm-test-list-verbose.out || fail "verbose list should show prompt-agent version"
pass "agent list --verbose shows prompt-agent version"

cat > "$LOCAL_REPO/AGENT_INSTALL_OPENCLAW.md" <<'EOF'
# OpenClaw Prompt

## Non-Negotiable Rules
- Test OpenClaw-specific prompt install.
EOF
cat > "$LOCAL_REPO/AGENT_INSTALL_HERMES.md" <<'EOF'
# Hermes Prompt

## Non-Negotiable Rules
- Test Hermes-specific prompt install.
EOF
cat > "$LOCAL_REPO/AGENT_INSTALL_LOCAL_LLM.md" <<'EOF'
# Local LLM Prompt

## Non-Negotiable Rules
- Test local-llm-specific prompt install.
EOF

cat > "$TMP_WORK/openclaw" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$OPENCLAW_SKILLS_ARGS_OUT"
if [[ "$1" == "skills" && "$2" == "install" ]]; then
  cp "$3/SKILL.md" "$OPENCLAW_SKILL_OUT"
fi
exit 0
EOF
chmod +x "$TMP_WORK/openclaw"

run_cmd env LOGLM_AGENT_INSTALL_NO_LAUNCH=1 PATH="$TMP_WORK:$PATH" OPENCLAW_SKILLS_ARGS_OUT="$TMP_WORK/openclaw-skills-args.out" OPENCLAW_SKILL_OUT="$TMP_WORK/openclaw-SKILL.md" "$ROOT_DIR/loglm" agent install "$LOCAL_REPO" --agent openclaw --force
LOCAL_REPO_CANON="$(cd "$LOCAL_REPO" && pwd -P)"
rg -q "repo=local:$LOCAL_REPO_CANON agent=openclaw source=AGENT_INSTALL_OPENCLAW.md" AGENTS.md || fail "OpenClaw prompt-agent block should be installed into AGENTS.md"
rg -q 'Use and follow `LOCAL-AGENT-SRC.md` only when that skill is selected' AGENTS.md || fail "OpenClaw prompt-agent block should be scoped to skill use"
rg -q 'Do not apply `LOCAL-AGENT-SRC.md` to unrelated skills or unrelated tasks' AGENTS.md || fail "OpenClaw prompt-agent block should avoid unrelated skills"
rg -q "skills install .*/local-agent-src --as local-agent-src" "$TMP_WORK/openclaw-skills-args.out" || fail "OpenClaw prompt-agent install should call openclaw skills install"
rg -q '^name: local-agent-src$' "$TMP_WORK/openclaw-SKILL.md" || fail "OpenClaw generated SKILL.md should include skill name"
rg -q 'Test OpenClaw-specific prompt install' "$TMP_WORK/openclaw-SKILL.md" || fail "OpenClaw generated SKILL.md should include prompt-agent content"
HERMES_HOME="$TMP_WORK/hermes-home"
run_cmd env LOGLM_AGENT_INSTALL_NO_LAUNCH=1 HOME="$HERMES_HOME" "$ROOT_DIR/loglm" agent install "$LOCAL_REPO" --agent hermes --force
rg -q "repo=local:$LOCAL_REPO_CANON agent=hermes source=AGENT_INSTALL_HERMES.md" AGENTS.md || fail "Hermes prompt-agent block should be installed into AGENTS.md"
rg -q 'Use and follow `LOCAL-AGENT-SRC.md` only when that skill is selected' AGENTS.md || fail "Hermes prompt-agent block should be scoped to skill use"
rg -q 'Do not apply `LOCAL-AGENT-SRC.md` to unrelated skills or unrelated tasks' AGENTS.md || fail "Hermes prompt-agent block should avoid unrelated skills"
[[ -f "$HERMES_HOME/.hermes/skills/research/local-agent-src/SKILL.md" ]] || fail "Hermes prompt-agent install should write SKILL.md"
rg -q '^name: local-agent-src$' "$HERMES_HOME/.hermes/skills/research/local-agent-src/SKILL.md" || fail "Hermes generated SKILL.md should include skill name"
rg -q 'Test Hermes-specific prompt install' "$HERMES_HOME/.hermes/skills/research/local-agent-src/SKILL.md" || fail "Hermes generated SKILL.md should include prompt-agent content"
run_cmd env LOGLM_AGENT_INSTALL_NO_LAUNCH=1 "$ROOT_DIR/loglm" agent install "$LOCAL_REPO" --agent local-llm --force
rg -q "repo=local:$LOCAL_REPO_CANON agent=local-llm source=AGENT_INSTALL_LOCAL_LLM.md" CLAUDE.md || fail "local-llm prompt-agent block should be installed into CLAUDE.md"
rg -q 'This session is Claude Code routed through a local LLM gateway by loglm' CLAUDE.md || fail "local-llm prompt-agent block should mention Claude Code local gateway runtime"
rg -q 'Test local-llm-specific prompt install' LOCAL-AGENT-SRC.md || fail "local-llm prompt file should use local-llm-specific source"
pass "experimental agent prompt install works"

# 9) Update validation
set +e
"$ROOT_DIR/loglm" agent update > /tmp/loglm-test-update-empty.out 2> /tmp/loglm-test-update-empty.err
st=$?
set -e
assert_exit_code 2 "$st" "agent update with no args"
rg -q "requires a source or --all" /tmp/loglm-test-update-empty.err || fail "missing update validation message"
pass "agent update validation"

run_cmd "$ROOT_DIR/loglm" agent update --all
pass "agent update --all on empty set"

if [[ "$RUN_E2E" -eq 1 ]]; then
  # 10) Network E2E: install/list/update/remove cycle against real GitHub repo
  E2E_DIR="$(/usr/bin/mktemp -d)"
  trap 'rm -rf "$TMP_WORK" "$NODE_TMP" "$DECODE_TMP" "$CLAUDE_TMP" "$EXPERIMENTAL_TMP" "$E2E_DIR"' EXIT
  cd "$E2E_DIR"

  run_cmd env LOGLM_AGENT_INSTALL_NO_LAUNCH=1 LOGLM_CODING_AGENT=codex "$ROOT_DIR/loglm" agent install "$E2E_REPO" --agent "$E2E_AGENT"
  pass "e2e install ($E2E_REPO, agent=$E2E_AGENT)"

  "$ROOT_DIR/loglm" agent list --agent "$E2E_AGENT" > /tmp/loglm-test-e2e-list1.out 2>/tmp/loglm-test-e2e-list1.err
  rg -q "repo=$E2E_REPO" /tmp/loglm-test-e2e-list1.out || fail "e2e list should include installed repo"
  pass "e2e list after install"

  run_cmd "$ROOT_DIR/loglm" agent update "$E2E_REPO" --agent "$E2E_AGENT"
  pass "e2e update ($E2E_REPO)"

  run_cmd "$ROOT_DIR/loglm" agent remove "$E2E_REPO" --agent "$E2E_AGENT"
  pass "e2e remove ($E2E_REPO)"

  "$ROOT_DIR/loglm" agent list --agent "$E2E_AGENT" > /tmp/loglm-test-e2e-list2.out 2>/tmp/loglm-test-e2e-list2.err
  ! rg -q "repo=$E2E_REPO" /tmp/loglm-test-e2e-list2.out || fail "e2e list should not include removed repo"
  pass "e2e list after remove"
fi

printf 'loglm regression passed\n' | tee -a "$LOG_FILE"
printf 'log: %s\n' "$LOG_FILE"
