#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

revision_file="${1:-/etc/nixos/.source-revision}"
repo="${2:-${HOME:-}/nixos-hyprland-vfio}"

[[ -f "$revision_file" && -s "$revision_file" ]] ||
  fail "Required source revision record is missing or empty: $revision_file"

revision="$(tr -d '[:space:]' < "$revision_file")" ||
  fail "Could not read source revision record: $revision_file"

[[ "$revision" =~ ^[0-9a-f]{40}$ ]] ||
  fail "Source revision record does not contain a full 40-character commit SHA: $revision_file"

git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
  fail "Source directory is not a Git checkout: $repo"

current_revision="$(git -C "$repo" rev-parse --verify 'HEAD^{commit}')" ||
  fail "Could not resolve HEAD in source checkout: $repo"

[[ "$current_revision" == "$revision" ]] ||
  fail "Installed configuration is pinned to $revision but $repo is at $current_revision"

if ! status="$(git -C "$repo" status --porcelain --untracked-files=all)"; then
  fail "Could not inspect the working-tree state in $repo"
fi
[[ -z "$status" ]] ||
  fail "Source checkout has local or untracked changes; use a clean checkout of $revision"

printf 'Source revision verified: %s\n' "$revision"
