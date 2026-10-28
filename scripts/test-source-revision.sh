#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
HELPER="$ROOT/scripts/verify-source-revision.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TMP_DIR"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

expect_failure() {
  local label="$1"
  shift
  if "$@" >"$TMP_DIR/stdout" 2>"$TMP_DIR/stderr"; then
    fail "source revision verifier accepted $label"
  fi
  printf 'OK: rejected %s\n' "$label"
}

TEST_REPO="$TMP_DIR/repo"
MARKER="$TMP_DIR/source-revision"
mkdir -p "$TEST_REPO"
git init -q "$TEST_REPO"
git -C "$TEST_REPO" config user.name "Source Revision Test"
git -C "$TEST_REPO" config user.email "source-revision-test@example.invalid"
printf 'base\n' > "$TEST_REPO/tracked.txt"
git -C "$TEST_REPO" add tracked.txt
git -C "$TEST_REPO" commit -q -m "base revision"
BASE_REVISION="$(git -C "$TEST_REPO" rev-parse --verify 'HEAD^{commit}')"
printf '%s\n' "$BASE_REVISION" > "$MARKER"

bash "$HELPER" "$MARKER" "$TEST_REPO" >/dev/null ||
  fail "clean checkout at the recorded revision was rejected"
expect_failure "a missing marker" bash "$HELPER" "$TMP_DIR/missing-marker" "$TEST_REPO"

printf 'not-a-commit\n' > "$MARKER"
expect_failure "a malformed revision" bash "$HELPER" "$MARKER" "$TEST_REPO"
printf '%s\n' "$BASE_REVISION" > "$MARKER"

printf 'second\n' >> "$TEST_REPO/tracked.txt"
git -C "$TEST_REPO" add tracked.txt
git -C "$TEST_REPO" commit -q -m "different revision"
expect_failure "a mismatched HEAD" bash "$HELPER" "$MARKER" "$TEST_REPO"
git -C "$TEST_REPO" reset -q --hard "$BASE_REVISION"

printf 'local edit\n' >> "$TEST_REPO/tracked.txt"
expect_failure "a modified tracked file" bash "$HELPER" "$MARKER" "$TEST_REPO"
git -C "$TEST_REPO" checkout -q -- tracked.txt

printf 'untracked\n' > "$TEST_REPO/untracked.txt"
expect_failure "an untracked file" bash "$HELPER" "$MARKER" "$TEST_REPO"
rm -f -- "$TEST_REPO/untracked.txt"

bash "$HELPER" "$MARKER" "$TEST_REPO" >/dev/null ||
  fail "clean checkout was not accepted after removing test changes"

printf 'OK: source revision provenance regression tests passed.\n'
