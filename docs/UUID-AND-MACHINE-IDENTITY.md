# UUID and machine-identity safeguards

This repository contains **two different kinds of UUIDs**. Do not treat them as interchangeable, and do not regenerate them merely to make the configuration look generic.

## 1. Host storage identifiers — keep the deployed values

The committed `nixos/hardware-configuration.nix` is specific to the currently deployed host. Its storage identifiers are intentional, not placeholders:

- `rootDev` selects the Btrfs filesystem used by the NixOS mount definitions.
- `boot.initrd.luks.devices."cryptroot".device` identifies the encrypted LUKS block device that is opened during boot.
- A `PARTUUID`, when used by a disk configuration, identifies a partition rather than the filesystem or encrypted container.

**A filesystem UUID, a PARTUUID, and a LUKS UUID are different identifiers.** Never copy one into a field expecting another. Do not edit, regenerate, swap, or replace the committed host identifiers on this machine simply to silence a warning or standardize the file. A mismatch can prevent the encrypted root from opening or the filesystem from mounting.

For a different physical machine, use that machine's own `nixos-generate-config` output and verify each layer against `lsblk -f`, `blkid`, and `findmnt` before building or activating. Do not copy this repository's host-specific identifiers to another machine. When reinstalling the same machine on unchanged disks, preserve the existing mapping; only update identifiers after an intentional disk replacement, repartition, re-encryption, or filesystem recreation and after confirming the new mapping. Run the documented Home Snapper preflight before activation.

## 2. Windows VM domain UUID — preserve an existing VM's identity

The `<uuid>` in `vm-xml/win10.xml` is a **template identity seed**, not an instruction to overwrite the identity of an already deployed Windows VM.

The XML synchronization helper follows two separate paths:

- **Genuinely new VM:** it creates a fresh domain UUID and network MAC before publishing the new XML. This prevents two new libvirt domains from sharing the template identity.
- **Existing VM:** it prefers the registered inactive definition from `virsh dumpxml --inactive`; otherwise it preserves the existing on-disk XML. It synchronizes only the GPU/audio PCI source addresses and keeps the existing UUID, MAC, disk path, and other customizations.

**Do not manually replace the UUID in an existing `win10` domain, and do not copy the template over its deployed XML.** Libvirt uses the domain UUID as persistent identity; changing it can make the same Windows installation appear to be a different domain and can separate it from UUID-associated state, including TPM state. Keep the domain UUID and MAC stable during ordinary updates, XML synchronization, rebuilds, and host maintenance.

A deliberate VM clone is a separate operation: it needs a unique domain UUID and MAC plus its own disk and state. Do not create a second domain by copying the existing XML unchanged. Use the documented VM preparation path and inspect the resulting domain before defining or starting it.

## 3. Safe verification before changing anything

For the host, inspect the identifiers and mount mapping without editing the configuration:

```bash
lsblk -f
sudo blkid
findmnt -no SOURCE,FSTYPE /
findmnt -no SOURCE,FSTYPE /home
```

For the deployed VM, inspect the persistent libvirt identity:

```bash
sudo virsh dominfo win10
sudo virsh dumpxml --inactive win10
```

Compare the reported values with the intended device/domain. If a value is unclear or does not match, stop before rebuilding, activating, redefining, or deleting anything. Preserve a backup and establish which physical device or existing VM is authoritative first.

These warnings do not request or imply any UUID change to the currently working host or Windows VM.
