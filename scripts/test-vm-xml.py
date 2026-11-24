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
HOOK_PATH = ROOT / "nixos" / "hosts" / "nixos" / "hooks" / "qemu"


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
    parser.add_argument(
        "--guest",
        choices=("win10", "win11"),
        default="win10",
        help="guest template identity to validate (win10 keeps Secure Boot off; win11 requires the MS-keys firmware)",
    )
    return parser.parse_args()


def fail(message: str, code: str | None = None) -> int:
    diagnostic = f" [{code}]" if code else ""
    print(f"FAIL{diagnostic}: {message}", file=sys.stderr)
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
    if name != args.guest:
        return fail(f"expected domain name {args.guest!r}, found {name!r}")

    firmware_features = {
        feature.get("name"): feature.get("enabled")
        for feature in root.findall("./os/firmware/feature")
    }
    if args.guest == "win11":
        if firmware_features.get("secure-boot") != "yes":
            return fail("the win11 template must enable the secure-boot firmware feature")
        if firmware_features.get("enrolled-keys") != "yes":
            return fail("the win11 template must use firmware with enrolled keys so Secure Boot can verify Windows bootloaders")
        loader = root.findtext("./os/loader")
        if loader != "/run/libvirt/nix-ovmf/edk2-x86_64-secure-code.fd":
            return fail(f"the win11 template must load the Secure Boot OVMF image edk2-x86_64-secure-code.fd, found {loader!r}")
        nvram = root.findtext("./os/nvram")
        if not nvram or not nvram.endswith("/win11_VARS.fd"):
            return fail(f"the win11 template must keep its own NVRAM image win11_VARS.fd, found {nvram!r}")
        smm = root.find("./features/smm")
        if smm is None or smm.get("state") != "on":
            return fail("the win11 template must enable SMM for Secure Boot variable protection")
    else:
        if firmware_features.get("secure-boot") == "yes":
            return fail("the win10 template stays on the non-Secure-Boot OVMF image; changing it requires a new validation attestation")

    tpm = root.find("./devices/tpm")
    tpm_backend = tpm.find("./backend") if tpm is not None else None
    if (
        tpm is None
        or tpm.get("model") != "tpm-crb"
        or tpm_backend is None
        or tpm_backend.get("type") != "emulator"
        or tpm_backend.get("version") != "2.0"
    ):
        return fail("VM XML must declare the swtpm-backed TPM 2.0 device (tpm-crb emulator)")

    sound = root.find("./devices/sound")
    if sound is None or sound.get("model") != "ich9":
        return fail("VM XML must declare the ICH9 sound device")
    sound_audio = sound.find("audio")
    if sound_audio is None or not sound_audio.get("id"):
        return fail("ICH9 sound device must reference a declared audio backend")
    audio_id = sound_audio.get("id")
    matching_backends = [
        backend for backend in root.findall("./devices/audio")
        if backend.get("id") == audio_id
    ]
    if len(matching_backends) != 1:
        return fail(
            "ICH9 sound device must reference exactly one declared audio backend; "
            f"audio id={audio_id!r}, matching backends={len(matching_backends)}"
        )

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
            return fail(
                f"{role} CD-ROM must use SATA target {expected_dev}",
                code="VMXML-E-CDROM-SATA",
            )
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

    # The read-only virtiofs share: libvirt spawns the Rust virtiofsd from the
    # libvirtd service PATH (see configuration.nix), and the guest may only
    # read the shared host directory. `readonly` is mandatory so a compromised
    # guest cannot write to host files.
    filesystems = root.findall("./devices/filesystem[@type='mount']")
    if len(filesystems) != 1:
        return fail("VM XML must contain exactly one mount filesystem device (the virtiofs host share)")
    virtiofs = filesystems[0]
    virtiofs_driver = virtiofs.find("driver")
    if virtiofs_driver is None or virtiofs_driver.get("type") != "virtiofs":
        return fail("the filesystem device must use driver type='virtiofs'")
    if virtiofs.get("accessmode") != "passthrough":
        return fail("the virtiofs device must use accessmode='passthrough'")
    if virtiofs.find("readonly") is None:
        return fail("the virtiofs device must be read-only; remove <readonly/> only with a new validation attestation")
    share_source = virtiofs.find("source")
    share_dir = share_source.get("dir", "").strip() if share_source is not None else ""
    if not share_dir or not Path(share_dir).is_absolute():
        return fail(f"the virtiofs source dir must be a non-empty absolute path, found {share_dir!r}")
    share_target_element = virtiofs.find("target")
    share_target = (
        share_target_element.get("dir", "").strip()
        if share_target_element is not None
        else ""
    )
    if not share_target:
        return fail("the virtiofs target dir must be a non-empty tag name")

    # Every PCI address in the device topology must be unique. Controllers sit
    # on bus 0x00 slots; plugged devices sit on the root-port buses, so a
    # collision means a malformed template.
    pci_addresses: list[tuple[str, str, str, str]] = []
    for element in root.iter("address"):
        if element.get("type") == "pci":
            address_key = (
                element.get("domain", ""),
                element.get("bus", ""),
                element.get("slot", ""),
                element.get("function", ""),
            )
            if "" in address_key:
                return fail("every PCI address must declare domain, bus, slot, and function")
            if address_key in pci_addresses:
                return fail(
                    "PCI addresses must be unique across controllers and devices; duplicate: "
                    + ":".join(address_key)
                )
            pci_addresses.append(address_key)

    # Keep the two documented, non-optional USB devices as the required
    # template baseline. Additional machine-specific devices are allowed only
    # when their source explicitly marks them optional, so an unplugged phone
    # or other removable device cannot prevent the VM from starting.
    # install.sh synchronizes PCI source addresses only; it does not discover
    # or replace USB IDs.
    usb_hostdevs = root.findall("./devices/hostdev[@type='usb']")
    expected_usb_ids = {(0x1532, 0x0098), (0x05AC, 0x024F)}
    required_usb_ids: list[tuple[int, int]] = []
    optional_usb_ids: list[tuple[int, int]] = []
    all_usb_ids: list[tuple[int, int]] = []
    for hostdev in usb_hostdevs:
        source = hostdev.find("./source")
        vendor = source.find("vendor") if source is not None else None
        product = source.find("product") if source is not None else None
        if vendor is None or product is None:
            return fail("every USB hostdev must declare both vendor and product IDs")
        startup_policy = source.get("startupPolicy")
        if startup_policy not in (None, "optional"):
            return fail(
                "USB hostdev source must omit startupPolicy for required devices "
                "or set startupPolicy='optional' for additional devices"
            )
        try:
            vendor_id = int(vendor.get("id", ""), 0)
            product_id = int(product.get("id", ""), 0)
        except ValueError:
            return fail("USB hostdev vendor/product IDs must be numeric")
        usb_id = (vendor_id, product_id)
        all_usb_ids.append(usb_id)
        if startup_policy == "optional":
            optional_usb_ids.append(usb_id)
        else:
            required_usb_ids.append(usb_id)

    if len(all_usb_ids) != len(set(all_usb_ids)):
        return fail("USB hostdev vendor/product ID pairs must be unique")
    if len(required_usb_ids) != len(expected_usb_ids):
        formatted_required = sorted(f"{vendor:04x}:{product:04x}" for vendor, product in required_usb_ids)
        return fail(
            "VM XML must contain exactly two required USB hostdev entries; "
            "mark every additional USB device with source startupPolicy='optional'; "
            f"required XML IDs={formatted_required}"
        )
    if not args.allow_custom_usb_ids and set(required_usb_ids) != expected_usb_ids:
        formatted = sorted(f"{vendor:04x}:{product:04x}" for vendor, product in required_usb_ids)
        expected = sorted(f"{vendor:04x}:{product:04x}" for vendor, product in expected_usb_ids)
        return fail(
            "the two required USB passthrough IDs must match the default template "
            "unless --allow-custom-usb-ids is set; "
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

    print("OK: VM XML invariants passed (Q35, separate Windows/NixOS VirtIO disks, optional NixOS disk, three SATA CD-ROMs with an empty NixOS tray, ICH9-to-PipeWire audio association, USB passthrough, GPU/audio PCI addresses matching the QEMU hook, swtpm TPM 2.0, and the read-only virtiofs host share).")
    print("NOTE: this test does not replace a libvirt/QEMU semantic validation or a real VM boot test.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
