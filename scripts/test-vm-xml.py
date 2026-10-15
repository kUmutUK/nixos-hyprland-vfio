#!/usr/bin/env python3
"""Check project-specific invariants in the Windows VM XML template."""
from __future__ import annotations

import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
XML_PATH = ROOT / "vm-xml" / "win10.xml"
HOOK_PATH = ROOT / "nixos" / "hooks" / "qemu"


def fail(message: str) -> int:
    print(f"FAIL: {message}", file=sys.stderr)
    return 1


def main() -> int:
    try:
        root = ET.parse(XML_PATH).getroot()
    except (ET.ParseError, OSError) as exc:
        return fail(f"cannot parse {XML_PATH}: {exc}")

    if root.tag != "domain":
        return fail("root element must be <domain>")
    name = root.findtext("name")
    if name != "win10":
        return fail(f"expected domain name 'win10', found {name!r}")

    os_type = root.find("./os/type")
    if os_type is None or os_type.get("arch") != "x86_64":
        return fail("OS type must declare arch='x86_64'")
    machine = os_type.get("machine", "")
    if machine != "q35" and not re.fullmatch(r"pc-q35-[0-9]+\.[0-9]+", machine):
        return fail(f"unsupported Q35 machine alias {machine!r}; use 'q35' or a versioned pc-q35-X.Y name")

    disks = root.findall("./devices/disk")
    boot_entries: dict[int, ET.Element] = {}
    for disk in disks:
        boot = disk.find("boot")
        if boot is not None:
            try:
                order = int(boot.get("order", ""))
            except ValueError:
                return fail("disk boot order must be an integer")
            if order in boot_entries:
                return fail(f"duplicate disk boot order {order}")
            boot_entries[order] = disk

    if 1 not in boot_entries:
        return fail("the virtual system disk must remain first in boot order")
    disk_one = boot_entries[1]
    if disk_one.get("device") != "disk" or disk_one.find("target") is None:
        return fail("boot order 1 must refer to the virtual system disk")

    windows_iso = next((d for d in disks if d.find("source") is not None and
                        "Win10_" in d.find("source").get("file", "")), None)
    virtio_iso = next((d for d in disks if d.find("source") is not None and
                       "virtio-win-" in d.find("source").get("file", "")), None)
    if windows_iso is None or windows_iso.get("device") != "cdrom":
        return fail("the Windows installation ISO must be attached as a CD-ROM")
    if virtio_iso is None or virtio_iso.get("device") != "cdrom":
        return fail("the VirtIO driver ISO must be attached as a CD-ROM")
    win_boot = windows_iso.find("boot")
    virtio_boot = virtio_iso.find("boot")
    if win_boot is None or virtio_boot is None:
        return fail("Windows and VirtIO CD-ROM boot priorities must be explicit")
    if int(win_boot.get("order", "99")) >= int(virtio_boot.get("order", "0")):
        return fail("Windows installation ISO must be tried before the VirtIO driver ISO")
    if windows_iso.find("target") is None or windows_iso.find("target").get("bus") != "sata":
        return fail("Windows installation ISO should use the SATA CD-ROM device")

    hostdevs = root.findall("./devices/hostdev[@type='pci']")
    if len(hostdevs) < 2:
        return fail("GPU passthrough template must include the GPU and its audio function")

    def source_bdf(hostdev: ET.Element) -> str | None:
        address = hostdev.find("./source/address")
        if address is None or any(address.get(attr) is None for attr in ("domain", "bus", "slot", "function")):
            return None
        try:
            domain = int(address.get("domain", ""), 0)
            bus = int(address.get("bus", ""), 0)
            slot = int(address.get("slot", ""), 0)
            function = int(address.get("function", ""), 0)
        except ValueError:
            return None
        return f"{domain:04x}:{bus:02x}:{slot:02x}.{function:x}"

    xml_bdfs = [source_bdf(hostdev) for hostdev in hostdevs]
    if any(bdf is None for bdf in xml_bdfs):
        return fail("every PCI hostdev must have a complete, numeric source address")

    try:
        hook_text = HOOK_PATH.read_text(encoding="utf-8")
    except OSError as exc:
        return fail(f"cannot read QEMU hook {HOOK_PATH}: {exc}")

    def hook_pci_value(variable: str) -> str | None:
        match = re.search(rf'^{re.escape(variable)}="([0-9a-fA-F:_.]+)"$', hook_text, re.MULTILINE)
        return match.group(1).lower() if match else None

    hook_gpu = hook_pci_value("GPU_PCI")
    hook_audio = hook_pci_value("GPU_AUDIO")
    if hook_gpu is None or hook_audio is None:
        return fail("QEMU hook must declare literal GPU_PCI and GPU_AUDIO defaults")
    if hook_gpu == hook_audio:
        return fail("QEMU hook GPU and audio defaults must be different PCI functions")
    if set(xml_bdfs) != {hook_gpu, hook_audio}:
        return fail(
            "VM XML GPU/audio source PCI addresses must match QEMU hook defaults; "
            f"XML={sorted(xml_bdfs)}, hook={[hook_gpu, hook_audio]}"
        )

    print("OK: VM XML invariants passed (well-formedness, Q35, boot order, and PCI addresses matching the QEMU hook).")
    print("NOTE: this test does not replace a libvirt/QEMU semantic validation or a real VM boot test.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
