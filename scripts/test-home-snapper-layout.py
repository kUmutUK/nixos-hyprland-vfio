#!/usr/bin/env python3
"""Regression tests for Home Snapper mount, subvolume, and UUID preflight."""
from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CHECKER = ROOT / "scripts" / "check-home-snapper-layout.py"
HOME_UUID = "11111111-2222-3333-4444-555555555555"
OTHER_UUID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"


def fixture_config() -> str:
    return f'''let
  rootDev = "/dev/disk/by-uuid/{HOME_UUID}";
  otherDev = "/dev/disk/by-uuid/{OTHER_UUID}";
in {{
  fileSystems."/home" = {{
    device = rootDev;
    fsType = "btrfs";
    options = [ "subvol=@home" "compress=zstd" ];
  }};
  fileSystems."/home/.snapshots" = {{
    device = rootDev;
    fsType = "btrfs";
    options = [ "subvol=@home/.snapshots" "compress=zstd" ];
    neededForBoot = true;
  }};
}}
'''


def write_fake_findmnt(path: Path) -> None:
    path.write_text(
        '''#!/bin/sh
mountpoint=""
while [ "$#" -gt 0 ]; do
  if [ "$1" = "-M" ] && [ "$#" -ge 2 ]; then
    mountpoint="$2"
    shift 2
  else
    shift
  fi
done
case "$mountpoint" in
  /home)
    [ "${TEST_HOME_MOUNT:-present}" = "present" ] || exit 1
    printf '%s %s %s %s\n' "${TEST_HOME_SOURCE:-/dev/disk/by-uuid/$TEST_HOME_UUID}" "$TEST_HOME_UUID" "${TEST_HOME_FSTYPE:-btrfs}" "${TEST_HOME_OPTIONS:-rw,subvol=/@home}"
    ;;
  /home/.snapshots)
    [ "${TEST_SNAPSHOT_MOUNT:-none}" != "none" ] || exit 1
    printf '%s %s %s %s\n' "${TEST_SNAPSHOT_SOURCE:-/dev/disk/by-uuid/$TEST_SNAPSHOT_UUID}" "$TEST_SNAPSHOT_UUID" "${TEST_SNAPSHOT_FSTYPE:-btrfs}" "${TEST_SNAPSHOT_OPTIONS:-rw,subvol=/@home/.snapshots}"
    ;;
  *)
    exit 1
    ;;
esac
''',
        encoding="utf-8",
    )
    path.chmod(0o755)


def run_case(
    name: str,
    bin_dir: Path,
    config_path: Path,
    config_text: str,
    overrides: dict[str, str],
    expected_success: bool,
) -> None:
    config_path.write_text(config_text, encoding="utf-8")
    environment = os.environ.copy()
    environment.update(
        {
            "PATH": f"{bin_dir}{os.pathsep}{environment.get('PATH', '/usr/bin:/bin')}",
            "TEST_HOME_UUID": HOME_UUID,
            "TEST_HOME_SOURCE": f"/dev/disk/by-uuid/{HOME_UUID}",
            "TEST_HOME_FSTYPE": "btrfs",
            "TEST_HOME_OPTIONS": "rw,subvol=/@home",
            "TEST_HOME_MOUNT": "present",
            "TEST_SNAPSHOT_MOUNT": "none",
            "TEST_SNAPSHOT_UUID": HOME_UUID,
            "TEST_SNAPSHOT_SOURCE": f"/dev/disk/by-uuid/{HOME_UUID}",
            "TEST_SNAPSHOT_FSTYPE": "btrfs",
            "TEST_SNAPSHOT_OPTIONS": "rw,subvol=/@home/.snapshots",
        }
    )
    environment.update(overrides)
    result = subprocess.run(
        [sys.executable, str(CHECKER), str(config_path)],
        check=False,
        capture_output=True,
        text=True,
        env=environment,
    )
    passed = result.returncode == 0
    if passed != expected_success:
        detail = (result.stdout + result.stderr).strip()
        raise AssertionError(
            f"{name}: expected {'success' if expected_success else 'failure'}, "
            f"got exit {result.returncode}: {detail}"
        )
    print(f"OK: {name}")


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="home-snapper-test-") as temp:
        base = Path(temp)
        bin_dir = base / "bin"
        bin_dir.mkdir()
        write_fake_findmnt(bin_dir / "findmnt")
        config_path = base / "hardware-configuration.nix"
        valid = fixture_config()

        run_case("valid @home; missing snapshot subvolume may be created later", bin_dir, config_path, valid, {}, True)
        run_case("valid separately mounted @home/.snapshots", bin_dir, config_path, valid, {"TEST_SNAPSHOT_MOUNT": "present"}, True)
        run_case("reject non-Btrfs /home", bin_dir, config_path, valid, {"TEST_HOME_FSTYPE": "ext4"}, False)
        run_case("reject /home without an exact mount", bin_dir, config_path, valid, {"TEST_HOME_MOUNT": "missing"}, False)
        run_case("reject active /home mounted from wrong subvolume", bin_dir, config_path, valid, {"TEST_HOME_OPTIONS": "rw,subvol=/@"}, False)

        wrong_home_device = valid.replace(
            f'rootDev = "/dev/disk/by-uuid/{HOME_UUID}";',
            f'rootDev = "/dev/disk/by-uuid/{OTHER_UUID}";',
        )
        run_case("reject target UUID that differs from active /home", bin_dir, config_path, wrong_home_device, {}, False)
        mismatched_devices = valid.replace(
            'device = rootDev;\n    fsType = "btrfs";\n    options = [ "subvol=@home/.snapshots"',
            'device = otherDev;\n    fsType = "btrfs";\n    options = [ "subvol=@home/.snapshots"',
        )
        run_case("reject different target UUIDs for /home and .snapshots", bin_dir, config_path, mismatched_devices, {}, False)
        wrong_home_config_subvol = valid.replace('"subvol=@home"', '"subvol=@"')
        run_case("reject target config with wrong @home subvolume", bin_dir, config_path, wrong_home_config_subvol, {}, False)
        wrong_snap_config_subvol = valid.replace('"subvol=@home/.snapshots"', '"subvol=@snapshots"')
        run_case("reject target config with wrong .snapshots subvolume", bin_dir, config_path, wrong_snap_config_subvol, {}, False)
        missing_boot_flag = valid.replace('    neededForBoot = true;\n', "")
        run_case("reject .snapshots without neededForBoot", bin_dir, config_path, missing_boot_flag, {}, False)
        run_case(
            "reject mounted root @snapshots at /home/.snapshots",
            bin_dir,
            config_path,
            valid,
            {"TEST_SNAPSHOT_MOUNT": "present", "TEST_SNAPSHOT_OPTIONS": "rw,subvol=/@snapshots"},
            False,
        )
        run_case(
            "reject mounted .snapshots with different UUID",
            bin_dir,
            config_path,
            valid,
            {"TEST_SNAPSHOT_MOUNT": "present", "TEST_SNAPSHOT_UUID": OTHER_UUID, "TEST_SNAPSHOT_SOURCE": f"/dev/disk/by-uuid/{OTHER_UUID}"},
            False,
        )
        run_case(
            "reject mounted .snapshots on non-Btrfs",
            bin_dir,
            config_path,
            valid,
            {"TEST_SNAPSHOT_MOUNT": "present", "TEST_SNAPSHOT_FSTYPE": "ext4"},
            False,
        )
        print("OK: Home Snapper layout regression tests passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
