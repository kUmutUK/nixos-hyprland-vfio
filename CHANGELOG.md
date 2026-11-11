# Changelog

This file summarizes notable changes in English. The Turkish release-by-release history is retained in [`docs/archive/DEGISIKLIK_GECMISI.md`](docs/archive/DEGISIKLIK_GECMISI.md); a dated status preface was added there to flag settings later superseded. Dated third-level headings under `[Unreleased]` are editorial event labels, not dated release sections; the top-level `[Unreleased]` bucket itself remains undated. The retained external-audit sequence begins at audit five because records for audits 1–4 are not retained; the broad 3 November 2026 cross-check is intentionally unnumbered.

## [Unreleased]

### Independent source-provenance and CI reconciliation — 2026-11-11

- Record v1.5.2 as the latest published release: Release ID `441604359`, Release run [#32](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/43012396764), exact tag commit `418bb687ec4f4d539e3ccc2d839baf242552c018`, Normal CI [#1396](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/43012004213), canonical ZIP 451,101 bytes, SHA-256 `11c0b38fc3de7c8f99a089018ad89131e175ca323c6652a19573f13f40b082c6`.
- Correct v1.4.9 provenance: the `v1.4.9` tag and Release run #25 target `a20962f9be065f17c7c2ec143473c47b7a75aae9`. Normal CI #1309 passed on the preceding `ad231d7529721eae343385cca9073790e4e3be61` commit, not the exact tag target. The 410,138-byte / `f28f9195...` archive is the canonical ZIP for `ad231d7`; the published 411,239-byte / `56c3d8df...` asset is the ZIP for `a20962f`.
- Reconcile Normal CI #1395–#1399: [#1395](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/43011838520) passed on `ec2482a`; [#1396](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/43012004213) passed on the v1.5.2 tag commit `418bb68`; [#1397](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/43022490748) failed on `7ea632a` when the bootstrap test lost its executable bit; [#1398](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/43022565265) passed on `ae175f4` after mode `100755` was restored; [#1399](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/43033685955) failed on `aebea08` because the old v1.4.9 test assertion had not yet been updated to the corrected provenance record. This commit updates that assertion; its own Normal CI result is separate.
- These are source-history and documentation corrections. They do not add a new full-system build, a new target-host activation result, or saved-state/managed-save evidence.


### Source-tree audit reconciliation — 2026-11-11

- Fix the manual VM bootstrap documentation drift: INSTALLATION now identifies the Windows primary disk by VirtIO target `vda`, so the optional `vdb` disk is tolerated.
- Extend the manual-bootstrap regression to compare the README and INSTALLATION Python snippets and execute both against the dual-disk VM XML fixture. Extend documentation integrity to derive the live tracked-file count from the checkout or canonical ZIP; the current source tree contains 75 tracked files.
- Correct the pinned WirePlumber module link to the root Nixpkgs revision `f4a03c008967841f2a0b3cb7c436fc6fc31671f6`, not the separate kernel-flake Nixpkgs revision.
- Reconcile Build #13's run-level timestamps (09:24:26–11:49:22 UTC) across the changelog and repair report; explicitly date-bound the v1.4.5 historical reference to Build #16 as of 8 November.
- Label the v1.4.9 410,138-byte record as an unresolved audit-intake snapshot and point to the later independent verification of the published 411,239-byte asset. Preserve both historical measurements and do not rewrite the release asset.
- Repair the Markdown continuation indentation and allowlist-line indentation in RELEASING.md. No NixOS runtime setting, VM XML, kernel input, hardware identity, or desktop preference was changed.


### Main-branch CI history reconciliation — 2026-11-11

- Reconcile push-triggered Normal CI runs #1385–#1394 against GitHub Actions: #1385 and #1387–#1389 failed at the documentation-integrity step for recorded assertion/name-binding regressions; #1386 and #1390–#1393 passed; the first report-only update failed #1394 on a remaining historical-reference assertion.
- Record the #1388/#1389 `DEGISIKLIK_GECMISI` NameError and its #1390 correction to the declared `STATE_INDEX` variable, the #1385/#1387 stale documentation assertions, and the #1394 missing #1382 README/status-index reference.
- Confirm the pre-reconciliation `main` snapshot `3c33b8b613c8c1da71263ea998607c11f046f22c` passed Normal CI #1393. This does not represent a new release or full-system build; Build #19 remains outstanding.


### CS2 Gamescope launch profile — 2026-11-11

- Document the owner-tested CS2 Steam launch option with Turkish Gamescope keyboard layout, 1440×1440-to-2560×1440 stretch scaling, GameMode, MangoHud, and an external 170 FPS cap.
- Keep Source 2's in-game FPS cap disabled with `+fps_max 0` to match the documented low-latency-layer frame-pacing workaround. This is documentation-only; no NixOS runtime defaults or existing per-game profiles are changed.

### VG27AQ1A DisplayPort audio idle-resume fix — 2026-11-11

- Add a device-specific WirePlumber ALSA rule for the reference-host VG27AQ1A DisplayPort sink, setting `session.suspend-timeout-seconds = 0` only on the exact observed node. Other audio sinks retain their existing idle-suspend behavior.
- The owner reported that a temporary user-level rule with the same property removed the 2–3 second audio delay after pausing and resuming video. The repository now carries the rule declaratively; activation through NixOS and persistence after reboot remain to be verified on the target host.
- The change touches `nixos/configuration.nix`, which remains outside the successful Build #18 ancestor baseline and the literal release allowlist. Build #19 or the documented explicit target-host release attestation is still required; normal CI alone is not a full-system build.

### Release-workflow and documentation audit — 2026-11-11

- Confirmed that the first-release release-notes block in `.github/workflows/release.yml` already uses the valid `body = source[match.end():]` expression on the reviewed `main` snapshot. Add a CI regression that extracts and syntax-compiles every embedded Python heredoc so future workflow-code syntax errors fail the normal check.
- Replace the incorrect fixed path-count wording with a reference to the exact literal ancestor-build allowlist; keep the documented path list and release workflow list identical and count-checked.
- Remove the orphaned dotted-number prefix from the README Rust/BTF troubleshooting heading and guard against similarly orphaned dotted-number headings.
- The current GitHub Release asset metadata reports 411,239 bytes and SHA-256 `56c3d8dfde3eb0b224803ccefa1b624b831a15eca02aaf62d5c4fd4907ff8a3e`. The owner subsequently reported an independent download-and-rehash confirming the published asset's size and digest. The earlier 410,138-byte / `f28f91955d05679b7ff64cb33fbd193a86f87527f856b9801f0e7a197c1f5e61` audit-intake archive is reproducible from `ad231d7`; only the acquisition/custody history of the original local copy remains unknown. No published release asset was modified.

### Home Snapper preflight parsing — 2026-11-11

- Fix the Btrfs subvolume-name parser to accept the horizontal indentation emitted by `btrfs subvolume show`, without relaxing the expected `@home` and `.snapshots` name checks.
- Make the Home Snapper regression fixture emit tab-indented, aligned `Name:` fields so the test matches real command output.

### Dual-guest VM disk layout — 2026-11-10

- Extend the existing `win10` libvirt domain with a separate optional NixOS VirtIO disk and an initially empty SATA installer tray. Keep the Windows disk and boot priority first, document safe create/attach/install/eject steps, and add regression coverage for the two-OS device layout.

### v1.5.0 source archive and v1.4.9 asset provenance — 2026-11-10

- Record the immutable v1.5.0 source-archive snapshot and the GitHub v1.4.9 asset size/digest provenance without rewriting either historical release asset.

### VM XML diagnostics and README bootstrap regression — 2026-11-10

- Replace brittle VM XML diagnostic text matching with a stable error code and test the README bootstrap by executing its extracted command in the mocked VM environment.

### Target-host NixOS-only VFIO first-start smoke test — 2026-11-11

- Record the owner-reported successful first start of a temporary NixOS-only win10 domain using a 90 GiB P4-backed qcow2 disk, NixOS Minimal 26.05 media, a separate NVRAM path, and the existing GPU/audio VFIO hook.
- Document the derived-XML workflow, QEMU USB bus/device requirement, SSH recovery channel, and exact scope boundary. The installed NixOS vdb boot, guest networking, full host GPU handback, and real Windows guest boot remain unverified; the canonical dual-guest XML release gate stays open.
- Record the unresolved host-continuity boundary: The available records do not establish whether the 9 November clean-install/Windows VM lifecycle test and the 11 November NixOS-only first-start test were performed on the same physical host. The 11 November inventory records only the state observed during that test; it does not establish when or why the Windows domain and disk became unavailable. No host reinstall, disk removal, or machine change is inferred.

### Rev 2 audit and validation boundaries — 2026-11-11

- Build #18 on `c6f4b955475de2ea16bc2b34c59a95dad3a1ae78` is 23 commits before v1.4.7, 58 before v1.5.0, and 66 before v1.5.1. Runtime-affecting paths changed in the intervening range; Build #19 remains outstanding.
- Keep the live `install.sh` migration/rollback test open. Bash syntax, ShellCheck, and mocked regressions do not replace an end-to-end run against an isolated, disposable NixOS/libvirt target with a verified recovery path.
- Preserve 9–11 November host continuity as unknown. Any reference-host inventory containing MAC addresses, serials, machine IDs, filesystem UUIDs, or PARTUUIDs belongs in a private local record, not this public repository.
- Clarify the GPU/audio IOMMU split: `0000:0b:00.0` was recorded in group 18 and `0000:0b:00.1` in group 19. Different group numbers alone do not prove an isolation defect or establish intra-device isolation; group membership and PCIe/ACS topology require separate review.
- H1 is already corrected in the archived [1.2.2] entry and dated preface: pinned Nixpkgs defines Hyprland `0.56.2` / hyprlock `0.9.6`; `0.54.3 / 0.9.5` is marked as the incorrect earlier statement. H3 and H4 remain documented historical anomalies; no old release description is rewritten and no missing Build #14 event is inferred.
- **Second reconciliation CI failure:** Nix Flake Check [#1383](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/42998196145) failed on `36c13be1558d70822edf9432fe6cca3507f6d8e5` at the documentation-integrity assertion `README must distinguish the immutable v1.5.0 release ZIP from later main-branch documentation`. Commit `edf78e8` restored `The v1.5.0 asset will not be rewritten`; [#1384](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/42998456098) then passed on exact commit `edf78e8559a289dda5da01467ce0082da2c38188`.

## [v1.5.2] - 2026-11-11

### Release and validation boundary — 2026-11-11

- Published [v1.5.2](https://github.com/kUmutUK/nixos-hyprland-vfio/releases/tag/v1.5.2), Release ID `441604359`, with Release workflow run [#32](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/43012396764) from exact tag commit `418bb687ec4f4d539e3ccc2d839baf242552c018`.
- Normal Nix Flake Check [#1396](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/43012004213) passed on that exact tag commit. The canonical source ZIP is 451,101 bytes with SHA-256 `11c0b38fc3de7c8f99a089018ad89131e175ca323c6652a19573f13f40b082c6`.
- The release contains the device-specific VG27AQ1A DisplayPort WirePlumber idle-resume rule. The owner-reported temporary-rule improvement is not evidence that this repository version has been activated through NixOS or verified after reboot.
- Manual full-system Build #18 remains on ancestor `c6f4b955475de2ea16bc2b34c59a95dad3a1ae78`, 82 commits before this release tag. Build #19 remains outstanding; release publication and Normal CI do not constitute a new full-system build.

## [v1.5.1] - 2026-11-11

### Release and validation boundary — 2026-11-11

- Published [v1.5.1](https://github.com/kUmutUK/nixos-hyprland-vfio/releases/tag/v1.5.1), Release ID `441417217`, with Release workflow run [#31](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/42988284472) from exact tag commit `c77db6f76f48ffc2640a7b242964a7b9b984bc0d`.
- Normal CI [#1380](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/42987182911) passed on the exact release commit. The source ZIP is 437,544 bytes with SHA-256 `7a37d0687ff8580aed0cb34eb4f4479cf2918fff0e65433e3e264e5b6787272f`.
- Release run #31 accepted later non-allowlisted post-build paths through the explicit `target_host_validated=true` maintainer attestation. The last completed full-system build remained #18 on ancestor `c6f4b955475de2ea16bc2b34c59a95dad3a1ae78`, 66 commits before the v1.5.1 tag; the attestation did not create a new full-system build result. Build #19 remains outstanding.
- The v1.5.1 source archive is immutable; subsequent `main` changes do not rewrite the published ZIP.

### Main-branch CI reconciliation — 2026-11-11

- The last CI-verified `main` baseline before this documentation update was `edf78e8559a289dda5da01467ce0082da2c38188`; Nix Flake Check [#1384](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/42998456098) passed on that exact commit.
- Its predecessor `36c13be1558d70822edf9432fe6cca3507f6d8e5` failed [#1383](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/42998196145) in the documentation-integrity step because the README no longer contained the required sentence distinguishing the immutable v1.5.0 ZIP from later `main` documentation. Commit `edf78e8` restored `The v1.5.0 asset will not be rewritten`; #1384 then passed.
- The preceding baseline `4cef0c5f02bb2a466070b6a2c9b5468fd59af7da` passed [#1382](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/42993935944). Earlier #1381 failed on `f63e5b5e9f3df6d00b3d6b2f6889540ab5f35b2a` and was corrected by `4cef0c5`. These runs are documentation/normal-CI history, not a new release or full-system build; Build #19 remains outstanding.
- For live branch state, use the [main commit history](https://github.com/kUmutUK/nixos-hyprland-vfio/commits/main) and [Nix Flake Check workflow runs](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/workflows/check.yml).

## [v1.5.0] - 2026-11-10

### Release and validation boundary — 2026-11-10

- Published [v1.5.0](https://github.com/kUmutUK/nixos-hyprland-vfio/releases/tag/v1.5.0), Release ID `440771489`, with Release workflow run [#27](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/42879152113) from exact commit `8818bd86dd55f8b456708902f16b01bf2052fbd8`.
- Normal CI [#1351](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/42873188122) passed all 28 workflow-defined steps on that exact commit; the runner-generated `Set up job` entry is not part of the YAML-defined step count.
- The canonical source ZIP contains 74 tracked files and 9 executable files; it is 423,969 bytes with SHA-256 `f886f40b2e6f73ab96dad67ab24d87b0734f955c8b26c6696c8746f6e8894ad0`.
- Release run #27 found successful full-system Build #18 on ancestor `c6f4b955475de2ea16bc2b34c59a95dad3a1ae78` and accepted later non-allowlisted changes using the explicit `target_host_validated=true` maintainer attestation. This is not a new full-system build result or a new independent physical-hardware test; saved-state/managed-save restore remains unverified.

### Remaining audit remediation — 2026-11-10

- Mark `install.sh` experimental in its runtime banner and user/contributor documentation. No end-to-end run of `install.sh` against a live NixOS/libvirt target host has been completed. Syntax, ShellCheck, and mocked regression checks are not live deployment validation; the 9 November clean-install report is not evidence that the helper was used.

- Move NixOS/live-media, root-user, and repository/deployment-overlap rejection ahead of the lock and high-risk warning/acknowledgement prompt; add a regression invariant for the exact ordering.
- Align the README, CONTRIBUTING, and CI ShellCheck script lists, and assert the same seven embedded-script count in contributor instructions and CI.
- Reconcile the full-system build run numbers against GitHub Actions history, clarify the 4 November Build #11 / 5 November release date boundary, and correct the v1.4.4 nested artifact-size record.
- Record the v1.4.3 GitHub Release publication on 10 November 2026, its original tag target, and its byte-identical source ZIP relationship to v1.4.4; the v1.4.4 release-description heading error remains a historical note.
- Use privileged `sudo cp -a` for installer recovery backups of root-owned or mode-restricted targets.
- Refuse VM XML template/destination identity, including resolved symlink and hard-link aliases, with regression coverage.
- Require a real `@home` Btrfs subvolume in all Home Snapper modes; strict manual checks require the existing child `@home/.snapshots`, while the installer uses an explicit allow-missing flag only because its later rollback-protected transaction creates that child. README and INSTALLATION now share the strict checker; regression tests cover both modes.
- Document the exact literal ancestor-build allowlist selection principle and keep `install.sh` gated by a fresh full-system build.
- Make installer PCI updates preserve valid leading indentation, keep preflight and replacement syntax consistent, print named-user tilde errors outside command substitution, and state explicitly that failed variable substitutions abort into transaction rollback.
- Add regression coverage proving untouched VFIO devices are skipped during rollback, the VM primary disk stays virtio and both CD-ROMs stay SATA, empty/network CD-ROM sources are valid non-file-backed media, CLI checker errors go to stderr, and line-leading Nix `''${` escapes are not mistaken for indented-string terminators.
- Disambiguate the 4 November configuration/installer cross-check from the separately numbered ninth audit; distinguish the v1.4.4 CI artifact and release ZIP records without inventing an explanation for their size difference.

### Audit remediation — 2026-11-10

- Fixed installer signal handling so INT, TERM, and HUP exit with non-zero statuses and reach the existing transactional rollback path; added subprocess regressions for all three signals.
- Updated the temporary VM diagnostic helper to accept both XML quote styles and added coverage for libvirt's single-quoted `dumpxml` output.
- Corrected the VM custom-USB test fixture to replace all four template IDs, including the lowercase Apple IDs, and verify each replacement.
- Made the OptiScaler v0.9.4 repository-pinned digest authoritative when GitHub also supplies an API digest, rejecting mismatches; invalid or empty XDG cache/state paths now fall back to their specified defaults.
- Corrected the release workflow's documented artifact/tag order and synchronized the literal ancestor-build allowlist for the standalone diagnostic helper and offline regression tests.
- **Historical gate correction:** the v1.4.6 release run #20 gate log reports that normal CI and the full-system build both passed for exact release commit `a6dd4544319fafa7ec517e73b31ad29a1b4010b3`. The audit's claim that v1.4.6 had no release-gate evidence is withdrawn; no underlying run ID is inferred where the retained log excerpt does not supply one.

## [v1.4.9] - 2026-11-10

### Release and validation boundary — 2026-11-10

- Published [v1.4.9](https://github.com/kUmutUK/nixos-hyprland-vfio/releases/tag/v1.4.9) with Release run [#25](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/42807672922) from exact tag commit `a20962f9be065f17c7c2ec143473c47b7a75aae9`.
- Normal CI #1309 (run ID `42807151011`) passed on the preceding commit `ad231d7529721eae343385cca9073790e4e3be61`; it is not the exact-tag CI result for `a20962f`. The corresponding exact-tag Normal CI run ID is not present in the retained source records and is not inferred here. The release run and annotated v1.4.9 tag both identify `a20962f` as the published source.
- The 410,138-byte / SHA-256 `f28f91955d05679b7ff64cb33fbd193a86f87527f856b9801f0e7a197c1f5e61` archive is reproduced from commit `ad231d7529721eae343385cca9073790e4e3be61`; it is the earlier audit-intake copy, not the published v1.4.9 asset. The published 411,239-byte asset is reproduced from the exact tag target `a20962f9be065f17c7c2ec143473c47b7a75aae9` and has SHA-256 `56c3d8dfde3eb0b224803ccefa1b624b831a15eca02aaf62d5c4fd4907ff8a3e`. The previous unknown-provenance description is withdrawn; neither published asset is rewritten.
- The release notes record the documentation-test file-mode correction, decoupling release documentation from the current version, and source-archive documentation-test coverage.
- Changes from the v1.4.8 tag are limited to documentation, CI workflow, and regression-test paths; no NixOS module, flake input/lock, hardware mapping, VM XML, or runtime hook was changed. The release workflow's full-system-build prerequisite passed against the existing baseline; v1.4.9 is not a new full-system build or a new physical-hardware test.

## [v1.4.8] - 2026-11-09

### Release and validation boundary — 2026-11-09

- Published [v1.4.8](https://github.com/kUmutUK/nixos-hyprland-vfio/releases/tag/v1.4.8) with release run [#24](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/42699056863) from exact commit `31acc15e5f590d67ab9d9ee477c7813e0766fe82`.
- Normal CI [#1306](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/42698412118) passed all 28 workflow-defined steps on that exact commit. The runner-generated `Set up job` entry is not part of the YAML-defined step count.
- The canonical source ZIP is 410,656 bytes; SHA-256 `4db66f4c856da157b8fc6995aaea7b86d40397868455976b21cb76566b1cadab`. The release also publishes the matching `.sha256` manifest.
- The documentation changes reconcile kernel/build evidence, record the owner-reported clean-install and normal VFIO VM lifecycle validation, and distinguish current from historical validation claims. The test changes align the kernel-validation assertions and distinguish current and historical hardware evidence.
- Manual full-system build #18 on ancestor commit `c6f4b955475de2ea16bc2b34c59a95dad3a1ae78` remains the last completed full-system build baseline. The v1.4.8 release gate passed; this release did not create a new full-system build result.

## [v1.4.7] - 2026-11-09

### Release and validation boundary — 2026-11-09

- Published [v1.4.7](https://github.com/kUmutUK/nixos-hyprland-vfio/releases/tag/v1.4.7) with release run #23 ([run ID 42685329584](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/42685329584)) from exact commit `c28250c34de4b4349023681305da99dee75aac9e`. The canonical ZIP is 407,251 bytes; SHA-256 `d33e36df8b8d6891c522fe2b8d27fa3d149da042c9284527d314c2eda89e9a05`.
- Normal CI #1299 ([run ID 42684408581](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/42684408581)) passed all 28 workflow-defined steps on that exact release commit. The runner-generated `Set up job` entry is not part of the YAML-defined step count.
- The last full-system build remains manual build #18 on ancestor `c6f4b955475de2ea16bc2b34c59a95dad3a1ae78`. The release commit is 23 commits ahead of that baseline; Build #18 did not build the exact v1.4.7 source snapshot.
- The 23-commit range includes runtime-affecting changes to `install.sh`, `nixos/configuration.nix`, `nixos/hardware-configuration.nix`, and `nixos/home.nix`. Release run #23 passed the gate through the explicit `target_host_validated=true` maintainer attestation after the owner-reported 9 November clean install, boot, normal Windows VM start/shutdown, GPU handback, and Hyprland recovery. This attestation is not a GitHub full-system build result.
- `nixos/home.nix` sets `render.cm_auto_hdr = 0`, disabling Hyprland's automatic fullscreen HDR switch. It does not force HDR or 10-bit output. The recorded clean-install/VM test did not separately validate HDR transitions, 10-bit output, or display flicker.
- The previous published release was [v1.4.6](https://github.com/kUmutUK/nixos-hyprland-vfio/releases/tag/v1.4.6), release run #20 on 6 November 2026; its 402,118-byte ZIP SHA-256 was `05ffe97ee342a4b233f56bc7ae0e455f3b91a1c87df86c42e57e0441e9089e76`.
- The prior pre-release reviewed source snapshot `f63250a4867105ea1e9e2724c0c47b5ae5e707cb` passed normal CI #1285; it is historical and superseded by the v1.4.7 release snapshot.

### Kernel, flake inputs, and host configuration refresh — 2026-11-09

- Disabled the two unused Rust kernel modules through `BLK_DEV_RUST_NULL = lib.kernel.no;` and `CPUFREQ_DT_RUST = lib.kernel.no;`, keeping general Rust, BTF, ThinLTO, and RT-Bore selection enabled.
- Manual full-system build #17 exposed the second Rust-module BTF failure in `rcpufreq_dt.ko`; **manual full-system build [run #18](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/42597469118) then completed successfully** with both symbols disabled on commit `c6f4b955475de2ea16bc2b34c59a95dad3a1ae78`.
- Updated the CachyOS kernel overlay to 7.3.3, refreshed the nested/root Nixpkgs and Home Manager lock entries, and updated the machine-specific hardware mapping. Verify host storage identifiers before activation.
- Normal CI #1285 passed all 28 workflow-defined steps on the earlier reviewed snapshot `f63250a4867105ea1e9e2724c0c47b5ae5e707cb`; the later v1.4.7 release commit was separately validated by CI #1299.

### Fresh-install and VM validation — 2026-11-09 (owner-reported)

- A clean NixOS installation from scratch on the reference physical machine completed without issues.
- The Windows 10 VFIO VM was started successfully and shut down normally; GPU control returned to the host and Hyprland resumed.
- This validates the ordinary VM lifecycle on the tested machine. Libvirt saved-state/managed-save restore remains unverified.

### Host storage and VM identity warnings — 2026-11-05

- Added explicit guidance that the deployed host's Btrfs/LUKS identifiers are intentional and must not be regenerated or interchanged with PARTUUID values.
- Documented that the libvirt domain UUID/MAC are persistent VM identity: the helper assigns fresh identity only for a genuinely new VM and preserves an existing domain's identity.

### Previous repository status and v1.4.5 release — 2026-11-05 (historical)

**Historical v1.4.5 release snapshot (5 November 2026):** GitHub `main` at `994b05c888fbb52295d93e8ef74e41bac66c5e65` at publication time; **normal CI:** run #1242 passed all 28 workflow-defined steps on this exact release commit; **full-system build:** manual [#13](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/42002113160) passed on ancestor build baseline `1dbb7d5407f5b478cee14da5d52dc0c1822d4e8b` (2 h 24 min 56 s); **published release:** [v1.4.5](https://github.com/kUmutUK/nixos-hyprland-vfio/releases/tag/v1.4.5) was published by release run #17 from this exact snapshot. As of 8 November 2026, the latest subsequent full-system build was manual run #16 on ancestor `a6dd4544319fafa7ec517e73b31ad29a1b4010b3`; changes after that build include kernel configuration, flake inputs/lock, and host hardware-configuration updates, so a new full-system build and successful normal CI on the exact candidate commit are required before a later release. The 3 November target-hardware validation remains owner-reported; libvirt saved-state/managed-save restore remains unverified.

**Pre-reconciliation main verification (5 November 2026):** GitHub `main` at `4eb6a106d825890a929fe57054a1660da524a458`; normal CI [#1244](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/42076151633) passed all 28 workflow-defined steps on this exact commit and uploaded `nixos-hyprland-vfio-source` (artifact ID `13438456860`, 383,949 bytes; outer artifact digest `sha256:f04a477945bc2b47d7f8c7394a8f178895ed950bba2f245fae9b7aecdf553d97`). The preceding documentation-only commit `d35155ce6b9fb089934ee2f15f4208279dc5e2da` had CI #1243 fail at the documentation-integrity gate; commit `4eb6a10` restored the missing historical assertions and CI #1244 passed. This is the last completed validation before this documentation/test reconciliation; this follow-up requires its own exact-commit normal CI before a later release.

- **Historical v1.4.5 canonical release ZIP:** 392,212 bytes; SHA-256 `f97fb12bdfbaaff4d32e7ab57bbc9251fababcd126a8ef7644947844924de9e0`; 72 tracked files, nine executable files, and no `.git/` entries.
- **Previous reviewed snapshot (historical):** `7f923a2c7aa59721bc00728faccbc073e06c697a`; CI #1239 / run ID `42032980751`; v1.4.4 from release run #15 / run ID `42035815458`. The release's canonical inner source ZIP is 388,000 bytes with SHA-256 `7621fcdccfe327e9e59f453947b9f7903cd0f477b73cde8f4aa5ee513061e0ff`. The CI artifact download is a 379,511-byte outer ZIP wrapper (artifact ID `13416329673`, outer digest `sha256:f9fdf7c3be15b69d032f4965e6765f841fd04f54e9096d2536091f5c01e267ed`) containing that same 388,000-byte source ZIP plus its 97-byte SHA-256 manifest; the inner manifest matches the published release ZIP digest.
- The earlier v1.4.4 release description inherited an incorrect `v1.4.3` heading; that remains a historical release-note issue. The v1.4.3 GitHub Release entry was subsequently published on 10 November 2026 at 11:52:57 UTC (Release ID `440298465`); the old v1.4.4 description was not retroactively rewritten. At the time of this 5 November historical section, v1.4.5 was the then-current published release; v1.4.6 was published on 6 November.
- That 5 November documentation/test reconciliation added no new physical-hardware or saved-state-restore evidence.
- The first documentation-only follow-up's normal CI #1243 failed only two documentation-integrity assertions (a missing exact build-baseline index line and missing historical `run #1239` wording); both records are restored in the follow-up. No runtime/NixOS configuration was changed.

### Target-machine hardware validation — 2026-11-03 (owner-reported; historical)

- On 3 November 2026, the project owner reported a successful NixOS rebuild on the then-current target configuration, successful local compilation of the selected RT-Bore-LTO ThinLTO kernel, and a successful Windows 10 VM start followed by normal shutdown and return of the host display/Hyprland session.
- The source lock at this validation point resolved the CachyOS kernel input to `755712deee259ef7efbfe9154038a270c3d75a87`. The result is maintainer-reported physical-hardware evidence, not an independently reproduced test and not a guarantee for other machines.
- This validates the ordinary VM start/shutdown and host-recovery path only. It does not claim a successful libvirt saved-state/managed-save restore cycle.

### Full-system build #13 baseline — 2026-11-05 (historical snapshot)
- Manual build #13 and normal CI #1233 both covered exact `main` commit `1dbb7d5407f5b478cee14da5d52dc0c1822d4e8b`; CI passed all 28 workflow-defined steps, including source ZIP validation, documentation/VM/installer regressions, Nix evaluation, LSFG-VK v2 and MAKO package builds, ShellCheck, Statix, and Deadnix. The later reviewed source snapshot and published v1.4.4 release are recorded above.
- Manual full-system build #13 passed on that same commit from 09:24:26 to 11:49:22 UTC (2 h 24 min 56 s), using the GitHub Actions workflow-run timestamps, including evaluation, the complete NixOS toplevel/selected-kernel build, and the unchanged-lock check.
- CI uploaded canonical artifact `nixos-hyprland-vfio-source` (artifact ID `13403280716`, 376,179 bytes; GitHub artifact digest `sha256:d892c0ee1a7227c9e4f593c04ce19fe0e3f69b35b1ae7a2562ed8e0804c3309d`). The digest identifies the outer GitHub Actions artifact.
- Build #13 covers the previously pending 5 November changes to `nixos/configuration.nix`, `install.sh`, and `nixos/home.nix`; the full-system build gate is now CLOSED for this exact source snapshot. No VM XML, PCI/USB identity, kernel selection, or desktop preference was changed by this verification follow-up.
- At the time of this historical build-baseline record, v1.4.2 was the latest published release from commit `9661091e35aed98b18483ff6d25a54fe0653c877` (run #7). It was superseded by v1.4.4, published by run #15 from the later reviewed source snapshot above. CI/build success does not add a new physical saved-state-restore result.

### GameMode priority and installer source preflight — 2026-11-05
- Corrected the GameMode comment and documentation-integrity regression: the configured positive `renice = 10` magnitude is negated by GameMode and applied as nice `-10`, raising CPU scheduling priority. The numeric setting itself is unchanged.
- Added `nixos/hooks/qemu` to the installer's initial required-source preflight through a separate runtime-source list, preserving the six-file Nix deployment loop. Expanded installer invariant and MAKO integration checks to cover the hook being present, non-empty, and required.
- These changes touch `nixos/configuration.nix` and `install.sh`, which remain outside the release ancestor-build allowlist. The previously required fresh build is now satisfied by exact-HEAD full-system build #13; normal CI #1233 also passed on that commit. `gpu_device = 1`, VM XML, VFIO behavior, and other hardware-specific settings remain unchanged.

### Conservative frame-generation fallback profiles — 2026-11-05
- Reduced the Genshin Impact LSFG-VK v2 fallback profile from 3x to 2x; Wuthering Waves remains at 2x. MAKO Adaptive remains the preferred first per-game Frame Generation path to validate, with LSFG-VK retained as the alternative.
- Added regression coverage for both 2x LSFG-VK profiles and clarified that the MAKO-first preference is not a measured RX 6700 XT performance ranking. Frame Generation remains opt-in per game; CS2, global AMD low-latency settings, Reflex, MAKO packaging, and OptiScaler behavior are unchanged.
- This updates `nixos/home.nix`; the earlier full-system build #11 did not cover the change. Exact-HEAD full-system build #13 and normal CI #1233 subsequently passed on `1dbb7d5407f5b478cee14da5d52dc0c1822d4e8b`, closing the build gate for this profile update.

### Previous exact-HEAD build, CI and v1.4.2 release verification — 2026-11-05 (historical)

The heading date follows the v1.4.2 publication date. Full-system Build #11 itself ran and completed on 4 November 2026 UTC; Release workflow run #7 published v1.4.2 on 5 November. Full-system build run numbers belong to a separate workflow and must not be confused with release run numbers.

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
- Reconciled the current-state index with the historical archive's explicit USB and IOMMU chronology. USB: `f46b8ac8` commented out the old `2a7a:8a47` hostdev on 9 October, and `fbd105c8` replaced it with active `1532:0098` and `05ac:024f` entries on 16 October. IOMMU: `ed6ca666` added `amd_iommu=on` and `iommu=pt` on 9 October; `0c035b2c` removed both on 13 October with the documented compatibility/semantics rationale; `91c4d58e` clarified the resulting state on 15 October. The former “history unknown” wording is withdrawn.
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
- Corrected the historical git-cliff explanation: pushed version tags use `--current` to process commits belonging to the tag at HEAD. The previous note claiming that manual dispatch from `main` used `--latest` was incorrect and is withdrawn; the current manual-release path uses the explicit previous-tag-to-HEAD range with the requested tag. A documentation-integrity regression pins this event-specific behavior.
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
- Historical lock snapshot: an earlier tree resolved the CachyOS upstream `master` input to `02ba4db52e62e1fbece80402d369127ae77cbbeb`. This is not the current lock value; the active resolved revision must be read from `nixos/flake.lock` (currently `9df32f70be3550911f178b3ba9ad784996a4e80c`). The lock keeps each checkout reproducible; advance it intentionally and inspect the lock diff.
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

### Independent audit cross-check and preflight fixes — 2026-11-11

- Correct the v1.4.9 snapshot narrative: the published tag / Release #25 targets `a20962f`; Normal CI #1309 belongs to preceding `ad231d7`. The 410,138-byte archive is reproducible from the latter, while the 411,239-byte published asset belongs to the tag target. Only the original local copy's acquisition history is unknown.
- Correct the dated repair-report claims about manual git-cliff dispatch and USB-ID chronology; clarify the historical v1.5.1 release note, separate Build #9's commit from the reviewed snapshot, and correct the 42-path allowlist count and Build #19 dispatch instructions.
- Fix the Home Snapper preflight so installer mode permits only a genuinely absent `/home/.snapshots` path; existing invalid paths and Btrfs verification errors remain fail-closed. Add regression coverage for all three states.
- Re-indent every line of the temporary VM diagnostic XML block and add a non-default-indentation regression.
- Strengthen documentation checks: use “five” for CI #1395–#1399, remove an unused placeholder, and compare the lock icon by Unicode code point.
- Two audit claims were not reproduced: the reported “anual” occurrences are correct “manual” substrings, and the seven omitted paths are deliberately excluded by the exact 42-path allowlist. No runtime NixOS setting, flake lock, VM XML, hardware identity, or published release asset was changed.
