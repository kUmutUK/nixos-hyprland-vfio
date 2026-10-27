#!/usr/bin/env bash
# Sourced by install.sh. The lock is per login user and lives in the user's runtime
# directory (or a private cache fallback), so it needs no privilege escalation.
# File descriptor 9 remains open for the lifetime of the installer shell.

acquire_nixos_installer_lock() {
  local lock_dir lock_file

  if ! command -v flock >/dev/null 2>&1; then
    printf 'ERROR: flock is required to prevent concurrent installer runs.\n' >&2
    return 1
  fi

  if [[ -n "${XDG_RUNTIME_DIR:-}" \
    && -d "$XDG_RUNTIME_DIR" \
    && ! -L "$XDG_RUNTIME_DIR" \
    && -O "$XDG_RUNTIME_DIR" ]]; then
    lock_dir="$XDG_RUNTIME_DIR"
  else
    lock_dir="$HOME/.cache/nixos-hyprland-vfio"
    if [[ -L "$lock_dir" ]]; then
      printf 'ERROR: Refusing a symlinked installer lock directory: %s\n' "$lock_dir" >&2
      return 1
    fi
    if ! mkdir -p -- "$lock_dir"; then
      printf 'ERROR: Could not create installer lock directory: %s\n' "$lock_dir" >&2
      return 1
    fi
    if [[ ! -d "$lock_dir" || -L "$lock_dir" || ! -O "$lock_dir" ]]; then
      printf 'ERROR: Installer lock directory must be a real directory owned by this user: %s\n' "$lock_dir" >&2
      return 1
    fi
    if ! chmod 700 -- "$lock_dir"; then
      printf 'ERROR: Could not secure installer lock directory: %s\n' "$lock_dir" >&2
      return 1
    fi
  fi

  lock_file="$lock_dir/nixos-hyprland-vfio-install.lock"
  if [[ -L "$lock_file" || ( -e "$lock_file" && ! -f "$lock_file" ) ]]; then
    printf 'ERROR: Refusing an unsafe installer lock path: %s\n' "$lock_file" >&2
    return 1
  fi
  if ! (umask 077; : >> "$lock_file"); then
    printf 'ERROR: Could not create installer lock file: %s\n' "$lock_file" >&2
    return 1
  fi
  if [[ -L "$lock_file" || ! -f "$lock_file" || ! -O "$lock_file" ]]; then
    printf 'ERROR: Installer lock file must be a regular file owned by this user: %s\n' "$lock_file" >&2
    return 1
  fi
  if ! chmod 600 -- "$lock_file"; then
    printf 'ERROR: Could not secure installer lock file: %s\n' "$lock_file" >&2
    return 1
  fi

  # The lock is non-blocking: a second run exits before prompts, backups, or system writes.
  exec 9> "$lock_file" || {
    printf 'ERROR: Could not open installer lock file: %s\n' "$lock_file" >&2
    return 1
  }
  if ! flock -n 9; then
    printf 'ERROR: Another install.sh process is already running for this user. No system files were changed.\n' >&2
    return 1
  fi
}
