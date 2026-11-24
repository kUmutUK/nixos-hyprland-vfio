#!/usr/bin/env bash
# Mock-backed host profile tests; never change the active host policy.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
BIN="$TMP/bin"
mkdir -p "$BIN"
export PROFILE_TEST_LOG="$TMP/commands.log"
export HOST_PROFILE_STATE_DIR="$TMP/state"
: > "$PROFILE_TEST_LOG"

cat > "$BIN/powerprofilesctl" <<'STUB'
#!/usr/bin/env bash
printf 'ppd %s\n' "$*" >> "$PROFILE_TEST_LOG"
STUB
cat > "$BIN/scxctl" <<'STUB'
#!/usr/bin/env bash
printf 'scx %s\n' "$*" >> "$PROFILE_TEST_LOG"
STUB
chmod +x "$BIN/"*

PATH="$BIN:$PATH" bash "$ROOT/scripts/host-profile.sh" desktop >/dev/null
grep -qx 'ppd set balanced' "$PROFILE_TEST_LOG" || { echo "desktop must select balanced PPD" >&2; exit 1; }
grep -qx 'scx restore' "$PROFILE_TEST_LOG" || { echo "desktop must restore scx-loader default" >&2; exit 1; }

: > "$PROFILE_TEST_LOG"
PATH="$BIN:$PATH" bash "$ROOT/scripts/host-profile.sh" low-latency >/dev/null
grep -qx 'ppd set performance' "$PROFILE_TEST_LOG"
grep -qx 'scx switch --mode lowlatency' "$PROFILE_TEST_LOG"

: > "$PROFILE_TEST_LOG"
PATH="$BIN:$PATH" bash "$ROOT/scripts/host-profile.sh" game-start >/dev/null
grep -qx 'scx switch --mode gaming' "$PROFILE_TEST_LOG"
grep -qx 'ppd set performance' "$PROFILE_TEST_LOG"
[ "$(cat "$HOST_PROFILE_STATE_DIR/game-return")" = "low-latency" ]

: > "$PROFILE_TEST_LOG"
PATH="$BIN:$PATH" bash "$ROOT/scripts/host-profile.sh" game-end >/dev/null
grep -qx 'scx switch --mode lowlatency' "$PROFILE_TEST_LOG"
grep -qx 'ppd set performance' "$PROFILE_TEST_LOG"
[ "$(cat "$HOST_PROFILE_STATE_DIR/current")" = "low-latency" ]
[ ! -e "$HOST_PROFILE_STATE_DIR/game-return" ]

echo "OK: host profile routing and GameMode restore passed."
