# Changelog

This file summarizes notable changes in English. The original detailed Turkish history is preserved in [`DEGISIKLIK_GECMISI.md`](DEGISIKLIK_GECMISI.md).

## Unreleased — 2026-10-15

### Fixed
- Changed the CachyOS kernel input to the upstream `release` branch and selected `overlays.pinned` to match the upstream binary-cache nixpkgs revision. Added the upstream Attic cache and public key to the flake and system Nix settings.
- Corrected the Windows VM's Q35 machine alias and made the Windows installation ISO boot ahead of the VirtIO driver ISO. Added a regression test for these XML invariants and wired it into CI.
- Hardened the Ollama fallback translator: HTTP errors, malformed responses, and empty translations now fail without being cached as successful translations.
- Translated English-named project documentation, installer comments/messages, and VFIO hook diagnostics/recovery messages into English. Kept `KURULUM.md` and `DEGISIKLIK_GECMISI.md` in Turkish, while translating comments embedded in installation command examples. Turkish OCR translation notifications remain intentional application UI.
- Replaced stale archive-document wording with English historical summaries so that `docs/` is consistently English and old audit findings are not mistaken for current defects.

### Validation
- Bash syntax checks passed for the installer, QEMU hook, and VFIO regression test.
- Python compilation checks passed for the scripts.
- VM XML invariants test passed.
- VFIO driver-state / rollback regression test passed.
- Nix evaluation/build and libvirt/QEMU semantic validation could not be run in this environment because the required executables were unavailable. The CachyOS lock entry must be refreshed on a Nix-enabled machine with `nix flake lock --update-input cachyos-kernel` before rebuilding.

## Historical releases

The original Turkish changelog contains detailed release-by-release notes for versions 1.0.0 through 1.3.9. This English index intentionally avoids restating historical claims as if they were re-tested against the current tree. See [`DEGISIKLIK_GECMISI.md`](DEGISIKLIK_GECMISI.md) for the complete historical record.
