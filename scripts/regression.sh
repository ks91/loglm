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
E2E_DIR=""

usage() {
  cat <<'EOF'
Usage:
  bash scripts/regression.sh [--e2e] [--repo <owner/repo>] [--agent codex|claude|gemini|all]

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
  codex|claude|gemini|all) ;;
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
pass "shell syntax checks"

# 2) Help output
run_cmd "$ROOT_DIR/loglm" --help
run_cmd "$ROOT_DIR/loglm" agent install --help
pass "help output"

"$ROOT_DIR/loglm" --version > /tmp/loglm-test-version.out 2>/tmp/loglm-test-version.err
rg -q '^loglm [0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$' /tmp/loglm-test-version.out || fail "version output format"
pass "version output"

# 3) loglm-decode overlap trimming
DECODE_TMP="$(/usr/bin/mktemp -d)"
trap 'rm -rf "$TMP_WORK" "$NODE_TMP" "$DECODE_TMP"' EXIT
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

cat > "$DECODE_TMP/sample.decoded.txt" <<'EOF'
Contact: ks91@example.com
Path: /Volumes/ks91home/ks91/project
Greeting: Welcome back Kenji!
Date: 2026-04-03
Timestamp: 2026-03-05 23
Compact: 20260306-021406
EOF

printf 'y\nn\ny\n' | "$ROOT_DIR/loglm-decode" --review-pii "$DECODE_TMP/sample.decoded.txt" > /tmp/loglm-test-pii-review.out 2> /tmp/loglm-test-pii-review.err
[[ -f "$DECODE_TMP/sample.redacted.txt" ]] || fail "pii review should create .redacted.txt from decoded input"
rg -q 'line 1: Contact: ks91@example.com' /tmp/loglm-test-pii-review.out || fail "pii review should show line context for candidates"
rg -q '\*\*\*' "$DECODE_TMP/sample.redacted.txt" || fail "pii review should replace accepted candidates"
! rg -q 'ks91@example.com' "$DECODE_TMP/sample.redacted.txt" || fail "pii review should redact accepted email candidates"
! rg -q '/Volumes/ks91home/ks91' "$DECODE_TMP/sample.redacted.txt" || fail "pii review should redact accepted user-path candidates"
rg -q 'Welcome back Kenji!' "$DECODE_TMP/sample.redacted.txt" || fail "pii review should keep rejected candidates unchanged"
rg -q 'Date: 2026-04-03' "$DECODE_TMP/sample.redacted.txt" || fail "pii review should not treat dates as phone candidates"
rg -q 'Timestamp: 2026-03-05 23' "$DECODE_TMP/sample.redacted.txt" || fail "pii review should not treat timestamps as phone candidates"
rg -q 'Compact: 20260306-021406' "$DECODE_TMP/sample.redacted.txt" || fail "pii review should not treat compact timestamps as phone candidates"
! rg -q 'phone .*2026-04-03' /tmp/loglm-test-pii-review.out || fail "pii review should not list dates as phone candidates"
! rg -q 'phone .*2026-03-05 23' /tmp/loglm-test-pii-review.out || fail "pii review should not list timestamps as phone candidates"
! rg -q 'phone .*20260306-021406' /tmp/loglm-test-pii-review.out || fail "pii review should not list compact timestamps as phone candidates"
pass "pii review on decoded input"

printf 'e\n[NAME]\n' | "$ROOT_DIR/loglm-decode" --review-pii "$DECODE_TMP/sample.redacted.txt" > /tmp/loglm-test-pii-reredact.out 2> /tmp/loglm-test-pii-reredact.err
rg -q 'Welcome back \[NAME\]!' "$DECODE_TMP/sample.redacted.txt" || fail "pii review should allow in-place re-review on redacted input"
pass "pii review on redacted input"

cat > "$DECODE_TMP/jp.decoded.txt" <<'EOF'
氏名: 斉藤賢爾
所属: 早稲田大学
EOF
cat > "$DECODE_TMP/pii-list.txt" <<'EOF'
# literal pii candidates
斉藤賢爾
ks91
EOF

printf 'y\n' | "$ROOT_DIR/loglm-decode" --review-pii --pii-list "$DECODE_TMP/pii-list.txt" "$DECODE_TMP/jp.decoded.txt" > /tmp/loglm-test-pii-list.out 2> /tmp/loglm-test-pii-list.err
rg -q '\[1/1\] pii_list \(1 hit\): 斉藤賢爾' /tmp/loglm-test-pii-list.out || fail "pii review should include external list candidates"
rg -q 'line 1: 氏名: 斉藤賢爾' /tmp/loglm-test-pii-list.out || fail "pii review should show UTF-8 context for external list candidates"
rg -q '氏名: \*\*\*' "$DECODE_TMP/jp.redacted.txt" || fail "pii review should replace accepted external list candidates"
pass "pii review with external candidate list"

printf 'y\n' | "$ROOT_DIR/loglm-decode" --review-pii --pii-list-only --pii-list "$DECODE_TMP/pii-list.txt" "$DECODE_TMP/jp.decoded.txt" > /tmp/loglm-test-pii-list-only.out 2> /tmp/loglm-test-pii-list-only.err
rg -q '\[1/1\] pii_list \(1 hit\): 斉藤賢爾' /tmp/loglm-test-pii-list-only.out || fail "pii-list-only should review external list candidates"
! rg -Fq 'email (' /tmp/loglm-test-pii-list-only.out || fail "pii-list-only should skip automatic candidate detection"
pass "pii review with external candidate list only"

cat > "$DECODE_TMP/bulk.decoded.txt" <<'EOF'
氏名: 斉藤賢爾
ID: ks91
EOF

"$ROOT_DIR/loglm-decode" --review-pii --replace-all --pii-list-only --pii-list "$DECODE_TMP/pii-list.txt" "$DECODE_TMP/bulk.decoded.txt" > /tmp/loglm-test-pii-replace-all.out 2> /tmp/loglm-test-pii-replace-all.err
rg -q '氏名: \*\*\*' "$DECODE_TMP/bulk.redacted.txt" || fail "replace-all should redact list candidates without prompting"
rg -q 'ID: \*\*\*' "$DECODE_TMP/bulk.redacted.txt" || fail "replace-all should redact every matched list candidate"
pass "pii replace-all with external candidate list"

# 4) install-node runtime behavior for missing NVM_DIR
NODE_TMP="$(/usr/bin/mktemp -d)"
trap 'rm -rf "$TMP_WORK" "$NODE_TMP" "$DECODE_TMP"' EXIT
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

# 7) Managed block list/remove behavior
TMP_WORK="$(/usr/bin/mktemp -d)"
trap 'rm -rf "$TMP_WORK" "$NODE_TMP" "$DECODE_TMP"' EXIT
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
[[ -f LOCAL-AGENT-SRC.md ]] || fail "local prompt file should be created"
pass "local source install works"

"$ROOT_DIR/loglm" agent list --agent codex --verbose > /tmp/loglm-test-list-verbose.out 2>/tmp/loglm-test-list-verbose.err
rg -q "prompt_agent_version: 9.9.9" /tmp/loglm-test-list-verbose.out || fail "verbose list should show prompt-agent version"
pass "agent list --verbose shows prompt-agent version"

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
  trap 'rm -rf "$TMP_WORK" "$NODE_TMP" "$DECODE_TMP" "$E2E_DIR"' EXIT
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
