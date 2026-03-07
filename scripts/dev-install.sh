#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/dev-install.sh [--branch <name>] [--repo <owner/repo>] [--print-only]

Behavior:
  - Installs loglm from GitHub raw URL for the selected branch.
  - Defaults to current git branch and origin repo.

Options:
  --branch <name>      Branch name (default: current branch)
  --repo <owner/repo>  GitHub repository (default: detected from origin)
  --print-only         Print resolved REPO_RAW_BASE and exit
  -h, --help           Show help
USAGE
}

detect_repo_from_origin() {
  local origin
  origin="$(git -C "$ROOT_DIR" remote get-url origin 2>/dev/null || true)"
  if [[ -z "$origin" ]]; then
    return 1
  fi

  case "$origin" in
    git@github.com:*.git)
      printf '%s\n' "${origin#git@github.com:}" | sed 's/\.git$//'
      ;;
    git@github.com:*)
      printf '%s\n' "${origin#git@github.com:}"
      ;;
    https://github.com/*.git)
      printf '%s\n' "${origin#https://github.com/}" | sed 's/\.git$//'
      ;;
    https://github.com/*)
      printf '%s\n' "${origin#https://github.com/}"
      ;;
    *)
      return 1
      ;;
  esac
}

BRANCH=""
REPO=""
PRINT_ONLY=0

while (($# > 0)); do
  case "$1" in
    --branch)
      if (($# < 2)); then
        echo "error: missing value for --branch" >&2
        exit 2
      fi
      BRANCH="$2"
      shift 2
      ;;
    --repo)
      if (($# < 2)); then
        echo "error: missing value for --repo" >&2
        exit 2
      fi
      REPO="$2"
      shift 2
      ;;
    --print-only)
      PRINT_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$BRANCH" ]]; then
  BRANCH="$(git -C "$ROOT_DIR" rev-parse --abbrev-ref HEAD)"
fi

if [[ -z "$REPO" ]]; then
  if ! REPO="$(detect_repo_from_origin)"; then
    REPO="ks91/loglm"
  fi
fi

if [[ ! "$REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
  echo "error: invalid repo format: $REPO" >&2
  exit 2
fi

REPO_RAW_BASE="https://raw.githubusercontent.com/$REPO/$BRANCH"

echo "REPO_RAW_BASE=$REPO_RAW_BASE"

if [[ "$PRINT_ONLY" -eq 1 ]]; then
  exit 0
fi

REPO_RAW_BASE="$REPO_RAW_BASE" bash "$ROOT_DIR/install.sh"
