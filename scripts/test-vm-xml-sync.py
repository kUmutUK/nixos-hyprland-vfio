#!/usr/bin/env python3
"""Regression tests for preserving deployed VM XML during PCI synchronization."""
from __future__ import annotations

import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "scripts" / "sync-vm-xml.py"
TEMPLATE = ROOT / "vm-xml" / "win10.xml"
GPU = "0000:0b:02.0"
AUDIO = "0000:0b:02.1"


def fail(message: str) -> int:
    print(f"FAIL: {message}", file=sys.stderr)
    return 1


def run_sync(template: Path, destination: Path, gpu: str = GPU, audio: str = AUDIO) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(HELPER), gpu, audio, str(template), str(destination)],
        text=True,
        capture_output=True,
        check=False,
    )


def source_bdf(hostdev: ET.Element) -> str | None:
    address = hostdev.find("./source/address")
    if address is None:
        return None
    try:
        values = [int(address.get(key, ""), 0) for key in ("domain", "bus", "slot", "function")]
    except ValueError:
        return None
    return f"{values[0]:04x}:{values[1]:02x}:{values[2]:02x}.{values[3]:x}"


def main() -> int:
    template_data = TEMPLATE.read_text(encoding="utf-8")

    # A new VM starts from the template but must receive a fresh UUID/MAC.
    with tempfile.TemporaryDirectory(prefix="vm-xml-sync-new-") as temp:
        temp_path = Path(temp)
        template = temp_path / "template.xml"
        deployed = temp_path / "win10.xml"
        template.write_text(template_data, encoding="utf-8")
        result = run_sync(template, deployed)
        if result.returncode != 0 or not deployed.is_file():
            return fail(f"new VM sync failed: {result.stdout}{result.stderr}")
        generated = ET.parse(deployed).getroot()
        original = ET.fromstring(template_data)
        if generated.findtext("uuid") == original.findtext("uuid"):
            return fail("new VM must not reuse the template UUID")
        original_mac = original.find("./devices/interface/mac")
        generated_mac = generated.find("./devices/interface/mac")
        if original_mac is None or generated_mac is None or original_mac.get("address") == generated_mac.get("address"):
            return fail("new VM must not reuse the template MAC address")
        got = [source_bdf(node) for node in generated.findall("./devices/hostdev[@type='pci']")]
        if got != [GPU, AUDIO]:
            return fail(f"new VM GPU/audio PCI addresses were not synchronized in order: {got!r}")

    # Existing VM: preserve every non-PCI customization, identity and disk path.
    with tempfile.TemporaryDirectory(prefix="vm-xml-sync-existing-") as temp:
        temp_path = Path(temp)
        template = temp_path / "template.xml"
        deployed = temp_path / "win10.xml"
        template.write_text(template_data, encoding="utf-8")
        custom_uuid = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee"
        custom_mac = "52:54:00:aa:bb:cc"
        custom_disk = "/var/lib/libvirt/images/my-existing-windows.qcow2"
        custom_data = template_data.replace(
            "<uuid>3def90f6-01d9-4640-badb-1488b66bec29</uuid>",
            f"<uuid>{custom_uuid}</uuid>",
            1,
        )
        custom_data = custom_data.replace('address="52:54:00:df:49:0b"', f'address="{custom_mac}"', 1)
        custom_data = custom_data.replace(
            "/var/lib/libvirt/images/win10new.qcow2", custom_disk, 1
        )
        custom_data = custom_data.replace(
            '<vcpu placement="static" current="6">6</vcpu>',
            '<vcpu placement="static" current="4">4</vcpu>',
            1,
        )
        # The PCI updater must retain non-BDF source-address attributes too.
        custom_data = custom_data.replace(
            'slot="0x00" function="0x0"/>',
            'slot="0x00" function="0x0" multifunction="on"/>',
            1,
        )
        custom_data = custom_data.replace(
            "  <memory unit=\"KiB\">16777216</memory>",
            '  <metadata><audit-setting>preserve-me</audit-setting></metadata>\n  <memory unit="KiB">16777216</memory>',
            1,
        )
        if custom_uuid not in custom_data or custom_mac not in custom_data or custom_disk not in custom_data or '<vcpu placement="static" current="4">4</vcpu>' not in custom_data or "preserve-me" not in custom_data:
            return fail("test fixture failed to create the expected VM customizations")
        deployed.write_text(custom_data, encoding="utf-8")
        before_usb = [
            ET.tostring(node, encoding="unicode")
            for node in ET.fromstring(custom_data).findall("./devices/hostdev[@type='usb']")
        ]

        result = run_sync(template, deployed)
        if result.returncode != 0:
            return fail(f"existing VM sync failed: {result.stdout}{result.stderr}")
        updated_data = deployed.read_text(encoding="utf-8")
        updated = ET.fromstring(updated_data)
        if updated.findtext("uuid") != custom_uuid:
            return fail("existing VM UUID was changed")
        updated_mac = updated.find("./devices/interface/mac")
        if updated_mac is None or updated_mac.get("address") != custom_mac:
            return fail("existing VM MAC address was changed")
        disk = updated.find("./devices/disk[@device='disk']/source")
        if disk is None or disk.get("file") != custom_disk:
            return fail("existing Windows disk path was changed")
        vcpu = updated.find("vcpu")
        if vcpu is None or vcpu.text != "4" or vcpu.get("current") != "4":
            return fail("custom CPU topology/vCPU configuration was changed")
        if "preserve-me" not in updated_data:
            return fail("custom metadata was lost")
        if 'multifunction="on"' not in updated_data:
            return fail("extra PCI source-address attributes were not preserved")
        after_usb = [
            ET.tostring(node, encoding="unicode")
            for node in updated.findall("./devices/hostdev[@type='usb']")
        ]
        if before_usb != after_usb:
            return fail("USB hostdev entries were modified during PCI synchronization")
        got = [source_bdf(node) for node in updated.findall("./devices/hostdev[@type='pci']")]
        if got != [GPU, AUDIO]:
            return fail(f"existing VM GPU/audio PCI addresses were not synchronized: {got!r}")
        backups = list(temp_path.glob("win10.xml.bak-*"))
        if len(backups) != 1 or backups[0].read_text(encoding="utf-8") != custom_data:
            return fail("existing deployed VM XML was not backed up byte-for-byte")

    # Reversing the two PCI hostdev blocks must not reverse GPU/audio roles.
    # The reviewed guest-side PCI target addresses, not document order, identify roles.
    with tempfile.TemporaryDirectory(prefix="vm-xml-sync-reordered-") as temp:
        temp_path = Path(temp)
        template = temp_path / "template.xml"
        deployed = temp_path / "win10.xml"
        template.write_text(template_data, encoding="utf-8")
        pci_blocks = list(
            re.finditer(
                r'<hostdev\b(?=[^>]*\btype=["\']pci["\'])[^>]*>.*?</hostdev>',
                template_data,
                re.DOTALL,
            )
        )
        if len(pci_blocks) != 2:
            return fail("could not identify exactly two PCI hostdev blocks for reorder test")
        first, second = pci_blocks
        first_block = template_data[first.start():first.end()]
        second_block = template_data[second.start():second.end()]
        reordered = (
            template_data[:first.start()]
            + second_block
            + template_data[first.end():second.start()]
            + first_block
            + template_data[second.end():]
        )
        deployed.write_text(reordered, encoding="utf-8")
        result = run_sync(template, deployed)
        if result.returncode != 0:
            return fail(f"reordered but otherwise supported PCI hostdev XML was rejected: {result.stdout}{result.stderr}")
        updated = ET.parse(deployed).getroot()
        role_sources: dict[str, str | None] = {}
        for hostdev in updated.findall("./devices/hostdev[@type='pci']"):
            target = hostdev.find("./address")
            if target is None:
                return fail("reordered PCI hostdev lost its guest-side target address")
            try:
                target_key = tuple(
                    int(target.get(key, ""), 0)
                    for key in ("domain", "bus", "slot", "function")
                )
            except ValueError:
                return fail("reordered PCI hostdev has an invalid guest-side target address")
            role_sources[str(target_key)] = source_bdf(hostdev)
        expected = {"(0, 6, 0, 0)": GPU, "(0, 7, 0, 0)": AUDIO}
        if role_sources != expected:
            return fail(f"GPU/audio roles changed when PCI hostdev blocks were reordered: {role_sources!r}")

    # Unknown guest-side targets make the GPU/audio role ambiguous and must fail closed.
    with tempfile.TemporaryDirectory(prefix="vm-xml-sync-unknown-target-") as temp:
        temp_path = Path(temp)
        template = temp_path / "template.xml"
        deployed = temp_path / "win10.xml"
        template.write_text(template_data, encoding="utf-8")
        unknown_target = template_data.replace(
            '<address type="pci" domain="0x0000" bus="0x06" slot="0x00" function="0x0"/>',
            '<address type="pci" domain="0x0000" bus="0x08" slot="0x00" function="0x0"/>',
            1,
        )
        if unknown_target == template_data:
            return fail("test fixture failed to change the guest-side PCI target")
        deployed.write_text(unknown_target, encoding="utf-8")
        result = run_sync(template, deployed)
        if result.returncode == 0:
            return fail("unknown guest-side PCI target was not rejected")
        if deployed.read_text(encoding="utf-8") != unknown_target:
            return fail("unknown guest-side PCI target was modified despite validation failure")
        if list(temp_path.glob("win10.xml.bak-*")):
            return fail("unknown guest-side PCI target should fail before creating a backup")

    # Unsupported custom XML must fail closed and must leave the current XML intact.
    with tempfile.TemporaryDirectory(prefix="vm-xml-sync-unsupported-") as temp:
        temp_path = Path(temp)
        template = temp_path / "template.xml"
        deployed = temp_path / "win10.xml"
        template.write_text(template_data, encoding="utf-8")
        extra_pci = '<hostdev mode="subsystem" type="pci"><source><address domain="0x0000" bus="0x0c" slot="0x00" function="0x0"/></source></hostdev>'
        unsupported = template_data.replace("</devices>", f"{extra_pci}</devices>", 1)
        deployed.write_text(unsupported, encoding="utf-8")
        result = run_sync(template, deployed)
        if result.returncode == 0:
            return fail("existing XML with an extra PCI hostdev should be rejected")
        if deployed.read_text(encoding="utf-8") != unsupported:
            return fail("unsupported existing XML was modified despite validation failure")
        if list(temp_path.glob("win10.xml.bak-*")):
            return fail("unsupported existing XML should fail before creating a replacement backup")

    # Invalid/equal PCI addresses must be rejected before any destination is created.
    with tempfile.TemporaryDirectory(prefix="vm-xml-sync-invalid-") as temp:
        temp_path = Path(temp)
        template = temp_path / "template.xml"
        deployed = temp_path / "win10.xml"
        template.write_text(template_data, encoding="utf-8")
        result = run_sync(template, deployed, GPU, GPU)
        if result.returncode == 0 or deployed.exists():
            return fail("duplicate GPU/audio PCI addresses were not rejected before writing")

    print("OK: VM XML sync preserves custom settings and identity, maps GPU/audio by reviewed guest PCI targets regardless of XML order, backs up first, and fails closed on unsupported layouts.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
