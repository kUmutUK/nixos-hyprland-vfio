# Changelog

This file summarizes notable changes in English. The Turkish release-by-release history is retained in [`docs/archive/DEGISIKLIK_GECMISI.md`](docs/archive/DEGISIKLIK_GECMISI.md); a dated status preface was added there to flag settings later superseded. Dated third-level headings under `[Unreleased]` are editorial event labels, not dated release sections; the top-level `[Unreleased]` bucket itself remains undated. The retained external-audit sequence begins at audit five because records for audits 1–4 are not retained; the broad 3 November 2026 cross-check is intentionally unnumbered.

## [Unreleased]

### Exact-HEAD build, CI and v1.4.2 release verification — 2026-11-05
- Reconciled the current-state README, root index, repair report, and documentation-integrity regression with the verified 5 November source snapshot `9661091e35aed98b18483ff6d25a54fe0653c877`.
- Normal CI #1220 passed all 28 workflow-defined steps on that exact commit; manual full-system build #11 also passed on the same commit, including complete NixOS toplevel/selected-kernel build and unchanged-lock verification.
- Release workflow run #7 published v1.4.2 from the same commit. The canonical release ZIP contains 72 tracked files and nine executable files, excludes `.git/`, expands `SOURCE_REVISION` to the exact commit, and is accompanied by a SHA-256 manifest.
- Clarified that the 4 November #10 / OPEN build-gate status was accurate for its then-reviewed snapshot but was superseded by #11. The documentation/changelog/test-only follow-up remains within the release ancestor-build allowlist; exact-commit normal CI is still required before a subsequent release.
- No NixOS runtime setting, kernel selection, VFIO hook, or VM XML was changed. The successful build does not independently validate real libvirt saved-state restore or add new target-host hardware-test evidence.


### Fourteenth supplied audit cross-check — 2026-11-04
- Flagged the contradictory historical Hyprland package tables attributed to the same nixpkgs 7a0f122 revision; the archive now records the conflict without asserting an unverified exact package version.
- Removed the redundant eza item from home.packages; programs.eza.enable remains responsible for the Home Manager package and integration. System-profile fzf, git, and kitty remain intentionally available alongside their per-user Home Manager configuration.
- Marked manual full-system build #9 as a historical 3 November baseline superseded by build #10 on 4 November.
- The supplied report is dated 5 November, one day after this repository update. Its ZIP size/hash/entry/mode claims remain unverified because the archive bytes were not attached.

### Thirteenth supplied audit cross-check — 2026-11-04
- Reconciled the latest supplied review against GitHub `main` at `b2d2691b98764705edd8a689924b0ae16024bde6`; the last successful full-system build remains #10 on `480972a235655f6d1e9ec6137f85ad3f30b8655a`.
- Kept the manual full-system build gate open for the later Home Manager, flake, MAKO derivation, and installer changes. Normal CI and package checks do not substitute for a complete NixOS/selected-kernel build.
- Marked the supplied ZIP measurements as unverified without the archive bytes and documented why the tracked `SOURCE_REVISION` placeholder is expected to expand via `.gitattributes` during canonical `git archive` packaging.
- Aligned the installer's example monitor output with INSTALLATION without changing monitor detection or runtime display settings; left the VFIO hook and all other runtime preferences untouched.

### Game graphics profile guidance — 2026-11-04
- Added a per-game baseline for the RX 6700 XT / 170 Hz setup: native CS2, conservative MAKO Adaptive profiles for single-player games, and the existing LSFG-VK profiles as alternatives.
- Documented the actual MAKO v4.6.0 controls, Gamescope refresh-feedback condition, FP16/quality-first defaults, and when to test GPU Headroom or a higher adaptive ceiling.
- Clarified that MAKO profiles are saved by `mako-ui` and are not generated or overwritten by the Nix package. The system-wide AMD low-latency default, Reflex choice, Home Manager settings, and current LSFG-VK profiles were not changed.
- Updated OptiScaler guidance so MAKO, LSFG-VK, and OptiScaler Frame Generation are explicitly mutually exclusive per game. This documentation/test update does not close the already documented full-system build gate, and it makes no new RX 6700 XT runtime-performance claim.

### CS2 frame-generation profile — 2026-11-04
- Removed the CS2 process match from the LSFG-VK v2 profile set to keep competitive CS2 on native rendering. Genshin Impact, Wuthering Waves, Benchmark, and vkcube profiles remain unchanged; the global AMD Anti-Lag/low-latency defaults, MAKO integration, and OptiScaler manager are untouched.
- Updated the LSFG-VK regression test to reject any CS2 process alias in the generated frame-generation profiles.
- Because this change modifies `nixos/home.nix`, it starts a new full-system build gate. Build #10 on `480972a` predates this change; a build covering the updated Home Manager source is required before release.

### Source-tree audit hardening — 2026-11-04
- Fixed the VM XML sync regression test so its mocked `lspci` executable is created in a `TemporaryDirectory` and cleaned up on every exit; normal CI now rejects a dirty or untracked checkout after validation.
- Aligned the current-state audit section order, qualified the historical four/five-file preflight wording, and corrected the Home Manager customization line range in INSTALLATION.
- The archive measurements quoted in the supplied audit remain report-supplied in this source-only pass because the ZIP bytes were not attached. The supplied twelfth-audit text names `e080015ca3593d4f185888f86379268a20706639` in its package summary but says `e0880015` in section 2.1; its 760,112-byte/126-entry/45-`.git` inventory is therefore not independently verified. The separate 54-`.git` count remains an unresolved report-supplied outlier, not a new source-tree measurement. The supported distribution remains the canonical output of `scripts/package-source-zip.sh`, published by CI/release automation.
- Reconciled the historical gaps against Git: the IOMMU parameters were added on 9 October and removed on 13 October; ICH9 audio was removed on 12 October and restored on 23 October; the old `2a7a:8a47` USB hostdev was disabled on 9 October and replaced by the active `1532:0098` / `05ac:024f` entries on 16 October. Exact commits and the documented rationale are recorded in the current-state index and Turkish archive preface.
- The supplied report's claimed empty Hyprlock label did not reproduce: the current lock label contains the lock glyph (`text = ;`), so no Home Manager runtime setting was changed.

### MAKO Renderer integration — 2026-11-04
- Added an optional Nix-packaged MAKO Renderer v4.6.0 from the official x86_64 Linux archive, pinned by its published SHA-256 and exposed as `.#mako-renderer`.
- Added the package to Home Manager without global Vulkan injection, Steam launch-option edits, LSFG-VK profile changes, OptiScaler changes, or latency-layer default changes; each game opts in with `mako-launch %command%`.
- Added package/integration regression checks and a normal-CI build. The new NixOS/Home Manager source requires a fresh full-system build; no target-host MAKO runtime or RX 6700 XT game test is claimed.

### VM XML and exact-HEAD audit reconciliation — 2026-11-04
- Reconciled the README's review date with the 4 November audit and documented the XML's separate emulated PS/2 inputs alongside the machine-specific USB passthrough devices.
- Documented the NixOS runtime QEMU/OVMF paths used by the VM template, including a host-side check for the configured QEMU emulator.
- Recorded exact-HEAD verification for `480972a235655f6d1e9ec6137f85ad3f30b8655a`: normal CI #1145 passed all 28 workflow-defined steps and uploaded canonical source artifact 13277885590; full NixOS system build #10 passed on the same commit.
- Confirmed the Git tree has 69 tracked files and nine tracked executable modes. The supplied hand-compressed ZIP's reported size, entry counts, metadata, and 60 mode changes remain unverified because its bytes were not attached; use the matching CI artifact or canonical packager.
- Kept the old eight-executable count as a dated 2026-10-28 snapshot, and retained the already-qualified ICH9/backup-retention history. No VM XML, installer, NixOS runtime setting, flake input, kernel, or desktop preference was changed.

### Pyprland, PCI and cursor audit remediation — 2026-11-04
- Corrected the Pyprland terminal scratchpad rule to match the configured Kitty window class `pypr-term`, rather than an unset `scratchterm` title; added a documentation-integrity regression for the class/command relationship.
- Tightened the installer's QEMU-hook PCI updater to the same valid slot range (`00`–`1f`) as the shared PCI validator. Added regressions accepting slot `1f` and rejecting `20`/`ff` for both GPU and audio functions without modifying the hook.
- Made `Plus-Cursor` a single-shape theme: every cursor filename and common XCursor alias resolves to the `+` glyph, with no inherited theme for hand, text, wait, or resize states. Removed the separately installed Bibata theme; it remains only the source asset for the generated plus-only theme.
- Kept the system-wide and Home Manager `XCURSOR_THEME` values aligned with Hyprland's explicit startup setting (`Plus-Cursor`).
- Preserved GameMode `gpu_device = 1`: the actual DRM `cardN` mapping still requires live output from the target host and was not guessed.
- The Home Manager and NixOS configuration changes require a fresh full-system build before release. This audit update does not claim a new complete-system build or physical VFIO/VM validation.

### Documentation audit reconciliation — 2026-11-03
- Removed the stale copied CachyOS commit SHA from the current-state index; the resolved revision is now sourced only from `nixos/flake.lock`. The documentation-integrity regression reads the lock and rejects a copied 40-character revision in the kernel status line.
- Reconciled the current-state index with the archived USB-hostdev note and the template's active `1532:0098` and `05ac:024f` IDs; the historical archive itself remains unchanged. Recorded that the available history does not prove when they were re-enabled. The historical IOMMU-parameter record is likewise qualified without inventing a removal commit or rationale.
- Corrected the stale date in the documentation-integrity test's README diagnostic. Normal CI run #1127 passed all 28 workflow-defined steps. GitHub numbers its runner-generated `Set up job` entry as step 1, followed by the 28 YAML-defined steps numbered 2–29; `#1127` is the workflow run number and `41693786038` is the distinct run ID used in the URL.
- No runtime NixOS settings, kernel selection, GameMode GPU index, QEMU/VFIO hook, VM XML, latency-layer defaults, LSFG-VK profile, or desktop theme were changed.

### OptiScaler update payload-removal recovery — 2026-11-03
- Fixed updates where a newer OptiScaler archive no longer contains a file managed by the previous release: restore the pre-install original when one was backed up, and remove only obsolete files that were absent before manager installation.
- Validate every required original-file backup before rotating the previous one-step rollback. A missing or unsafe backup now aborts before game-file mutation; obsolete original-file mappings are removed from the new manager state after restoration.
- Added offline regressions for dropped payload files, original-file restoration, subsequent removal, update rollback, and a missing-backup failure that must preserve the previous installed state and rollback snapshot.

### Audit remediation and verification update — 2026-11-03
- Fixed the OptiScaler shared-cache race: every download now owns a unique same-directory temporary file, hashes the bytes it writes, flushes them before publication, atomically replaces the cached archive, and removes only its own temporary file. A barrier-synchronized two-thread regression reproduces the former collision deterministically.
- Closed the idle-display security gap: Hyprlock now starts at 300 seconds and DPMS powers the display off at 305 seconds, so the screen is locked before it goes dark.
- Updated the contributor validation sequence to include the pinned Actionlint command, ShellCheck of the Nix-generated VFIO hook, and syntax validation of the generated Hyprland Lua file.
- Updated current CI/artifact history: pre-remediation main snapshot `d34c8c3545da92d5d9dae97afb4e627edd0c167f` passed normal CI #1127; artifact `13258097729` (331,775 bytes) belongs to that snapshot. CI #1120 / artifact `13217103984` remain historical records for reviewed snapshot `8d1e4585`.
- The maintainer reports a successful 3 November rebuild and normal Windows 10 VM/GPU passthrough shutdown-and-return test on the physical RX 6700 XT host. This report does not claim that libvirt saved-state restore was tested.
- The `nixos/home.nix` idle-timer change is a system-configuration change. Full-system build #9 remains the previous verified baseline; a fresh full-system build is required before release. The current `gpu_device = 1` value was deliberately preserved because the target host's live DRM card mapping cannot be measured through this repository update.

### Exact-HEAD full-build baseline refresh — 2026-11-03
- Promoted manual full-system build #9 (`ab89f350803d47eb16499c613b110da05a57673f`) to the verified baseline. The complete NixOS toplevel/selected-kernel build, flake evaluation, and unchanged-`flake.lock` check all passed on that exact commit (4 h 46 min 26 s).
- Diagnosed normal CI #1124: its documentation-integrity regression still compared changes against the superseded `ca6edf2` baseline and incorrectly rejected `nixos/configuration.nix`, `nixos/flake.lock`, and `nixos/home.nix`, even though full-system build #9 covered that exact tree. Updated the test to track the newest verified full-build baseline while retaining its ancestry and changed-path gate.
- Kept the verification records distinct: normal CI #1120 passed on ancestor snapshot `8d1e4585c9cd3f690c1df80ee531008c7e9d30ef`; its canonical artifact (ID `13217103984`) belongs to that snapshot and is not represented as an artifact for build baseline #9. Physical saved-state restore and GPU/display lifecycle validation remain target-host tasks.

### Post-audit regression hardening — 2026-11-03
- Preserved the previous OptiScaler one-step rollback when an update cannot back up a newly encountered original game file: original backups are now atomically copied before rollback history is rotated, with a fault-injection regression for the failed-copy path.
- Added fail-fast per-game `flock` serialization for install/update, status, rollback, and removal so concurrent commands cannot race over one game's files or manager state; separate game directories remain independent.
- Made OptiScaler rollback and removal recoverable across injected mid-operation I/O failures: durable pre-operation snapshots restore the prior game state when possible and are retained with an explicit path if automatic recovery also fails. Added tests for rollback-copy failure, final state-file write failure, and second-stage recovery failure.
- Made VM XML synchronization reject a `--domain` value that does not match the template domain, before querying libvirt or touching deployed XML; added a no-write regression.
- Made installer `apply_var` reject duplicate Home Manager assignments instead of rewriting every match; added unique/missing/duplicate assignment regression cases.
- Fixed the repair report's duplicate 2 November heading and completed the README repository map with the OptiScaler Manager guide, implementation, and tests.
- Kept `install.sh` outside the release ancestor-build allowlist. At the time of this audit entry, its source change still required a new full build; that requirement was subsequently satisfied by exact-HEAD manual build #9. The mock-only `scripts/test-installer-invariants.sh` regression harness remains allowlisted as CI test code.

### Safety and recovery follow-up — 2026-11-03
- Closed the latest audit gaps: OptiScaler now rejects symbolic links, hard links, reparse points, and special files from 7-Zip metadata before extraction, and validates the complete state JSON shape, safe paths, proxy names, backup mappings, and SHA-256 values. Manual VM XML synchronization now verifies `lspci` classes and requires the GPU/audio functions to share the same PCI slot; mock-backed regressions cover wrong classes and unrelated devices.
- Added the OptiScaler manager regression command to the README validation sequence and clarified that this repository's optional manager is an independent, nonofficial third-party helper, not an upstream component.
- Hardened the optional OptiScaler manager: rollback and removal preflight every required backup, install/update state writes now participate in rollback, failed removal attempts restore the pre-remove file state, the 4 GiB extracted-size limit is enforced from a complete 7-Zip listing before extraction, while incomplete size metadata is rejected. Added regression tests for missing backups and injected I/O failures.
- Added support for libvirt saved-state restore through the QEMU `restore begin` XML-filter hook. The hook shares the cold-start VFIO preparation path and returns the original domain XML unchanged only after successful preparation. Mock tests cover the filter contract; the later exact-HEAD full-system build #9 includes this hook, while target-hardware saved-state restore remains pending.

### Optional Proton gaming integration
- Added an optional OptiScaler Manager for stable-release checks, verified downloads, explicit per-game Proton installation, status, one-step rollback, and removal with original-file restoration. It fails closed without a trusted SHA-256, rejects unsafe archive paths, requires an offline/single-player confirmation, and never edits global Steam/NixOS settings. Added offline regression coverage; no NixOS derivation, LSFG-VK profile, or latency-layer default changed.

### Exact-HEAD verification refresh — 2026-11-02
- Updated the current-state index and repair report from the superseded `b7950ee` / CI #1082 baseline to `ca6edf2a381118fbd81aeccb82287f234f44a257`, which passed normal CI #1084 and full NixOS system build #6 on the exact same commit.
- Recorded the canonical CI source artifact metadata for run #1084 and clarified that the manually uploaded checkout ZIP is a noncanonical external archive; the tracked `scripts/package-source-zip.sh` implementation remains the supported packaging path.
- Replaced fixed historical-SHA assertions in the documentation regression test with parsed cross-document baseline checks and a Git-history guard that permits only the documented release/documentation/CI allowlist after the last exact-HEAD verified baseline.
- Made normal CI fetch full Git history so the documentation regression can check the baseline ancestor and changed-path allowlist instead of silently accepting a stale verification record.



### Release workflow and audit follow-up — 2026-11-01
- Repaired `.github/workflows/release.yml`: closed the stable-semver filter, removed the stray fragment and duplicate publication steps, and kept one release pipeline.
- Added pinned `actionlint` validation of every workflow to normal CI so malformed workflow YAML and common GitHub Actions expression/configuration errors fail the standard check.
- Fixed ShellCheck findings exposed by the new workflow lint gate: documented the intentional single-quoted nested Bash script and removed shell-sensitive backticks from the flake.lock error message.
- Aligned README release prerequisites with `RELEASING.md`: normal CI is required for the exact tagged commit; the full-system build may be on an ancestor only when all later changed paths are explicitly allowlisted release/documentation/CI metadata.
- Updated the release allowlist and its documentation together, added the omitted VM XML structure test to `CONTRIBUTING.md`, expanded documentation-integrity regressions, and completed the README repository map.
- Rechecked the 2026-11-01 uploaded ZIP: its `.git/` directory and missing ZIP Unix-mode metadata are properties of that uploaded checkout archive, not the tracked source packager. The literal `$Format:%H$` in a normal Git worktree is intentional because `.gitattributes` applies `export-subst`; `scripts/package-source-zip.sh` uses `git archive` to expand the exact revision and preserve executable modes. No NixOS, VFIO, VM XML, kernel, latency-layer, or desktop-theme settings were changed.
- Refined git-cliff release-note selection: pushed version tags use `--current` to process commits belonging to the tag at HEAD; manual dispatch from `main` uses `--latest` to process commits since the previous tag. A documentation-integrity regression now pins this event-specific behavior.
- Refreshed current verification records with normal CI run #1078 for `da159dd` and successful full-system build #5 for `3afc40d`. The subsequent source diff is limited to the release/documentation/CI paths permitted by the ancestor-build release policy; no system derivation inputs changed.
- Independently measured the 1 November ad-hoc ZIP and confirmed it is noncanonical (.git metadata, absent ZIP Unix-mode metadata, and an unexpanded worktree revision placeholder). Independently verified the matching CI artifact and its SHA-256 manifest instead; the canonical packager itself remains unchanged.
- Follow-up commit `272f434e` passed normal CI run #1080, including the documentation-integrity regression, actionlint, Nix evaluation, LSFG-VK v2 package build, ShellCheck, Statix, and Deadnix. Its canonical source artifact was downloaded and independently verified (65 files, no `.git/`, matching manifest, nine executable entries at `0755`).
- Added the root `DEGISIKLIK_GECMISI.md` current-state index to the full-build ancestor release allowlist, and pinned the matching `RELEASING.md` explanation and documentation-integrity regression. This keeps index-only documentation updates from blocking a release while system-affecting paths remain gated by a fresh full build.
- Aligned `.git-cliff.toml`, release-tag validation, and previous-tag selection to one strict stable `vMAJOR.MINOR.PATCH` rule; the documentation-integrity regression now verifies exact pattern parity and valid/invalid examples.
- Refreshed the current-state index and repair report with the `b7950ee` source baseline, successful exact-HEAD CI run #1082, canonical artifact provenance, and the continuing distinction between normal CI and the ancestor full-system build.

### Tenth audit follow-up — 2026-10-30
- Repaired the malformed ninth-audit entry, which had accidentally pasted the changelog heading into the middle of a source-ZIP sentence.
- Re-measured the newly supplied 587,335-byte ZIP (`6b0111ca7cfb442d84bdbc22c516efbde2e90c6ea5a1f88bf9076317d99b4b11`): 116 entries, including `.git/`; all entries lack Unix mode metadata; the nine Git-tracked executable files therefore extract as non-executable with the tested extractor. The embedded Git metadata identifies main commit `a627fcb13b15e71e90983a3a2ff391d38eb743e5`; the uploaded `SOURCE_REVISION` file itself still contains the literal `$Format:%H$` placeholder.
- Confirmed that the ZIP defect is in the supplied artifact, not the canonical packager. Use `scripts/package-source-zip.sh` or the matching CI artifact; do not distribute a checkout ZIP containing `.git/` and missing executable modes.
- Fixed `install.sh` so the GPU/audio PCI rewrite must succeed and both assignments must be present exactly once with the expected values before VM XML synchronization can continue. Added regression tests for failed writes, missing assignments, and invalid PCI input.
- Left `vm-xml/win10.xml`, the active NixOS configuration, kernel selection, and the Arthur wallpaper/theme unchanged.

### Ninth audit follow-up — 2026-10-30
- Recorded the prior supplied ZIP's independently verified provenance separately from the current upload; its measurements apply only to that earlier 583,569-byte artifact and commit `65b0028cd76352daea9e5a01e4d7d9afb954b10b`.
- Classified the missing `.git` exclusion, Unix executable metadata, and expanded `SOURCE_REVISION` as canonical-package requirements; the tracked packager generates and validates those properties.
- Marked the older LSFG-VK v1 schema decision as historical and superseded by the 2026-10-29 v2 migration.
### Eighth audit follow-up — 2026-10-30
- Corrected the README and disclaimer to state that `install.sh` does not create VM XML for a new, unregistered VM; fresh XML generation belongs to the post-install VM-preparation flow.
- Expanded the documentation-integrity test to reject the stale template-generation wording and verify the disclaimer's new-VM behavior.
- Marked the archived `[1.3.8]` ICH9-removal statement as historical: the current template still defines a backend-less ICH9 device, while the available history does not establish when it returned or whether the old removal was fully applied.
- Distinguished the archive's 2026-10-19 snapshot date from the 2026-10-30 preface update, and clarified that the file includes a dated preface rather than being a byte-for-byte unchanged copy.

### Seventh audit follow-up — 2026-10-30
- Recorded the supplied seventh ZIP's reported size, SHA-256, embedded revision, and metadata as unverified provenance; the ZIP bytes were not attached for independent remeasurement.
- Scoped the README's VM XML synchronization statement to registered/deployed VM state and documented that a genuinely new VM receives its XML in the post-install preparation flow.
- Added an evaluation-time assertion for Hyprland 0.55.0+ and a documentation-integrity regression check for both the version guard and README wording.
- Clarified that ZIP permission recovery depends on extraction behavior; corrected the report's inventory arithmetic note without inventing a replacement line count.
- Confirmed that the reported “anual” typo is not present in the current report and left the protected `vm-xml/win10.xml` template unchanged.

### Fifth audit follow-up — 2026-10-30
- Repaired the pasted heading in the supplied-ZIP provenance table and expanded the documentation-integrity regression test to check both audit reports, the current archive record, the five-file migration instruction, and the date reference.
- Restored the executable bit on `scripts/test-installer-invariants.sh`; the canonical ZIP helper now checks the complete expected executable-file set so a lost mode bit is caught before artifact publication.
- Removed the 602-line duplicate block from `scripts/test-installer-invariants.sh`; the root current-state index records this cleanup.
- The upstream [low_latency_layer v0.2.0 release](https://github.com/Korthos-Software/low_latency_layer/releases/tag/v0.2.0) explicitly requires `LOW_LATENCY_LAYER=1` to opt in. The current global setting is correct; Reflex remains unset globally and opt-in per compatible game.

### Documentation consistency follow-up — 2026-10-30
- Corrected the README's stale `nix build .#lsfg-vk` reference to the actual `.#lsfg-vk-v2` flake output and extended the documentation-integrity test to compare the documented command with `nixos/flake.nix`.
- Clarified that the ICH9 device in the VM template has no host audio backend (`audio type="none"`); guest audio is expected through the passed-through GPU HDMI/DP function when available. Added a regression check for the XML/README agreement; `vm-xml/win10.xml` itself is unchanged.
- Recorded the verified current kernel defaults: `boot.kernelParams` contains `amd_pstate=active`, `nowatchdog`, and `nmi_watchdog=0`; `usbcore.autosuspend=-1`, `kvm.ignore_msrs=1`, `amdgpu.ppfeaturemask`, `amd_iommu=on`, and `iommu=pt` are not active defaults. The IOMMU history is now resolved: `ed6ca666` added both parameters on 9 October; `0c035b2c` removed them on 13 October because `amd_iommu=on` was not documented across all kernel versions and `iommu=pt` does not prove firmware activation; `91c4d58e` clarified the no-parameter state on 15 October.
- Clarified that the current VM template has active USB passthrough IDs `1532:0098` and `05ac:024f`; `2a7a:8a47` is absent. The older `[1.2.0]` archive entry describes a past state. Commit `f46b8ac8` disabled the old `2a7a:8a47` hostdev on 9 October; `fbd105c8` replaced that block with the two active IDs on 16 October. README instructions require users to verify these machine-specific IDs.
- Reaffirmed that installer backups are not automatically pruned; the older `[1.3.8]` “last five backups” line is historical, not the current policy.
- Corrected the historical `amd_iommu=on` section reference, aligned README's full Bash syntax-check loop with CONTRIBUTING, updated the `home.nix` line hint, and recorded the supplied noncanonical ZIP's provenance separately from the earlier archive measurements.

### Sixth audit follow-up — 2026-10-30
- Corrected the README layer-inspection command placement, expanded the WuWa monitor parser to accept resolutions with or without a refresh-rate suffix, and updated the wallpaper watchdog description to include GameMode.
- Documented the Hyprland 0.55+ Lua requirement from the upstream 0.55 release notes, the RX 6700 XT native `gfx1031` identity versus the `gfx1030` compatibility override, the e1000e guest NIC, and a qualified 32 GiB host-memory recommendation.
- Added explicit `lsusb` checks for the two machine-specific USB passthrough IDs before VM definition. This is a manual preflight; the XML and installer behavior are unchanged.
- Documented that `input-remapper` is installed but its daemon is not enabled; mappings require the optional `services.input-remapper.enable` setting. Removed the redundant direct `steam` package entry; `programs.steam.enable` remains authoritative.
- Added the sixth supplied ZIP's reported measurements to the provenance table. The ZIP bytes were not attached, so the measurements and claimed payload match were not independently rechecked.
- The available history still does not identify the exact USB reactivation commit or a complete rationale for the historical IOMMU-parameter removals. No rationale was fabricated; the current IOMMU and ICH9/audio state was already documented.

### SSH authentication policy — 2026-10-30
- Recorded the rollback of the 2026-10-23 password-enabled SSH setting. The current configuration disables `PasswordAuthentication` and `KbdInteractiveAuthentication`, requires configured public keys, and keeps root SSH login disabled. TCP 22 should remain restricted at the network edge.

### Correct Reflex default — 2026-10-29
- Keep `LOW_LATENCY_LAYER=1` enabled globally while leaving `LOW_LATENCY_LAYER_REFLEX` unset in system-wide session variables, preserving the layer’s default AMD Anti-Lag interface. Compatible games can opt into Reflex per game with `LOW_LATENCY_LAYER_REFLEX=1 %command%`.
- Updated the installer regression gate, workflow label, and README to prevent an accidental system-wide Reflex default.

### LSFG-VK v2 migration — 2026-10-29
- Replaced the archived v1-only flake module with the upstream LSFG-VK v2 package, pinned to an immutable source revision and hash; registered the v2 Vulkan layer manifest and migrated the Home Manager TOML to `version = 2` / `[[profile]]`.
- Updated the installer source preflight, private backup set, deployment transaction, rollback tests, contributor instructions, and CI to include `nixos/lsfg-vk-v2.nix` and build `.#lsfg-vk-v2`.
- Kept the latency layer enabled globally while keeping Reflex selection opt-in per compatible Proton title; native Linux CS2 retains the default AMD Anti-Lag interface.
- The upstream v2 package is CC BY-NC-ND 4.0; the Nix expression pins and builds upstream source without patching it. Lossless Scaling remains a separate Steam prerequisite.

### Installer safety and regression coverage — 2026-10-28
- Moved NixOS/live-installer detection ahead of installer locking and the high-risk acknowledgement prompt, so unsupported environments stop before interactive consent.
- Added a fail-closed win10 libvirt state guard: the installer now requires a successful domain query, only accepts the exact `shut off` state for a registered VM, and rechecks immediately before the first backup/file mutation. The installer-invariant suite now executes the guard with mocked `virsh` success, running/paused states, and list/state query failures.
- Added fail-closed Home Snapper validation for the exact `/home` mount, the `@home` and `@home/.snapshots` subvolumes, the target hardware configuration's device UUIDs, and any active `/home/.snapshots` mount. The preflight runs before backups/deployment and again after the final hardware configuration is selected.
- Added mocked Home Snapper regression cases for wrong subvolumes, mismatched UUIDs, missing mounts, non-Btrfs filesystems, and the boot-critical snapshots mount.
- Included `/etc/nixos/.source-revision` in the installer's backup set and added rollback coverage proving that a failed deployment restores the prior marker.
- Aligned profile backups, Home Manager `home.stateVersion` fallback, and `~/` wallpaper expansion with the configured `localhost` home instead of the invoking administrator's `$HOME`.
- Kept `SOURCE_REVISION` as an `export-subst` placeholder: canonical packaging expands it to the exact archived commit. A malformed manual ZIP should be replaced by a validated canonical archive, not given a stale fixed SHA.

### Archive provenance and validation correction — 2026-10-28
- Fixed the README Bash syntax-validation command to run `bash -n` separately for each listed script in a fail-fast loop. Passing multiple pathnames to one `bash -n` invocation does not syntax-check every file independently.
- Recorded the user-supplied measurements for the ZIP under review before remediation: **494,995 bytes**, SHA-256 prefix `00805455…`, embedded Git HEAD `cdfd3d8d5008e4b7405ce2433e29b8a0e34ffebe`, and 105 entries including 45 `.git/` entries. The ZIP bytes were not attached to this editing session, so these values were not independently recalculated.
- Reclassified the previous **493,030-byte / `45e3edaa…` / `c395611f…`** ZIP as a different historical archive; do not use it as the provenance for the submitted file.
- Confirmed the canonical `git archive` helper and CI already exclude `.git/` and preserve tracked executable modes. Added validation that each canonical ZIP embeds the exact commit being packaged.
- Fixed inconsistent source pinning across clean install, README Path B, and `install.sh`: each deployment records the source commit, and VM preparation refuses a missing/malformed marker, a mismatched HEAD, or a dirty checkout.
- Closed the initially-inactive-to-active VFIO service race with an ActiveState recheck, fail-closed handling, and a mocked regression test.
- Adapted the manual VM-bootstrap regression fixture to create a real, clean temporary Git checkout and a matching source-revision marker, so it exercises mandatory pin verification rather than stopping early at the new preflight.

### Audit regression fixes — consolidated historical notes
- Corrected the installer’s `hashedPassword` preflight and regression tests to identify it as the local `localhost` account password hash, not an SSH password file; the warning now explicitly confirms SSH password authentication stays disabled. Added an invariant against reintroducing that mismatch.
- Made `scripts/package-source-zip.sh` publish its validated ZIP with mode `0644` so shared artifact collectors can read it. Updated README’s source tree and local validation commands plus CONTRIBUTING to cover the installer-lock test and ShellCheck/package-helper scope.
- Updated current-state documentation to use the canonical packaging helper and describe SSH public-key-only authentication. The 2026-10-16 repair-report section is now explicitly historical and superseded.
- Added `scripts/package-source-zip.sh` as the single canonical source-archive path; it verifies archive completeness, excludes `.git`, and preserves all tracked executable bits. CI now uses and ShellChecks the same helper, while README instructions no longer encourage ad-hoc ZIP creation.
- Fixed fresh-VM bootstrap retry behavior in both manual guides: new XML and qcow2 files are staged until ISO preflight and disk creation/ownership/permissions succeed, with an end-to-end regression test for missing-ISO retry, failed/partial disk creation, orphan-disk refusal, and success. The clean install now records its source commit and verifies the post-reboot checkout rather than silently cloning a newer `main`; the README repository map now includes `full-system-build.yml`.
- A previous manually compressed full-source ZIP was found to be noncanonical because it included `.git/` and omitted Unix execute permissions for `install.sh`, although the Git index retained mode `100755`. This was a packaging-only defect; the canonical `git archive` helper and CI validation already handled it. The old run #928 reference applies only to SHA `a631d195891ff6da74ae727ac3c531ffc77c50ed`, not later `main` revisions.
- Added a manually dispatched full NixOS system-build workflow with a six-hour budget; it builds the complete `nixosConfigurations.nixos.config.system.build.toplevel` (including RT-Bore-LTO) without slowing every push/PR run. The workflow still does not replace physical GPU/VM lifecycle validation.
- Removed unused `self` and `pkgs` function parameters, configured Statix to ignore only the style-only `repeated_keys` warning for the repository's flat NixOS option style, and promoted Statix/Deadnix from informational steps to required CI gates.
- Restricted PCI slot/device numbers to the hardware-valid range `00`–`1f` in installer-side and VM XML address validation; regression tests cover acceptance of `1f` and rejection of `20`/`ff`.
- Clarified the firewall documentation: KDE Connect's NixOS module opens TCP/UDP ports 1714–1764 automatically, while separate P2P/seed services should receive only their explicitly required ports.
- Added an early preflight for the four Nix source files required at the time in `install.sh`. The 2026-10-29 LSFG-VK v2 migration added a fifth required source file (`nixos/lsfg-vk-v2.nix`), and the 2026-11-04 MAKO integration added the sixth (`nixos/mako-renderer.nix`). The current preflight and regression coverage require all six. Missing or empty sources now abort before the user prompt, and the deployment phase rechecks them so a disappearing source triggers rollback instead of mixing configuration trees.
- Hardened the VM diagnostic helper against dangling output symlinks and destination races. It rejects output symlinks and publishes the temporary file atomically without overwriting an existing destination; a regression test covers dangling links.
- Included `waydroid-container.service` in VFIO handoff state capture, stop, and restore because Waydroid is enabled in the reference configuration and may retain GPU resources. A real target-machine VM lifecycle test is still required.
- Added common Proton/Wine Wuthering Waves LSFG-VK process aliases and a TOML regression test. The actual process matched at runtime must still be confirmed from target-machine logs.
- Updated `actions/checkout` to the pinned Node 24-compatible v7.0.1 revision, added a targeted LSFG-VK package build gate, added read-only Nix formatting checks, and included Python in the development shell.
- Restored Lossless Scaling installation prerequisites, corrected the README repository map, and changed validation instructions to fail fast without rewriting Nix files.
- Removed the duplicated installer-invariant test block, consolidated contributor validation into one correctly fenced command block, refreshed the root current-state index to 2026-10-27, and clarified that SSH's `AllowUsers` rule restricts the account name rather than the remote source address.
- Made VM XML migration query libvirt's registered `win10` domain and prefer its persistent `virsh dumpxml --inactive win10` definition over a stale/missing `/var/lib/libvirt/win10.xml`; libvirt query/export failures now stop before writing, and both registered and existing on-disk XML are backed up.
- Hardened `scripts/extract-embedded-scripts.py` so a `source = ...` attribute cannot capture a later script body's `text = ''` block, and unterminated Nix indented strings fail explicitly. Added a regression test and made it a CI and contributor-validation step.
- Made VFIO service stops fail closed when a previously active unit cannot be verified inactive, while retaining the saved pre-VM state for rollback. Added mocked stop/start failure coverage. Installer `stateVersion` discovery now prompts instead of choosing silently when existing candidate files conflict or contain duplicate/non-literal assignments; regression tests cover conflict and ambiguity cases.
- Updated the manual installation guide to pass `--domain win10` and document the persistent `virsh dumpxml --inactive` source of truth, aligning it with the README and installer.
- Fixed the manual VM setup’s new-versus-existing decision: it now queries libvirt’s registered domain list before checking the on-disk XML, and refuses to guess if the query fails. Added regression guards for both manual guides. The existing CI archive step already creates and validates the canonical ZIP (`git archive`, no `.git/`, executable `install.sh`); use its uploaded artifact rather than an ad-hoc ZIP.
- Fixed the installer/manual-setup handoff for a genuinely new VM: `install.sh` now synchronizes XML only for a registered `win10` domain or an already deployed XML. If neither exists, it defers fresh XML creation to the VM-preparation block, preserving the new-disk path while still refusing to overwrite or silently adopt an existing disk.
- Made the clean-install VM-preparation blocks self-contained after reboot: because `/tmp/repo` belongs to the Live ISO session, README and INSTALLATION.md now create/use a persistent checkout under `$HOME` when needed and refuse to overwrite a conflicting non-Git path.
- Historical provenance note: the recheck against parent `8e063bd3ddcf5774dba10553fe06be2cbcb15fdc` referred to a different earlier ZIP with embedded HEAD `8c6cf467038bacbc8cba46a0c9dcfe54e13c467d`. Those identifiers do not describe the latest archive now summarized at the top of the repair report.

- Historical pre-v2 design note (superseded 2026-10-29): the earlier LSFG-VK v1 (`[[game]]`/`exe`) schema decision said v2 was not wired into the active tree. That statement no longer describes the current configuration; see “LSFG-VK v2 migration — 2026-10-29” above for the active package, `version = 2` / `[[profile]]` configuration, deployment/rollback paths, tests, and CI.
- Added the embedded-script extractor regression test to the README's manual validation commands, keeping the documented test sequence aligned with CONTRIBUTING and CI.
- Updated the current repair report to record the successful CI run for the already-merged `main` commit and to distinguish that result from physical GPU/VM lifecycle validation.
- Historical archive-audit provenance: the 456,770-byte / 101-entry upload, the 436,212-byte / 96-entry upload (`a631d195…`), and the 455,316-byte / 101-entry upload (`8467e496…`) were separate prior attachments. They are retained only as historical records and must not be reused as measurements of the latest 493,030-byte archive. No change to the installer's tracked executable mode is justified by a ZIP-only permission defect.
- Updated the validation report to record a reproduced combined-command timeout at the outer 120-second limit after all eight regression scripts and separate syntax/compile/JSON/XML checks printed success. The tests themselves did not report failures; per-test timing and the exact runner timeout trace are still missing, so combined-run stability remains unresolved.

- Added a fail-closed preflight for file-backed CD-ROM ISO paths before VM disk creation and XML definition, with regression tests wired into CI and documented in the README and installation guide.
- Validated the XML root element in both the ISO preflight and diagnostic-copy helpers, with wrong-root regression tests. Hardened the two-file new-VM publication rollback so a concurrent final-XML collision removes only the disk inode created by this run; added a mocked concurrency regression test. Added the VM bootstrap test to CI/contributor Bash syntax and ShellCheck coverage and completed the repository map entries for `scripts/test-manual-vm-bootstrap.sh` and `statix.toml`.

## Follow-up fixes — documented 2026-10-23 (includes earlier changes)

This is the date the consolidated note was recorded, not a claim that every listed change first occurred on 23 October. Earlier status snapshots and repair notes retain their own dates.

### Follow-up audit fixes
- Preserved an existing deployed VM XML as the source of truth during migration and synchronized only the two GPU/audio PCI addresses. The helper retains the existing VM identity, custom CPU/firmware/NVRAM/device settings, disk path, USB passthrough entries, and extra source-address attributes; unsupported layouts fail closed. Added regression tests for new VM identity, existing XML preservation, backups, and unsafe XML refusal.
- Documented the upstream `low_latency_layer` v0.2.0 incompatibility with the `obs_vkcapture` Vulkan capture layer and the per-game opt-out.
- Added regression coverage for the README's manual migration guard (copy when the generated source exists, preserve an existing target, and fail closed when the source is missing). The supplied README already checked the correct source path; the earlier audit's quoted faulty snippet did not match the actual archive.
- CI now builds and validates one canonical Git archive and uploads that same ZIP as the `nixos-hyprland-vfio-source` workflow artifact after all required checks pass, preventing an independently repackaged archive from being mistaken for the tested source bundle.
- Clarified the repair report so historical full-project and patch-only archives are not conflated. The `install.sh` contents are unchanged; this patch ZIP preserves its executable mode.
- Marked the 2026-10-21 patch-bundle description explicitly as historical, so the repair report no longer describes the full-source tree that contains it as a “current patch-only ZIP”.
- Fixed GPU/audio PCI role assignment in the VM XML sync helper: existing hostdev blocks are matched by the reviewed guest-side PCI target addresses rather than XML order. Unknown/custom target addresses now fail closed, and regression tests cover reordered blocks and unknown targets.

### Changed
- Switched the selected kernel from standard CachyOS BORE-LTO to `linuxPackages-cachyos-rt-bore-lto`. The version is not hard-coded: the flake follows the upstream `master` branch and the lock can be updated for newer upstream revisions with `nix flake update cachyos-kernel`. Upstream does not publish the RT-Bore-LTO ThinLTO build in its binary cache, so it is expected to compile locally. The project owner has since reported a successful local RT-Bore-LTO build and VM/Hyprland recovery cycle on the target machine.
- Enabled the Vulkan low-latency layer and Reflex system-wide through PAM session variables `LOW_LATENCY_LAYER=1` and `LOW_LATENCY_LAYER_REFLEX=1`. Applications with compatibility issues can opt out with `DISABLE_LOW_LATENCY_LAYER=1` in their Steam launch options. **Superseded on 2026-10-29:** the global `LOW_LATENCY_LAYER_REFLEX=1` default was removed; Reflex is opt-in per compatible game.
- Enabled password SSH for the `localhost` user on TCP 22 while keeping root SSH login disabled, restricting allowed users, and applying Fail2ban to private LAN sources too. Updated the VFIO hook to terminate only the local `seat0` sessions so remote SSH sessions are not killed by `loginctl terminate-user`; a busy GPU still triggers the existing fail-closed handoff check. **Superseded on 2026-10-30:** password and keyboard-interactive authentication are now disabled; public-key authentication is required.
- The checked-in CachyOS lock in this tree resolves the upstream `master` input to `02ba4db52e62e1fbece80402d369127ae77cbbeb`. The lock keeps this checkout reproducible; advance it intentionally when a newer upstream revision is desired. The revision is recorded without inferring a kernel version from the commit hash.
- Replaced the broad `nup` alias (`nix flake update`, which could update unrelated inputs and depended on the current directory) with a privileged CachyOS-only update targeting `/etc/nixos/nixos`.

### Fixed
- Made the installer roll back the prior NixOS flake files, hardware configuration, VFIO hook directory, and deployed VM XML when a non-zero exit occurs after deployment begins. The XML is now included in the pre-change backup set, and targets that did not previously exist are removed during rollback.
- Updated the VFIO hook to persist the pre-VM active state of `greetd`, `ollama`, and `polkit.service` under `/run/libvirt/vfio-state`; VM release and prepare rollback now start only services that were active before handoff. Added mocked regression coverage for active and inactive states.
- Changed the installer to stop by default before deployment on non-AMD or unidentified CPU/GPU hardware rather than proceed with an AMD-only configuration after a warning.
- Documented the upstream CS2/Source 2 frame-pacing caveat for the globally enabled Vulkan latency layer, including the `fps_max 0` workaround and per-game opt-out.
- Added a dedicated rollback regression test and made it a required CI step; retained the explicit RT-Bore-LTO ThinLTO selection.
- Corrected the Fail2ban comment so it matches the active setting: only loopback is exempt; private LAN ranges remain bannable.
- Added an installer preflight check for `/etc/nixos/hashedPassword` presence, non-empty content, root ownership, and mode `0600`. This is warning-only so the documented manual setup can fix the file before activation.
- Reject running the installer from `/etc/nixos` before system changes, trim monitor-name input before using it in Hyprland defaults, and abort VM XML synchronization unless exactly two real PCI `hostdev` elements have supported source-address blocks. Added regression coverage for malformed/incomplete/extra PCI pairs and whitespace-only monitor input.
- Corrected the Rofi theme comment without changing the working `arthur` binding; clarified that `wuwa-gemma` is a custom Ollama alias based on Aya Expanse 8B, not a Gemma-family model.
- Restricted installer XML address synchronization to PCI `hostdev` nodes, fixed warnings for incomplete versus extra PCI entries, and added a regression test that ensures USB address sources are never rewritten as PCI addresses.
- Aligned the README with the default VM XML and documented the two active fixed USB passthrough IDs. The system-wide Reflex configuration is now enabled again; per-game opt-out is documented for incompatible Vulkan applications.
- Clarified that installer host-device counts and synchronization refer to PCI `hostdev` entries, not all device types; extended the VM XML regression test to guard the documented USB IDs as well as the PCI pair.
- Clarified single-GPU recovery guidance and changed the hook to terminate only `seat0`, preserving headless SSH sessions while retaining the fail-closed GPU-use check. Removed a duplicate `android-file-transfer` package entry and corrected a stale Home Manager package-list comment.
- Removed the unused Waypaper package and `SUPER+W` binding, corrected the installer's missing-PCI-device diagnostic so it does not invoke `lspci` a second time, and translated the color notification title to English.
- Clarified that IOMMU kernel parameters are not enabled by default, corrected the VM input limitation comment, and added a regression check that VM XML GPU/audio PCI addresses match the QEMU hook defaults.
- Standardized root-required commands in the fresh-install guides and preserved the generated NixOS config as a backup before installing the repository tree.
- Fixed the Home Manager startup command so it starts `mpvpaper-watchdog` only when the optional `monitorOutput` is configured; documented the disabled-by-default kernel parameters and correct per-activation swap encryption behavior.
- Removed stale advice to refresh the CachyOS lock for every install and corrected the English changelog's claim about historical version coverage.
- Historical change: the CachyOS input was switched to upstream `release` at that point to align with its cached nixpkgs revision. The current `nixos/flake.nix` follows `master`; `overlays.pinned` still selects the kernel flake’s pinned nixpkgs revision. The upstream Attic cache and public key were configured at an earlier point, but are not present in the current active cache lists; the current tree configures Nix Community's cache only. The selected RT-Bore-LTO ThinLTO variant is not published in upstream binary cache, so adding another cache would not remove its local-build requirement.
- Corrected the Windows VM's Q35 machine alias and made the Windows installation ISO boot ahead of the VirtIO driver ISO. Added a regression test for these XML invariants and wired it into CI.
- Hardened the Ollama fallback translator: HTTP errors, malformed responses, and empty translations now fail without being cached as successful translations.
- Translated English-named project documentation, installer comments/messages, and VFIO hook diagnostics/recovery messages into English. The root `KURULUM.md` and `DEGISIKLIK_GECMISI.md` are English compatibility/current-state pointers; the original Turkish release-by-release history is preserved at `docs/archive/DEGISIKLIK_GECMISI.md`. Comments embedded in installation command examples are translated too. Turkish OCR translation notifications remain intentional application UI.
- Replaced stale archive-document wording with English historical audit summaries so old findings are not mistaken for current defects. The original Turkish release-by-release changelog remains intentionally preserved at `docs/archive/DEGISIKLIK_GECMISI.md`; that historical source is the explicit exception to the English active-document policy.
- Corrected migration instructions for the required `hashedPassword` file and the VM XML fallback source; updated the related regression test, and guarded against the old undeclared IOMMU path variable recurring. Retracted the false OVMF template mismatch claim, marked old commit hashes as historical, and removed stale guidance to refresh the pinned CachyOS lock for routine installs. The input ZIP did not encode the executable bit for `install.sh`; this follow-up fix bundle restores Unix mode `100755`.
- Corrected the installer and documentation to distinguish the VFIO hook source under `/etc/nixos/nixos/hooks` from the active NixOS-generated libvirt hook, which is refreshed only by a successful rebuild/activation. Clarified that the installer writes but does not automatically define the VM XML, and that timestamped installer backups are not pruned automatically. Translated the remaining Turkish installer risk/compatibility prompts into English and updated their regression assertions; corrected the README's Nix formatting command to format each `.nix` file explicitly.
- Made the password-hash checklist preserve existing valid hashes, aligned the Turkish install guide's root-password command with the post-install stage, and translated the last Turkish comment in active Nix code. The repair bundle encodes `install.sh` as executable in the ZIP itself.
- Hardened the VM XML regression test to require exactly two distinct PCI hostdev addresses matching the QEMU hook, and clarified hook recovery logging when GPU display and GPU audio driver restoration differ.
- Corrected disk-size units in `KURULUM.md` and `README.md` (the `sgdisk` `G` suffix means GiB), added whole-disk, mounted-volume, and minimum-capacity checks before the destructive partition-table wipe, and narrowed the documented GPU target to RX 6700 XT/Navi 22. The fix-only patch ZIP stores `install.sh` with Unix mode `100755`; the originally uploaded full-project ZIP did not preserve that mode.
- Corrected the README Hyprland mouse-wheel entry to describe workspace cycling, matching `nixos/home.nix`; corrected the repository tree caption for the historical archive and documented the preserved Turkish changelog as an explicit language-policy exception. Updated the current changelog and current-state index dates to 2026-10-21.

### Validation
- Bash syntax checks passed for the installer, QEMU hook, and VFIO regression test.
- Python compilation checks passed for the scripts.
- VM XML invariants test passed.
- VFIO driver-state and service-state regression tests passed.
- Installer partial-deployment rollback regression test passed.
- The project owner reports a successful NixOS rebuild, local RT-Bore-LTO ThinLTO kernel build, Windows VM startup and normal shutdown, and return to the Hyprland host session on the target machine. This is owner-reported hardware validation and was not independently reproduced in the review container; it does not guarantee compatibility on other hardware. The review environment lacked Nix, ShellCheck, and libvirt/QEMU tools, so independent flake evaluation/build, ShellCheck, and semantic VM validation were not performed here. The checked-in `flake.lock` pins the CachyOS `master` input at `02ba4db52e62e1fbece80402d369127ae77cbbeb`; newer upstream revisions still require an intentional input update. RT-Bore-LTO ThinLTO is not published in the upstream binary cache and therefore requires a local build.

## Historical releases

The historical Turkish release entries are retained below a dated status preface in [`docs/archive/DEGISIKLIK_GECMISI.md`](docs/archive/DEGISIKLIK_GECMISI.md); the combined file is not a byte-for-byte unchanged copy of the original changelog. This English index intentionally avoids restating historical claims as if they were re-tested against the current tree; consult the Turkish file for the release entries it actually contains.
