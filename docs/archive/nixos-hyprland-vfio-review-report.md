# NixOS + Hyprland + VFIO review report — 2026-10-12 snapshot

**Method:** static inspection of a supplied ZIP, including Nix configuration, shell scripts, QEMU hook, libvirt XML, docs, and cross-file references. The review explicitly did not run a live rebuild or an actual GPU passthrough cycle on the target machine.

The historical review focused on the installer backup workflow, machine-specific hardware configuration, XML PCI synchronization, QEMU hook rollback, and the distinction between source checks and runtime checks. Subsequent changes and retractions mean this is provenance, not a current defect list.

The current package adds an XML invariant test, fixes the Q35 alias and ISO boot priority, hardens the Ollama fallback, and configures the CachyOS upstream release/pinned-overlay path. Nix evaluation and a real passthrough cycle still require a compatible test host. See [`../REPAIR-AND-VALIDATION-REPORT.md`](../REPAIR-AND-VALIDATION-REPORT.md).
