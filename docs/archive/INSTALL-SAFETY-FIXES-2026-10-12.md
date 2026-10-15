# Installer safety fixes — 2026-10-12 snapshot

**Scope:** installer static review of an earlier source ZIP. No target machine or VM was accessible during that review.

The historical maintenance pass documented these areas:

- Executable mode for `install.sh` and the documented invocation paths.
- Preservation of existing `system.stateVersion` and `home.stateVersion` values, with validation before copying files.
- Unique backup names to avoid collisions when different source paths have the same basename.
- Explicit warnings when a repository copy of `hardware-configuration.nix` could be mistaken for a machine-generated file.
- Synchronization between the deployed QEMU hook and libvirt XML without modifying the repository template.
- Safe replacement of Nix string values without interpolating raw user input into a `sed` replacement.

These notes record the earlier review, not a claim of a live install test. Review the current installer and run CI before deployment.
