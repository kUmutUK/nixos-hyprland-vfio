# Remaining-issues audit — 2026-10-09 snapshot

> Historical snapshot of an earlier ZIP. The open/fixed status below does not automatically describe the current working tree.

That review distinguished confirmed source defects from items requiring a Nix-enabled system or real VM. Its main advice was to avoid treating XML parsing or ShellCheck as proof of a successful NixOS evaluation or GPU-passthrough cycle.

The retained live-only categories were: actual OVMF NVRAM template availability, the installed system's state-version values, whether initrd amdgpu is required on the real host, and swtpm state-directory ownership at boot. Later audits also emphasized testing both GPU and audio driver restoration after VM shutdown.

Do not apply an old recommendation without comparing it with the current source. See [`HISTORICAL-AUDITS.md`](HISTORICAL-AUDITS.md) for retracted claims and [`../REPAIR-AND-VALIDATION-REPORT.md`](../REPAIR-AND-VALIDATION-REPORT.md) for the current maintenance pass.
