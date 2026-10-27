# Repair and validation report — updated 2026-10-27

> **Delivery-scope note:** This report is part of the tracked source tree. The dated “patch-only ZIP” notes below are historical. For a canonical full-source ZIP, use the `git archive` command documented in `README.md` or the CI-uploaded `nixos-hyprland-vfio-source` artifact; CI validates `.git/` exclusion and `install.sh`’s tracked executable mode.

## ZIP audit confirmation — 2026-10-27

### Exact-byte identity of the attachment inspected in this review

The ZIP bytes attached to this review were hashed and inspected directly on 2026-10-27. These are the measurements for that exact attachment, not estimates copied from an earlier report:

- File size: `436,212` bytes.
- SHA-256: `3f0f0ed580f58815f792635720a51b8c0066989add88460ccf3d2620ce771da0`.
- ZIP central-directory entry count: `96`.
- Entries under `nixos-hyprland-vfio/.git/`: `45` total, including `29` file entries and `16` directory entries.
- Embedded `.git/HEAD` resolves to `a631d195891ff6da74ae727ac3c531ffc77c50ed`; the `.git/shallow` marker contains the same SHA.
- The `install.sh` ZIP entry has `create_system=0` and `external_attr=0x00000000`, so it encodes no Unix permission bits. Extraction produces mode `0644`; the embedded Git index records mode `100755`.
- GitHub `main` was observed at `81b4501392ea99ba431864367d8a15cc231fc1ff` during this review. The attached ZIP therefore does not represent that current source revision.

Earlier audit notes also mention SHA-256 `89362330c8565d27e58260aef3bb3a16ab8941415c9f02e6c20640f0a57838ed`, `101` entries, and embedded HEAD `81b4501392ea99ba431864367d8a15cc231fc1ff`; that is a separate, unverified measurement set for this attachment. A later audit message labels another archive `nixos-hyprland-vfio(7).zip` and reports `455,316` bytes, `101` entries, SHA-256 prefix `8d38226c…`, and embedded HEAD `8467e496f6ec40d46fec1af71326e32e5c8e2337`. Those latter values were not reproduced from the bytes available in this review: the mounted attachment still measures exactly as listed above. The reported embedded HEAD happens to match the current GitHub `main` commit, but that alone does not prove that a ZIP contains those bytes or that its entry count and hash are correct. If the separately named v7 archive is intended to be audited, its exact bytes must be supplied and measured independently; do not merge these measurement sets.

### Regression checks performed against the attached snapshot

Passed in this review: Bash syntax checks; `scripts/test-installer-invariants.sh`; `scripts/test-installer-rollback.sh`; `scripts/test-vfio-hook-driver-state.sh`; `scripts/test-vm-xml.py`; `scripts/test-vm-xml-sync.py`; `scripts/test-vm-diagnostic.py`; `scripts/test-lsfg-v1-config.py`; `scripts/test-extract-embedded-scripts.py`; and `python3 -m compileall -q scripts`. The installer-invariants test completed in 12 seconds, and the reported timeout was not reproduced in this run. This does not prove the timeout cannot occur under other runner loads or in a different combined invocation.

The local environment did not provide Nix, ShellCheck, Statix, Deadnix, `xmllint`, or `virt-xml-validate`; no Nix evaluation/build or libvirt/QEMU semantic validation is claimed. Physical GPU passthrough and VM shutdown/display-recovery testing also remain outside this review. The SSH password-authentication setting remains a network-dependent security risk already documented by the project; it was not changed automatically because doing so without verifying a working alternate access path could lock out a deployed host.

The tracked source already has the correct `install.sh` mode, and `.github/workflows/check.yml` already builds a canonical ZIP with `git archive` and rejects archives that include `.git/` or lose the executable mode. The source/workflow logic was not altered for a defect confined to this ad-hoc ZIP.

Review baseline before this documentation correction: `e5d491b60f48a35a3cb0b4288c02a7e789a31e4d`. The uploaded ZIP's embedded shallow Git checkout points to `a631d195891ff6da74ae727ac3c531ffc77c50ed`; it is not a faithful snapshot of the then-current `main`.

- The supplied `nixos-hyprland-vfio.zip` contains 96 ZIP entries. There are 45 entries under `nixos-hyprland-vfio/.git/`, including 29 actual files plus directory entries, so the internal Git metadata is definitely included.
- The `nixos-hyprland-vfio/install.sh` ZIP entry uses DOS/FAT creator metadata (`create_system=0`) and carries no Unix permission bits (`external_attr` mode `0000`). Extracting this archive therefore does not preserve the executable bit required by the documented `./install.sh` command and may cause `Permission denied` on Unix. The embedded Git index records `install.sh` as `100755`; the tracked script content and Git mode are not the defect.
- The current source workflow `.github/workflows/check.yml` already has the correct defense: it generates the source archive using `git archive`, rejects `.git/` entries, and validates the Unix executable mode on `install.sh`. The README already documents the same canonical command. This audit does not justify changing the installer or weakening/replacing those checks; the problem is the supplied noncanonical ZIP.
- GitHub Actions run [#928](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/40478786307) succeeded for SHA `a631d195891ff6da74ae727ac3c531ffc77c50ed` and produced the canonical source artifact. That artifact cannot be the supplied ZIP because the run's archive validation excludes `.git/`, while this ZIP contains it. Run #928 is historical evidence for its exact SHA only, not for the later main revision.
- Remediation: after the desired source changes are committed, generate the ZIP from that exact commit with the README's `git archive` command, or use the CI artifact produced for that exact commit. Do not distribute a manually compressed checkout containing `.git/`.

- **Re-verification against current `main` — 2026-10-27:** At parent revision `5959a79dcba3a0b8c7db4743c9a4a57a1025e36b`, I rechecked the exact ZIP attached to this review. Its measured values remain **96 entries**, **45 entries under `.git/`**, DOS/FAT creator metadata with no encoded Unix mode for `install.sh`, and embedded Git HEAD `a631d195891ff6da74ae727ac3c531ffc77c50ed`. Thus the proposed figures of 101 entries and embedded HEAD `5959a79…` do not describe this attached file. The existing report's 96/`a631d195…` values are correct for this attachment; no installer content or tracked mode change is warranted.
- GitHub Actions run [#953](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/40518482880) succeeded for parent SHA `5959a79dcba3a0b8c7db4743c9a4a57a1025e36b` and uploaded the validated `nixos-hyprland-vfio-source` artifact (artifact ID `12739669466`, SHA-256 `df7db0982c1ebeb7f65d0279368cb85946eef2de2eb5a3f373e4d1c59492125b`). This run applies only to that exact parent SHA. The documentation-only update below must receive its own CI run before its resulting artifact is considered validated.

## Manual validation parity and installer-test timeout follow-up — 2026-10-27

- Updated the README and CONTRIBUTING validation commands to ShellCheck `scripts/pci-address.sh`, and to run `statix check .` plus `deadnix .`, matching the required CI gates. The README repository map now also lists the shared PCI helper.
- Extended `scripts/test-installer-invariants.sh` so documentation drift for these commands and their CI counterparts fails the regression test.
- The supplied audit notes report that `test-installer-invariants.sh` passed when run independently but timed out once during a combined audit. The available evidence does not include a timeout trace or establish whether the limit came from the test, the enclosing runner, or competing work. This remains an unconfirmed test-stability issue; no arbitrary delay, timeout relaxation, or product-failure claim is introduced. Capture elapsed time and the exact timeout/log context on the next reproduction before changing test behavior.
- The source-archive evidence above remains unchanged: the attached ZIP measures 96 entries and embeds HEAD `a631d195891ff6da74ae727ac3c531ffc77c50ed`, while the canonical-source packaging protections already exist in CI. No change to the installer's tracked mode or content is required for this finding.
- This change records and guards the manual-validation parity correction. It does not claim that Nix evaluation, Statix, Deadnix, a complete system build, QEMU/libvirt startup, or physical GPU passthrough was executed in this workspace.

## Audit follow-up — 2026-10-27

- The reviewed ad-hoc full-source ZIP included `.git/` metadata and did not preserve `install.sh`’s Unix executable bit. These are packaging defects: the existing GitHub Actions workflow already creates the canonical archive with `git archive`, checks that `.git/` is absent and `install.sh` retains mode `100755`, then uploads that exact validated ZIP. Distribution should use the CI artifact rather than manually compressing a checkout.
- Fixed `INSTALLATION.md` to query `sudo virsh list --all --name` before classifying the VM. A registered `win10` is now treated as existing even when `/var/lib/libvirt/win10.xml` is missing; a failed libvirt query aborts rather than entering the new-VM path. An existing on-disk XML also remains classified as existing.
- Extended `scripts/test-installer-invariants.sh` to require the registered-domain check in both `README.md` and `INSTALLATION.md`, alongside the existing `--domain win10` synchronizer checks.
- Static regression tests were run against the correction bundle and passed, including installer invariants/rollback, VM XML/sync/diagnostic, VFIO handoff, LSFG-VK, embedded-script extraction, Bash syntax, and Python compilation. Nix evaluation, ShellCheck, libvirt/QEMU semantic checks, and physical GPU/VM lifecycle testing remain separate and are not claimed here.

## Current follow-up correction — 2026-10-27

- Closed the VM-definition source-of-truth gap found in the October 24 audit. The XML synchronizer accepts an optional `--domain win10`, checks libvirt's registered domain list, and, when the domain exists, uses a validated `virsh dumpxml --inactive win10` result instead of trusting a stale or missing `/var/lib/libvirt/win10.xml`.
- The synchronizer now fails closed if the libvirt query/export fails or returns an unexpected domain. It creates a mode-`0600` recovery copy of the registered XML and backs up any existing on-disk XML before writing the PCI-address-synchronized result.
- Restored the embedded-script extractor's Nix-attribute boundary guard, made unterminated indented strings fail closed, and added `scripts/test-extract-embedded-scripts.py`. CI and contributor validation now run this focused regression test before ShellCheck extracts the seven real scripts.
- Both `install.sh` and the manual README flow pass `--domain win10`. The VM XML regression suite uses a fake `virsh` executable to cover registered-domain vs stale XML, registered-domain with missing on-disk XML, and list/dump failures with no mutation.

### Cross-conversation recheck on 2026-10-27

- The earlier report had not covered two fault paths deeply enough: a service stop may return success while systemd still reports an active unit, and `stateVersion` discovery could silently prefer one existing file when other existing candidates conflicted. The VFIO hook now checks the post-stop `ActiveState` and aborts before unbinding unless it is `inactive`/`failed`; mocked tests now cover stop failures, restoration failures, and retained retry state. Installer discovery now rejects duplicate or mixed literal/non-literal assignments and prompts when existing candidate values conflict; regression tests cover these cases.
- Closed the old LSFG-v2 scope question as a version decision, not an active v1/v2 mismatch: the current repo explicitly targets upstream v1 `[[game]]`/`exe` profiles, tests that schema, and builds `.#lsfg-vk`. A future v2 change must migrate packaging, profile format, deployment/rollback handling, and CI together.
- Cross-checked the manual `INSTALLATION.md` VM synchronization example against the README and `install.sh`. It previously omitted `--domain win10`; it now uses the same persistent `virsh dumpxml --inactive win10` source-of-truth path and documents fail-closed behavior.
- The report's historical audit is still not a reproducible 927-commit-per-finding manifest: imported conversation summaries and prior reports do not provide exact source/destination SHA coverage for every review turn. Findings are therefore mapped by report and current code state below rather than pretending every historical commit has been individually re-audited in this single pass.
- Historical CI note (not current HEAD): commit `a631d195891ff6da74ae727ac3c531ffc77c50ed` was the `main` revision used by GitHub Actions run [#928](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/40478786307), which succeeded on 2026-10-27. Before this documentation correction, `main` had advanced to `e5d491b60f48a35a3cb0b4288c02a7e789a31e4d`. Run #928 validates only its exact SHA, not later commits or physical hardware behavior.
- No live libvirt guest, physical GPU passthrough/release cycle, full RT-Bore-LTO kernel build, or target-host lifecycle run was performed as part of this follow-up audit. The CI result does not replace those target-machine checks.

## Post-audit documentation and delivery corrections — 2026-10-27

- Added `scripts/test-extract-embedded-scripts.py` to the README's manual validation sequence so it matches CONTRIBUTING and CI.
- Renamed the older 2026-10-23 changelog subsection to `Follow-up fixes — 2026-10-23`, leaving one current `Unreleased` heading and making the dated history clearer.
- Historical CI reference: run #928 passed for SHA `a631d195891ff6da74ae727ac3c531ffc77c50ed`; it should not be described as CI status for the later `main` revision.
- The inspected ad-hoc full-source ZIP was not a valid distribution archive because it included `.git/` and did not preserve `install.sh`'s executable mode. The tracked Git mode remains `100755`. Recreate the distributable bundle with the canonical `git archive` command in README, or use the CI artifact for the exact source commit being distributed; do not infer that an artifact from an earlier commit validates the current tree.

## Follow-up corrections — 2026-10-23

- Preserved the executable bit for `install.sh` in the correction bundle (`100755`) and clarified that its monitor-output prompt controls both the Hyprland monitor rule and mpvpaper wallpaper. The supplied full-source archive's `.git/` packaging issue is avoided here because this is a patch-only ZIP containing only the corrected paths.
- Corrected the cache description in `nixos/flake.nix` and `README.md`: the active configuration lists the Nix Community cache, not the upstream CachyOS Attic cache. No new third-party substituter was added. The upstream cache does not publish the RT-Bore-LTO ThinLTO variant; the project owner reports that the currently locked revision has built successfully on the target machine, while each newly selected upstream revision still requires a local build.
- Updated the current changelog and configuration index to match the actual CachyOS revision in `nixos/flake.lock` (`02ba4db52e62e1fbece80402d369127ae77cbbeb`). Updated current validation wording to record the project owner's report of a successful rebuild, RT-Bore-LTO compile, VM start/shutdown, and return to Hyprland. Older date-stamped entries below remain historical records of what was known at those dates.
- Fixed the six Hyprlock label text colors in `nixos/home.nix`: label widgets now use the documented `color` option, while `input-field.font_color` remains unchanged. Replaced the network label's `xargs`/`||` fallback with an `awk` empty-input check so it reliably displays `Disconnected` when no active connection name is available.
- Validation for this follow-up patch: all six repository regression suites, Bash syntax checks, Python compilation, JSON/XML/YAML parsing, embedded-script extraction/syntax checks, and Markdown relative-link checks were rerun. Nix evaluation/build, ShellCheck, libvirt semantic validation, and independent physical GPU/VM lifecycle testing remain unverified in this environment.

## Historical correction record — 2026-10-21

The patch-only ZIP created for the 2026-10-21 correction set contained `CHANGELOG.md`, this report, `install.sh` (content unchanged, ZIP Unix mode `100755`), `scripts/sync-vm-xml.py`, and `scripts/test-vm-xml-sync.py`. It excluded `.git/` and all unchanged project files. It was an overlay for the matching project tree, not a full-source archive or replacement for the original project ZIP.

- Corrected the changelog's language-policy description: the root `KURULUM.md` and `DEGISIKLIK_GECMISI.md` are English compatibility/current-state pointers, while the original Turkish release-by-release history is in `docs/archive/DEGISIKLIK_GECMISI.md`.
- Corrected VM XML GPU/audio role identification. The helper now matches each PCI hostdev's guest-side PCI target against the reviewed template's role map, so reordering the two XML blocks no longer swaps GPU/audio source addresses. Unknown target addresses fail closed before a destination or backup is modified.
- Added regression tests for reordered PCI hostdev blocks and unrecognized guest-side target addresses, in addition to the existing preservation/backup/unsupported-layout tests.
- Preserved `install.sh`'s tracked executable mode (`100755`) in this patch ZIP. Its contents are unchanged. The full-source ZIP supplied for review had dropped that mode and included `.git/`; this patch-only ZIP intentionally excludes `.git/` and is not a repackaged full source bundle.

Validation for this patch: all six regression suites passed (`test-vm-xml.py`, `test-vm-xml-sync.py`, `test-vm-diagnostic.py`, installer invariants, installer rollback, and VFIO driver/service-state tests). Bash syntax checks, Python source compilation, `flake.lock` JSON parsing, template XML parsing, extraction and `bash -n` checks for all seven embedded scripts, and all 38 Markdown relative-link checks also passed. Nix evaluation/build, ShellCheck, and libvirt semantic validation were not run in this environment; no real GPU/VM lifecycle behavior is claimed.


## Delivery-scope clarification — 2026-10-19

This report contains historical notes about earlier correction bundles; those dated notes must not be read as a description of the original full-project archive currently under review. The original uploaded archive (`nixos-hyprland-vfio(5).zip`) included the full project tree and `.git/`, and its `install.sh` ZIP entry did not preserve the Unix executable bit. The English `README.md` also contained one Turkish error message.

The corrective ZIP produced from this review is a **patch-only bundle** containing only the three files corrected for these findings: `README.md`, `install.sh` (stored with Unix mode `100755`), and this report. It excludes `.git/` and unchanged project files. Applying it overlays those paths onto the matching project tree; it is not a replacement for the full source archive. This bundle addresses the confirmed packaging/documentation findings only and does not claim Nix evaluation, libvirt validation, or real hardware/VM lifecycle verification.

## Follow-up corrections — 2026-10-19

This follow-up patch-only bundle contains only the files modified in this correction set: `README.md`, `scripts/test-installer-invariants.sh`, `.github/workflows/check.yml`, `CHANGELOG.md`, this report, and `install.sh` (mode correction only). It excludes `.git/` and does not duplicate the full source tree. The user-supplied full-project ZIP included `.git/` and did not preserve executable permission for `install.sh`; this patch ZIP explicitly stores that entry as Unix mode `100755`.

- The README snippet for preserving machine-specific hardware configuration was already correct in the supplied source archive: when the destination is missing, it checks the generated source at `/etc/nixos/hardware-configuration.nix` before copying. The earlier audit's quoted “current example” incorrectly showed the destination path twice. No logic change was needed; `scripts/test-installer-invariants.sh` now executes the documented block against temporary paths and checks copy, preserve-existing-target, and missing-source failure cases.
- CI creates the canonical source ZIP with `git archive`, validates that ZIP for `.git` exclusion and Unix executable mode, and uploads the exact validated ZIP as the `nixos-hyprland-vfio-source` workflow artifact after the required checks pass. This narrows the distribution gap between a tested archive and a separately repackaged download.
- The installer source code is unchanged in this correction set. Its executable bit is restored in the patch archive so applying/extracting that file does not repeat the original ZIP's mode-loss problem.

Validation for this correction set: Bash syntax checks, the installer invariants/rollback tests, VFIO driver-state tests, VM XML and diagnostic tests, Python compilation, workflow YAML parsing, canonical ZIP metadata checks, and patch ZIP metadata checks. This remains static validation only; Nix evaluation/build, ShellCheck if unavailable, libvirt semantic validation, and physical VM/GPU lifecycle testing remain separate checks that must not be inferred from static results.


## Follow-up status — 2026-10-17: packaging and documentation audit corrections

The 2026-10-17 audit of `nixos-hyprland-vfio(6).zip` found that the uploaded full-project archive included its internal `.git/` directory and extracted `install.sh` as mode `0644`, despite the Git index recording mode `100755`. This is an input-archive packaging defect, not a content-level installer bug. The fix-only ZIP for this correction set contains only the changed documentation/workflow files plus `install.sh` with Unix mode `100755`; it does not include `.git/` or duplicate the full project. To publish a canonical full-source ZIP from a Git checkout, commit the intended revision and use the `git archive` command documented in `README.md`. The CI check validates both exclusion of `.git/` and preservation of the executable bit.

The documentation and validation workflow were updated to close the other findings from that audit:

- `KURULUM.md` now distinguishes manual Btrfs `/home/.snapshots` setup from the installer's existing create-and-verify behavior, warns against running `btrfs subvolume create` on an already-existing subvolume, and keeps the boot-critical mount requirement explicit.
- `README.md` lists `scripts/test-installer-rollback.sh` in the repository map and local validation steps; `CONTRIBUTING.md` includes the same test and ShellCheck/syntax coverage.
- The embedded Bash validation in README, CONTRIBUTING, and CI now uses a fresh temporary directory, captures and checks the extractor's exit status directly, verifies exactly seven scripts before invoking ShellCheck, and removes the temporary files. An extraction failure or missing marker can no longer be masked by a downstream `xargs` success.
- `README.md` now names the default Windows and VirtIO ISO files and their expected `/var/lib/libvirt/images/` location, matching `vm-xml/win10.xml` and `KURULUM.md`.

Validation completed in this environment: installer invariants, rollback, VFIO driver-state, and VM XML tests passed; Bash syntax checks passed for the installer, QEMU hook, regression scripts, and all seven extracted embedded scripts; Python compilation, XML parsing, `flake.lock` JSON parsing, and workflow YAML parsing passed. The embedded-script extractor returned exactly seven scripts. ShellCheck and Nix flake evaluation were not run because those executables are unavailable here; libvirt semantic validation and real GPU/VM lifecycle behavior still require validation on the target host.

## Scope

Reviewed the uploaded source archive and modified source files, configuration, VM XML, installer, CI, scripts, and documentation. This is a static maintenance pass, not a claim that the configuration was activated on the target PC.

## Follow-up status — 2026-10-17: installer and VFIO safety corrections

The RT-Bore-LTO ThinLTO kernel selection remains intentional and unchanged in `nixos/flake.nix`. The following code-level findings from the follow-up static audit have now been addressed:

- `install.sh` backs up `/var/lib/libvirt/win10.xml` together with the deployed NixOS files, tracks which targets existed before deployment, and installs an `EXIT` rollback handler. If deployment exits non-zero after the first target mutation, existing files are restored from the run's backup and newly created targets are removed. Rollback is best-effort; if it reports a restoration failure, inspect the backup directory before rebuilding.
- `nixos/hooks/qemu` writes the pre-VM active state of `greetd`, `ollama`, and `polkit.service` to a mode-0600 state file under `/run/libvirt/vfio-state`. The release hook and prepare rollback restore only services which were active before the handoff; inactive Ollama is no longer started just because its unit is enabled.
- The installer now stops before deploying configuration if either CPU or GPU is not positively identified as AMD, matching the supported configuration scope.
- `README.md` and `KURULUM.md` document the upstream `low_latency_layer` v0.2.0 CS2/Source 2 frame-pacing limitation, the `fps_max 0` workaround, and per-game opt-out.
- New mocked tests cover the rollback path and service active-state restoration. CI invokes the rollback test and includes it in ShellCheck.

Validation performed for this follow-up: `bash -n` on the installer, hook, and affected shell tests; `scripts/test-installer-rollback.sh`; `scripts/test-vfio-hook-driver-state.sh`; `scripts/test-installer-invariants.sh`; `scripts/test-vm-xml.py`; Python compilation of `scripts/*.py`; and XML well-formedness parsing all passed. This environment does not have Nix, ShellCheck, or libvirt/QEMU validation tools, and no actual GPU passthrough or RT-Bore-LTO boot was performed here. The selected kernel still requires local build and real target-system boot/VM lifecycle verification.

## Follow-up status — 2026-10-16: RT-Bore-LTO selected

The current `nixos/flake.nix` selects `pkgs.cachyosKernels.linuxPackages-cachyos-rt-bore-lto` from the upstream `master` input; no kernel version is hard-coded in the flake expression. The checked-in `flake.lock` records the resolved input revision for reproducibility, as Nix flakes normally do; run a targeted `nix flake update` to move to a newer upstream revision. Upstream does not publish the RT-Bore-LTO LTO variant in its binary cache, so expect a local kernel build; the `pinned` overlay aligns nixpkgs revisions but cannot create a missing cache artifact. The earlier user-provided linker log named standard BORE-LTO, a different package derivation, and does not prove or disprove the RT-Bore-LTO build. This audit environment has no Nix CLI, so package evaluation and compilation were not run here.

The previously reported successful target-machine build and VM display recovery were performed with the standard (non-RT) BORE-LTO kernel. They do not validate the selected RT-Bore-LTO kernel. After a successful build, boot it and test VM start, normal shutdown, host display/Hyprland recovery, and a second VM start before treating the migration as validated. Upstream package reference: https://github.com/xddxdd/nix-cachyos-kernel/blob/master/README.md

## Corrections applied for the 2026-10-16 audit

- `KURULUM.md` now states the 810 GiB minimum (about 870 GB decimal) and explicitly documents that the `G` suffix accepted by `sgdisk` represents GiB. The reference partitions total 809 GiB.
- Before `sgdisk -Z` can run, the guide checks that the target exists, is a whole-disk block device, has no mounted descendants, and is at least 810 GiB. These checks reduce common mistakes but do not replace the operator's final model/serial-number verification; `sgdisk -Z` remains destructive.
- `KURULUM.md` and `README.md` now identify RX 6700 XT/Navi 22 as the reference GPU and do not imply universal support for RX 6000/7000 cards.
- The original uploaded full-project ZIP's missing Unix executable bit is distinguished from the new patch-only ZIP, which stores `install.sh` as mode `100755`. This patch archive contains only the corrected paths, not a duplicate full project or `.git` metadata.

## Changes made

### CachyOS kernel build/cache path

- Historical note (the tree at the time of that earlier audit): the CachyOS flake input was changed from `master` to `github:xddxdd/nix-cachyos-kernel/release`. The current tree has since returned to `master`. [Upstream documentation](https://github.com/xddxdd/nix-cachyos-kernel/blob/release/README.md) says this branch contains a kernel built by its Hydra CI and published to its binary cache.
- Changed `cachyos-kernel.overlays.default` to `cachyos-kernel.overlays.pinned`, which selects packages from the kernel flake's pinned nixpkgs revision. See the [upstream overlay definition](https://github.com/xddxdd/nix-cachyos-kernel/blob/release/flake.nix). For variants that upstream actually caches, this can avoid a local ThinLTO build when a matching derivation exists. RT-Bore-LTO's LTO variant is not cached, as noted in the follow-up status above.
- Replaced the previous CachyOS cache entry with the Attic substituter and public key documented by upstream in both the flake `nixConfig` and system Nix settings. [Upstream cache configuration](https://github.com/xddxdd/nix-cachyos-kernel/blob/release/flake.nix).
- The previous archive's CachyOS lock referred to an older upstream `release` snapshot. This correction refreshed the CachyOS input and its matching nested nixpkgs revision at the time of that audit. At the time of that earlier audit, the flake expression followed the upstream `release` branch rather than hard-coding a kernel version; the current tree follows `master`. The `flake.lock` records the selected source snapshot so rebuilds remain reproducible until the CachyOS input is intentionally updated. RT-Bore-LTO LTO is not in the upstream binary cache, so local build failures such as linker regressions still need their own investigation.

### Windows VM XML

- Changed the Q35 machine alias from `pc-q35` to `q35`. A versioned alias such as `pc-q35-X.Y` may also be used if that exact version is supported by the installed QEMU/libvirt.
- Reordered CD-ROM boot priorities so the Windows installation ISO is attempted before the VirtIO driver ISO. The disk remains boot priority 1.
- Added `scripts/test-vm-xml.py`, which parses the XML and checks the machine alias, disk/CD-ROM priority, SATA CD-ROM bus, and complete PCI hostdev addresses. CI runs this test.

### Ollama translation fallback

- Changed the API call to fail on HTTP error responses and display transport errors.
- Added validation that the response includes a non-empty string `response` property.
- Removed use of `xargs` as a generic whitespace trimmer, so quotes/backslashes are not reinterpreted. Empty/error responses now fail and are not appended to the translation cache.

### Documentation and language consistency (current state, 2026-10-23)

- `README.md`, `CONTRIBUTING.md`, and `CHANGELOG.md` are maintained in English. The root `KURULUM.md` is an English compatibility pointer to `INSTALLATION.md`; it is not the canonical Turkish installation guide.
- The root `DEGISIKLIK_GECMISI.md` is an English current-state/compatibility summary. The full historical Turkish change log is preserved at `docs/archive/DEGISIKLIK_GECMISI.md`.
- Installer prompts, warnings, desktop labels, status messages, notifications, service descriptions, and VFIO hook comments are maintained in English. The OCR/game-translation utility intentionally translates recognized English game text into Turkish.
- Older statements in this report that described the root `KURULUM.md` as Turkish or the root `DEGISIKLIK_GECMISI.md` as the full Turkish history were true only of an earlier project state and were superseded by the documentation migration recorded on 2026-10-19. They should not be treated as descriptions of the current tree.

## Checks performed in this environment

| Check | Result |
|---|---|
| Individual `bash -n` syntax checks for `install.sh`, `nixos/hooks/qemu`, and both regression shell scripts | Passed |
| `bash scripts/test-installer-invariants.sh` | Passed |
| `python3 -m py_compile` for repository Python scripts | Passed |
| `python3 scripts/test-vm-xml.py` | Passed |
| `bash scripts/test-vfio-hook-driver-state.sh` | Passed |
| ZIP/tree and JSON/YAML/XML parsing | Passed where relevant tooling was available |
| GitHub Actions CI | The project owner reports that CI is green for the updated repository; this status was not independently re-run from the audit container. |
| Nix evaluation / `nixos-rebuild dry-activate` | Not run by this reviewer: `nix` is unavailable in the audit environment. The project owner separately reports a successful target-system rebuild; whether the exact `dry-activate` command was run was not specified. |
| `shellcheck`, `xmllint`, `virt-xml-validate` | Not run: tools are unavailable in this environment |
| Real VM/GPU lifecycle | Not independently run by this reviewer. The project owner now reports that the RT-Bore-LTO kernel built successfully and that the Windows VM started, shut down normally, and returned the host to Hyprland. This is target-machine owner-reported validation, not an independent test or a guarantee for other hardware. |

The checked-in `nixos/flake.lock` records the CachyOS `master` revision `02ba4db52e62e1fbece80402d369127ae77cbbeb` for reproducibility; `nixos/flake.nix` does not hard-code a kernel version. To move the system to a newer upstream revision, update only the CachyOS input, inspect the lock diff, then evaluate and build the candidate. Nix is unavailable in the review environment, so this reviewer did not independently run flake evaluation or a kernel build. The project owner reports that the target system rebuilt successfully, compiled RT-Bore-LTO locally, started and shut down the Windows VM normally, and restored the Hyprland host session. This is owner-reported evidence rather than a result independently reproduced in this container, and it does not guarantee compatibility on other hardware.

## Required checks on the target NixOS host

From `/etc/nixos/nixos/`:

```bash
nix flake check --no-build --show-trace --no-update-lock-file --option warn-dirty false
sudo nixos-rebuild dry-activate --flake .#nixos -L
```

Watch whether the kernel is substituted from cache or built locally. If the same `tools/bpf/resolve_btfids` `ld.lld: undefined symbol` error recurs, capture the full derivation log with `nix log /nix/store/<kernel-derivation>.drv`; a lock/cache change does not itself fix a linker bug in source. Keep the currently working system generation until the candidate generation succeeds.

The project owner has confirmed a successful RT-Bore-LTO build and rebuild, VM start, normal shutdown, and host Hyprland recovery on the target machine; this closes the previously reported VM recovery issue for that setup. After future kernel, firmware, PCI-layout, VM XML, or hook changes, repeat the lifecycle check and inspect GPU/audio driver restoration. XML parsing is not a substitute for libvirt/QEMU validation or a real boot.


## Follow-up fixes in the reviewed archive

- Defined `PATCHED_XML=/var/lib/libvirt/win10.xml` before its first use in `install.sh` and translated the remaining installer prompt/help strings. The originally uploaded full-project ZIP did not encode Unix permission bits for `install.sh`, so extraction produced mode `0644` even though the Git index records `100755`. The fix-only patch ZIP for the 2026-10-16 corrections stores `install.sh` as mode `100755`; this statement is verified against the patch archive, not inferred from the Git index.
- The installer backs up an existing deployed VM XML, then regenerates it from the repository template while preserving the existing UUID and MAC and synchronizing GPU/audio PCI addresses; arbitrary custom XML edits are not merged into the regenerated file. Manual-copy instructions warn that host-specific PCI addresses must be checked.
- Documented a manual migration prerequisite check for `/etc/nixos/hashedPassword` in `README.md`, including non-empty content, root ownership, and mode `0600`, before rebuild commands. The installer now performs the same presence/metadata check during preflight and warns without aborting, because the manual checklist may still need to create or repair the file. Its example creates a hash only when the file is missing or empty, preserving an existing valid hash. Added a regression assertion that rejects the former undeclared `iommu_dir` spelling; the checked-in installer already uses the declared `gpu_iommu_dir`.
- Retracted the false OVMF template-architecture finding, corrected historical HEAD wording, and removed stale advice to refresh the CachyOS lock during routine installation.
- Set all configured locale categories and the supported generated locale to `en_US.UTF-8`. The Turkish Q keyboard mapping remains intentionally configured as a physical keyboard-layout choice, not as the system language.
- Translated remaining Waybar/Hyprlock labels, notifications, service descriptions, runtime errors, hook comments, and the commented USB-input XML notes into English. Translation output from the OCR/game translation feature remains Turkish intentionally.
- Added `scripts/test-installer-invariants.sh` and connected it to CI to guard the XML destination, preservation of deployed XML, English locale, and known user-visible strings.
- Added a Windows 10 lifecycle warning to the README; standard Home/Pro support ended on October 14, 2025.
- Corrected the installer preflight summary to disclose the actual changes: replacing the NixOS VFIO hook source under `/etc/nixos/nixos/hooks`, writing `/var/lib/libvirt/win10.xml`, and retaining backups without automatic pruning. The active NixOS-generated libvirt hook is refreshed only after a successful rebuild/activation; the installer does not run `virsh define` for the written VM XML. The README and disclaimer state these timing and activation limits explicitly.
- Replaced the ambiguous `nixfmt ./nixos` README command with a `find`/`xargs` pipeline that invokes `nixfmt` separately on each `.nix` file.
- Hardened `scripts/test-vm-xml.py`: the checked-in template must contain exactly two PCI `hostdev` elements, their source addresses must be unique, and they must match the two distinct hook defaults.
- Clarified the VFIO release log so it distinguishes restoration of the GPU display function from restoration of the HDMI/DP audio function; a restored display GPU no longer implies that both functions recovered.
- Made the installer checklist non-destructive for `hashedPassword`, translated the final remaining Turkish source comment, and moved the `nixos-enter ... passwd root` instruction to after successful `nixos-install` in `KURULUM.md`.

## Follow-up validation of this fix bundle

- The fix-only patch ZIP produced for the 2026-10-16 corrections stores `install.sh` with Unix mode `100755`. The original full-project ZIP is intentionally not included or repackaged in this patch-only delivery; apply these files over the project tree and create a fresh full-project archive from the corrected tree when needed. ZIP mode was read back from the produced patch archive, not inferred from the Git index.
- The pre-existing validation suite passed again for the 2026-10-16 correction set: `bash -n` for the installer, QEMU hook, and regression tests; `scripts/test-installer-invariants.sh`; `scripts/test-vfio-hook-driver-state.sh`; `scripts/test-vm-xml.py`; Python compilation for repository scripts; JSON parsing for `flake.lock`; and XML parsing for `win10.xml`. The newly added disk preflight code block in `KURULUM.md` was also extracted and Bash-syntax-checked. These checks do not simulate a real disk operation or VM lifecycle. Negative tests in the existing suite also confirm that duplicate PCI addresses and a third PCI `hostdev` are rejected.
- `shellcheck`, Nix evaluation/build, and libvirt validation were not run by this reviewer because the required tools are unavailable in the preparation environment. Real hardware tests were also not run independently by this reviewer. The project owner confirms the VM problem is resolved on the target system: rebuild and BORE-LTO kernel build succeeded, the VM started and shut down normally, and the display/Hyprland session recovered. The report records this as owner-verified real-system validation, not independent reproduction or a general guarantee for other hardware.

- The privileged XML updater uses the already-resolved Python interpreter. XML parsing errors, an incomplete/extra PCI `hostdev` pair, or a PCI node whose source-address structure cannot be synchronized now abort before a VM XML backup/write. Added a preflight guard against running the checkout from `/etc/nixos` (which would overlap source and destination), trimmed monitor-name input before generating Hyprland defaults, and expanded the installer regression tests. Source ZIPs should be built from Git so `install.sh` remains mode `100755`; patch ZIP delivery independently stores that mode in the archive metadata.


## Latest requested configuration changes — 2026-10-16

- The current RT-Bore-LTO package follows `github:xddxdd/nix-cachyos-kernel/master`; the package version is not hard-coded in `flake.nix`. The lock file records the resolved upstream source revision for reproducibility, and a newer revision is selected by running `sudo nix flake update --flake /etc/nixos/nixos cachyos-kernel` followed by a review of the lock diff. Do not use `--accept-flake-config` simply to bypass the cache-trust prompt. The `nup` Fish alias targets only this CachyOS input and works from any directory.
- `LOW_LATENCY_LAYER=1` and `LOW_LATENCY_LAYER_REFLEX=1` are set through `environment.sessionVariables` so PAM-launched desktop sessions receive the system-wide Reflex setting. Affected applications may opt out with `DISABLE_LOW_LATENCY_LAYER=1`.
- OpenSSH password authentication is enabled for `localhost` only, root login is disabled, TCP/22 is permitted by the firewall, and Fail2ban no longer exempts RFC1918 ranges. The contradictory Fail2ban comment was removed. The installer now checks the SSH hash file's presence and `root:root:0600` metadata during preflight and warns if setup is incomplete. The QEMU hook terminates only `seat0` rather than all sessions for the desktop user, preserving a remote SSH session. The existing GPU-node check still aborts and rolls back if a process retains the device.
- This environment did not run Nix evaluation or build the RT-Bore-LTO kernel. Test the lock update, full rebuild, SSH persistence during VM startup, and complete VM stop/host-GPU recovery sequence on the target system before relying on these changes.

## 2026-10-19 follow-up — VM XML preservation and Vulkan capture compatibility

- Extracted the privileged VM XML synchronization code into `scripts/sync-vm-xml.py` so it can be tested independently and called by `install.sh`. When `/var/lib/libvirt/win10.xml` already exists, the existing XML is now the source of truth; the helper backs it up and updates only the four BDF attributes for the two PCI hostdev source addresses. It retains the current UUID/MAC, disk path, firmware/NVRAM, CPU/device settings, USB passthrough entries, comments, and additional PCI-address attributes. Malformed XML, a different domain, unsupported primary-disk layout, extra/missing PCI hostdevs, or unsupported source-address shapes abort before the destination is changed. New VM XML continues to start from the checked-in template and receives a new UUID/MAC.
- Added `scripts/test-vm-xml-sync.py` and made CI run it. Tests cover new VM identity, existing VM customization/identity/disk path/USB retention, exact backup contents, PCI address updates, and fail-closed behavior when a deployed XML has an unexpected extra PCI hostdev.
- Added the upstream `low_latency_layer` v0.2.0 `obs_vkcapture` compatibility caveat and per-game opt-out to the English project guides.
- Validation run after these changes: Bash syntax checks for all shell entry points; Python compilation for `scripts/*.py`; `scripts/test-vm-xml.py`, `scripts/test-vm-xml-sync.py`, `scripts/test-vm-diagnostic.py`; `scripts/test-installer-invariants.sh`, `scripts/test-installer-rollback.sh`, and `scripts/test-vfio-hook-driver-state.sh` all passed. `nix`, ShellCheck, and libvirt/QEMU validation tools are not installed in the review environment; no Nix evaluation/build or real hardware lifecycle test is claimed.
- Made `INSTALLATION.md` the canonical English installation guide. The root `KURULUM.md` filename remains only as an English compatibility pointer; automated checks now validate the canonical guide. Replaced the root `DEGISIKLIK_GECMISI.md` with an English current-state summary and preserved the full original Turkish history unchanged at `docs/archive/DEGISIKLIK_GECMISI.md`.


## Follow-up corrections — 2026-10-20

- The installer now records whether the NixOS deployment directory existed before the run. The transaction is marked active before the first `mkdir -p`, so a failed or partial directory-creation operation is covered by rollback. After managed targets are restored/removed, rollback uses `rmdir` only for a directory created by this run. It never recursively deletes the directory itself; if unrelated content remains or removal fails, the directory is retained and rollback is reported as incomplete.
- `scripts/test-installer-rollback.sh` now covers both new-directory outcomes: an empty directory created by the failed installation is removed, while unrelated content is preserved and the directory remains. Existing-file and symlink rollback tests remain in place.
- The patch-only ZIP stores `install.sh` with Unix mode `100755`; the archive contains only files changed in this correction set and excludes `.git/`.
- Validation for this correction set: `bash -n install.sh scripts/test-installer-rollback.sh` and `bash scripts/test-installer-rollback.sh`. Nix evaluation/build, ShellCheck, libvirt semantic validation, and real hardware/VM lifecycle checks were not performed here unless separately available in the target CI/host environment.
