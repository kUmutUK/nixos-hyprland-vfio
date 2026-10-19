#!/usr/bin/env python3
"""Synchronize the GPU/audio PCI addresses in a Windows libvirt XML safely."""
from __future__ import annotations

import os
import re
import secrets
import shutil
import stat
import sys
import tempfile
import time
import uuid
import xml.etree.ElementTree as ET
from pathlib import Path

PCI_RE = re.compile(r"^([0-9a-fA-F]{4}):([0-9a-fA-F]{2}):([0-9a-fA-F]{2})\.([0-9a-fA-F])$")
HOSTDEV_ADDRESS_RE = re.compile(
    r"(<hostdev\b(?=[^>]*\btype\s*=\s*['\"]pci['\"])[^>]*>\s*"
    r"(?:<driver\b[^>]*/>\s*)?<source>\s*<address\s+)([^/]+)(/>)",
    re.DOTALL,
)


def fail(message: str) -> "NoReturn":
    raise SystemExit(f"ERROR: {message}")


def pci_address_components(address: str) -> tuple[str, str, str, str]:
    match = PCI_RE.fullmatch(address)
    if not match:
        fail(f"invalid PCI address {address!r}; expected domain:bus:slot.function")
    domain, bus, slot, function = match.groups()
    return (
        f"0x{domain.lower()}",
        f"0x{bus.lower()}",
        f"0x{slot.lower()}",
        f"0x{function.lower()}",
    )


def parse_xml(data: str, description: str) -> ET.Element:
    try:
        root = ET.fromstring(data)
    except ET.ParseError as exc:
        fail(f"{description} is malformed ({exc}); no file was written.")
    if root.tag != "domain":
        fail(f"{description} root must be <domain>; no file was written.")
    return root


def primary_disk_path(root: ET.Element, description: str) -> str:
    disks = root.findall("./devices/disk[@device='disk']")
    if len(disks) != 1:
        fail(
            f"expected exactly one primary file-backed disk in {description}; "
            "inspect and synchronize this XML manually."
        )
    source = disks[0].find("source")
    path = source.get("file") if source is not None else None
    if not path:
        fail(f"the primary disk in {description} is not file-backed; no file was written.")
    return path


def synchronize_pci_addresses(data: str, description: str, addresses: tuple[str, str]) -> str:
    root = parse_xml(data, description)
    hostdevs = root.findall(".//hostdev[@type='pci']")
    if len(hostdevs) != 2:
        fail(
            f"{description} must contain exactly two PCI hostdev elements "
            f"(found {len(hostdevs)}); no file was written."
        )

    comment_spans = [match.span() for match in re.finditer(r"<!--.*?-->", data, re.DOTALL)]
    counter = 0
    replacement_components = tuple(pci_address_components(address) for address in addresses)

    def replace_address(match: re.Match[str]) -> str:
        nonlocal counter
        if any(start <= match.start() < end for start, end in comment_spans):
            return match.group(0)
        index = counter
        counter += 1
        if index >= len(replacement_components):
            return match.group(0)
        source_address = match.group(2)
        # Update only the four BDF attributes. Preserve any additional attributes,
        # original quote style, ordering, spacing, and future libvirt extensions.
        for key, value in zip(("domain", "bus", "slot", "function"), replacement_components[index]):
            attribute = re.compile(rf"(\b{key}\s*=\s*)([\"']).*?\2")
            source_address, changed = attribute.subn(
                lambda attr_match: attr_match.group(1) + attr_match.group(2) + value + attr_match.group(2),
                source_address,
                count=1,
            )
            if changed != 1:
                fail(f"{description} has an unsupported PCI source-address attribute {key!r}.")
        return match.group(1) + source_address + match.group(3)

    rewritten = HOSTDEV_ADDRESS_RE.sub(replace_address, data)
    if counter != 2:
        fail(
            f"{description} does not contain exactly two supported PCI hostdev source-address blocks "
            f"(found {counter}); no file was written."
        )
    # Re-parse the result before touching the deployed path.
    rewritten_root = parse_xml(rewritten, f"synchronized {description}")
    if len(rewritten_root.findall(".//hostdev[@type='pci']")) != 2:
        fail(f"synchronized {description} failed PCI hostdev validation; no file was written.")
    return rewritten


def fresh_identity(data: str) -> str:
    if not re.search(r"<uuid>[^<]+</uuid>", data):
        fail("the XML template does not contain a UUID; no file was written.")
    if not re.search(r'<mac\s+address="[^"]+"\s*/>', data):
        fail("the XML template does not contain a network MAC address; no file was written.")
    vm_uuid = str(uuid.uuid4())
    vm_mac = "52:54:00:" + ":".join(secrets.token_hex(3)[i:i + 2] for i in (0, 2, 4))
    data, uuid_count = re.subn(r"<uuid>[^<]+</uuid>", f"<uuid>{vm_uuid}</uuid>", data, count=1)
    data, mac_count = re.subn(
        r'<mac\s+address="[^"]+"\s*/>', f'<mac address="{vm_mac}"/>', data, count=1
    )
    if uuid_count != 1 or mac_count != 1:
        fail("could not assign a unique VM UUID/MAC to the new XML; no file was written.")
    return data


def atomic_write(destination: Path, data: str, previous_stat: os.stat_result | None) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    target_mode = stat.S_IMODE(previous_stat.st_mode) if previous_stat else 0o644
    temp_path: str | None = None
    try:
        fd, temp_path = tempfile.mkstemp(
            dir=str(destination.parent), prefix=f".{destination.name}.", suffix=".tmp"
        )
        with os.fdopen(fd, "w", encoding="utf-8") as file:
            file.write(data)
            file.flush()
            os.fsync(file.fileno())
        os.chmod(temp_path, target_mode)
        if previous_stat is not None:
            os.chown(temp_path, previous_stat.st_uid, previous_stat.st_gid)
        os.replace(temp_path, destination)
        temp_path = None
        try:
            dir_fd = os.open(destination.parent, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0))
            try:
                os.fsync(dir_fd)
            finally:
                os.close(dir_fd)
        except OSError:
            pass
    finally:
        if temp_path is not None:
            try:
                os.unlink(temp_path)
            except OSError:
                pass


def main() -> int:
    if len(sys.argv) != 5:
        fail("usage: sync-vm-xml.py GPU_PCI GPU_AUDIO TEMPLATE_XML DEPLOYED_XML")
    gpu, audio, template_name, destination_name = sys.argv[1:]
    gpu_components = pci_address_components(gpu)
    audio_components = pci_address_components(audio)
    if gpu_components == audio_components:
        fail("GPU and GPU audio PCI addresses must be different.")

    template_path = Path(template_name)
    destination = Path(destination_name)
    try:
        template_data = template_path.read_text(encoding="utf-8")
    except OSError as exc:
        fail(f"could not read VM XML template {template_path}: {exc}")
    template_root = parse_xml(template_data, "VM XML template")
    if not template_root.findtext("name"):
        fail("VM XML template has no domain name; no file was written.")
    template_disk_path = primary_disk_path(template_root, "the VM XML template")
    # Validate the template's own PCI shape even when an existing XML will be kept.
    synchronize_pci_addresses(template_data, "VM XML template", (gpu, audio))

    if destination.is_symlink():
        fail(f"refusing to replace symlinked VM XML path {destination}.")

    previous_stat: os.stat_result | None = None
    if os.path.lexists(destination):
        if not destination.is_file():
            fail(f"existing deployed VM XML is not a regular file: {destination}.")
        try:
            existing_data = destination.read_text(encoding="utf-8")
        except OSError as exc:
            fail(f"could not read existing deployed VM XML {destination}: {exc}")
        if not existing_data.strip():
            fail("existing deployed VM XML is empty; refusing to replace it automatically.")
        existing_root = parse_xml(existing_data, "existing deployed VM XML")
        if existing_root.findtext("name") != template_root.findtext("name"):
            fail("existing deployed XML belongs to a different VM domain; refusing to overwrite it.")
        existing_disk_path = primary_disk_path(existing_root, "the existing deployed VM XML")
        if existing_disk_path != template_disk_path:
            print(f"NOTE: preserving existing Windows disk path -> {existing_disk_path}")
        # Use the user's deployed XML as the source of truth. This preserves firmware,
        # NVRAM, CPU topology/features, extra non-primary devices, custom boot settings,
        # and all other supported settings rather than rebuilding them from the template.
        data = existing_data
        previous_stat = destination.stat()
    else:
        # A new domain has no custom settings to preserve; start from the reviewed template
        # and assign unique identity values before syncing the selected PCI addresses.
        data = fresh_identity(template_data)

    new_data = synchronize_pci_addresses(data, "VM XML", (gpu, audio))
    if previous_stat is not None:
        backup = Path(f"{destination}.bak-{time.time_ns()}")
        shutil.copy2(destination, backup)
        print(f"NOTE: existing XML backup -> {backup}")
        print("NOTE: preserved the existing VM XML; only its two PCI hostdev source addresses were synchronized.")

    atomic_write(destination, new_data, previous_stat)
    print(f"OK: synchronized GPU/audio PCI addresses -> {destination}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
