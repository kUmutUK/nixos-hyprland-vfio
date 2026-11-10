#!/usr/bin/env python3
"""Regression tests for structural VM XML validation with custom ISO paths."""
from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VALIDATOR = ROOT / "scripts" / "test-vm-xml.py"
TEMPLATE = ROOT / "vm-xml" / "win10.xml"
HOOK = ROOT / "nixos" / "hooks" / "qemu"
TIMEOUT_SECONDS = 30


class VmXmlStructureTests(unittest.TestCase):
    def setUp(self) -> None:
        self.root = ET.parse(TEMPLATE).getroot()

    def run_validator(self) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory(prefix="vm-xml-structure-") as temp:
            xml_path = Path(temp) / "custom-win10.xml"
            ET.ElementTree(self.root).write(xml_path, encoding="unicode")
            return subprocess.run(
                [
                    sys.executable,
                    str(VALIDATOR),
                    "--xml-path",
                    str(xml_path),
                    "--hook-path",
                    str(HOOK),
                ],
                check=False,
                capture_output=True,
                text=True,
                timeout=TIMEOUT_SECONDS,
            )

    def test_custom_iso_filenames_and_paths_pass(self) -> None:
        cdroms = self.root.findall("./devices/disk[@device='cdrom']")
        self.assertEqual(len(cdroms), 3)
        cdroms[0].find("source").set("file", "/mnt/install media/WindowsInstall.iso")
        cdroms[1].find("source").set("file", "/srv/iso/virtio.iso")

        result = self.run_validator()

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("VM XML invariants passed", result.stdout)

    def test_duplicate_iso_source_paths_fail(self) -> None:
        cdroms = self.root.findall("./devices/disk[@device='cdrom']")
        cdroms[1].find("source").set(
            "file", cdroms[0].find("source").get("file")
        )

        result = self.run_validator()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("source paths must be different", result.stderr)

    def test_relative_iso_source_path_fails(self) -> None:
        cdrom = self.root.find("./devices/disk[@device='cdrom']")
        cdrom.find("source").set("file", "WindowsInstall.iso")

        result = self.run_validator()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("source paths must be absolute", result.stderr)

    def test_empty_iso_source_path_fails(self) -> None:
        cdrom = self.root.find("./devices/disk[@device='cdrom']")
        cdrom.find("source").set("file", "  ")

        result = self.run_validator()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("non-empty source file path", result.stderr)

    def test_exactly_three_cdrom_devices_are_required(self) -> None:
        devices = self.root.find("./devices")
        cdroms = self.root.findall("./devices/disk[@device='cdrom']")
        devices.remove(cdroms[-1])

        result = self.run_validator()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("exactly three CD-ROM devices", result.stderr)

    def test_nixos_disk_must_be_optional(self) -> None:
        nixos_disk = next(disk for disk in self.root.findall("./devices/disk[@device='disk']") if disk.find("target") is not None and disk.find("target").get("dev") == "vdb")
        nixos_disk.find("source").attrib.pop("startupPolicy")

        result = self.run_validator()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("startupPolicy='optional'", result.stderr)

    def test_nixos_cdrom_tray_must_start_empty(self) -> None:
        nixos_cdrom = next(disk for disk in self.root.findall("./devices/disk[@device='cdrom']") if disk.find("target") is not None and disk.find("target").get("dev") == "sdd")
        ET.SubElement(nixos_cdrom, "source", {"file": "/srv/iso/nixos.iso"})

        result = self.run_validator()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("tray must start empty", result.stderr)

    def test_cdrom_boot_order_must_be_explicit(self) -> None:
        cdrom = self.root.find("./devices/disk[@device='cdrom']")
        cdrom.remove(cdrom.find("boot"))

        result = self.run_validator()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("boot priorities must be 3, 4, and 5", result.stderr)

    def test_optical_boot_must_follow_both_virtual_system_disks(self) -> None:
        first_cdrom = min(
            self.root.findall("./devices/disk[@device='cdrom']"),
            key=lambda disk: int(disk.find("boot").get("order")),
        )
        first_cdrom.find("boot").set("order", "0")

        result = self.run_validator()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("boot priorities must be 3, 4, and 5", result.stderr)

    def test_earliest_optical_boot_entry_must_use_sata(self) -> None:
        first_cdrom = min(
            self.root.findall("./devices/disk[@device='cdrom']"),
            key=lambda disk: int(disk.find("boot").get("order")),
        )
        first_cdrom.find("target").set("bus", "virtio")

        result = self.run_validator()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("[VMXML-E-CDROM-SATA]", result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
