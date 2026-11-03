#!/usr/bin/env python3
"""OptiScaler manager for explicit, per-game Proton installations.

No system-wide installation, Steam launch-option editing, or background updater.
Only official stable releases are considered. Archives are verified before extraction.
"""

from __future__ import annotations

import argparse
from contextlib import contextmanager
import fcntl
import hashlib
import json
import os
from pathlib import Path, PurePosixPath, PureWindowsPath
import re
import shutil
import stat
import subprocess
import sys
import tempfile
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse
from urllib.request import Request, urlopen

API_URL = "https://api.github.com/repos/optiscaler/OptiScaler/releases/latest"
USER_AGENT = "nixos-hyprland-vfio-optiscaler-manager/1.0"
MAX_ARCHIVE_BYTES = 2 * 1024 * 1024 * 1024
MAX_EXTRACTED_BYTES = 4 * 1024 * 1024 * 1024
MAX_ARCHIVE_FILES = 20_000
SUPPORTED_PROXIES = {
    "dxgi.dll", "winmm.dll", "d3d12.dll", "dbghelp.dll",
    "version.dll", "wininet.dll", "winhttp.dll",
}
PINNED_SHA256 = {
    ("v0.9.4", "Optiscaler_0.9.4-final.20260718._MM.7z"):
        "575cb4df866116093df75af607e37fd70e10f5163e0f23fd5c804142e80ef0ad",
}


class ManagerError(Exception):
    """An expected, user-actionable manager error."""


def cache_root() -> Path:
    base = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
    return base / "optiscaler-manager"


def state_root() -> Path:
    base = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
    return base / "optiscaler-manager"


@contextmanager
def game_operation_lock(game_dir: Path):
    """Serialize manager operations for one game directory without blocking indefinitely."""
    lock_root = state_root() / "locks"
    descriptor: int | None = None
    locked = False
    try:
        try:
            lock_root.mkdir(parents=True, exist_ok=True, mode=0o700)
            root_info = lock_root.lstat()
            if not stat.S_ISDIR(root_info.st_mode) or root_info.st_uid != os.getuid():
                raise ManagerError(f"Per-game lock directory is not a user-owned directory: {lock_root}")
            os.chmod(lock_root, 0o700)

            lock_path = lock_root / f"{game_identity(game_dir)}.lock"
            flags = os.O_CREAT | os.O_RDWR
            flags |= getattr(os, "O_CLOEXEC", 0)
            flags |= getattr(os, "O_NOFOLLOW", 0)
            descriptor = os.open(lock_path, flags, 0o600)
            lock_info = os.fstat(descriptor)
            if (
                not stat.S_ISREG(lock_info.st_mode)
                or lock_info.st_uid != os.getuid()
                or lock_info.st_nlink != 1
            ):
                raise ManagerError(f"Per-game lock file is not a private regular file: {lock_path}")
            os.fchmod(descriptor, 0o600)
        except OSError as exc:
            raise ManagerError(f"Could not prepare the per-game operation lock: {exc}") from exc

        try:
            fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as exc:
            raise ManagerError(
                f"Another OptiScaler Manager operation is already running for {game_dir}. "
                "Let it finish before retrying."
            ) from exc
        except OSError as exc:
            raise ManagerError(f"Could not acquire the per-game operation lock: {exc}") from exc
        locked = True
        yield
    finally:
        if descriptor is not None:
            try:
                if locked:
                    fcntl.flock(descriptor, fcntl.LOCK_UN)
            except OSError:
                # Closing the descriptor below also releases the advisory lock.
                pass
            finally:
                os.close(descriptor)


def request_json(url: str) -> dict:
    request = Request(url, headers={
        "Accept": "application/vnd.github+json",
        "User-Agent": USER_AGENT,
        "X-GitHub-Api-Version": "2022-11-28",
    })
    try:
        with urlopen(request, timeout=30) as response:
            data = response.read(8 * 1024 * 1024 + 1)
    except (HTTPError, URLError, TimeoutError) as exc:
        raise ManagerError(f"GitHub release lookup failed: {exc}") from exc
    if len(data) > 8 * 1024 * 1024:
        raise ManagerError("GitHub release metadata exceeded the 8 MiB safety limit.")
    try:
        value = json.loads(data)
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ManagerError("GitHub returned invalid release metadata.") from exc
    if not isinstance(value, dict):
        raise ManagerError("GitHub returned an unexpected release metadata shape.")
    return value


def stable_release() -> tuple[dict, dict]:
    release = request_json(API_URL)
    tag = release.get("tag_name", "")
    if release.get("draft") or release.get("prerelease"):
        raise ManagerError("The latest release endpoint returned a draft or prerelease.")
    if not re.fullmatch(r"v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", tag):
        raise ManagerError(f"Refusing non-stable or unexpected release tag: {tag!r}")
    assets = release.get("assets", [])
    candidates = [
        asset for asset in assets
        if isinstance(asset, dict)
        and str(asset.get("name", "")).lower().startswith("optiscaler_")
        and str(asset.get("name", "")).lower().endswith(".7z")
    ]
    if len(candidates) != 1:
        raise ManagerError(
            f"Expected exactly one official OptiScaler .7z asset for {tag}; "
            f"found {len(candidates)}."
        )
    asset = candidates[0]
    parsed = urlparse(asset.get("browser_download_url", ""))
    if parsed.scheme != "https" or parsed.hostname != "github.com":
        raise ManagerError("The release asset URL is not an HTTPS github.com URL.")
    size = asset.get("size")
    if not isinstance(size, int) or size <= 0 or size > MAX_ARCHIVE_BYTES:
        raise ManagerError("The release asset has an invalid or excessive advertised size.")
    return release, asset


def expected_digest(tag: str, asset: dict, override: str | None = None) -> str:
    asset_name = str(asset.get("name", ""))
    api_digest = asset.get("digest")
    if isinstance(api_digest, str) and re.fullmatch(r"sha256:[0-9a-fA-F]{64}", api_digest):
        trusted = api_digest.split(":", 1)[1].lower()
    else:
        trusted = PINNED_SHA256.get((tag, asset_name))
    if override is not None:
        supplied = override.lower().removeprefix("sha256:")
        if not re.fullmatch(r"[0-9a-f]{64}", supplied):
            raise ManagerError("--sha256 must contain exactly 64 hexadecimal characters.")
        if trusted is not None and supplied != trusted:
            raise ManagerError("--sha256 conflicts with the trusted release digest.")
        trusted = supplied
    if trusted is None:
        raise ManagerError(
            f"No trusted SHA-256 is available for {tag} ({asset_name}). "
            "Refusing to download or install it. Verify the checksum from the "
            "official release and pass it explicitly with --sha256."
        )
    return trusted


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def download_release(sha256_override: str | None = None) -> tuple[Path, str, str]:
    release, asset = stable_release()
    tag = release["tag_name"]
    digest = expected_digest(tag, asset, sha256_override)
    name = asset["name"]
    destination_dir = cache_root() / tag
    destination_dir.mkdir(parents=True, exist_ok=True)
    destination = destination_dir / name
    if destination.is_file() and sha256_file(destination) == digest:
        return destination, tag, name
    if destination.exists() or destination.is_symlink():
        destination.unlink()
    partial = destination.with_name(destination.name + ".part")
    if partial.exists() or partial.is_symlink():
        partial.unlink()

    request = Request(asset["browser_download_url"], headers={
        "User-Agent": USER_AGENT,
        "Accept": "application/octet-stream",
    })
    total = 0
    digest_builder = hashlib.sha256()
    try:
        with urlopen(request, timeout=60) as response, partial.open("xb") as output:
            while True:
                block = response.read(1024 * 1024)
                if not block:
                    break
                total += len(block)
                if total > MAX_ARCHIVE_BYTES:
                    raise ManagerError("Download exceeded the 2 GiB safety limit.")
                digest_builder.update(block)
                output.write(block)
    except ManagerError:
        partial.unlink(missing_ok=True)
        raise
    except (HTTPError, URLError, TimeoutError, OSError) as exc:
        partial.unlink(missing_ok=True)
        raise ManagerError(f"OptiScaler download failed: {exc}") from exc
    if total != asset["size"]:
        partial.unlink(missing_ok=True)
        raise ManagerError(
            f"Downloaded size ({total}) does not match GitHub's advertised size "
            f"({asset['size']})."
        )
    actual = digest_builder.hexdigest()
    if actual != digest:
        partial.unlink(missing_ok=True)
        raise ManagerError(
            f"SHA-256 mismatch for {name}: expected {digest}, received {actual}. "
            "The archive was discarded."
        )
    os.replace(partial, destination)
    return destination, tag, name


def validate_archive_member(name: str) -> str:
    normalized = name.replace("\\", "/")
    windows_path = PureWindowsPath(name)
    posix_path = PurePosixPath(normalized)
    if (
        not normalized
        or normalized.startswith("/")
        or windows_path.is_absolute()
        or windows_path.drive
        or any(part == ".." for part in posix_path.parts)
    ):
        raise ManagerError(f"Unsafe path in release archive: {name!r}")
    clean = [part for part in posix_path.parts if part not in ("", ".")]
    if not clean:
        raise ManagerError(f"Invalid empty path in release archive: {name!r}")
    return "/".join(clean)


def find_7z() -> str:
    for candidate in ("7zz", "7z"):
        found = shutil.which(candidate)
        if found:
            return found
    raise ManagerError(
        "7-Zip was not found. On NixOS, open a temporary shell with "
        "nix shell nixpkgs#p7zip and retry."
    )


def parse_archive_listing(stdout: str, archive: Path) -> tuple[list[str], int]:
    """Validate archive member paths/types/sizes before starting extraction."""
    records: list[dict[str, str]] = []
    current: dict[str, str] = {}
    for line in stdout.splitlines():
        stripped = line.strip()
        if not stripped or stripped == "----------":
            if current:
                records.append(current)
                current = {}
            continue
        if " = " not in line:
            continue
        key, value = line.split(" = ", 1)
        if key in current:
            raise ManagerError(f"7-Zip returned duplicate {key!r} metadata for one archive entry.")
        current[key] = value
    if current:
        records.append(current)
    members: list[str] = []
    seen_paths: set[str] = set()
    total_size = 0
    for record in records:
        name = record.get("Path")
        if name is None:
            if "Size" in record:
                raise ManagerError("7-Zip returned a member without a path; refusing extraction.")
            continue
        if name == str(archive) and "Size" not in record:
            continue
        normalized = validate_archive_member(name)
        if normalized in seen_paths:
            raise ManagerError(f"Archive contains duplicate normalized path {normalized!r}.")
        seen_paths.add(normalized)
        attributes = record.get("Attributes", "")
        unix_modes = re.findall(r"(?<!\S)([bcdlps-][rwxstST-]{9})(?!\S)", attributes)
        metadata_link = any(key in record for key in ("Symbolic Link", "Hard Link", "Reparse Point"))
        type_name = record.get("Type", "").strip().lower()
        link_type = type_name in {"symbolic link", "hard link", "junction", "reparse point"}
        special_type = any(mode[0] not in {"-", "d"} for mode in unix_modes)
        if metadata_link or link_type or special_type:
            raise ManagerError(
                f"Archive member {name!r} is a symbolic link, hard link, reparse point, "
                "or special file; refusing extraction."
            )
        size_text = record.get("Size")
        if size_text is None or not re.fullmatch(r"[0-9]+", size_text):
            raise ManagerError("7-Zip listing omitted or duplicated uncompressed member sizes; refusing extraction.")
        total_size += int(size_text)
        if total_size > MAX_EXTRACTED_BYTES:
            raise ManagerError("Archive advertises more than the 4 GiB extracted-size safety limit; refusing to extract it.")
        members.append(normalized)
    if not members or len(members) > MAX_ARCHIVE_FILES:
        raise ManagerError("Archive file count is empty or exceeds the safety limit.")
    return members, total_size

def extract_payload(archive: Path, proxy_name: str) -> tuple[tempfile.TemporaryDirectory, dict[str, Path]]:
    extractor = find_7z()
    listing = subprocess.run(
        [extractor, "l", "-slt", "-ba", str(archive)],
        check=False, capture_output=True, text=True,
    )
    if listing.returncode != 0:
        raise ManagerError("7-Zip could not list the verified OptiScaler archive.")
    members, _ = parse_archive_listing(listing.stdout, archive)


    temporary = tempfile.TemporaryDirectory(prefix="optiscaler-manager-")
    stage = Path(temporary.name)
    result = subprocess.run(
        [extractor, "x", "-y", f"-o{stage}", str(archive)],
        check=False, capture_output=True, text=True,
    )
    if result.returncode != 0:
        temporary.cleanup()
        raise ManagerError("7-Zip failed to extract the verified OptiScaler archive.")

    extracted_files = []
    extracted_size = 0
    for path in stage.rglob("*"):
        if path.is_symlink():
            temporary.cleanup()
            raise ManagerError("The release archive contains a symbolic link; refusing it.")
        if path.is_file():
            extracted_size += path.stat().st_size
            if extracted_size > MAX_EXTRACTED_BYTES:
                temporary.cleanup()
                raise ManagerError("Extracted archive exceeded the 4 GiB safety limit.")
            extracted_files.append(path)

    dlls = [path for path in extracted_files if path.name.lower() == "optiscaler.dll"]
    if len(dlls) != 1:
        temporary.cleanup()
        raise ManagerError(f"Expected one OptiScaler.dll in the release; found {len(dlls)}.")
    payload_root = dlls[0].parent
    ini = payload_root / "OptiScaler.ini"
    if not ini.is_file() or ini.is_symlink():
        temporary.cleanup()
        raise ManagerError("OptiScaler.ini was not found beside OptiScaler.dll.")

    payload: dict[str, Path] = {}
    for source in payload_root.rglob("*"):
        if source.is_symlink():
            temporary.cleanup()
            raise ManagerError("The extracted payload contains a symbolic link.")
        if not source.is_file():
            continue
        relative = validate_archive_member(source.relative_to(payload_root).as_posix())
        if source == dlls[0]:
            relative = proxy_name
        if relative in payload:
            temporary.cleanup()
            raise ManagerError(f"Archive files collide at target path {relative!r}.")
        payload[relative] = source
    if proxy_name in payload and payload[proxy_name].name.lower() != "optiscaler.dll":
        temporary.cleanup()
        raise ManagerError(f"The archive already contains {proxy_name}; refusing ambiguity.")
    return temporary, payload


def game_identity(game_dir: Path) -> str:
    return hashlib.sha256(str(game_dir).encode("utf-8")).hexdigest()[:24]


def game_state_file(game_dir: Path) -> Path:
    return state_root() / "installs" / f"{game_identity(game_dir)}.json"


def backup_root(game_dir: Path) -> Path:
    return state_root() / "backups" / game_identity(game_dir)


def validate_state_document(value: object, description: str) -> dict:
    """Validate the complete state shape before trusting its paths or hashes."""
    if not isinstance(value, dict):
        raise ManagerError(f"{description} must be a JSON object.")
    if type(value.get("schema")) is not int or value["schema"] != 1:
        raise ManagerError(f"{description} has an unsupported or invalid schema.")
    for field in ("game_dir", "version", "asset"):
        if not isinstance(value.get(field), str) or not value[field].strip():
            raise ManagerError(f"{description} has an invalid {field!r} field.")
    proxy = value.get("proxy")
    if not isinstance(proxy, str) or proxy not in SUPPORTED_PROXIES:
        raise ManagerError(f"{description} has an unsupported proxy name.")
    files = value.get("files")
    if not isinstance(files, dict):
        raise ManagerError(f"{description} has an invalid managed-files map.")
    for relative, digest in files.items():
        if not isinstance(relative, str) or validate_archive_member(relative) != relative:
            raise ManagerError(f"{description} contains an invalid managed-file path.")
        if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-fA-F]{64}", digest):
            raise ManagerError(f"{description} contains an invalid SHA-256 for {relative!r}.")
    originals = value.get("originals", {})
    if not isinstance(originals, dict):
        raise ManagerError(f"{description} has an invalid original-files map.")
    for relative, backup_relative in originals.items():
        if not isinstance(relative, str) or validate_archive_member(relative) != relative:
            raise ManagerError(f"{description} contains an invalid original-file path.")
        if backup_relative != f"originals/{relative}":
            raise ManagerError(f"{description} has an invalid backup mapping for {relative!r}.")
    if "rollback_available" in value and not isinstance(value["rollback_available"], bool):
        raise ManagerError(f"{description} has an invalid rollback_available flag.")
    return value


def load_state(path: Path) -> dict | None:
    if path.is_symlink():
        raise ManagerError("The manager state file is a symbolic link; inspect it manually.")
    if not path.exists():
        return None
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ManagerError(f"Could not read manager state {path}: {exc}") from exc
    return validate_state_document(value, "Manager state")


def atomic_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        mode="w", encoding="utf-8", dir=path.parent, prefix=".state-", delete=False
    ) as stream:
        temporary = Path(stream.name)
        json.dump(value, stream, indent=2, sort_keys=True)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temporary, path)


def target_path(game_dir: Path, relative: str) -> Path:
    safe = validate_archive_member(relative)
    parts = safe.split("/")
    current = game_dir
    for part in parts[:-1]:
        current = current / part
        if current.is_symlink():
            raise ManagerError(f"Refusing to follow a symbolic-link directory: {current}")
        if current.exists() and not current.is_dir():
            raise ManagerError(f"Target parent is not a directory: {current}")
    target = game_dir.joinpath(*parts)
    if target.is_symlink():
        raise ManagerError(f"Refusing to replace a symbolic link: {target}")
    if target.exists() and not target.is_file():
        raise ManagerError(f"Target exists but is not a regular file: {target}")
    return target


def copy_atomic(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=destination.parent, prefix=".optiscaler-", delete=False) as stream:
        temporary = Path(stream.name)
    try:
        shutil.copy2(source, temporary)
        os.replace(temporary, destination)
    finally:
        temporary.unlink(missing_ok=True)


def snapshot_file(source: Path, destination: Path) -> None:
    """Copy an existing file into the manager's backup area."""
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)


def require_regular_backup(path: Path, description: str) -> None:
    """Fail before mutation if a required backup is absent or unsafe."""
    try:
        mode = path.lstat().st_mode
    except OSError as exc:
        raise ManagerError(f"{description} is unavailable: {path}: {exc}") from exc
    if not stat.S_ISREG(mode):
        raise ManagerError(f"{description} is not a regular file: {path}")


def safe_backup_path(root: Path, relative: str) -> Path:
    """Resolve a backup-relative path without following symlink components."""
    safe = validate_archive_member(relative)
    if root.is_symlink():
        raise ManagerError(f"Refusing a symbolic-link backup directory: {root}")
    candidate = root.joinpath(*safe.split("/"))
    try:
        candidate.relative_to(root)
    except ValueError as exc:  # defensive; validate_archive_member already rejects '..'
        raise ManagerError(f"Backup path escapes its root: {relative!r}") from exc
    current = root
    for part in safe.split("/"):
        current = current / part
        if current.is_symlink():
            raise ManagerError(f"Refusing a symbolic link in the backup path: {current}")
    return candidate


def snapshot_file_set(
    targets: dict[str, Path],
    snapshot_root: Path,
) -> dict[str, bool]:
    """Persist the current regular-file state before a multi-file transaction."""
    existed: dict[str, bool] = {}
    for relative in sorted(targets):
        target = targets[relative]
        if target.is_symlink() or (target.exists() and not target.is_file()):
            raise ManagerError(f"Refusing to snapshot a non-regular target: {target}")
        existed[relative] = target.is_file()
        if existed[relative]:
            snapshot_file(target, snapshot_root / relative)
    return existed


def restore_file_set(
    targets: dict[str, Path],
    snapshot_root: Path,
    existed: dict[str, bool],
    description: str,
) -> None:
    """Restore a captured file set without following or deleting symlink targets."""
    for relative in sorted(targets):
        target = targets[relative]
        if target.is_symlink() or (target.exists() and not target.is_file()):
            raise ManagerError(f"Refusing to restore through a non-regular target: {target}")
        if existed[relative]:
            saved = snapshot_root / relative
            require_regular_backup(saved, description)
            copy_atomic(saved, target)
        elif target.exists():
            target.unlink()


def apply_payload(
    game_dir: Path,
    payload: dict[str, Path],
    version: str,
    asset_name: str,
    proxy_name: str,
    replace_existing: bool,
) -> dict:
    state_file = game_state_file(game_dir)
    backup_dir = backup_root(game_dir)
    previous = load_state(state_file)
    old_files = previous["files"] if previous else {}
    originals = dict(previous.get("originals", {})) if previous else {}
    new_hashes = {relative: sha256_file(source) for relative, source in payload.items()}
    changed_paths = set(old_files) | set(payload)

    targets = {}
    for relative in sorted(changed_paths):
        target = target_path(game_dir, relative)
        targets[relative] = target
        if not target.exists():
            continue
        current_hash = sha256_file(target)
        managed_hash = old_files.get(relative)
        if managed_hash is not None and current_hash == managed_hash:
            continue
        if not replace_existing:
            raise ManagerError(
                f"Existing file would be replaced: {target}. Inspect it first; "
                "use --replace-existing only when you intend to back it up."
            )

    backup_dir.mkdir(parents=True, exist_ok=True)
    if backup_dir.is_symlink():
        raise ManagerError(f"Refusing a symbolic-link backup directory: {backup_dir}")
    rollback_dir = backup_dir / "rollback"
    transaction = {"paths": {}}
    # Build a complete rollback snapshot away from the active transaction. A failed
    # snapshot must not erase the previous known-good rollback directory.
    with tempfile.TemporaryDirectory(prefix=".rollback-stage-", dir=backup_dir) as staging:
        staged_rollback = Path(staging)
        files_dir = staged_rollback / "files"
        for relative, target in targets.items():
            exists = target.is_file()
            transaction["paths"][relative] = exists
            if exists:
                snapshot_file(target, files_dir / relative)
        if previous is not None:
            atomic_json(staged_rollback / "previous-state.json", previous)
        atomic_json(staged_rollback / "transaction.json", transaction)

        # Preserve newly encountered game files before replacing the previous
        # one-step rollback. copy_atomic publishes each backup only after the full
        # copy succeeds, so a failed backup leaves the current rollback untouched.
        for relative, target in targets.items():
            if target.is_file() and relative not in old_files and relative not in originals:
                backup_relative = f"originals/{relative}"
                backup_path = safe_backup_path(backup_dir, backup_relative)
                try:
                    copy_atomic(target, backup_path)
                except OSError as exc:
                    raise ManagerError(
                        f"Could not preserve original game-file backup for {target}: {exc}"
                    ) from exc
                originals[relative] = backup_relative

        old_rollback = backup_dir / ".rollback-previous"
        if rollback_dir.is_symlink() or old_rollback.is_symlink():
            raise ManagerError("Refusing a symbolic link in the rollback directory.")
        for candidate in (rollback_dir, old_rollback):
            if candidate.exists() and not candidate.is_dir():
                raise ManagerError(f"Rollback path is not a directory: {candidate}")
        if old_rollback.exists():
            shutil.rmtree(old_rollback)
        if rollback_dir.exists():
            os.replace(rollback_dir, old_rollback)
        try:
            os.replace(staged_rollback, rollback_dir)
        except Exception:
            if old_rollback.exists() and not rollback_dir.exists():
                os.replace(old_rollback, rollback_dir)
            raise
        if old_rollback.exists():
            if previous is not None:
                # The prior rollback snapshot has been superseded. Persist that fact
                # before changing the game directory; if this write fails, put the
                # previous rollback directory back and leave the game untouched.
                previous = dict(previous)
                previous["rollback_available"] = False
                try:
                    atomic_json(state_file, previous)
                except Exception:
                    shutil.rmtree(rollback_dir, ignore_errors=True)
                    os.replace(old_rollback, rollback_dir)
                    raise
            shutil.rmtree(old_rollback, ignore_errors=True)
    state = {
        "schema": 1,
        "game_dir": str(game_dir),
        "version": version,
        "asset": asset_name,
        "proxy": proxy_name,
        "files": new_hashes,
        "originals": originals,
        "rollback_available": True,
    }
    try:
        for relative in sorted(set(old_files) - set(payload)):
            target = targets[relative]
            if target.exists():
                target.unlink()
        for relative, source in payload.items():
            copy_atomic(source, targets[relative])
        # The state record is part of the same transaction as the game files.
        # A failed atomic write must not leave an untracked or partially updated install.
        atomic_json(state_file, state)
    except Exception as install_error:
        try:
            restore_transaction(game_dir, rollback_dir, state_file)
        except Exception as rollback_error:
            raise ManagerError(
                "OptiScaler installation failed and automatic restoration was "
                f"incomplete ({rollback_error}). Preserve {rollback_dir} and "
                f"inspect {game_dir} before retrying; original error: {install_error}"
            ) from rollback_error
        raise
    return state


def restore_transaction(
    game_dir: Path,
    rollback_dir: Path,
    state_file: Path,
) -> None:
    transaction_file = rollback_dir / "transaction.json"
    if not transaction_file.is_file() or transaction_file.is_symlink():
        raise ManagerError("No valid rollback transaction is available.")
    try:
        transaction = json.loads(transaction_file.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ManagerError(f"Could not read rollback transaction: {exc}") from exc
    if not isinstance(transaction, dict) or not isinstance(transaction.get("paths"), dict):
        raise ManagerError("Rollback transaction has an invalid paths map.")

    previous_file = rollback_dir / "previous-state.json"
    if previous_file.exists() or previous_file.is_symlink():
        if previous_file.is_symlink() or not previous_file.is_file():
            raise ManagerError(f"Previous manager state is not a regular file: {previous_file}")
        try:
            previous = json.loads(previous_file.read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise ManagerError(f"Could not read previous manager state: {exc}") from exc
        previous = validate_state_document(previous, "Previous manager state")
    else:
        previous = None

    current = load_state(state_file)
    current_files = current["files"] if current else {}
    paths = transaction["paths"]
    if not isinstance(current_files, dict):
        raise ManagerError("Current manager state has an invalid files map.")

    # Validate every path and every needed backup before touching the game folder.
    targets: dict[str, Path] = {}
    backups: dict[str, Path] = {}
    for relative in set(paths) | set(current_files):
        if relative not in paths:
            raise ManagerError(
                f"Rollback transaction does not contain a snapshot for managed file {relative!r}."
            )
        existed = paths[relative]
        if not isinstance(existed, bool):
            raise ManagerError(f"Rollback transaction has an invalid existence flag for {relative!r}.")
        targets[relative] = target_path(game_dir, relative)
        if existed:
            saved = safe_backup_path(rollback_dir / "files", relative)
            require_regular_backup(saved, "Rollback backup")
            backups[relative] = saved

    # Keep a persistent copy of the currently installed game state until every
    # rollback file and the final manager-state JSON have been committed. A failed
    # rollback can restore the pre-rollback state and leave the original one-step
    # rollback transaction available for a retry.
    recovery_dir = Path(
        tempfile.mkdtemp(prefix=".rollback-recovery-", dir=rollback_dir.parent)
    )
    recovery_files = recovery_dir / "files"
    try:
        existed_before = snapshot_file_set(targets, recovery_files)
        state_existed = state_file.is_file()
        if state_existed:
            snapshot_file(state_file, recovery_dir / "manager-state.json")
    except Exception:
        shutil.rmtree(recovery_dir, ignore_errors=True)
        raise

    try:
        rollback_existed = {relative: relative in backups for relative in targets}
        restore_file_set(
            targets, rollback_dir / "files", rollback_existed, "Rollback backup"
        )
        if previous is not None:
            previous["rollback_available"] = False
            atomic_json(state_file, previous)
        else:
            state_file.unlink(missing_ok=True)
    except Exception as rollback_error:
        try:
            restore_file_set(
                targets, recovery_files, existed_before, "Pre-rollback recovery snapshot"
            )
            if state_existed:
                copy_atomic(recovery_dir / "manager-state.json", state_file)
            elif state_file.exists():
                state_file.unlink()
        except Exception as recovery_error:
            raise ManagerError(
                "OptiScaler rollback failed and restoration of the pre-rollback "
                f"state was incomplete ({recovery_error}). "
                f"Preserve the recovery snapshot at {recovery_dir}; inspect it before retrying. "
                f"Original rollback error: {rollback_error}"
            ) from recovery_error
        shutil.rmtree(recovery_dir, ignore_errors=True)
        raise

    shutil.rmtree(recovery_dir, ignore_errors=True)
    shutil.rmtree(rollback_dir, ignore_errors=True)
    if previous is None:
        shutil.rmtree(rollback_dir.parent, ignore_errors=True)


def remove_installation(game_dir: Path) -> None:
    state_file = game_state_file(game_dir)
    state = load_state(state_file)
    if state is None:
        raise ManagerError("OptiScaler is not managed in this game directory.")

    managed_files = state["files"]
    originals = state.get("originals", {})
    if not isinstance(managed_files, dict) or not isinstance(originals, dict):
        raise ManagerError("Manager state contains invalid managed/original file maps.")

    root = backup_root(game_dir)
    if root.is_symlink():
        raise ManagerError(f"Refusing a symbolic-link backup directory: {root}")
    targets: dict[str, Path] = {}
    original_backups: dict[str, Path] = {}
    for relative, expected_hash in managed_files.items():
        target = target_path(game_dir, relative)
        targets[relative] = target
        if target.exists() and sha256_file(target) != expected_hash:
            raise ManagerError(
                f"Managed file was modified; refusing to delete it: {target}. "
                "Restore it manually or use rollback after reviewing the changes."
            )

    # Validate all original-file backups and their destinations before removing even
    # one manager-owned file. Older versions performed this check after deletion.
    for relative, backup_relative in originals.items():
        target = targets.get(relative) or target_path(game_dir, relative)
        if relative not in managed_files and target.exists():
            raise ManagerError(f"Cannot restore original because the destination exists: {target}")
        saved = safe_backup_path(root, backup_relative)
        require_regular_backup(saved, "Original-file backup")
        original_backups[relative] = saved
        targets[relative] = target

    # Stage the pre-remove file set persistently. Delete it only after removal
    # succeeds or after automatic restoration fully recovers the game. If that
    # recovery also fails, report and retain the exact snapshot path.
    root.mkdir(parents=True, exist_ok=True)
    recovery_dir = Path(tempfile.mkdtemp(prefix=".remove-transaction-", dir=root))
    snapshot_root = recovery_dir / "files"
    try:
        existed_before = snapshot_file_set(targets, snapshot_root)
    except Exception:
        shutil.rmtree(recovery_dir, ignore_errors=True)
        raise

    try:
        for relative in managed_files:
            if relative not in original_backups:
                target = targets[relative]
                if target.exists():
                    target.unlink()
        for relative, saved in original_backups.items():
            copy_atomic(saved, targets[relative])
        state_file.unlink()
    except Exception as remove_error:
        try:
            restore_file_set(
                targets, snapshot_root, existed_before, "Pre-remove recovery snapshot"
            )
        except Exception as rollback_error:
            raise ManagerError(
                "OptiScaler removal failed and automatic restoration was "
                f"incomplete ({rollback_error}). "
                f"Preserve the recovery snapshot at {recovery_dir}; inspect it before retrying. "
                f"Original removal error: {remove_error}"
            ) from rollback_error
        shutil.rmtree(recovery_dir, ignore_errors=True)
        raise

    shutil.rmtree(recovery_dir, ignore_errors=True)
    shutil.rmtree(root, ignore_errors=True)


def select_game_dir(raw: str) -> Path:
    path = Path(raw).expanduser()
    if not path.exists() or not path.is_dir():
        raise ManagerError(f"Game executable directory does not exist: {path}")
    resolved = path.resolve(strict=True)
    executables = [p for p in resolved.iterdir() if p.is_file() and p.suffix.lower() == ".exe"]
    if not executables:
        raise ManagerError(
            "The selected directory contains no .exe file. Pass the exact directory "
            "that contains the game's main Windows executable."
        )
    return resolved


def print_launch_override(proxy_name: str) -> None:
    key = Path(proxy_name).stem
    print("\nAdd this only to the selected game's Steam launch options:")
    print(f'WINEDLLOVERRIDES="{key}=n,b" %command%')
    print("Keep existing launch options; do not add this globally.")


def command_check(_: argparse.Namespace) -> None:
    release, asset = stable_release()
    tag = release["tag_name"]
    try:
        digest_note = f"SHA-256 available: {expected_digest(tag, asset)}"
    except ManagerError as exc:
        digest_note = str(exc)
    print(f"Latest stable OptiScaler: {tag}")
    print(f"Asset: {asset['name']} ({asset['size']} bytes)")
    print(digest_note)
    print("Nightly/prerelease builds are intentionally ignored.")


def command_download(args: argparse.Namespace) -> None:
    archive, tag, asset = download_release(args.sha256)
    print(f"Verified {tag}: {archive}")
    print(f"SHA-256: {sha256_file(archive)}")
    print(f"Asset: {asset}")


def command_install(args: argparse.Namespace) -> None:
    if not args.confirm_offline_singleplayer:
        raise ManagerError(
            "Installation requires --confirm-offline-singleplayer. "
            "Do not use OptiScaler with online or anti-cheat-protected games."
        )
    game_dir = select_game_dir(args.game_dir)
    print("WARNING: OptiScaler can trigger anti-cheat and account penalties.")
    print("Continue only for an offline/single-player game whose mod policy permits it.")
    print(f"Target directory: {game_dir}")
    if input("Type INSTALL to confirm this per-game change: ").strip() != "INSTALL":
        raise ManagerError("Installation cancelled.")
    with game_operation_lock(game_dir):
        archive, version, asset = download_release(args.sha256)
        temporary, payload = extract_payload(archive, args.proxy)
        try:
            state = apply_payload(
                game_dir, payload, version, asset, args.proxy, args.replace_existing
            )
        finally:
            temporary.cleanup()
        print(f"Installed OptiScaler {version} into {game_dir}")
        print(f"Managed files: {len(state['files'])}")
        print("A one-step rollback is available with the rollback command.")
        print_launch_override(args.proxy)


def command_status(args: argparse.Namespace) -> None:
    game_dir = select_game_dir(args.game_dir)
    with game_operation_lock(game_dir):
        state = load_state(game_state_file(game_dir))
        if state is None:
            print(f"No manager-owned OptiScaler installation in {game_dir}")
            return
        mismatches = []
        missing = []
        for relative, expected in state["files"].items():
            target = target_path(game_dir, relative)
            if not target.is_file():
                missing.append(relative)
            elif sha256_file(target) != expected:
                mismatches.append(relative)
        print(f"OptiScaler: {state['version']}")
        print(f"Game directory: {game_dir}")
        print(f"Proxy: {state['proxy']}")
        print(f"Tracked files: {len(state['files'])}")
        print(f"Integrity: {'OK' if not mismatches and not missing else 'needs review'}")
        if mismatches:
            print("Modified: " + ", ".join(mismatches))
        if missing:
            print("Missing: " + ", ".join(missing))
        print(f"Rollback available: {'yes' if state.get('rollback_available') else 'no'}")


def command_rollback(args: argparse.Namespace) -> None:
    game_dir = select_game_dir(args.game_dir)
    with game_operation_lock(game_dir):
        state_file = game_state_file(game_dir)
        state = load_state(state_file)
        if state is None or not state.get("rollback_available"):
            raise ManagerError("No one-step rollback is available for this game directory.")
        for relative, expected in state["files"].items():
            target = target_path(game_dir, relative)
            if target.exists() and sha256_file(target) != expected:
                raise ManagerError(f"Managed file was modified; refusing rollback: {target}")
        restore_transaction(game_dir, backup_root(game_dir) / "rollback", state_file)
        print(f"Restored the previous game-folder state for {game_dir}")


def command_remove(args: argparse.Namespace) -> None:
    game_dir = select_game_dir(args.game_dir)
    with game_operation_lock(game_dir):
        remove_installation(game_dir)
        print(f"Removed manager-owned OptiScaler files and restored originals in {game_dir}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Safely manage verified OptiScaler releases in an explicitly selected game folder."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    check = subparsers.add_parser("check", help="check the latest official stable release")
    check.set_defaults(function=command_check)

    download = subparsers.add_parser("download", help="download and verify the stable release")
    download.add_argument("--sha256", help="manually verified SHA-256 for a release without published digest")
    download.set_defaults(function=command_download)

    install = subparsers.add_parser("install", help="install/update in one selected game folder")
    install.add_argument("--game-dir", required=True, help="exact directory containing the game's main .exe")
    install.add_argument("--proxy", choices=sorted(SUPPORTED_PROXIES), default="dxgi.dll")
    install.add_argument("--sha256", help="manually verified SHA-256 if the release API has no digest")
    install.add_argument("--replace-existing", action="store_true", help="back up and replace colliding files")
    install.add_argument(
        "--confirm-offline-singleplayer",
        action="store_true",
        help="confirm this is an offline/single-player game and its mod policy permits OptiScaler",
    )
    install.set_defaults(function=command_install)

    status = subparsers.add_parser("status", help="check files managed in a game folder")
    status.add_argument("--game-dir", required=True)
    status.set_defaults(function=command_status)

    rollback = subparsers.add_parser("rollback", help="restore the previous state of a game folder")
    rollback.add_argument("--game-dir", required=True)
    rollback.set_defaults(function=command_rollback)

    remove = subparsers.add_parser("remove", help="remove managed files and restore original files")
    remove.add_argument("--game-dir", required=True)
    remove.set_defaults(function=command_remove)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        args.function(args)
    except ManagerError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    except KeyboardInterrupt:
        print("Interrupted.", file=sys.stderr)
        return 130
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
