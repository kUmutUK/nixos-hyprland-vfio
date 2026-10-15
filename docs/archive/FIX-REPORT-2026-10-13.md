# Fix report — 2026-10-13 snapshot

This document summarizes a historical maintenance pass. It is not a statement that every listed behavior was runtime-tested.

- **PCI pairing (`install.sh`):** required the GPU display and HDMI/DisplayPort audio functions to share the same PCI domain, bus, and slot.
- **Documentation links:** corrected links to match files actually present in the archive.
- **Monitor defaults:** documented the empty `monitorOutput` default separately from an example output name.
- **IOMMU guidance:** clarified firmware requirements and removed the unverified `amd_iommu=on` parameter from the documented kernel command line. `iommu=pt` alone is not proof that IOMMU is enabled.

For the current source state, refer to [`../REPAIR-AND-VALIDATION-REPORT.md`](../REPAIR-AND-VALIDATION-REPORT.md).
