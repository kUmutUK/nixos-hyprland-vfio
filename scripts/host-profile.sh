#!/usr/bin/env bash
# Coordinate the existing PPD and scx-loader controls without adding a second daemon.
set -euo pipefail

STATE_DIR="${HOST_PROFILE_STATE_DIR:-/run/kumutuk-host-profile}"
PROFILE_FILE="$STATE_DIR/current"
GAME_RETURN_FILE="$STATE_DIR/game-return"
LOCK_FILE="$STATE_DIR/lock"

mkdir -p "$STATE_DIR"
exec 9>"$LOCK_FILE"
flock -x 9

current_profile() {
  if [[ -r "$PROFILE_FILE" ]]; then
    IFS= read -r PROFILE < "$PROFILE_FILE" || PROFILE=desktop
  else
    PROFILE=desktop
  fi
}

apply_profile() {
  local profile="$1"
  case "$profile" in
    desktop)
      powerprofilesctl set balanced
      scxctl restore
      ;;
    gaming)
      powerprofilesctl set performance
      scxctl switch --mode gaming
      ;;
    low-latency)
      powerprofilesctl set performance
      scxctl switch --mode lowlatency
      ;;
    vm)
      powerprofilesctl set performance
      scxctl switch --mode server
      ;;
    *)
      echo "Unknown profile: $profile" >&2
      return 2
      ;;
  esac
}

set_profile() {
  local requested="$1" previous
  current_profile
  previous="$PROFILE"
  if ! apply_profile "$requested"; then
    echo "Profile switch failed; restoring $previous." >&2
    apply_profile "$previous" || true
    return 1
  fi
  printf '%s\n' "$requested" > "$PROFILE_FILE"
  printf 'Active profile: %s\n' "$requested"
}

case "${1:-}" in
  desktop|gaming|low-latency|vm)
    set_profile "$1"
    ;;
  game-start)
    current_profile
    if [[ ! -e "$GAME_RETURN_FILE" ]]; then
      printf '%s\n' "$PROFILE" > "$GAME_RETURN_FILE"
    fi
    if apply_profile gaming; then
      printf 'gaming\n' > "$PROFILE_FILE"
      echo "GameMode entered the gaming profile."
    else
      apply_profile "$PROFILE" || true
      rm -f -- "$GAME_RETURN_FILE"
      echo "GameMode could not enter the gaming profile." >&2
      exit 1
    fi
    ;;
  game-end)
    if [[ -r "$GAME_RETURN_FILE" ]]; then
      IFS= read -r RETURN_PROFILE < "$GAME_RETURN_FILE" || RETURN_PROFILE=desktop
    else
      RETURN_PROFILE=desktop
    fi
    set_profile "$RETURN_PROFILE"
    rm -f -- "$GAME_RETURN_FILE"
    ;;
  status)
    current_profile
    printf 'Profile: %s\n' "$PROFILE"
    scxctl get
    powerprofilesctl get
    ;;
  *)
    echo "Usage: host-profile {desktop|gaming|low-latency|vm|game-start|game-end|status}" >&2
    exit 2
    ;;
esac
