#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/platform-detect.sh"

resolve_lang

usage() {
  cat <<'EOF'
Usage:
  loglm agent install <github_repo_or_url> [--agent codex|claude|gemini|all]
  loglm agent list [--agent codex|claude|gemini|all]
  loglm agent remove <github_repo_or_url> [--agent codex|claude|gemini|all]
  loglm agent update <github_repo_or_url|--all> [--agent codex|claude|gemini|all]

Examples:
  loglm agent install ks91/gamer-pat
  loglm agent list
  loglm agent remove ks91/gamer-pat
  loglm agent update --all

Notes:
  - If --agent is omitted, loglm uses the currently selected coding agent
    from ./.loglm_agent.
EOF
}

new_tmp_file() {
  if [[ -x /usr/bin/mktemp ]]; then
    /usr/bin/mktemp
  else
    mktemp
  fi
}

download_to_file() {
  local url="$1"
  local out="$2"

  if command -v curl > /dev/null 2>&1; then
    curl -fsSL "$url" -o "$out"
    return
  fi
  if command -v wget > /dev/null 2>&1; then
    wget -qO "$out" "$url"
    return
  fi
  say "curl または wget が必要です。" \
      "curl or wget is required." >&2
  return 1
}

normalize_repo_spec() {
  local spec="$1"

  spec="${spec#https://github.com/}"
  spec="${spec#http://github.com/}"
  spec="${spec#git@github.com:}"
  spec="${spec%.git}"
  spec="${spec%/}"
  spec="${spec%%/tree/*}"
  spec="${spec%%/blob/*}"

  if [[ ! "$spec" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
    return 1
  fi

  printf '%s\n' "$spec"
}

target_file_for_agent() {
  case "$1" in
    codex) printf '%s\n' "AGENTS.md" ;;
    claude) printf '%s\n' "CLAUDE.md" ;;
    gemini) printf '%s\n' "GEMINI.md" ;;
    *)
      return 1
      ;;
  esac
}

source_candidates_for_agent() {
  case "$1" in
    codex)
      printf '%s\n' "AGENT_INSTALL_CODEX.md"
      printf '%s\n' "AGENT_INSTALL.md"
      ;;
    claude)
      printf '%s\n' "AGENT_INSTALL_CLAUDE.md"
      printf '%s\n' "AGENT_INSTALL.md"
      ;;
    gemini)
      printf '%s\n' "AGENT_INSTALL_GEMINI.md"
      printf '%s\n' "AGENT_INSTALL.md"
      ;;
    *)
      return 1
      ;;
  esac
}

repo_prompt_filename() {
  local repo="$1"
  local base sanitized
  base="${repo##*/}"
  sanitized="$(printf '%s' "$base" | tr '[:lower:]' '[:upper:]' | sed -E 's/[^A-Z0-9]+/-/g; s/^-+//; s/-+$//')"
  if [[ -z "$sanitized" ]]; then
    sanitized="PROMPT-AGENT"
  fi
  printf '%s.md\n' "$sanitized"
}

write_repo_prompt_file() {
  local repo="$1"
  local source="$2"
  local src_file="$3"
  local out

  out="$(repo_prompt_filename "$repo")"
  {
    printf '<!-- source: https://github.com/%s/blob/HEAD/%s -->\n' "$repo" "$source"
    cat "$src_file"
  } > "$out"
}

repo_is_referenced_anywhere() {
  local repo="$1"
  local file
  for file in AGENTS.md CLAUDE.md GEMINI.md; do
    [[ -f "$file" ]] || continue
    if grep -q "repo=$repo " "$file"; then
      return 0
    fi
  done
  return 1
}

remove_repo_prompt_file_if_unreferenced() {
  local repo="$1"
  local prompt_file
  prompt_file="$(repo_prompt_filename "$repo")"
  if repo_is_referenced_anywhere "$repo"; then
    return 0
  fi
  rm -f "$prompt_file"
}

runtime_context() {
  local p
  p="$(detect_platform)"

  if [[ "$p" == "ubuntu" ]]; then
    if grep -qi lima /proc/version 2>/dev/null || grep -qi lima /proc/sys/kernel/osrelease 2>/dev/null; then
      printf '%s\n' "ubuntu-lima"
      return
    fi
  fi

  printf '%s\n' "$p"
}

platform_block_content() {
  local ctx="$1"

  case "$ctx" in
    macos)
      cat <<'EOF'
# loglm Platform Notes (managed)
- Runtime: native macOS.
- Prefer macOS-native commands and paths.
- For preview/open, use `open` (example: `open -a Skim paper.pdf`).
- loglm repository: `https://github.com/ks91/loglm`
- Raw logs are stored under `./logs/` (from launch directory).
- Raw log filename pattern: `logs/loglm-<agent>-log-YYYYMMDD-HHMMSS-pid<PID>.txt`
- If `--daily-log` is used: `logs/loglm-<agent>-log-YYYYMMDD.txt`
- Decode logs with: `loglm-decode <raw-log-file>`
EOF
      ;;
    wsl2)
      cat <<'EOF'
# loglm Platform Notes (managed)
- Runtime: Ubuntu on WSL2.
- Linux commands run inside WSL; Windows apps are outside.
- For opening files on Windows side, prefer `wslview` or `cmd.exe /c start`.
- Be explicit when converting paths (`wslpath`) between Linux and Windows.
- loglm repository: `https://github.com/ks91/loglm`
- Raw logs are stored under `./logs/` (from launch directory).
- Raw log filename pattern: `logs/loglm-<agent>-log-YYYYMMDD-HHMMSS-pid<PID>.txt`
- If `--daily-log` is used: `logs/loglm-<agent>-log-YYYYMMDD.txt`
- Decode logs with: `loglm-decode <raw-log-file>`
EOF
      ;;
    ubuntu-lima)
      cat <<'EOF'
# loglm Platform Notes (managed)
- Runtime: Ubuntu on Lima (macOS host).
- Work inside shared directories when host-side preview is needed.
- Do not assume guest can directly control host GUI apps.
- For PDF preview, prefer files in host-shared paths and open from host (e.g., Skim).
- loglm repository: `https://github.com/ks91/loglm`
- Raw logs are stored under `./logs/` (from launch directory).
- Raw log filename pattern: `logs/loglm-<agent>-log-YYYYMMDD-HHMMSS-pid<PID>.txt`
- If `--daily-log` is used: `logs/loglm-<agent>-log-YYYYMMDD.txt`
- Decode logs with: `loglm-decode <raw-log-file>`
EOF
      ;;
    ubuntu)
      cat <<'EOF'
# loglm Platform Notes (managed)
- Runtime: native Ubuntu.
- Prefer standard Linux CLI workflow and package management.
- For GUI actions, use Linux-native tools available in the environment.
- loglm repository: `https://github.com/ks91/loglm`
- Raw logs are stored under `./logs/` (from launch directory).
- Raw log filename pattern: `logs/loglm-<agent>-log-YYYYMMDD-HHMMSS-pid<PID>.txt`
- If `--daily-log` is used: `logs/loglm-<agent>-log-YYYYMMDD.txt`
- Decode logs with: `loglm-decode <raw-log-file>`
EOF
      ;;
    raspberrypi)
      cat <<'EOF'
# loglm Platform Notes (managed)
- Runtime: Raspberry Pi OS.
- Keep commands lightweight and avoid heavy defaults.
- Prefer architecture-compatible binaries and packages.
- loglm repository: `https://github.com/ks91/loglm`
- Raw logs are stored under `./logs/` (from launch directory).
- Raw log filename pattern: `logs/loglm-<agent>-log-YYYYMMDD-HHMMSS-pid<PID>.txt`
- If `--daily-log` is used: `logs/loglm-<agent>-log-YYYYMMDD.txt`
- Decode logs with: `loglm-decode <raw-log-file>`
EOF
      ;;
    chromeos)
      cat <<'EOF'
# loglm Platform Notes (managed)
- Runtime: Chrome OS Linux container (Crostini).
- Linux CLI runs in container; host integration can be limited.
- Prefer container-local workflows and explicit file export paths.
- loglm repository: `https://github.com/ks91/loglm`
- Raw logs are stored under `./logs/` (from launch directory).
- Raw log filename pattern: `logs/loglm-<agent>-log-YYYYMMDD-HHMMSS-pid<PID>.txt`
- If `--daily-log` is used: `logs/loglm-<agent>-log-YYYYMMDD.txt`
- Decode logs with: `loglm-decode <raw-log-file>`
EOF
      ;;
    *)
      cat <<'EOF'
# loglm Platform Notes (managed)
- Runtime: generic Linux/unknown.
- Prefer conservative, portable shell commands.
- loglm repository: `https://github.com/ks91/loglm`
- Raw logs are stored under `./logs/` (from launch directory).
- Raw log filename pattern: `logs/loglm-<agent>-log-YYYYMMDD-HHMMSS-pid<PID>.txt`
- If `--daily-log` is used: `logs/loglm-<agent>-log-YYYYMMDD.txt`
- Decode logs with: `loglm-decode <raw-log-file>`
EOF
      ;;
  esac
}

block_begin_platform() {
  printf '%s\n' "<!-- loglm:begin platform -->"
}

block_end_platform() {
  printf '%s\n' "<!-- loglm:end platform -->"
}

block_begin_repo() {
  local repo="$1"
  local agent="$2"
  local source="$3"
  printf '<!-- loglm:begin repo=%s agent=%s source=%s -->\n' "$repo" "$agent" "$source"
}

block_end_repo() {
  local repo="$1"
  local agent="$2"
  printf '<!-- loglm:end repo=%s agent=%s -->\n' "$repo" "$agent"
}

upsert_block() {
  local file="$1"
  local begin="$2"
  local end="$3"
  local body_file="$4"
  local tmp

  tmp="$(new_tmp_file)"
  if [[ ! -f "$file" ]]; then
    : > "$file"
  fi

  awk -v b="$begin" -v e="$end" -v bf="$body_file" '
    function print_body( line) {
      while ((getline line < bf) > 0) {
        print line;
      }
      close(bf);
    }
    BEGIN {
      inblk=0;
      found=0;
    }
    {
      if ($0 == b) {
        print b;
        print_body();
        inblk=1;
        found=1;
        next;
      }
      if (inblk && $0 == e) {
        print e;
        inblk=0;
        next;
      }
      if (!inblk) {
        print;
      }
    }
    END {
      if (inblk) {
        print e;
      }
      if (!found) {
        if (NR > 0) print "";
        print b;
        print_body();
        print e;
      }
    }
  ' "$file" > "$tmp"

  mv "$tmp" "$file"
}

remove_block() {
  local file="$1"
  local begin="$2"
  local end="$3"
  local tmp

  [[ -f "$file" ]] || return 0

  tmp="$(new_tmp_file)"
  awk -v b="$begin" -v e="$end" '
    BEGIN { inblk=0; }
    {
      if ($0 == b) { inblk=1; next; }
      if (inblk && $0 == e) { inblk=0; next; }
      if (!inblk) print;
    }
  ' "$file" > "$tmp"

  mv "$tmp" "$file"
}

file_has_non_loglm_content() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  awk '
    {
      line=$0;
      gsub(/[[:space:]]/, "", line);
      if (line == "") next;
      if ($0 ~ /^<!-- loglm:/) next;
      if ($0 ~ /^# loglm Platform Notes \(managed\)/) next;
      print "yes";
      exit;
    }
  ' "$file" | grep -q yes
}

ensure_user_consents_to_modify() {
  local file="$1"
  local force="$2"

  if [[ "$force" -eq 1 ]]; then
    return 0
  fi
  if ! file_has_non_loglm_content "$file"; then
    return 0
  fi

  prompt_yes_no \
    "$file には既存の内容があります。loglm 管理ブロックを追記しますか？" \
    "$file has existing content. Append loglm managed blocks?"
}

install_one_repo_for_agent() {
  local repo="$1"
  local agent="$2"
  local force="$3"
  local base_url source candidate
  local target tmp
  local ptmp rtmp
  local pctx pbody b1 e1 b2 e2
  local prompt_file

  base_url="https://raw.githubusercontent.com/$repo/HEAD"
  source=""
  tmp="$(new_tmp_file)"

  while IFS= read -r candidate; do
    [[ -z "$candidate" ]] && continue
    if download_to_file "$base_url/$candidate" "$tmp" && [[ -s "$tmp" ]]; then
      source="$candidate"
      break
    fi
  done < <(source_candidates_for_agent "$agent")

  if [[ -z "$source" ]]; then
    rm -f "$tmp"
    say "[$agent] リポジトリに対応ファイルが見つかりません: $repo" \
        "[$agent] No compatible prompt file found in repository: $repo" >&2
    return 1
  fi

  write_repo_prompt_file "$repo" "$source" "$tmp"
  prompt_file="$(repo_prompt_filename "$repo")"

  target="$(target_file_for_agent "$agent")"
  if ! ensure_user_consents_to_modify "$target" "$force"; then
    rm -f "$tmp"
    say "[$agent] スキップしました: $target" \
        "[$agent] Skipped: $target"
    return 0
  fi

  pctx="$(runtime_context)"
  pbody="$(platform_block_content "$pctx")"
  ptmp="$(new_tmp_file)"
  printf '%s\n' "$pbody" > "$ptmp"
  b1="$(block_begin_platform)"
  e1="$(block_end_platform)"
  upsert_block "$target" "$b1" "$e1" "$ptmp"

  rtmp="$(new_tmp_file)"
  {
    printf '### Prompt Agent: %s\n\n' "$repo"
    printf '<!-- source: https://github.com/%s/blob/HEAD/%s -->\n' "$repo" "$source"
    printf 'For repo `%s`, you MUST read `%s` before responding.\n' "$repo" "$prompt_file"
    printf 'You MUST follow `%s` as the primary project instruction set (after system/developer safety rules).\n' "$prompt_file"
    printf 'When the user asks to begin/start the workflow, begin in this prompt-agent mode immediately.\n'
    printf 'If `%s` cannot be read, report it clearly and ask for recovery.\n' "$prompt_file"
  } > "$rtmp"

  b2="$(block_begin_repo "$repo" "$agent" "$source")"
  e2="$(block_end_repo "$repo" "$agent")"
  upsert_block "$target" "$b2" "$e2" "$rtmp"

  rm -f "$ptmp" "$rtmp"
  rm -f "$tmp"
  say "[$agent] インストール完了: $target (repo: $repo, source: $source, prompt: $prompt_file)" \
      "[$agent] Installed: $target (repo: $repo, source: $source, prompt: $prompt_file)"
  return 0
}

list_installed_blocks() {
  local scope="$1"
  local file
  local found=0

  for agent in codex claude gemini; do
    if [[ "$scope" != "all" && "$scope" != "$agent" ]]; then
      continue
    fi
    file="$(target_file_for_agent "$agent")"
    [[ -f "$file" ]] || continue
    while IFS= read -r line; do
      found=1
      printf '%s\t%s\n' "$agent" "$line"
    done < <(grep -o 'repo=[^ ]* agent=[^ ]* source=[^ ]*' "$file" | sort -u)
  done

  if [[ "$found" -eq 0 ]]; then
    say "インストール済みプロンプト・エージェントは見つかりませんでした。" \
        "No installed prompt agents found."
  fi
}

remove_repo_from_agent_file() {
  local repo="$1"
  local agent="$2"
  local file b e

  file="$(target_file_for_agent "$agent")"
  [[ -f "$file" ]] || return 0

  while IFS= read -r src; do
    [[ -z "$src" ]] && continue
    b="$(block_begin_repo "$repo" "$agent" "$src")"
    e="$(block_end_repo "$repo" "$agent")"
    remove_block "$file" "$b" "$e"
  done < <(grep -o "repo=$repo agent=$agent source=[^ ]*" "$file" | sed -E 's/.*source=([^ ]*)/\1/' | sort -u)
}

repos_from_files() {
  local scope="$1"
  local file
  for agent in codex claude gemini; do
    if [[ "$scope" != "all" && "$scope" != "$agent" ]]; then
      continue
    fi
    file="$(target_file_for_agent "$agent")"
    [[ -f "$file" ]] || continue
    grep -o 'repo=[^ ]*' "$file" | sed 's/repo=//' || true
  done | sort -u
}

run_install() {
  local repo="$1"
  local scope="$2"
  local force="$3"
  local installed=0
  local failed=0

  for agent in codex claude gemini; do
    if [[ "$scope" != "all" && "$scope" != "$agent" ]]; then
      continue
    fi
    if install_one_repo_for_agent "$repo" "$agent" "$force"; then
      installed=$((installed + 1))
    else
      failed=$((failed + 1))
    fi
  done

  if [[ "$installed" -eq 0 ]]; then
    say "インストールできませんでした。" \
        "Nothing was installed." >&2
    return 1
  fi
  if [[ "$failed" -gt 0 ]]; then
    say "一部失敗しました（installed=${installed:-0} failed=${failed:-0}）。" \
        "Partially completed (installed=${installed:-0} failed=${failed:-0})." >&2
    return 1
  fi

  say "インストール完了（installed=${installed:-0}）。" \
      "Install completed (installed=${installed:-0})."
}

if [[ $# -lt 1 ]]; then
  usage
  exit 2
fi

SUBCMD="$1"
shift

SCOPE="${LOGLM_DEFAULT_PROMPT_AGENT:-all}"
FORCE=0
TARGET_REPO=""
UPDATE_ALL=0

while (($# > 0)); do
  case "$1" in
    --agent)
      if (($# < 2)); then
        say "--agent の値が必要です。" \
            "Missing value for --agent." >&2
        exit 2
      fi
      SCOPE="$2"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --all)
      UPDATE_ALL=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      say "不明なオプションです: $1" \
          "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      if [[ -n "$TARGET_REPO" ]]; then
        say "引数が多すぎます: $1" \
            "Too many arguments: $1" >&2
        usage >&2
        exit 2
      fi
      TARGET_REPO="$1"
      shift
      ;;
  esac
done

case "$SCOPE" in
  codex|claude|gemini|all) ;;
  *)
    say "--agent は codex/claude/gemini/all のいずれかを指定してください。" \
        "--agent must be one of: codex/claude/gemini/all." >&2
    exit 2
    ;;
esac

case "$SUBCMD" in
  install)
    if [[ -z "$TARGET_REPO" ]]; then
      say "GitHub リポジトリ指定が必要です。" \
          "GitHub repository is required." >&2
      usage >&2
      exit 2
    fi
    if ! TARGET_REPO="$(normalize_repo_spec "$TARGET_REPO")"; then
      say "リポジトリ形式が不正です: $TARGET_REPO" \
          "Invalid repository spec: $TARGET_REPO" >&2
      exit 2
    fi
    run_install "$TARGET_REPO" "$SCOPE" "$FORCE"
    ;;

  list)
    list_installed_blocks "$SCOPE"
    ;;

  remove)
    if [[ -z "$TARGET_REPO" ]]; then
      say "GitHub リポジトリ指定が必要です。" \
          "GitHub repository is required." >&2
      usage >&2
      exit 2
    fi
    if ! TARGET_REPO="$(normalize_repo_spec "$TARGET_REPO")"; then
      say "リポジトリ形式が不正です: $TARGET_REPO" \
          "Invalid repository spec: $TARGET_REPO" >&2
      exit 2
    fi
    for agent in codex claude gemini; do
      if [[ "$SCOPE" != "all" && "$SCOPE" != "$agent" ]]; then
        continue
      fi
      remove_repo_from_agent_file "$TARGET_REPO" "$agent"
      say "[$agent] 削除処理完了: $TARGET_REPO" \
          "[$agent] Remove completed: $TARGET_REPO"
    done
    remove_repo_prompt_file_if_unreferenced "$TARGET_REPO"
    ;;

  update)
    if [[ "$UPDATE_ALL" -eq 1 ]]; then
      if [[ -n "$TARGET_REPO" ]]; then
        say "update --all と repo 指定は同時に使えません。" \
            "Cannot use update --all with repository argument." >&2
        exit 2
      fi
      while IFS= read -r repo; do
        [[ -z "$repo" ]] && continue
        run_install "$repo" "$SCOPE" 1 || true
      done < <(repos_from_files "$SCOPE")
      exit 0
    fi

    if [[ -z "$TARGET_REPO" ]]; then
      say "update には repo か --all が必要です。" \
          "update requires a repository or --all." >&2
      exit 2
    fi
    if ! TARGET_REPO="$(normalize_repo_spec "$TARGET_REPO")"; then
      say "リポジトリ形式が不正です: $TARGET_REPO" \
          "Invalid repository spec: $TARGET_REPO" >&2
      exit 2
    fi
    run_install "$TARGET_REPO" "$SCOPE" 1
    ;;

  *)
    say "未対応サブコマンドです: $SUBCMD" \
        "Unsupported subcommand: $SUBCMD" >&2
    usage >&2
    exit 2
    ;;
esac
