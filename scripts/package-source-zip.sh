#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(git rev-parse --show-toplevel)"
commit="$(git -C "$repo_root" rev-parse --verify 'HEAD^{commit}')"
output="${1:-$repo_root/nixos-hyprland-vfio-source.zip}"

case "$output" in
  /*) ;;
  *) output="$PWD/$output" ;;
esac

output_dir="$(dirname -- "$output")"
mkdir -p -- "$output_dir"
tmp_archive="$(mktemp "${output}.tmp.XXXXXX")"
trap 'rm -f -- "$tmp_archive"' EXIT

if ! git -C "$repo_root" diff --quiet HEAD --; then
  echo "WARNING: packaging committed HEAD ($commit); uncommitted tracked changes are excluded." >&2
fi

git -C "$repo_root" archive \
  --format=zip \
  --prefix=nixos-hyprland-vfio/ \
  --output="$tmp_archive" \
  "$commit"

python3 - "$tmp_archive" "$repo_root" "$commit" <<'PY'
import copy
import os
import subprocess
import sys
import zipfile
from pathlib import PurePosixPath

archive_path, repo_root, commit = sys.argv[1:]
prefix = "nixos-hyprland-vfio/"

tracked_output = subprocess.run(
    ["git", "-C", repo_root, "ls-tree", "-r", "-z", "--full-tree", commit],
    check=True,
    stdout=subprocess.PIPE,
).stdout
tracked_files: set[str] = set()
tracked_executables: set[str] = set()
for record in tracked_output.split(b"\0"):
    if not record:
        continue
    metadata, path_bytes = record.split(b"\t", 1)
    mode = metadata.split(b" ", 1)[0].decode("ascii")
    # A gitlink points to a submodule commit; it is not a regular archive file.
    if mode == "160000":
        continue
    path = path_bytes.decode("utf-8", errors="surrogateescape")
    archive_name = prefix + path
    tracked_files.add(archive_name)
    if mode == "100755":
        tracked_executables.add(archive_name)

expected_executables = {
    prefix + path
    for path in (
        "install.sh",
        "nixos/hosts/nixos/hooks/qemu",
        "scripts/package-source-zip.sh",
        "scripts/test-installer-invariants.sh",
        "scripts/test-installer-rollback.sh",
        "scripts/test-manual-vm-bootstrap.sh",
        "scripts/test-source-revision.sh",
        "scripts/test-vfio-hook-driver-state.sh",
        "scripts/verify-source-revision.sh",
    )
}
if tracked_executables != expected_executables:
    missing_executables = sorted(expected_executables - tracked_executables)
    unexpected_executables = sorted(tracked_executables - expected_executables)
    if missing_executables:
        print("Missing tracked executable mode (expected 100755):", *missing_executables, sep="\n  ", file=sys.stderr)
    if unexpected_executables:
        print("Unexpected tracked executable mode (expected 100644):", *unexpected_executables, sep="\n  ", file=sys.stderr)
    raise SystemExit("ERROR: tracked executable-mode set differs from canonical packaging policy.")

# Python's zipfile sees ordinary git-archive ZIP entries as DOS-origin files
# even though Git tracks their Unix modes. Rewrite metadata for every entry so
# consumers on Unix receive explicit regular-file/executable permission bits.
normalized_path = archive_path + ".normalized"
try:
    with zipfile.ZipFile(archive_path, "r") as original:
        with zipfile.ZipFile(normalized_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as normalized:
            for source_entry in original.infolist():
                entry = copy.copy(source_entry)
                entry.create_system = 3
                if entry.is_dir():
                    entry.external_attr = (0o40755 << 16) | 0x10
                else:
                    expected_mode = 0o755 if entry.filename in tracked_executables else 0o644
                    file_mode = 0o100000 | expected_mode
                    entry.external_attr = file_mode << 16
                normalized.writestr(entry, original.read(source_entry.filename), compress_type=source_entry.compress_type, compresslevel=9)
    os.replace(normalized_path, archive_path)
finally:
    if os.path.exists(normalized_path):
        os.unlink(normalized_path)

with zipfile.ZipFile(archive_path, "r") as bundle:
    corrupt_entry = bundle.testzip()
    if corrupt_entry is not None:
        raise SystemExit(f"ERROR: corrupt ZIP entry: {corrupt_entry}")

    entries = bundle.infolist()
    names = {entry.filename for entry in entries}
    revision_name = prefix + "SOURCE_REVISION"
    if revision_name not in names:
        raise SystemExit("ERROR: source ZIP is missing its embedded SOURCE_REVISION identity.")
    try:
        archived_revision = bundle.read(revision_name).decode("ascii").strip()
    except (UnicodeDecodeError, KeyError) as error:
        raise SystemExit("ERROR: source ZIP has an invalid embedded SOURCE_REVISION identity.") from error
    if archived_revision != commit:
        raise SystemExit(
            "ERROR: source ZIP SOURCE_REVISION does not match the packaged commit "
            f"({archived_revision!r} != {commit!r})."
        )

    if any(".git" in PurePosixPath(name).parts for name in names):
        raise SystemExit("ERROR: source ZIP must not include .git metadata.")

    archived_files = {entry.filename for entry in entries if not entry.is_dir()}
    missing = sorted(tracked_files - archived_files)
    extra = sorted(archived_files - tracked_files)
    if missing or extra:
        if missing:
            print("Missing tracked files:", *missing, sep="\n  ", file=sys.stderr)
        if extra:
            print("Unexpected archive files:", *extra, sep="\n  ", file=sys.stderr)
        raise SystemExit("ERROR: ZIP contents do not match the committed source tree.")

    entries_by_name = {entry.filename: entry for entry in entries}
    for name in sorted(tracked_files):
        entry = entries_by_name[name]
        mode = (entry.external_attr >> 16) & 0o777
        expected_mode = 0o755 if name in tracked_executables else 0o644
        if entry.create_system != 3 or mode != expected_mode:
            raise SystemExit(
                "ERROR: ZIP has non-canonical Unix permission metadata: "
                f"{name} (create_system={entry.create_system}, "
                f"mode={mode:04o}, expected={expected_mode:04o})."
            )

print(
    f"Validated source ZIP for {commit}: {len(tracked_files)} tracked files, "
    f"{len(tracked_executables)} executable files; .git excluded."
)
PY

# A source archive is a distributable artifact, not a secret: make it readable
# by other users/services that may collect it from a shared output directory.
chmod 0644 -- "$tmp_archive"
mv -f -- "$tmp_archive" "$output"
trap - EXIT
printf 'Source ZIP created: %s\n' "$output"
