#!/usr/bin/env python3
"""Check project-specific invariants in the Windows VM XML template."""
from __future__ import annotations

import argparse
import os
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
XML_PATH = ROOT / "vm-xml" / "win10.xml"
HOOK_PATH = ROOT / "nixos" / "hooks" / "qemu"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check VM XML invariants and compare its PCI addresses with a QEMU hook."
    )
    parser.add_argument(
        "--xml-path",
        type=Path,
        default=XML_PATH,
        help=f"VM XML to validate (default: {XML_PATH})",
    )
    parser.add_argument(
        "--hook-path",
        type=Path,
        default=HOOK_PATH,
        help=f"QEMU hook whose GPU_PCI/GPU_AUDIO values are checked (default: {HOOK_PATH})",
    )
    parser.add_argument(
        "--allow-custom-usb-ids",
        action="store_true",
        help="allow local USB vendor/product IDs while still validating their numeric format and count",
    )
    return parser.parse_args()


def fail(message: str) -> int:
    print(f"FAIL: {message}", file=sys.stderr)
    return 1


def main() -> int:
    args = parse_args()
    try:
        root = ET.parse(args.xml_path).getroot()
    except (ET.ParseError, OSError) as exc:
        return fail(f"cannot parse {args.xml_path}: {exc}")

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

    hard_disks = root.findall("./devices/disk[@device='disk']")
    if len(hard_disks) != 2:
        return fail("VM XML must contain exactly two virtual system disks (Windows vda and NixOS vdb)")

    for order, role, expected_dev in (
        (1, "Windows", "vda"),
        (2, "NixOS", "vdb"),
    ):
        disk = boot_entries.get(order)
        if disk is None or disk.get("device") != "disk":
            return fail(f"boot order {order} must refer to the {role} virtual system disk")
        target = disk.find("target")
        if target is None or target.get("dev") != expected_dev:
            return fail(f"boot order {order} must target {expected_dev} for the {role} virtual system disk")
        if target.get("bus") != "virtio":
            return fail(f"the {role} virtual system disk must use the virtio bus")
        source = disk.find("source")
        source_path = source.get("file", "").strip() if source is not None else ""
        if disk.get("type") != "file" or not source_path:
            return fail(f"the {role} virtual system disk must use a file-backed source")
        if not Path(source_path).is_absolute():
            return fail(f"{role} virtual disk source path must be absolute: {source_path!r}")

    windows_disk = boot_entries[1]
    nixos_disk = boot_entries[2]
    windows_source = windows_disk.find("source")
    nixos_source = nixos_disk.find("source")
    windows_path = os.path.normpath(windows_source.get("file", "").strip())
    nixos_path = os.path.normpath(nixos_source.get("file", "").strip())
    if windows_path == nixos_path:
        return fail("Windows and NixOS virtual disk source paths must be different")
    if nixos_source.get("startupPolicy") != "optional":
        return fail("the NixOS virtual disk must use startupPolicy='optional' so Windows can start before it is created")
    nixos_driver = nixos_disk.find("driver")
    if nixos_driver is None or nixos_driver.get("type") != "qcow2":
        return fail("the NixOS virtual disk must use the qcow2 format")

    # The first two SATA CD-ROMs carry the Windows installer and VirtIO drivers.
    # The third SATA CD-ROM is deliberately an empty tray: attach the NixOS ISO
    # only when needed so a missing/unconfigured installer cannot block Windows.
    cdroms = root.findall("./devices/disk[@device='cdrom']")
    if len(cdroms) != 3:
        return fail(
            "VM XML must contain exactly three CD-ROM devices "
            "(Windows installer, VirtIO driver, and an empty NixOS installer tray)"
        )

    cdroms.sort(key=lambda disk: int(disk.find("boot").get("order", "")) if disk.find("boot") is not None else 0)
    cdrom_orders = [
        int(cdrom.find("boot").get("order", "")) if cdrom.find("boot") is not None else None
        for cdrom in cdroms
    ]
    if cdrom_orders != [3, 4, 5]:
        return fail("Windows, VirtIO, and NixOS CD-ROM boot priorities must be 3, 4, and 5 after both virtual disks")

    cdrom_paths: list[str] = []
    for role, cdrom, expected_dev in (
        ("Windows installer", cdroms[0], "sdb"),
        ("VirtIO driver", cdroms[1], "sdc"),
    ):
        target = cdrom.find("target")
        if target is None or target.get("bus") != "sata" or target.get("dev") != expected_dev:
            return fail(f"{role} CD-ROM must use SATA target {expected_dev}")
        source = cdrom.find("source")
        if source is None:
            return fail(f"{role} CD-ROM must declare a file-backed source path")
        source_path = source.get("file", "").strip()
        if not source_path:
            return fail(f"{role} CD-ROM must declare a non-empty source file path")
        if not Path(source_path).is_absolute():
            return fail(f"CD-ROM source paths must be absolute: {source_path!r}")
        normalized_path = os.path.normpath(source_path)
        if normalized_path in cdrom_paths:
            return fail("Windows and VirtIO CD-ROM source paths must be different")
        cdrom_paths.append(normalized_path)

    nixos_cdrom = cdroms[2]
    nixos_target = nixos_cdrom.find("target")
    if nixos_target is None or nixos_target.get("bus") != "sata" or nixos_target.get("dev") != "sdd":
        return fail("NixOS installer CD-ROM must use SATA target sdd")
    nixos_tray_source = nixos_cdrom.find("source")
    if nixos_tray_source is not None and (nixos_tray_source.attrib or len(nixos_tray_source)):
        return fail("NixOS CD-ROM tray must start empty; attach the installer ISO on demand")

    # The default template intentionally includes two active USB passthrough
    # entries. Keep this invariant in sync with the README: install.sh only
    # synchronizes PCI source addresses and does not discover/replace USB IDs.
    usb_hostdevs = root.findall("./devices/hostdev[@type='usb']")
    expected_usb_ids = {(0x1532, 0x0098), (0x05AC, 0x024F)}
    actual_usb_ids: list[tuple[int, int]] = []
    for hostdev in usb_hostdevs:
        source = hostdev.find("./source")
        vendor = source.find("vendor") if source is not None else None
        product = source.find("product") if source is not None else None
        if vendor is None or product is None:
            return fail("every USB hostdev must declare both vendor and product IDs")
        try:
            vendor_id = int(vendor.get("id", ""), 0)
            product_id = int(product.get("id", ""), 0)
        except ValueError:
            return fail("USB hostdev vendor/product IDs must be numeric")
        actual_usb_ids.append((vendor_id, product_id))

    if len(actual_usb_ids) != len(expected_usb_ids) or (
        not args.allow_custom_usb_ids and set(actual_usb_ids) != expected_usb_ids
    ):
        formatted = sorted(f"{vendor:04x}:{product:04x}" for vendor, product in actual_usb_ids)
        expected = sorted(f"{vendor:04x}:{product:04x}" for vendor, product in expected_usb_ids)
        return fail(
            "XML USB passthrough IDs must contain exactly two numeric devices; "
            "default template IDs must match unless --allow-custom-usb-ids is set; "
            f"XML={formatted}, expected={expected}"
        )

    hostdevs = root.findall("./devices/hostdev[@type='pci']")
    if len(hostdevs) != 2:
        return fail(
            "GPU passthrough template must contain exactly two PCI hostdevs "
            f"(GPU and audio function); found {len(hostdevs)}"
        )

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

    # A set comparison alone can hide duplicate entries: sets collapse repeated
    # BDFs. Check uniqueness explicitly before comparing with the two hook defaults.
    normalized_xml_bdfs = [bdf.lower() for bdf in xml_bdfs if bdf is not None]
    if len(set(normalized_xml_bdfs)) != len(normalized_xml_bdfs):
        return fail("PCI hostdev source addresses must be unique; duplicate BDF found")

    try:
        hook_text = args.hook_path.read_text(encoding="utf-8")
    except OSError as exc:
        return fail(f"cannot read QEMU hook {args.hook_path}: {exc}")

    def hook_pci_value(variable: str) -> str | None:
        match = re.search(rf'^{re.escape(variable)}="([0-9a-fA-F:_.]+)"$', hook_text, re.MULTILINE)
        return match.group(1).lower() if match else None

    hook_gpu = hook_pci_value("GPU_PCI")
    hook_audio = hook_pci_value("GPU_AUDIO")
    if hook_gpu is None or hook_audio is None:
        return fail("QEMU hook must declare literal GPU_PCI and GPU_AUDIO defaults")
    if hook_gpu == hook_audio:
        return fail("QEMU hook GPU and audio defaults must be different PCI functions")
    if set(normalized_xml_bdfs) != {hook_gpu, hook_audio}:
        return fail(
            "VM XML GPU/audio source PCI addresses must match QEMU hook defaults; "
            f"XML={sorted(xml_bdfs)}, hook={[hook_gpu, hook_audio]}"
        )

    print("OK: VM XML invariants passed (Q35, separate Windows/NixOS VirtIO disks, optional NixOS disk, three SATA CD-ROMs with an empty NixOS tray, USB passthrough, and GPU/audio PCI addresses matching the QEMU hook).")
    print("NOTE: this test does not replace a libvirt/QEMU semantic validation or a real VM boot test.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
