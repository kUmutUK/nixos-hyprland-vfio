#!/usr/bin/env python3
"""Regression tests for the VM ISO path checker."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

CHECKER = Path(__file__).with_name("check-vm-iso-paths.py")


class CheckVmIsoPathsTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.addCleanup(self.tempdir.cleanup)
        self.root = Path(self.tempdir.name)
        self.xml = self.root / "win10.xml"

    def run_checker(self) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(CHECKER), str(self.xml)],
            check=False,
            capture_output=True,
            text=True,
        )

    def write_xml(self, body: str) -> None:
        self.xml.write_text(f"<domain><devices>{body}</devices></domain>\n", encoding="utf-8")

    @staticmethod
    def cdrom(source: str) -> str:
        return f'<disk device="cdrom"><source {source}/></disk>'

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
