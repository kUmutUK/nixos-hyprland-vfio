#!/usr/bin/env python3
"""Synchronize the GPU/audio PCI addresses in a Windows libvirt XML safely."""
from __future__ import annotations

import os
import re
import secrets
import subprocess
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


def guest_pci_address_key(hostdev: ET.Element, description: str) -> tuple[int, int, int, int]:
    """Return the guest-side PCI target so GPU/audio roles don't depend on XML order."""
    address = hostdev.find("./address")
    if address is None or address.get("type") != "pci":
        fail(
            f"{description} has a PCI hostdev without a guest-side PCI address; "
            "its GPU/audio role cannot be identified safely, so no file was written."
        )
    try:
        values = tuple(
            int(address.get(key, ""), 16)
            for key in ("domain", "bus", "slot", "function")
        )
    except ValueError:
        fail(f"{description} has an invalid guest-side PCI target; no file was written.")
    limits = (0xFFFF, 0xFF, 0x1F, 0x7)
    if any(value < 0 or value > limit for value, limit in zip(values, limits)):
        fail(f"{description} has an out-of-range guest-side PCI target; no file was written.")
    return values  # type: ignore[return-value]


def synchronize_pci_addresses(
    data: str,
    description: str,
    addresses: tuple[str, str],
    role_by_guest_address: dict[tuple[int, int, int, int], int],
) -> str:
    root = parse_xml(data, description)
    hostdevs = root.findall(".//hostdev[@type='pci']")
    if len(hostdevs) != 2:
        fail(
            f"{description} must contain exactly two PCI hostdev elements "
            f"(found {len(hostdevs)}); no file was written."
        )

    # The reviewed template defines the guest-side address that identifies each
    # role (GPU first, audio second). Existing XML elements can be in any order,
    # but customized/unknown guest addresses fail closed rather than being guessed.
    hostdev_roles: list[int] = []
    for hostdev in hostdevs:
        guest_address = guest_pci_address_key(hostdev, description)
        role = role_by_guest_address.get(guest_address)
        if role is None:
            fail(
                f"{description} contains an unrecognized guest-side PCI address "
                f"{guest_address!r}; GPU/audio roles cannot be identified safely. "
                "Restore the reviewed guest PCI target addresses or synchronize this XML manually. "
                "No file was written."
            )
        hostdev_roles.append(role)
    if sorted(hostdev_roles) != [0, 1]:
        fail(
            f"{description} does not identify exactly one GPU and one audio hostdev "
            "from the reviewed guest PCI targets; no file was written."
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
        if index >= len(hostdev_roles):
            return match.group(0)
        role = hostdev_roles[index]
        source_address = match.group(2)
        # Update only the four BDF attributes. Preserve any additional attributes,
        # original quote style, ordering, spacing, and future libvirt extensions.
        for key, value in zip(("domain", "bus", "slot", "function"), replacement_components[role]):
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
    # Re-parse and verify the semantic role-to-source mapping before any write.
    rewritten_root = parse_xml(rewritten, f"synchronized {description}")
    rewritten_hostdevs = rewritten_root.findall(".//hostdev[@type='pci']")
    if len(rewritten_hostdevs) != 2:
        fail(f"synchronized {description} failed PCI hostdev validation; no file was written.")
    expected_components = tuple(
        tuple(int(part, 0) for part in component) for component in replacement_components
    )
    for hostdev in rewritten_hostdevs:
        role = role_by_guest_address[guest_pci_address_key(hostdev, f"synchronized {description}")]
        source = hostdev.find("./source/address")
        if source is None:
            fail(f"synchronized {description} is missing a PCI source address; no file was written.")
        try:
            actual = tuple(int(source.get(key, ""), 0) for key in ("domain", "bus", "slot", "function"))
        except ValueError:
            fail(f"synchronized {description} has an invalid PCI source address; no file was written.")
        if actual != expected_components[role]:
            fail(f"synchronized {description} has an incorrect GPU/audio role mapping; no file was written.")
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


def registered_domain_xml(domain: str) -> str | None:
    """Return the live libvirt XML, or None only when the domain is absent.

    Listing failure and dump failure are fatal: they must not be mistaken for a
    missing VM, because doing so could cause a template to replace a registered
    domain's on-disk XML.
    """
    if not re.fullmatch(r"[A-Za-z0-9_.-]+", domain):
        fail(f"invalid libvirt domain name {domain!r}.")
    virsh = shutil.which("virsh")
    if virsh is None:
        fail("--domain requires virsh so the registered VM definition can be checked safely.")
    try:
        listed = subprocess.run(
            [virsh, "list", "--all", "--name"],
            capture_output=True,
            text=True,
            check=False,
            timeout=15,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        fail(f"could not query libvirt domains; refusing to use an on-disk/template XML instead: {exc}")
    if listed.returncode != 0:
        detail = listed.stderr.strip() or f"exit status {listed.returncode}"
        fail(f"could not query libvirt domains; refusing to proceed: {detail}")
    names = {line.strip() for line in listed.stdout.splitlines() if line.strip()}
    if domain not in names:
        print(f"NOTE: libvirt domain {domain!r} is not registered; the on-disk XML/template path may be used.")
        return None
    try:
        dumped = subprocess.run(
            [virsh, "dumpxml", domain],
            capture_output=True,
            text=True,
            check=False,
            timeout=15,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        fail(f"could not export the registered libvirt domain {domain!r}: {exc}")
    if dumped.returncode != 0:
        detail = dumped.stderr.strip() or f"exit status {dumped.returncode}"
        fail(f"could not export the registered libvirt domain {domain!r}; refusing to use stale XML: {detail}")
    live_data = dumped.stdout
    live_root = parse_xml(live_data, f"live libvirt domain {domain!r}")
    if live_root.tag != "domain" or live_root.findtext("name") != domain:
        fail(f"virsh dumpxml returned an unexpected domain for {domain!r}; no file was written.")
    return live_data


def main() -> int:
    args = sys.argv[1:]
    domain: str | None = None
    if len(args) == 6 and args[4] == "--domain":
        gpu, audio, template_name, destination_name, _, domain = args
    elif len(args) == 4:
        gpu, audio, template_name, destination_name = args
    else:
        fail("usage: sync-vm-xml.py GPU_PCI GPU_AUDIO TEMPLATE_XML DEPLOYED_XML [--domain DOMAIN]")

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
    template_domain = template_root.findtext("name")
    if not template_domain:
        fail("VM XML template has no domain name; no file was written.")
    template_disk_path = primary_disk_path(template_root, "the VM XML template")
    template_hostdevs = template_root.findall(".//hostdev[@type='pci']")
    if len(template_hostdevs) != 2:
        fail(
            "VM XML template must contain exactly two PCI hostdev elements "
            f"(found {len(template_hostdevs)}); no file was written."
        )
    # In the reviewed template only, the order defines GPU (0) then audio (1).
    # Their guest-side target addresses then provide stable role identities in
    # existing XML even if those hostdev blocks have been reordered.
    role_by_guest_address: dict[tuple[int, int, int, int], int] = {}
    for role, hostdev in enumerate(template_hostdevs):
        key = guest_pci_address_key(hostdev, "VM XML template")
        if key in role_by_guest_address:
            fail("VM XML template reuses a guest PCI target for both GPU and audio; no file was written.")
        role_by_guest_address[key] = role
    synchronize_pci_addresses(template_data, "VM XML template", (gpu, audio), role_by_guest_address)

    if destination.is_symlink():
        fail(f"refusing to replace symlinked VM XML path {destination}.")
    if os.path.lexists(destination) and not destination.is_file():
        fail(f"existing deployed VM XML is not a regular file: {destination}.")

    # The registered definition outranks a potentially stale/missing on-disk XML.
    # A failed libvirt query is fatal; it is never silently interpreted as an absent VM.
    live_data = registered_domain_xml(domain) if domain is not None else None
    previous_stat: os.stat_result | None = None
    existing_data: str | None = None
    if os.path.lexists(destination):
        try:
            existing_data = destination.read_text(encoding="utf-8")
        except OSError as exc:
            if live_data is None:
                fail(f"could not read existing deployed VM XML {destination}: {exc}")
            print(f"WARNING: on-disk XML could not be read, but a validated live domain export is available: {exc}")
        if existing_data is not None:
            try:
                existing_root = parse_xml(existing_data, "existing deployed VM XML")
            except SystemExit:
                if live_data is None:
                    raise
                print("WARNING: existing on-disk XML is invalid; a validated live libvirt definition will be used and the old file will be backed up.")
                existing_root = None
            if existing_root is not None and existing_root.findtext("name") != template_domain:
                fail("existing deployed XML belongs to a different VM domain; refusing to overwrite it.")
        previous_stat = destination.stat()

    if live_data is not None:
        live_root = parse_xml(live_data, "live libvirt VM XML")
        live_disk_path = primary_disk_path(live_root, "the live libvirt VM XML")
        if live_disk_path != template_disk_path:
            print(f"NOTE: preserving live libvirt Windows disk path -> {live_disk_path}")
        data = live_data
        print(f"NOTE: using virsh dumpxml {domain} as the source of truth for the registered VM.")
    elif existing_data is not None:
        if not existing_data.strip():
            fail("existing deployed VM XML is empty; refusing to replace it automatically.")
        existing_root = parse_xml(existing_data, "existing deployed VM XML")
        existing_disk_path = primary_disk_path(existing_root, "the existing deployed VM XML")
        if existing_disk_path != template_disk_path:
            print(f"NOTE: preserving existing Windows disk path -> {existing_disk_path}")
        data = existing_data
    else:
        # An unregistered domain has no current definition to preserve; start from
        # the reviewed template and assign a fresh UUID/MAC.
        data = fresh_identity(template_data)

    new_data = synchronize_pci_addresses(data, "VM XML", (gpu, audio), role_by_guest_address)

    # Save the current registered definition even if the on-disk XML was absent.
    # Exclusive creation ensures an existing recovery copy is never overwritten.
    if live_data is not None:
        live_backup = Path(f"{destination}.libvirt-{domain}-{time.time_ns()}.xml")
        try:
            fd = os.open(live_backup, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(fd, "w", encoding="utf-8") as handle:
                handle.write(live_data)
                handle.flush()
                os.fsync(handle.fileno())
            print(f"NOTE: registered live XML backup -> {live_backup}")
        except OSError as exc:
            fail(f"could not save a recovery copy of the live libvirt XML: {exc}")
    if previous_stat is not None:
        backup = Path(f"{destination}.bak-{time.time_ns()}")
        try:
            shutil.copy2(destination, backup)
        except OSError as exc:
            fail(f"could not back up existing deployed XML {destination}: {exc}")
        print(f"NOTE: existing on-disk XML backup -> {backup}")

    if previous_stat is not None:
        print("NOTE: preserving the existing VM definition; only its two PCI hostdev source addresses were synchronized.")
    atomic_write(destination, new_data, previous_stat)
    print(f"OK: synchronized GPU/audio PCI addresses -> {destination}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
