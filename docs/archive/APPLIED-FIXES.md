# Historical fix register

**Snapshot date:** 2026-10-05; later annotated on 2026-10-12.

This is a historical decision record for an older archive. The commit IDs quoted by the old document may not exist in this repository's current history. It must not be treated as a list of current defects.

- PCI device addresses were validated before being written to the QEMU hook.
- The installer synchronized PCI host devices into the deployed VM XML without mutating the repository template.
- The monitor default was changed to avoid assuming that all hosts use `DP-3`.
- Existing `system.stateVersion` and `home.stateVersion` values were preserved when the installer could identify them.
- Hardware-specific `hardware-configuration.nix` content was treated as host-local data and not copied from the generic template without validation.

Compare every item against the current source before changing it. The current report lives at [`../REPAIR-AND-VALIDATION-REPORT.md`](../REPAIR-AND-VALIDATION-REPORT.md).
