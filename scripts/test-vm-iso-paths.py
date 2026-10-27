#!/usr/bin/env python3
"""Regression tests for the VM ISO path checker."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path

CHECKER = Path(__file__).with_name("check-vm-iso-paths.py")
SUBPROCESS_TIMEOUT_SECONDS = 30


class CheckVmIsoPathsTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.addCleanup(self.tempdir.cleanup)
        self.root = Path(self.tempdir.name)
        self.xml = self.root / "win10.xml"

    def run_checker(self) -> subprocess.CompletedProcess[str]:
        command = [sys.executable, str(CHECKER), str(self.xml)]
        try:
            return subprocess.run(
                command,
                check=False,
                capture_output=True,
                text=True,
                timeout=SUBPROCESS_TIMEOUT_SECONDS,
            )
        except subprocess.TimeoutExpired as exc:
            stdout = exc.stdout or ""
            stderr = exc.stderr or ""
            if isinstance(stdout, bytes):
                stdout = stdout.decode("utf-8", errors="replace")
            if isinstance(stderr, bytes):
                stderr = stderr.decode("utf-8", errors="replace")
            stderr = (
                f"{stderr.rstrip()}\n"
                "TIMEOUT: check-vm-iso-paths.py did not finish within "
                f"{SUBPROCESS_TIMEOUT_SECONDS} seconds"
            ).lstrip()
            return subprocess.CompletedProcess(command, 124, stdout, stderr)

    def write_xml(self, body: str) -> None:
        self.xml.write_text(f"<domain><devices>{body}</devices></domain>\n", encoding="utf-8")

    @staticmethod
    def cdrom(source: str) -> str:
        return f'<disk device="cdrom"><source {source}/></disk>'

    def test_checker_timeout_is_reported_clearly(self) -> None:
        with patch(
            "subprocess.run",
            side_effect=subprocess.TimeoutExpired(
                "check-vm-iso-paths.py", SUBPROCESS_TIMEOUT_SECONDS
            ),
        ):
            result = self.run_checker()

        self.assertEqual(result.returncode, 124)
        self.assertIn("TIMEOUT", result.stderr)
        self.assertIn(f"{SUBPROCESS_TIMEOUT_SECONDS} seconds", result.stderr)

    def test_existing_file_backed_sources_pass(self) -> None:
        windows_iso = self.root / "windows.iso"
        virtio_iso = self.root / "virtio.iso"
        windows_iso.write_bytes(b"test")
        virtio_iso.write_bytes(b"test")
        self.write_xml(
            self.cdrom(f'file="{windows_iso}"')
            + self.cdrom(f'file="{virtio_iso}"')
        )

        result = self.run_checker()

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("2 file path(s) checked", result.stdout)

    def test_missing_file_backed_source_fails_with_path(self) -> None:
        missing_iso = self.root / "missing.iso"
        self.write_xml(self.cdrom(f'file="{missing_iso}"'))

        result = self.run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(str(missing_iso), result.stdout)
        self.assertIn("preflight failed", result.stdout)

    def test_malformed_xml_fails_closed(self) -> None:
        self.xml.write_text("<domain><devices>", encoding="utf-8")

        result = self.run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Cannot read valid VM XML", result.stdout)

    def test_wrong_root_fails_closed(self) -> None:
        self.xml.write_text(
            '<not-domain><devices><disk device="cdrom"><source dev="/dev/sr0"/></disk></devices></not-domain>',
            encoding="utf-8",
        )

        result = self.run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("root must be <domain>", result.stdout)

    def test_missing_cdrom_fails_closed(self) -> None:
        self.write_xml('<disk device="disk"><source file="/tmp/disk.qcow2"/></disk>')

        result = self.run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("No CD-ROM devices", result.stdout)

    def test_host_device_source_is_reported_and_allowed(self) -> None:
        self.write_xml(self.cdrom('dev="/dev/sr0"'))

        result = self.run_checker()

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("filesystem existence check skipped", result.stdout)

    def test_relative_file_path_fails_closed(self) -> None:
        self.write_xml(self.cdrom('file="relative/windows.iso"'))

        result = self.run_checker()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("must be absolute", result.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
