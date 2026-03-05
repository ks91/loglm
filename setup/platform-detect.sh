#!/usr/bin/env bash

set -euo pipefail

detect_platform() {
  if [[ -n "${LOGLM_PLATFORM:-}" ]]; then
    printf '%s\n' "$LOGLM_PLATFORM"
    return
  fi

  local os
  os="$(uname -s)"

  if [[ "$os" == "Darwin" ]]; then
    printf '%s\n' "macos"
    return
  fi

  if [[ "$os" != "Linux" ]]; then
    printf '%s\n' "unknown"
    return
  fi

  if grep -qi microsoft /proc/version 2>/dev/null; then
    printf '%s\n' "wsl2"
    return
  fi

  if grep -qi chromeos /proc/version 2>/dev/null; then
    printf '%s\n' "chromeos"
    return
  fi

  if [[ -r /etc/lsb-release ]] && grep -qi chromeos /etc/lsb-release 2>/dev/null; then
    printf '%s\n' "chromeos"
    return
  fi

  if [[ -r /proc/device-tree/model ]] && grep -qi raspberry /proc/device-tree/model 2>/dev/null; then
    printf '%s\n' "raspberrypi"
    return
  fi

  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    if [[ "${ID:-}" == "ubuntu" ]] || [[ "${ID_LIKE:-}" == *ubuntu* ]]; then
      printf '%s\n' "ubuntu"
      return
    fi
    if [[ "${ID:-}" == "raspbian" ]]; then
      printf '%s\n' "raspberrypi"
      return
    fi
  fi

  printf '%s\n' "linux"
}

platform_label() {
  case "$1" in
    macos) printf '%s\n' "macOS" ;;
    ubuntu) printf '%s\n' "Ubuntu" ;;
    wsl2) printf '%s\n' "Ubuntu on WSL2" ;;
    raspberrypi) printf '%s\n' "Raspberry Pi OS" ;;
    chromeos) printf '%s\n' "Chrome OS (Linux container)" ;;
    linux) printf '%s\n' "Linux (generic)" ;;
    *) printf '%s\n' "Unknown" ;;
  esac
}
