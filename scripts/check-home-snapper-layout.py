#!/usr/bin/env python3
"""Fail-closed verification of Home Snapper's Btrfs mounts and UUIDs."""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path


def fail(message: str) -> None:
    raise RuntimeError(message)


def strip_nix_comments(text: str) -> str:
    # Only simple machine-generated device expressions are accepted below.
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    return re.sub(r"(?m)#.*$", "", text)


def filesystem_block(text: str, mountpoint: str) -> str:
    pattern = re.compile(
        rf'(?m)^[ \t]*fileSystems\."{re.escape(mountpoint)}"\s*=\s*\{{(.*?)^[ \t]*\}};',
        re.DOTALL,
    )
    matches = list(pattern.finditer(text))
    if len(matches) != 1:
        fail(f"expected exactly one fileSystems.{mountpoint!r} block in target hardware configuration")
    return matches[0].group(1)


def parse_filesystem(text: str, mountpoint: str, expected_subvolume: str) -> str:
    block = filesystem_block(text, mountpoint)
    fs_type = re.search(r'\bfsType\s*=\s*"([^"]+)"\s*;', block)
    if not fs_type or fs_type.group(1).lower() != "btrfs":
        fail(f'fileSystems.{mountpoint!r} must explicitly use fsType = "btrfs"')
    device = re.search(r"\bdevice\s*=\s*([^;]+);", block)
    if not device:
        fail(f"fileSystems.{mountpoint!r} has no unambiguous device assignment")
    options = re.findall(r'"subvol=([^"]+)"', block)
    normalized = [option.lstrip("/") for option in options]
    if normalized.count(expected_subvolume) != 1 or len(normalized) != 1:
        fail(f'fileSystems.{mountpoint!r} must specify exactly subvol={expected_subvolume}')
    if mountpoint == "/home/.snapshots" and not re.search(
        r"\bneededForBoot\s*=\s*true\s*;", block
    ):
        fail('fileSystems."/home/.snapshots" must retain neededForBoot = true')
    return device.group(1).strip()


def resolve_device(expression: str, text: str) -> str:
    value = expression.strip()
    for _ in range(5):
        literal = re.fullmatch(r'"([^"]+)"', value)
        if literal:
            return literal.group(1)
        if (
            not value
            or not (value[0].isalpha() or value[0] == "_")
            or not all(character.isalnum() or character == "_" for character in value)
        ):
            fail(f"cannot safely resolve target hardware device expression: {expression!r}")
        name = value
        assignment = re.compile(
            rf'(?m)^[ \t]*{re.escape(name)}[ \t]*=[ \t]*(?:"([^"]+)"|([A-Za-z_][A-Za-z0-9_]*))[ \t]*;'
        )
        matches = list(assignment.finditer(text))
        if len(matches) != 1:
            fail(f"target hardware device variable {name!r} is missing or ambiguous")
        match = matches[0]
        if match.group(1) is not None:
            return match.group(1)
        value = match.group(2)
    fail(f"target hardware device expression is too indirect to validate safely: {expression!r}")


def configured_uuid(device: str) -> str:
    value = device.strip()
    if value.startswith("UUID="):
        result = value[5:].strip().strip('"')
    else:
        by_uuid = re.search(r"(?:^|/)by-uuid/([^/]+)$", value, flags=re.IGNORECASE)
        if by_uuid:
            result = by_uuid.group(1)
        else:
            try:
                probe = subprocess.run(
                    ["sudo", "blkid", "-s", "UUID", "-o", "value", "--", value],
                    check=False,
                    capture_output=True,
                    text=True,
                )
            except OSError as error:
                fail(f"could not run blkid to verify target device {value!r}: {error}")
            if probe.returncode != 0:
                fail(f"could not resolve a filesystem UUID for configured device {value!r}")
            result = probe.stdout.strip()
    if not result or "\n" in result or "\r" in result or result == "-":
        fail(f"configured device {device!r} has no single usable filesystem UUID")
    return result.lower()


def mounted_filesystem(mountpoint: str, required: bool) -> dict[str, str] | None:
    try:
        result = subprocess.run(
            ["findmnt", "-rn", "-M", mountpoint, "-o", "SOURCE,UUID,FSTYPE,OPTIONS"],
            check=False,
            capture_output=True,
            text=True,
        )
    except OSError as error:
        fail(f"could not run findmnt for {mountpoint}: {error}")
    if result.returncode != 0:
        if not required and result.returncode == 1:
            return None
        fail(f"{mountpoint} is not mounted at its exact expected mountpoint or findmnt failed")
    rows = [row.split() for row in result.stdout.splitlines() if row.strip()]
    if len(rows) != 1 or len(rows[0]) < 4:
        fail(f"findmnt did not return one complete mount record for {mountpoint}")
    source, uuid, fs_type = rows[0][:3]
    options = " ".join(rows[0][3:])
    if not uuid or uuid == "-":
        fail(f"findmnt could not report a filesystem UUID for {mountpoint} (source {source})")
    return {"source": source, "uuid": uuid.lower(), "fstype": fs_type.lower(), "options": options}


def mounted_subvolume(mount: dict[str, str], mountpoint: str, expected: str) -> None:
    if mount["fstype"] != "btrfs":
        fail(f"{mountpoint} is mounted as {mount['fstype']!r}, not Btrfs")
    options = [item for item in mount["options"].split(",") if item.startswith("subvol=")]
    actual = [item.split("=", 1)[1].lstrip("/") for item in options]
    if len(actual) != 1 or actual[0] != expected:
        fail(f"{mountpoint} must be mounted from subvol={expected}; observed options: {options!r}")


def validate(config_path: Path) -> None:
    try:
        text = strip_nix_comments(config_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError) as error:
        fail(f"cannot read target hardware configuration {config_path}: {error}")

    home_device = resolve_device(parse_filesystem(text, "/home", "@home"), text)
    snapshots_device = resolve_device(
        parse_filesystem(text, "/home/.snapshots", "@home/.snapshots"), text
    )
    home_config_uuid = configured_uuid(home_device)
    snapshots_config_uuid = configured_uuid(snapshots_device)
    if home_config_uuid != snapshots_config_uuid:
        fail("target /home and /home/.snapshots entries reference different filesystem UUIDs")

    home_mount = mounted_filesystem("/home", required=True)
    assert home_mount is not None
    mounted_subvolume(home_mount, "/home", "@home")
    if home_mount["uuid"] != home_config_uuid:
        fail("active /home mount UUID does not match the target hardware configuration")

    snapshots_mount = mounted_filesystem("/home/.snapshots", required=False)
    if snapshots_mount is not None:
        mounted_subvolume(snapshots_mount, "/home/.snapshots", "@home/.snapshots")
        if snapshots_mount["uuid"] != home_mount["uuid"]:
            fail("/home/.snapshots is mounted from a different filesystem UUID than /home")


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(f"Usage: {Path(argv[0]).name} TARGET_HARDWARE_CONFIGURATION_NIX", file=sys.stderr)
        return 2
    try:
        validate(Path(argv[1]))
    except (RuntimeError, AssertionError) as error:
        print(f"ERROR: Home Snapper preflight: {error}", file=sys.stderr)
        return 1
    print("OK: Home Snapper @home, .snapshots mount, and target UUID layout verified.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
