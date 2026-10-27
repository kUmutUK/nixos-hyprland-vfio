#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$ROOT/scripts/installer-lock.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TMP_DIR"' EXIT

mkdir -m 700 -- "$TMP_DIR/runtime" "$TMP_DIR/home"
export XDG_RUNTIME_DIR="$TMP_DIR/runtime"
export HOME="$TMP_DIR/home"

# shellcheck source=scripts/installer-lock.sh
source "$HELPER"
if ! acquire_nixos_installer_lock; then
  printf 'FAIL: first installer process could not acquire its lock.\n' >&2
  exit 1
fi

LOCK_FILE="$XDG_RUNTIME_DIR/nixos-hyprland-vfio-install.lock"
mode="$(stat -c '%a' -- "$LOCK_FILE")"
if [[ "$mode" != 600 ]]; then
  printf 'FAIL: lock file permissions are %s rather than 600.\n' "$mode" >&2
  exit 1
fi

# A concurrent process must be rejected while descriptor 9 holds the same lock.
if bash -c 'set -euo pipefail; source "$1"; acquire_nixos_installer_lock' bash "$HELPER" >/dev/null 2>&1; then
  printf 'FAIL: a second installer process acquired an already-held lock.\n' >&2
  exit 1
fi

# Once the first lock is released, a subsequent run must be able to acquire it.
exec 9>&-
if ! bash -c 'set -euo pipefail; source "$1"; acquire_nixos_installer_lock' bash "$HELPER"; then
  printf 'FAIL: installer lock remained unavailable after the first process released it.\n' >&2
  exit 1
fi

printf 'OK: installer lock rejects concurrent runs and releases cleanly.\n'
