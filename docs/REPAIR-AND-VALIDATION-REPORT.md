# Repair and validation report — updated 2026-11-09

> **Delivery-scope note:** This report is part of the tracked source tree. The dated “patch-only ZIP” notes below are historical. For a canonical full-source ZIP, use `scripts/package-source-zip.sh` or the CI-uploaded `nixos-hyprland-vfio-source` artifact for the exact commit. The helper verifies tracked-file completeness, excludes `.git/`, preserves executable bits, and makes the finished artifact readable from shared output directories.

## Chronological navigation (newest first)

The detailed sections remain grouped by subject and source snapshot; this index supplies their date order without rewriting the historical record.

- **2026-11-09 (Razer scroll-wheel filter):** pinned the MIT-licensed `mouse-hardware-fix` daemon and its C++ filter tests; a udev rule and sandboxed systemd template target only the Razer DeathAdder Essential USB ID `1532:0098`. The filter is configured for scroll-only correction; physical buttons and other pointing devices are not filtered.

- **2026-11-09 (current source/release snapshot):** GitHub `main` at `f63250a4867105ea1e9e2724c0c47b5ae5e707cb`; normal CI #1285 passed; Build #18 succeeded on baseline `c6f4b955475de2ea16bc2b34c59a95dad3a1ae78`; v1.4.6 is the latest published release.
- **2026-11-05 (previous reviewed snapshot; historical):** CI #1239 passed on `7f923a2c7aa59721bc00728faccbc073e06c697a`; release run #15 published v1.4.4 from that snapshot. The former 388,000-byte ZIP and 379,511-byte CI artifact measurements are retained in the historical status section below.
- **2026-11-05 (release workflow hardening):** explicit previous-tag-to-HEAD note range, requested-tag heading validation, and same-commit duplicate-version-tag guard.
- **2026-11-05 (last system-affecting source change):** GameMode priority regression wrap-safety and installer QEMU-hook preflight changes; covered by build #13.
- **2026-11-05 (earlier configuration update):** conservative Genshin LSFG-VK fallback profile and MAKO-first selection guidance; covered by build #13.
- **2026-11-05 (previous release snapshot):** exact-HEAD normal CI #1220, full-system build #11, and v1.4.2 publication from `9661091e35aed98b18483ff6d25a54fe0653c877`; superseded as the current build baseline by #13.
- **2026-11-04 (historical):** fourteenth supplied audit cross-check; archive version-table reconciliation; Home Manager package de-duplication; historical build-label correction.
- **2026-11-04 (earlier, historical):** thirteenth supplied audit cross-check; MAKO Renderer integration; supplied VM XML/exact-HEAD cross-check; current supplied archive-report reconciliation; supplied configuration/installer cross-check; Pyprland, PCI, and cursor remediation.
- **Last completed full-system build baseline (2026-11-09):** manual [run #18](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/42597469118) passed on `c6f4b955475de2ea16bc2b34c59a95dad3a1ae78`.
- **2026-11-05 build/navigation records (historical):** full-system build #13 remains recorded below as an earlier successful baseline; the 4 November CHANGELOG-only entries for Game graphics profile guidance, CS2 frame-generation profile, and Source-tree audit hardening remain listed below.
- **2026-11-09 (target hardware):** owner-reported clean NixOS installation from scratch and successful Windows 10 VFIO VM start/shutdown with GPU handback and Hyprland recovery.
- **2026-11-03:** post-audit remediation; supplied comprehensive audit cross-check (unnumbered).
- **2026-11-01:** ShellCheck follow-up; eleventh audit/release-workflow repair; twelfth audit update.
- **2026-10-30:** ninth and tenth audit cross-checks.
- **2026-10-28 and earlier:** historical source-ZIP, packaging, installer, and configuration follow-ups.

## Latest verified CI and release status — 2026-11-09

**Latest published release:** [v1.4.6](https://github.com/kUmutUK/nixos-hyprland-vfio/releases/tag/v1.4.6), published by [release run #20](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/42203730895) on 6 November 2026 from `a6dd4544319fafa7ec517e73b31ad29a1b4010b3`. The canonical ZIP is 402,118 bytes with SHA-256 `05ffe97ee342a4b233f56bc7ae0e455f3b91a1c87df86c42e57e0441e9089e76`.

**Verified full-system build baseline:** GitHub `main` at `c6f4b955475de2ea16bc2b34c59a95dad3a1ae78`. Manual full-system build #18 completed successfully on this exact commit.

**Reviewed source snapshot:** GitHub `main` at `f63250a4867105ea1e9e2724c0c47b5ae5e707cb`.
- **Normal CI for the reviewed snapshot:** [run #1285](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/42625179836) completed successfully for the exact reviewed snapshot `f63250a4867105ea1e9e2724c0c47b5ae5e707cb`; all 28 workflow-defined steps passed. GitHub's runner-generated `Set up job` entry is not a YAML-defined workflow step.
- **Full-system build:** manual [run #18](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/42597469118) completed successfully for the **same exact commit** `c6f4b955475de2ea16bc2b34c59a95dad3a1ae78`. The job built the full NixOS system and selected kernel with both unused Rust module symbols disabled.
- **Build-to-HEAD boundary:** Build #18 is tied to `c6f4b955475de2ea16bc2b34c59a95dad3a1ae78`, not to current HEAD `f63250a4867105ea1e9e2724c0c47b5ae5e707cb`. The repository owner confirms the 11 subsequent commits do not invalidate its successful result; normal CI #1285 covers exact current `main`. No claim is made that GitHub's full-system build workflow ran on current HEAD.
- **v1.4.6 release artifact:** 402,118 bytes; SHA-256 `05ffe97ee342a4b233f56bc7ae0e455f3b91a1c87df86c42e57e0441e9089e76`.
- **Previous v1.4.5 release (historical):** release run #17; commit `994b05c888fbb52295d93e8ef74e41bac66c5e65`; 392,212-byte ZIP; SHA-256 `f97fb12bdfbaaff4d32e7ab57bbc9251fababcd126a8ef7644947844924de9e0`.
- **Previous reviewed snapshot (historical, 5 November 2026):** `7f923a2c7aa59721bc00728faccbc073e06c697a`; normal CI run #1239 (run ID `42032980751`); v1.4.4 release run #15 (run ID `42035815458`). Its 388,000-byte ZIP SHA-256 was `7621fcdccfe327e9e59f453947b9f7903cd0f477b73cde8f4aa5ee513061e0ff`.
- **Historical release-note anomaly:** the v1.4.3 annotated tag had no GitHub Release; the v1.4.4 release description inherited an incorrect v1.4.3 heading. Neither is the current v1.4.6 release.
- **Target-host validation (owner-reported, 9 November 2026):** NixOS was installed from scratch on the reference machine without issues. The Windows 10 VFIO VM started successfully, shut down normally, returned GPU control to the host, and Hyprland resumed. This confirms ordinary VM start/shutdown and host recovery on that machine; saved-state/managed-save restore remains unverified.
- **Earlier target-host validation (owner-reported, 3 November 2026):** successful rebuild, selected-kernel compile, ordinary VM start/shutdown, GPU handback, and Hyprland recovery are retained as historical evidence.
- **Storage portability:** clean installation on the reference machine succeeded. For a different machine or a manual migration, check the optional `/mnt/media` UUID in `nixos/configuration.nix` separately from the storage identifiers in `hardware-configuration.nix`; use `lsblk -f`, `sudo blkid`, and `findmnt`.
- **Release safeguard:** the release workflow still enforces the exact ancestor-build allowlist. Current changes include `nixos/configuration.nix` (including the `XCURSOR_THEME` configuration), `nixos/home.nix`, `nixos/hardware-configuration.nix`, and `install.sh`. A fresh full-system build is required before release whenever a future candidate is not covered by the successful ancestor baseline and exact allowlist. This status note does not publish a new release.

## Historical Rust/BTF build failure — superseded by full-system build #18

Manual full-system build [#17](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/42530020089) on commit `ba1b79458d683a20a0144ec2c5f196e1ab228b0e` failed during BTF finalization for `rcpufreq_dt.ko` after the first workaround had removed `rnull_mod.ko`. The failure identified the second unused Rust module, controlled by `CPUFREQ_DT_RUST`.

The follow-up configuration disables both `BLK_DEV_RUST_NULL` and `CPUFREQ_DT_RUST` while retaining general Rust, BTF, ThinLTO, and RT-Bore selection. **Manual full-system build #18 subsequently passed** on `c6f4b955475de2ea16bc2b34c59a95dad3a1ae78`, validating this two-symbol workaround.

The 11 commits after the Build #18 baseline are present on current `main`. The repository owner confirms that they do not invalidate the successful build result. The current branch independently passes normal CI #1285. The full-system workflow result must still be described with its exact build SHA rather than relabelled as an exact-HEAD run.

For any future release, the changed-path rule remains active: `nixos/configuration.nix`, `nixos/home.nix`, `nixos/hardware-configuration.nix`, and `install.sh` are among the paths requiring deliberate review. The report records `lsblk -f`, `sudo blkid`, and `findmnt` checks for host-specific storage IDs. A fresh full-system build is required before release if the selected candidate is outside the exact successful ancestor-build allowlist.



- **Apple keyboard function-row mapping — 2026-11-09:** the target USB keyboard reports USB ID `05ac:024f` (Apple Aluminium Keyboard), although its Linux input-device name is `SONiX Gaming Keyboard`. With the automatic `hid_apple` Fn mode, F1/F2 were emitted as brightness/media events instead of function-key events. A live `fnmode=2` test changed the events to `KEY_F1`, `KEY_F2`, and `KEY_F3`. `nixos/configuration.nix` now declares `options hid_apple fnmode=2` through `boot.extraModprobeConfig`, making F1-F12 the default and retaining media actions behind Fn. This is a system-configuration change: the normal CI evaluation and a fresh manual full-system build are required before release, followed by a rebooted target-host check of both the F-row and Fn-media behavior.

- **ALC897 mixer-state persistence — 2026-11-09:** the target host exposes a Realtek ALC897 analog capture device through `snd_hda_intel` and PipeWire. The initial `Capture` control was at 100% (+30 dB); the owner tested a temporary reduction to 40% (+1.5 dB), after which the background noise was still being evaluated. `nixos/configuration.nix` now enables `hardware.alsa.enablePersistence` so ALSA card controls are saved on shutdown and restored when the card appears. This does not set a preferred capture gain, select the front/rear microphone jack, or guarantee removal of acoustic/electrical noise. The ALC897 input routing and capture level still need target-host verification. This runtime configuration change requires normal CI and a new manual full-system build before release.

- **Razer DeathAdder scroll-wheel bounce filter — 2026-11-09:** the raw `libinput` stream from the Razer DeathAdder Essential pointer node repeatedly alternated positive and negative vertical wheel deltas during one-direction scrolling, establishing that the reversal occurs before Hyprland. The configuration pins `mouse-hardware-fix` at upstream commit `9cb3bc2ae313cac8fbe60dc573955cb68a0354ae` (MIT), builds the C++ daemon and runs its platform-independent filter tests, and installs a udev-triggered systemd template restricted to USB ID `1532:0098` plus `ID_INPUT_MOUSE=1`. The daemon is invoked with `--disable-click`, a 300 ms gesture-idle reset, and a two-notch intentional-reversal threshold; its default behavior inverts isolated opposite-direction bounce steps. The daemon clones the mouse through `uinput` while grabbing only the matched evdev node; when it exits, the kernel releases the grab and the physical mouse is available again. This is a software mitigation, not an encoder repair. The new filter has not yet been tested on the target host; normal CI and a manual full-system build are required before release, followed by scroll direction-change and device hotplug tests.

## GameMode and installer preflight remediation — 2026-11-05

- **GameMode semantics:** corrected the `nixos/configuration.nix` comment to state that GameMode negates the configured positive `renice` magnitude. With `renice = 10`, the effective nice value is `-10`, which raises CPU scheduling priority when GameMode successfully applies it. The documentation-integrity regression now calculates and checks the effective value and direction. No GameMode numeric setting was changed.
- **Installer preflight:** `install.sh` now requires the non-empty `nixos/hooks/qemu` source before asking for the high-risk acknowledgement or creating backups. A separate runtime-source list preserves the six-file Nix copy loop. The extracted preflight regression checks that the hook is accepted when valid and rejected when missing or empty; the MAKO integration test is aligned with the split source lists.
- **Preserved choices:** `gpu_device = 1` remains pending the target host's live `/sys/class/drm` mapping. VM XML, PCI/USB identities, VFIO runtime behavior, kernel selection, frame-generation settings, and desktop preferences were not changed.
- **Build-gate disposition:** the gate was OPEN when these `nixos/configuration.nix` and `install.sh` changes were first recorded. It was subsequently closed by exact-HEAD full-system build #13 on `1dbb7d5407f5b478cee14da5d52dc0c1822d4e8b`; normal CI #1233 also passed on that commit. This does not add a new physical VFIO test or saved-state-restore result.

## Last completed full-system build baseline — 2026-11-07

**Reviewed source snapshot:** GitHub `main` at `a6dd4544319fafa7ec517e73b31ad29a1b4010b3`.

**Verified full-system build baseline:** GitHub `main` at `a6dd4544319fafa7ec517e73b31ad29a1b4010b3` (7 November 2026).

- **Normal CI for the reviewed snapshot:** [run #1251](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/42525185215) completed successfully for the exact reviewed snapshot `a6dd4544319fafa7ec517e73b31ad29a1b4010b3`.
- **Full NixOS system build:** [manual run #16](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/42414377307) completed successfully for the **same exact commit** `a6dd4544319fafa7ec517e73b31ad29a1b4010b3`. The complete NixOS toplevel, selected kernel, and unchanged-lock check passed.
- **Verified full-system build baseline:** GitHub `main` at `a6dd4544319fafa7ec517e73b31ad29a1b4010b3` (7 November 2026).
- **Build-gate boundary:** the 7.3.3 CachyOS input update, the Rust null-block workaround, the later root Nixpkgs/Home Manager lock updates, and the uploaded host hardware-configuration refresh all occurred after this build. A new full-system build is required before release.
- **Hardware boundary:** runner success does not validate the newly uploaded storage mapping on the physical host or add a new VFIO/VM lifecycle or saved-state-restore result.

## Previous full-system build baseline — 2026-11-05 (historical; superseded by #16)

**Build-baseline snapshot:** GitHub `main` at `1dbb7d5407f5b478cee14da5d52dc0c1822d4e8b`; **normal CI at that time:** #1233 passed on this exact commit; **full-system build:** #13 passed on this exact commit; **published release at that time:** v1.4.2 from earlier commit `9661091e35aed98b18483ff6d25a54fe0653c877` by run #7. **Full-system build gate: CLOSED** — the complete NixOS toplevel and selected kernel were built on this snapshot. The later reviewed source snapshot and v1.4.4 release are recorded in the current-status section above.

**Historical verified full-system build baseline:** GitHub `main` at `1dbb7d5407f5b478cee14da5d52dc0c1822d4e8b` (5 November 2026).

- **Normal CI:** [run #1233](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/42001709686) completed successfully for this exact commit. All **28 workflow-defined steps** passed, including canonical source ZIP creation/validation, documentation integrity and MAKO integration, VM XML and installer regressions, Nix formatting/evaluation, LSFG-VK v2 and MAKO package builds, ShellCheck, Statix, and Deadnix.
- **Full NixOS system build:** [manual run #13](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/42002113160) completed successfully for the **same exact commit** `1dbb7d5407f5b478cee14da5d52dc0c1822d4e8b`. It started at 09:24:30 UTC and completed at 11:49:21 UTC on 5 November 2026 (**2 h 24 min 51 s**). Flake evaluation, the complete NixOS toplevel/selected-kernel build, and the unchanged-lock check all passed.
- **Canonical source artifact:** normal CI uploaded `nixos-hyprland-vfio-source` (artifact ID `13403280716`, **376,179 bytes**, GitHub artifact digest `sha256:d892c0ee1a7227c9e4f593c04ce19fe0e3f69b35b1ae7a2562ed8e0804c3309d`). This digest is for the outer GitHub Actions artifact; it is not presented as the inner source ZIP's SHA-256.
- **Previously pending source paths:** full-system build #13 includes the 5 November changes to `nixos/configuration.nix`, `install.sh`, and `nixos/home.nix`. The full-system build gate is CLOSED for this exact source snapshot. The current documentation/test follow-up is confined to paths in the release ancestor-build allowlist.
- **Release status at this historical build baseline:** v1.4.2 was published from the earlier `9661091e35aed98b18483ff6d25a54fe0653c877` snapshot by release run #7. It was superseded by v1.4.4, published by run #15 from the later reviewed source commit `7f923a2c7aa59721bc00728faccbc073e06c697a`.
- **Hardware boundary:** the successful CI and build do not prove physical GPU/VM behavior or libvirt saved-state restore. The maintainer-reported normal VM start/shutdown, RX 6700 XT GPU handback, and Hyprland recovery remain separate target-host evidence; saved-state restore remains unverified.

## Previous exact-HEAD build and v1.4.2 release verification — 2026-11-05 (historical)

**Previous verified main snapshot:** GitHub `main` at `9661091e35aed98b18483ff6d25a54fe0653c877`; **normal CI:** #1220 passed on this exact commit; **full-system build:** #11 passed on this exact commit; **release:** v1.4.2 published by run #7. **Full-system build gate: CLOSED** — the complete NixOS toplevel and selected kernel were built on this snapshot. This follow-up changes only documentation, changelog, and the documentation-integrity regression, all covered by the release ancestor-build allowlist; normal CI must still pass on the exact resulting `main` commit before any subsequent release.

**Previous full-system build baseline:** GitHub `main` at `9661091e35aed98b18483ff6d25a54fe0653c877` (5 November 2026).

- **Normal CI:** [run #1220](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/41896624560) completed successfully for this exact commit. All **28 workflow-defined steps** passed, including documentation integrity and MAKO integration regressions, canonical source ZIP validation, VM XML checks, Nix evaluation, LSFG-VK v2 / MAKO package builds, ShellCheck, Statix, and Deadnix.
- **Full NixOS system build:** [manual run #11](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/41898065626) completed successfully for the **same exact commit** `9661091e35aed98b18483ff6d25a54fe0653c877`. It started at 19:33:24 UTC and completed at 23:14:13 UTC on 4 November 2026 (**3 h 40 min 49 s**). Flake evaluation, the complete NixOS toplevel/selected-kernel build, and the unchanged-lock check all passed.
- **Release:** [run #7](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/41992293188) published [v1.4.2](https://github.com/kUmutUK/nixos-hyprland-vfio/releases/tag/v1.4.2) from the same exact commit on 5 November 2026.
- **Canonical source artifact:** the release contains `nixos-hyprland-vfio-source.zip` (**380,135 bytes**) and its SHA-256 manifest. The ZIP digest is `ef3b430ccff66f3c1905516be018991585e5945ceccdd2b06eaaf1545fdd06fd`. The release job verified **72 tracked files**, **9 executable files**, the embedded `SOURCE_REVISION`, and exclusion of `.git` metadata.
- **Release input retry:** run #6 stopped at strict version-input validation because `1.4.2` lacked the required `v` prefix. Run #7 used `v1.4.2` and completed successfully; the first attempt did not fail in Nix build or normal CI.
- **Build-gate disposition:** build #11 covers the exact verified source commit. The documentation, changelog, and documentation-integrity updates in this follow-up are inside the release workflow's explicit ancestor-build allowlist; they do not reopen the system-build gate. The normal-CI exact-commit requirement still applies before any later release.
- **Hardware boundary:** this build and normal CI do not prove a real libvirt saved-state restore. The maintainer-reported normal VM start/shutdown, RX 6700 XT GPU handback, and Hyprland recovery remain separate target-host evidence.

## Target-host hardware validation — 2026-11-03

- **NixOS rebuild:** the project owner reports that rebuilding the then-current target configuration completed successfully.
- **Kernel compilation:** the selected RT-Bore-LTO ThinLTO kernel compiled locally. The corresponding `nixos/flake.lock` resolved the CachyOS kernel input to `755712deee259ef7efbfe9154038a270c3d75a87`.
- **Windows VM lifecycle:** the VM started and completed a normal shutdown; the host GPU/display returned and the Hyprland session recovered.
- **Evidence boundary:** this is maintainer-reported physical-hardware validation dated 3 November 2026, not independent reproduction and not a compatibility guarantee for other hardware. It covers ordinary start/shutdown only; libvirt saved-state and managed-save restore remain unverified.

## Frame-generation fallback profile update — 2026-11-05

- **LSFG-VK fallback:** changed only the Genshin Impact profile in `nixos/home.nix` from a 3x to a 2x multiplier. Wuthering Waves remains at 2x; Benchmark and vkcube profiles are unchanged.
- **Selection guidance:** MAKO Adaptive remains the first per-game Frame Generation path to validate; LSFG-VK v2 is the fallback when MAKO is unavailable or unsuitable for that title. OptiScaler remains optional and game-local. This is a configuration preference, not a measured performance comparison on the RX 6700 XT.
- **Preserved settings:** CS2 remains native with no Frame Generation; global AMD low-latency/Anti-Lag settings and the unset Reflex variable are unchanged. No MAKO profile is auto-enabled, no OptiScaler files or Steam options are changed, and no VM XML or VFIO behavior is touched.
- **Build-gate disposition:** the profile update was initially newer than build #11 and its gate was OPEN at that time. Exact-HEAD full-system build #13 and normal CI #1233 subsequently passed on `1dbb7d5407f5b478cee14da5d52dc0c1822d4e8b`, covering this Home Manager profile; the gate is now CLOSED for that snapshot.
- **Hardware boundary:** no new game runtime, frame-pacing, VRR, or RX 6700 XT MAKO-vs-LSFG performance result is claimed.

## Fourteenth supplied audit cross-check — 2026-11-04 (historical, superseded)

**Historical status at the time of the 4 November review:** GitHub `main` at `ce2cd55ffbc8bc6859f746445ad533212f1aec25`; full-system build #10 at `480972a235655f6d1e9ec6137f85ad3f30b8655a` did not yet cover the later `nixos/home.nix` change. The build gate was OPEN then; exact-HEAD build #11 on 5 November subsequently closed it for the verified snapshot.

**Date qualification:** The supplied report labels its review date as 5 November 2026. This repository cross-check is dated 4 November 2026, so 5 November is retained only as the source report's stated metadata, not treated as the date of this update.

- **Historical Hyprland table conflict — confirmed as an internal contradiction.** The [1.2.2] entry says nixpkgs 7a0f122 supplied Hyprland 0.54.3 / hyprlock 0.9.5, while [1.3.0] and [1.3.3] attribute Hyprland 0.56.2 / hyprlock 0.9.6 to the same revision; [1.3.2] also records the root nixpkgs lock at 7a0f122f5090. Those tables cannot both describe the same immutable source revision. Hyprland's official [0.56 release announcement](https://hypr.land/news/update56/) dates v0.56.0 to 20 July 2026, but that release date alone does not establish the exact package expression at the nixpkgs commit. The Turkish archive preface now flags the contradiction and treats the older ABI narrative as unverified pending an exact upstream-source check; the historical entry itself was not silently rewritten.
- **Home Manager package overlap — narrowed to the actual duplicate.** programs.eza.enable already supplies the user-level eza package, so the separate eza item was removed from home.packages. The existing exclusion comment is specifically about playerctl, wev, libnotify, and hyprpicker; it is not a blanket rule for every Home Manager module. The system-profile entries for fzf, git, and kitty were preserved, and the Home Manager modules continue to own their per-user integration/settings.
- **Historical build wording — corrected.** At the time of this 4 November audit, build #9 had been superseded by build #10. The 5 November exact-HEAD section above now records build #13 as the latest completed full-system build.
- **Audit numbering — clarified.** The English CHANGELOG now explains why the retained external-audit sequence starts at audit five and why the 3 November broad cross-check is intentionally unnumbered.
- **Supplied ZIP boundary — unchanged.** The ZIP bytes were not attached to this repository-editing turn. Its reported 770,684-byte size, SHA-256, 126-entry inventory, .git counts, and mode metadata were therefore not independently measured or copied into the verified archive ledger as facts.

**Validation/build boundary at the time of this audit:** the focused Home Manager/package invariant modified `nixos/home.nix`, so build #10 did not cover that source. Exact-HEAD full-system build #11 on 5 November first covered it; build #13 later revalidated the newer source snapshot. Neither runner build adds a new target-host VFIO/VM or saved-state restore test.

## Thirteenth supplied audit cross-check — 2026-11-04 (historical, superseded)

**Historical status at the time of the 4 November review:** GitHub `main` at `b2d2691b98764705edd8a689924b0ae16024bde6`; full-system build #10 at `480972a235655f6d1e9ec6137f85ad3f30b8655a` did not yet cover the later Home Manager, flake, MAKO derivation, and installer changes. The build gate was OPEN then; exact-HEAD build #11 on 5 November subsequently covered the verified source snapshot.

**Scope and date qualification:** The supplied review describes its report date as 5 November 2026, which is one day after this 4 November 2026 repository cross-check. The supplied report date is therefore retained as input metadata, not adopted as the date of this verification.

- **HEAD and build ancestry — confirmed.** GitHub `main` was at `b2d2691b98764705edd8a689924b0ae16024bde6` when checked. Comparing it with the last successful full-system build commit `480972a235655f6d1e9ec6137f85ad3f30b8655a` shows 46 commits ahead, with the build commit as the merge base. The current HEAD includes later changes to `nixos/home.nix`, `nixos/flake.nix`, `nixos/mako-renderer.nix`, and `install.sh`; these are outside the release workflow's ancestor-build allowlist. A new manual full-system build is required before release. Normal CI, package builds, and static regressions do not replace it.
- **Exact-HEAD CI — not independently confirmed here.** The tracked `.github/workflows/check.yml` defines 28 workflow steps, including flake evaluation, generated Lua validation, and LSFG-VK v2 / MAKO package builds. The current commit-status lookup returned no status contexts; that response is not evidence of failure or success. Do not describe the supplied report's 19-package pass as independently reproduced by this repository cross-check.
- **B1 / archive provenance — supplied measurements remain unverified.** The ZIP bytes were not attached to this repository-editing session. Its reported 765,259-byte size, 126 entries, 45 `.git/` records, ZIP external attributes, and embedded content were therefore not recalculated. The tracked `SOURCE_REVISION` file contains Git's export-substitution placeholder in a normal checkout; this is expected because `.gitattributes` declares `SOURCE_REVISION export-subst`, and the canonical `git archive` step expands it to the packaged commit. The packager verifies the embedded revision, rejects `.git/`, checks the tracked-file inventory, and verifies all nine executable paths. Use that helper or the exact-commit CI artifact, not a manually compressed checkout.
- **B3 / build-gate readability — consolidated.** The 4 November snapshot-specific gate line was placed in this report, the root status index, and the README validation section. It named the reviewed HEAD, exact build #10 baseline, affected paths, and then-required next action. The 5 November exact-HEAD build #13 record above supersedes that historical OPEN status.
- **B4 / monitor example — aligned.** The installer prompt's illustrative output name is now `DP-1`, matching the installation guide. The script still detects the actual output with `hyprctl monitors`; this example does not hard-code a monitor or alter the target machine's monitor configuration. The explanatory comment warning against hard-coding `DP-3` is intentionally retained.
- **B5 / navigation — completed.** The chronological navigation now lists the 4 November full-system-build baseline section and the related CHANGELOG-only entries for game graphics guidance, the CS2 profile, and source-tree audit hardening.
- **B6 / VFIO release sub-actions — unchanged.** The `end` / `failed` release behavior remains an informational hardening opportunity, not a documented code/documentation contradiction. No QEMU hook behavior was changed in this cross-check; any future hook change remains subject to a new full-system build and target-host testing.
- **B7 / remaining notes — preserved as non-blocking observations.** The `builtins.fetchGit` network dependency, asynchronous Btrfs discard plus disabled periodic fstrim service, and early log-directory creation are not changed without a separate design decision. No kernel, VFIO, VM XML, GameMode, GPU, LSFG-VK, MAKO, OptiScaler, latency-layer, or desktop preference was changed.

**Verification boundary:** This cross-check verifies the public GitHub source snapshot, selected file contents, commit ancestry, workflow definitions, and release-gate configuration. It does not independently reproduce the supplied ZIP measurements, run the target machine's NixOS build, execute physical VFIO/VM tests, or establish a saved-state restore result.

## MAKO Renderer integration — 2026-11-04

- Added the official MAKO Renderer v4.6.0 x86_64 Linux archive as a fixed-hash Nix package (`nixos/mako-renderer.nix`) and exposed it to Home Manager through `nixos/home.nix`. The Home Manager package is optional at game level: it does not edit Steam launch options, add a global Vulkan layer manifest, replace LSFG-VK, change OptiScaler files, or alter the global AMD Anti-Lag/latency-layer defaults.
- Added the package output to `nixos/flake.nix`, the new Nix expression to `install.sh` source preflight, deployment, backup, and rollback handling, and a static integration test plus normal-CI package build target. The changes to `nixos/home.nix`, `nixos/flake.nix`, `nixos/mako-renderer.nix`, and `install.sh` are covered by the full-build pending-path guard.
- **Build gate:** `nixos/home.nix`, `nixos/mako-renderer.nix`, and `install.sh` changed after the last successful full-system build baseline. A fresh full-system build is required before release. The normal-CI/package checks and upstream archive checksum do not replace that build.
- **Hardware boundary:** no target-host MAKO runtime test, RDNA2/RX 6700 XT compatibility result, per-game frametime comparison, or Gamescope/VRR qualification is claimed. No MAKO frame generation should be stacked with LSFG-VK or OptiScaler frame generation in one game. The upstream launcher uses a private Vulkan implicit-layer path, so the globally registered latency layer must be checked separately for any MAKO-launched game.

## Supplied VM XML and exact-HEAD cross-check — 2026-11-04

**Reviewed Git snapshot before this documentation-only reconciliation:** GitHub `main` at `480972a235655f6d1e9ec6137f85ad3f30b8655a`. GitHub's recursive tree response was not truncated: **69 tracked file blobs**, with **9 tracked executable files** stored as `100755`.

- **Supplied ZIP — measurements remain audit-supplied.** The submitted report describes `nixos-hyprland-vfio.zip` as 725,451 bytes, 124 entries (54 under `.git/`), with embedded HEAD `480972a235655f6d1e9ec6137f85ad3f30b8655a`, timestamp 2026-11-04 11:47:58, and a SHA-256 prefix `fd21ac4e…`. The ZIP itself was not attached to this conversation, and the full digest was not supplied; its byte size, entry inventory, external attributes, shallow metadata, and reported 60 mode changes were therefore **not independently recalculated**. Do not treat those archive-specific numbers as fresh measurements.
- **Canonical packaging path — confirmed in source and CI.** `scripts/package-source-zip.sh` packages committed HEAD using `git archive`, verifies the tracked-file inventory and embedded revision, excludes `.git/`, and checks the exact nine executable modes. The exact-HEAD normal-CI run #1145 passed the package-validation and artifact-upload steps. Use that artifact or run the helper from a clean checkout; the reported hand-compressed ZIP is not the canonical distribution format.
- **Installer provenance gate — conditional finding confirmed.** When `.git` is present, `install.sh` obtains the commit from `git rev-parse` and stops if `git status --porcelain --untracked-files=all` is nonempty. If the reported extraction really changes tracked modes, that dirty checkout fails the gate. The exact count and which paths need normalization depend on the extracted archive and filesystem; the unavailable ZIP prevents independently endorsing the report's “60 files”/“51 remaining” arithmetic. A clean Git checkout or exact-commit canonical CI ZIP is the supported recovery route.
- **Shallow Git metadata — scope corrected.** A shallow `.git` directory in a supplied archive can prevent a user from locally reproducing ancestry checks from that extracted copy. It does not disable the repository's CI history check: the normal workflow performs its own checkout with `fetch-depth: 0`. Run #1145 passed the documentation-integrity step on the exact reviewed source commit.
- **README review date — corrected.** The introduction now points to the 2026-11-04 cross-check rather than the previous 2026-11-03 source-tree date.
- **USB and PS/2 input layers — confirmed and documented.** The VM XML has two USB hostdev entries and also declares emulated PS/2 mouse and keyboard inputs. They are separate XML devices. Removing USB hostdev blocks leaves the PS/2 definitions present, but static XML alone does not prove that host input events reach the guest at runtime.
- **QEMU emulator path — NixOS-specific, now documented.** The XML pins `/run/libvirt/nix-emulators/qemu-system-x86_64` and OVMF paths under `/run/libvirt/nix-ovmf/`. NixOS's libvirtd module creates stable runtime symlinks for QEMU executables in the former directory; the README and installation guide now tell users to verify the configured path on the installed host. The CI VM XML structure test does not attempt to validate a host's live `/run` tree.
- **Eight versus nine executable files — historical count, not a current conflict.** The eight-file inventory belongs to the superseded 2026-10-28 snapshot `1b652cb663feb7a60c62086b51f97a7d7611b804` (55 tracked files). The reviewed HEAD has 69 tracked files and the nine-file executable inventory listed above. The old historical count is retained with its snapshot context.
- **ICH9 and backup-retention notes — already qualified.** The preface in `docs/archive/DEGISIKLIK_GECMISI.md` already labels the ICH9 removal and “last five backups” entries as historical, tells readers to use the active XML for current VM behavior, and states that current installer backups are not automatically pruned. No XML or installer behavior change was justified.
- **Other attention notes — retained without guessing.** The revision marker in `SOURCE_REVISION` remains the expected checkout placeholder expanded by `export-subst` when producing `git archive`; the lockfile is guarded by CI; Pypr's class rule matches the configured `pypr-term` command; GameMode `gpu_device = 1` remains pending live target-host DRM mapping; LSFG-VK v2's package/configuration/test chain remains the documented current path.
- **Verification boundary.** Normal CI #1145 and full-system build #10 both passed on exact parent snapshot `480972a235655f6d1e9ec6137f85ad3f30b8655a`. The reconciliation commit changes only documentation and the documentation-integrity regression; its own push-triggered normal CI remains the validation gate. No new physical VM/VFIO or saved-state restore test is claimed.

## Current supplied archive report reconciliation — 2026-11-04

- **Source identity mismatch in the supplied text:** its package summary names `e080015ca3593d4f185888f86379268a20706639`, which is the reviewed GitHub `main` HEAD, while section 2.1 names `e0880015`. Those identifiers do not establish one consistent archive revision.
- **ZIP measurements remain unverified:** the archive bytes were not attached to this repository-editing session. The reported 760,112-byte size, 126 entries, 101 files, 25 directories, 45 `.git/` entries, missing Unix mode metadata, and extracted mode changes are therefore retained as supplied measurements and are not independently verified. The source tree was inspected at the GitHub commit above; that does not substitute for inspecting the ZIP.
- **The 54-entry `.git/` count is an unresolved outlier:** the supplied report contrasts it with repeated 45-entry measurements. Without both corresponding archive byte streams, neither the outlier nor a proposed explanation can be independently established.
- **Disposition:** do not install or distribute a hand-compressed checkout ZIP. The canonical `scripts/package-source-zip.sh` output or the CI artifact built for the exact commit remains the supported source bundle. No package-helper, installer, NixOS, VFIO, VM XML, kernel, or desktop setting change is warranted by unverified ZIP metadata.

## Supplied configuration and installer cross-check — 2026-11-04

**Audit target snapshot:** GitHub `main` at `7addd412e06181239ccab0422cc175768df7a3fd`, matching the revision named by the supplied ninth audit.

- **GameMode nice-value history — superseded.** The earlier cross-check's claim that the comment should describe nice `+10` was itself incorrect. GameMode negates the configured positive `renice` magnitude: `renice = 10` produces effective nice `-10` when successfully applied, raising CPU scheduling priority. The 5 November GameMode correction and regression test record this behavior; the numeric setting remains `10`.
- **Normal-CI step arithmetic — clarified.** `.github/workflows/check.yml` contains 28 workflow-defined YAML steps. The GitHub job record for run #1127 numbers its runner-generated `Set up job` entry as step 1, followed by the 28 workflow-defined steps numbered 2–29. All 28 workflow-defined steps completed successfully. The previous phrase “29 declared workflow steps” incorrectly counted the generated setup entry as a YAML step; the changelog, current-state index, and this report now use the corrected distinction.
- **Supplied checkout ZIP — not independently remeasured in this update.** The ninth audit reports 123 entries, 45 `.git/` entries, missing Unix mode metadata, and an unexpanded Git export-substitution marker in `SOURCE_REVISION`. The ZIP bytes were not attached to this review, so those measurements remain supplied findings rather than fresh byte-level verification. The tracked `scripts/package-source-zip.sh` already uses `git archive`, excludes `.git/`, checks the exact tracked-file inventory and embedded revision, and validates all nine executable modes. No packager change is indicated; do not use a manually compressed checkout ZIP as the install source.
- **Live ISO versus flake channel — clarified.** `INSTALLATION.md` now explains that the NixOS 26.05 Live ISO is the installer environment, while the installed package set comes from the flake's locked `nixos-unstable` input. `system.stateVersion = "26.05"` is a compatibility setting, not a package-channel pin.
- **Unchanged target-specific choices.** GameMode `gpu_device = 1` remains pending inspection of the live `/sys/class/drm` mapping. The `scratchterm-float` rule still matches a title while the Pyprland terminal is configured with class `pypr-term`; its effective runtime behavior and intended sizing need target-session verification before changing the rule. The historical ICH9, USB, IOMMU, and backup-retention records remain historical uncertainties rather than grounds for speculative runtime changes.
- **Build and hardware boundary.** The only edit to `nixos/configuration.nix` in this update is comment-only: it corrects the inaccurate GameMode explanation, with no Nix option or expression changed. The path is nevertheless conservatively tracked as requiring a fresh full-system build before release. This update does not claim a new complete-system build or physical VM/VFIO test; normal CI on the resulting commit is the next validation gate.

## Pyprland, PCI and cursor remediation against main — 2026-11-04

**Starting source snapshot:** `48d9533f8b8ea83533e4297d810df7174a28e4ff`, confirmed as the `main` HEAD before these changes.

- **Pypr scratchpad window rule — corrected statically.** The Hyprland rule previously matched the title `scratchterm`, while Pyprland launches Kitty with `--class pypr-term` and configures the same class. The rule now matches `class = "^(pypr-term)$"`. The documentation-integrity regression checks that the rule, command, and Pyprland class remain aligned. This validates the static match contract; it does not claim a live target-session sizing test.
- **Installer PCI slot validator — tightened.** The secondary `update_qemu_hook_pci()` check now restricts the slot to `00`–`1f`, matching `scripts/pci-address.sh` and `scripts/sync-vm-xml.py`. The shared validator already rejected these out-of-range values before the normal install flow reached the updater, so the old mismatch did not let the documented installer flow pass an invalid BDF. The extracted-helper regression now accepts the upper valid slot `1f` and rejects `20` and `ff` for both GPU and audio values, while checking that rejected attempts do not write the hook.
- **Cursor appearance — made plus-only.** The generated `Plus-Cursor` theme now points every cursor filename from the Bibata source set, plus common XCursor aliases, at the same `plus` glyph. Its `index.theme` declares no `Inherits` entry, so hand, text, wait, busy, resize, and other context states do not use alternate cursor artwork. `XCURSOR_THEME`, Home Manager's `home.pointerCursor`, GTK/X11 integration, and Hyprland's startup command all select `Plus-Cursor`. The standalone Bibata theme was removed from `environment.systemPackages`; the Bibata package remains only as the source from which the plus-only theme is generated.
- **CHANGELOG — brought current.** Added a dated `2026-11-04` Unreleased entry describing the code/test changes and the remaining target-host boundary.
- **GameMode — intentionally unchanged.** `gpu_device = 1` remains pending the target host's live `/sys/class/drm` mapping. The repository cannot infer the active DRM card index from the PCI BDF or CPU/GPU model alone.
- **ZIP provenance — not independently remeasured in this session.** The report's archive size, SHA-256, entry counts, and ZIP metadata remain supplied measurements because the ZIP bytes were not attached to this conversation; only the report text was available for this cross-check.
- **Validation boundary.** The edits to `nixos/configuration.nix` and `nixos/home.nix` mean a fresh full-system build is required before release. Normal CI can validate the static regression suite but is not a substitute for that build. No new complete-system build, physical VFIO handoff, live DRM mapping, or saved-state restore is claimed here.

## OptiScaler update payload-removal recovery — 2026-11-03

- **Finding:** an update removed paths present in the previously managed payload by unlinking them unconditionally. If such a path had replaced a pre-existing game file, its preserved original backup was not restored into the game directory; the backup mapping also remained in manager state, which could make a later removal report a destination conflict.
- **Fix:** preflight all original backups for obsolete paths before rotating the one-step rollback. During the update transaction, restore each available pre-install original atomically; remove obsolete manager-owned files only when no original existed. Drop mappings for paths no longer present in the new payload while retaining mappings for still-managed paths. A failed copy remains inside the existing transaction rollback path.
- **Regression coverage:** added offline tests for a new payload dropping a previously overwritten file, deletion of obsolete manager-owned files that had no original, rollback to the previous payload, subsequent removal restoring the pre-install original, and fail-closed behavior when an obsolete path's required backup is missing. The missing-backup case asserts that game files, manager state, and the previous rollback snapshot remain unchanged.
- **Scope:** only the optional OptiScaler manager, its offline tests, and related documentation changed. No NixOS module, flake input/lock, kernel selection, VM XML, QEMU/VFIO hook, LSFG-VK profile, latency-layer default, or desktop setting was modified.

## Pre-remediation main verification and target-host update — 2026-11-03

**Pre-remediation main snapshot:** `d34c8c3545da92d5d9dae97afb4e627edd0c167f` (the source state reviewed immediately before this remediation).

- **Latest normal CI before this remediation:** [run #1127](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/41693786038) passed all 28 workflow-defined steps on that exact commit. GitHub's generated `Set up job` entry is numbered 1, so the YAML-defined steps are numbered 2–29.
- **Canonical artifact for that pre-remediation snapshot:** run #1127 uploaded `nixos-hyprland-vfio-source`, artifact ID `13258097729`, size 331,775 bytes. The older run #1120 / artifact `13217103984` remains the artifact for reviewed snapshot `8d1e4585c9cd3f690c1df80ee531008c7e9d30ef`; it is not the latest artifact.
- **Maintainer-reported target-host verification (3 November):** after a successful NixOS rebuild, the maintainer reports normal Windows 10 VM launch and shutdown, RX 6700 XT GPU passthrough, return of the GPU to the host driver, and successful return to Hyprland. These are user-reported physical test results, not measurements performed by CI.
- **Remaining physical boundary:** the above result covers the normal VM shutdown/handback path. It does not establish libvirt saved-state restore; that path remains unverified.
- **Build gate after this remediation:** the Hypridle change modifies `nixos/home.nix`. Full-system build #9 at `ab89f350803d47eb16499c613b110da05a57673f` remains the previous successful full-system baseline. A fresh full-system build is required before release.

## Reviewed source snapshot and verification status — 2026-11-03

**Reviewed source snapshot:** GitHub `main` at `8d1e4585c9cd3f690c1df80ee531008c7e9d30ef`. This is the reviewed snapshot associated with normal CI #1120; its CI record remains valid for that exact commit. The later pre-remediation main snapshot `d34c8c3` passed #1127, as recorded above. The full-system build baseline is a separate verification record.

- **Normal CI for the reviewed snapshot:** [run #1120](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/41608022759) completed successfully for the exact reviewed snapshot `8d1e4585c9cd3f690c1df80ee531008c7e9d30ef` on 3 November 2026. This is the successful normal-CI run for the reviewed snapshot; later pre-remediation main snapshot `d34c8c3` passed #1127. It covered canonical ZIP validation, Actionlint, Nix formatting/evaluation, VM and installer regressions, OptiScaler safety tests, VFIO hook tests, generated Lua syntax, LSFG-VK v2 build, ShellCheck, Statix, and Deadnix.
- **Full-system build for this reviewed 2026-11-03 snapshot (historical; superseded by #10 on 2026-11-04):** [manual run #9](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/41643450896) passed for exact commit `ab89f350803d47eb16499c613b110da05a57673f` on 3 November 2026. It built the complete NixOS toplevel and selected kernel, passed flake evaluation, and confirmed that `nixos/flake.lock` was unchanged. The run took 4 h 46 min 26 s (13:20:22–18:06:48 UTC).
- **Why normal CI #1124 was red:** run [#1124](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/41643189403) stopped at the documentation-integrity regression because its recorded full-build baseline was stale. The test compared against `ca6edf2` and treated `nixos/configuration.nix`, `nixos/flake.lock`, and `nixos/home.nix` as unverified changes, even though manual build #9 had already passed on the exact newer commit. No system-build step failed. This update advances the recorded baseline and preserves the guard for any system-affecting changes made after it.
- **Canonical source artifact for this reviewed snapshot:** run #1120 uploaded [`nixos-hyprland-vfio-source`](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/41608022759), artifact ID `13217103984`, size 329,643 bytes, outer digest `sha256:d3d674f7a7e2d33b022ba1448f73aa02805867e9897541b6dc266676c5c804d8`. This artifact corresponds to the older CI-verified snapshot `8d1e4585c9cd3f690c1df80ee531008c7e9d30ef`, not the later build baseline.
- **Release build gate:** manual build #9 is now the full-system baseline. Any later change to NixOS modules or inputs, the kernel, installer, VM template, or runtime hooks remains gated by a new successful full-system build.
- **Target-host verification:** the maintainer later reported successful normal VM start/shutdown, RX 6700 XT VFIO handback to the host driver, and Hyprland recovery on 3 November 2026. A libvirt saved-state restore remains unverified. A successful CI/full-system build does not prove those hardware results.

## Follow-up remediation — 2026-11-03 (full-system build passed; target-host restore pending)

- The uploaded checkout ZIP was not modified. The tracked source package helper and its successful CI artifact remain the canonical distribution route; `.git/`, lost ZIP permission metadata, and a literal `SOURCE_REVISION` from a manually exported checkout are archive-generation properties, not defects in the tracked source packager.
- **OptiScaler transaction safety:** rollback validates its transaction map and all required backup files before mutation, then stages the current game files and manager state under a persistent `.rollback-recovery-*` directory. If applying a rollback or publishing its final state JSON fails, it restores the pre-rollback installation and leaves the original one-step rollback transaction available for retry. If that recovery also fails, it reports and retains the exact recovery snapshot path. Removal uses the same durable approach with `.remove-transaction-*`; the snapshot is deleted only after removal succeeds or automatic restoration completes. A second recovery failure therefore cannot silently delete the only recovery copy. The final install/update state JSON remains inside the rollback-protected transaction, and new rollback snapshots are staged separately before replacement.
- **Original-file backup ordering:** a first-time file backup during update now uses the atomic copy helper before the existing rollback directory is rotated or invalidated. If that backup fails, the previous manager state, installed files, and one-step rollback remain unchanged; a fault-injection regression covers this exact boundary.
- **Per-game operation serialization:** install/update, status, rollback, and removal now take a fail-fast Linux `flock` lock keyed by the canonical game directory. Competing operations for the same game are rejected, while independent games can proceed; lock mode/ownership, rejection, and release are regression-tested.
- **OptiScaler extraction bound:** the manager now totals the uncompressed `Size` values from the 7-Zip listing and rejects archives exceeding 4 GiB before starting extraction; the existing post-extraction actual-size check remains as a second guard.
- **VFIO saved-state restore:** libvirt invokes the QEMU hook with `restore begin` and passes domain XML through standard input/output. The hook now buffers that XML, runs the same VFIO/desktop preparation used for `prepare begin`, and writes the unchanged XML only after preparation succeeds. A failed preparation aborts restore without emitting a partial XML document. The mocked filter test covers unchanged output and fail-closed behavior.
- **Verification boundary:** full-system build #9 at `ab89f350803d47eb16499c613b110da05a57673f` includes both the QEMU saved-state hook update and the `install.sh` assignment-validation change; the complete NixOS toplevel/selected-kernel build and unchanged-lock check passed. Normal VM shutdown, GPU handback, and Hyprland recovery were later reported successful by the maintainer on 3 November 2026; a real saved-state restore remains unverified.

## Audit finding fixes — 2026-11-03

- **OptiScaler archive member types:** the 7-Zip listing is parsed as per-entry records. Symbolic links, hard links, reparse points, and Unix special files are rejected before a staging directory is created or extraction begins. The existing post-extraction symlink scan remains defense in depth.
- **OptiScaler state schema:** the JSON root must be an object with the supported schema and required fields. Managed-file paths, SHA-256 digests, proxy names, original-backup mappings, and the rollback flag are validated before the manager trusts the record. The same validator is used for the previous state restored by rollback.
- **Manual VM PCI validation:** `sync-vm-xml.py` now verifies the selected GPU/display class, audio class, and shared domain:bus:slot with `lspci -Dn -s`, matching the installer's checks. The mock-backed XML sync regression covers wrong classes and different physical slots.
- **Installer and VM helper preflight:** `install.sh` now requires exactly one matching Home Manager variable assignment before replacing it; duplicate assignments fail without changing the file. `sync-vm-xml.py --domain` now rejects a requested libvirt domain whose name differs from the XML template's domain before querying libvirt or writing backups/XML. Both paths have focused mock-backed regressions.
- **Documentation and regression harness:** README's full validation command includes `scripts/test-optiscaler-manager.py` and its repository map lists the manager guide, implementation, and tests. The OptiScaler guide explicitly identifies the in-repository manager as an independent, nonofficial third-party helper. The release ancestor allowlist documents the two Python VM XML sync paths as migration-time helpers outside the NixOS flake/derivation graph, and the mock-only `scripts/test-manual-vm-bootstrap.sh` harness is allowed as test code. The VM XML template and QEMU hook remain gated.
- **Previous normal-CI reference (superseded):** [run ID 41603404803](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/41603404803) completed successfully for the parent snapshot `3105ea2c90a17584e11a9776d0767f1de5d59221` on 3 November 2026. It predates the original-backup ordering and per-game lock changes; current normal-CI verification for the reviewed snapshot is run #1120 above.
- **OptiScaler-specific scope:** the OptiScaler fixes in this audit subsection are limited to the standalone helper, its offline regression tests, and related documentation. Those OptiScaler changes do not alter NixOS modules, flake inputs/lock, RT-Bore-LTO selection, QEMU/VFIO hook, VM XML template, LSFG-VK, latency-layer defaults, or the desktop theme. Separately, the VFIO saved-state hook change recorded in the preceding section does alter `nixos/hooks/qemu`; it is covered by full-system build #9, while normal VM shutdown/handback and Hyprland recovery were subsequently reported successful by the maintainer; saved-state restore remains outstanding.
## Previous full-system build baseline — 2026-11-04 (historical, superseded by #11)

**Previous verified full-system build baseline:** GitHub `main` at `480972a235655f6d1e9ec6137f85ad3f30b8655a` (4 November 2026). The recursive Git tree response was not truncated and contains **69 tracked file blobs**, including **9 files stored with mode `100755`**.

- **Full NixOS system build:** [manual run #10](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/41733290263) completed successfully for the **same exact commit** `480972a235655f6d1e9ec6137f85ad3f30b8655a`. It started at 22:43:37 UTC on 3 November and completed at 02:44:13 UTC on 4 November 2026 (**4 h 00 min 36 s**). Flake evaluation, the complete NixOS toplevel/selected-kernel build, and the unchanged-lock check all passed.
- **Normal CI:** [run #1145](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/41731452053) completed successfully for the exact same commit. All **28 workflow-defined steps** passed, including canonical source ZIP creation/validation, documentation-integrity tests, VM XML checks, Nix evaluation, LSFG-VK v2 package build, ShellCheck, Statix, and Deadnix.
- **Canonical source artifact:** run #1145 uploaded `nixos-hyprland-vfio-source` (artifact ID `13277885590`, **346,040 bytes**, outer digest `sha256:e7b11c0f967b2df3428b4c3ca9417df741e8727a4a4fb67001bd9a43e45a5730`). It belongs to this exact source commit.
- **Git-tree executable inventory:** the nine `100755` paths are `install.sh`, `nixos/hooks/qemu`, `scripts/package-source-zip.sh`, `scripts/test-installer-invariants.sh`, `scripts/test-installer-rollback.sh`, `scripts/test-manual-vm-bootstrap.sh`, `scripts/test-source-revision.sh`, `scripts/test-vfio-hook-driver-state.sh`, and `scripts/verify-source-revision.sh`. The tracked package helper expects this same nine-file set.
- **Historical release/build scope:** this was the latest completed full-system build at the time. It was superseded by exact-HEAD build #11 on 5 November 2026.
- **Runtime boundary:** the maintainer reports that normal RX 6700 XT VFIO handoff/return and Hyprland recovery succeeded after a normal Windows 10 VM shutdown on the target host. This build and normal CI do not establish a real libvirt saved-state restore or verify every target-host OVMF/NVRAM path.

## Previous full-system build baseline — 2026-11-03 (historical, superseded)

**Verified full-system build baseline:** GitHub `main` at `ab89f350803d47eb16499c613b110da05a57673f` (3 November 2026). The recursive Git tree contains **69 tracked file blobs** and was not truncated.

- **Full NixOS system build:** [manual run #9](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/41643450896) completed successfully for the **same exact commit** `ab89f350803d47eb16499c613b110da05a57673f`. It started at 13:20:22 UTC and completed at 18:06:48 UTC on 3 November 2026 (**4 h 46 min 26 s**). Flake evaluation, the complete NixOS toplevel/selected-kernel build, and the unchanged-lock check all passed.
- **Normal-CI distinction:** the last fully successful normal-CI run remains #1120 for the earlier ancestor snapshot `8d1e4585c9cd3f690c1df80ee531008c7e9d30ef`. Run #1124 targeted this build-baseline commit but failed only because the documentation-integrity test still named the older `ca6edf2` baseline; this correction updates the test and baseline record rather than weakening the changed-path guard.
- **Last successful canonical distribution artifact:** run #1120 uploaded artifact [`nixos-hyprland-vfio-source`](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/41608022759) (artifact ID `13217103984`, 329,643 bytes, outer digest `sha256:d3d674f7a7e2d33b022ba1448f73aa02805867e9897541b6dc266676c5c804d8`). It belongs to the earlier `8d1e4585c9cd3f690c1df80ee531008c7e9d30ef` snapshot; run #1124 failed before artifact upload.
- **Future release gate:** later changes to NixOS modules/inputs, `vm-xml/win10.xml`, `install.sh`, runtime hooks, or other system-affecting paths remain outside the ancestor-build allowlist and require a new full-system build.
- **Runtime boundary:** the maintainer reports that normal RX 6700 XT VFIO handoff/return and Hyprland recovery succeeded after a normal Windows 10 VM shutdown on the target host. The available report does not establish libvirt saved-state restore or compatibility of every OVMF/NVRAM path.

## Previous full-system build baseline — 2026-11-02 (historical)

**Previous verified baseline (superseded):** GitHub `main` at `ca6edf2a381118fbd81aeccb82287f234f44a257` (2 November 2026). The recursive Git tree contains **65 tracked file blobs** and was not truncated.

- **Normal CI at this full-system-build baseline:** [run #1084](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/41348680950) completed successfully for that exact HEAD on 1 November 2026. Every required job step passed: canonical source ZIP generation and validation, actionlint, Nix formatting, VM XML invariants, documentation-integrity regressions, LSFG-VK v2 consistency/build, installer and rollback tests, Snapper checks, source provenance, ShellCheck, VFIO hook checks, generated Hyprland Lua syntax, Nix flake evaluation, Statix, and Deadnix.
- **Full NixOS system build:** [manual run #6](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/41349059471) completed successfully for the **same exact commit** `ca6edf2a381118fbd81aeccb82287f234f44a257`. It started at 20:52:21 UTC on 1 November and completed at 01:11:19 UTC on 2 November (**4 h 18 min 58 s**). Evaluation, the complete NixOS toplevel/selected kernel build, and the unchanged-lock check all passed. Unlike the earlier baseline, this record does not rely on an ancestor-build exception.
- **Canonical distribution artifact:** CI run #1084 uploaded artifact [`nixos-hyprland-vfio-source`](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/41348680950) (artifact ID `13100027765`, 293,289 bytes, outer digest `sha256:a8ee0e9682ef0ee1795bc611a18a963e05e8bf46bee86cf3ba878600960512b1`). The workflow's canonical source ZIP validation, SHA-256 manifest creation, and artifact upload steps all succeeded for this exact commit. The packaging helper validates tracked-file completeness, excludes `.git/`, expands `SOURCE_REVISION` to the packaged commit, and requires the nine tracked executable files to retain Unix `0755` mode.
- **Supplied checkout ZIP:** the separately supplied 1 November checkout archive remains noncanonical: its `.git/` metadata, missing Unix mode metadata, and unexpanded `SOURCE_REVISION` placeholder are properties of that uploaded archive, not of the tracked packager or CI artifact. Do not use that checkout ZIP for installation; use the matching CI artifact or `scripts/package-source-zip.sh` output.
- **Release tag consistency:** the previous `.git-cliff.toml` pattern accepted optional `v` prefixes and leading-zero components, while the release workflow accepted only strict stable `vMAJOR.MINOR.PATCH`. The current fix aligns git-cliff, release validation, and previous-tag selection to the same strict pattern; the documentation-integrity regression checks their equality and representative accepted/rejected tags.
- **Release-note range:** a pushed version tag is checked out at the tagged commit, so git-cliff uses `--current` for that event. A manual dispatch runs on `main` before the new tag is created, so it uses `--latest` to collect commits since the previous release. The workflow selects the range by event, and the documentation-integrity regression pins that distinction. The successful first-release run used curated `[Unreleased]` notes; a subsequent pushed-version release remains the end-to-end confirmation of that path.
- **Runtime boundary:** CI and the full build do not establish physical RX 6700 XT reset/rebind behavior, a second VM start, display restoration, or compatibility of the installed host's OVMF/NVRAM paths. Those still require tests on the target machine.
- **Scope of the 2026-11-01 maintenance update:** changes were restricted to release tag consistency, its regression assertions, and current-state/release documentation. Active NixOS settings, kernel selection/lock, VFIO hook behavior, PCI/USB identities, `vm-xml/win10.xml`, Low Latency Layer / Reflex defaults, and the Arthur desktop theme were preserved. The resulting source was subsequently validated on this exact HEAD by normal CI #1084 and full-system build #6.

## Seventh audit cross-check — 2026-10-30

**Source snapshot:** GitHub `main` was at `de33e2ddb8481fc31408d42573df79f7f800d95c` when this review began. Its recursive Git tree contains **62 tracked file blobs**.

**Inventory arithmetic correction:** the supplied audit's Table 2 groups total 61 files (12 + 7 + 25 + 1 + 14 + 2) because `install.sh` is described separately in section 4.4 but omitted from the group inventory. The six listed group line totals add to **21,789**, not the stated 14,546; adding the separately stated 1,161-line `install.sh` gives **22,950**. The seven Nix file line counts in the table add to 3,520, not the listed 3,517. These are internal inconsistencies in the supplied inventory. The submitted ZIP was not attached to this editing session, so this update does not invent a replacement line total; recalculate the counts from the original archive before publishing an aggregate.

| Seventh-audit item | Current-source cross-check / disposition |
|---|---|
| B-01 / B-02 — supplied ZIP | The reported 576,323-byte archive and metadata are recorded below as supplied measurements only. The ZIP bytes were not available here for an independent SHA-256, permission, entry-count, or payload comparison. The canonical packager and CI validation remain the supported distribution paths. |
| B-03 / B-04 — historical policy changes | Current SSH/Reflex/kernel settings and the documented supersession notes remain the active record. The missing historical removal commits/rationales are not inferred. |
| B-05 — README XML-sync wording | Corrected: installer synchronization is now explicitly limited to a registered `win10` domain or an already-deployed XML; fresh XML generation is deferred for a new, unregistered VM. |
| B-06 — “anual” typo | Not reproduced in the current tracked report: the cited historical CI sentence already says “manual run”. No spelling edit was needed. |
| B-07 — K-1 permission recovery | Clarified below: restoring only nine executable modes is sufficient only when the extractor has already preserved the 53 ordinary files as 0644. The supplied seventh audit reports a different extraction result requiring all 62 tracked file modes to be normalized. |
| B-08 — Vulkan manifests | Kept both registrations unchanged; added a source comment explaining that the explicit `/etc` entry is the system-level Vulkan loader registration alongside the package's profile manifest. |
| B-09 — Hyprland minimum | Added a NixOS assertion requiring the selected `programs.hyprland.package` to be version 0.55.0 or newer; the documentation-integrity test now checks that guard. |
| B-10 — XML indentation | Confirmed as a formatting-only difference. `vm-xml/win10.xml` was intentionally left unchanged to preserve the existing VM template. |
| B-12 — report readability | This dated status block provides a current snapshot ahead of the historical correction layers. |

The submitted audit reports 16/16 regression suites passing. That result is attributed to the supplied report; this repository-editing session did not independently rerun those suites. The pushed commit's GitHub Actions result must be checked separately. Physical GPU handoff, VM lifecycle, and target-host recovery remain outside static source validation.

## Supplied ZIP provenance and canonical packaging — 2026-10-30

The measurements below were transcribed from supplied audit text. The ZIP bytes were not attached to this repository-editing session, so the byte count, SHA-256, entry count, `.git` contents, and ZIP metadata have not been independently remeasured here. This is a provenance record for the reported archives, **not** a current canonical-artifact index. The dated sections are grouped by subject and source snapshot rather than strict chronological order. The described archives are reported as noncanonical and must not be used as installation sources. For a canonical archive of a particular commit, run `scripts/package-source-zip.sh` from a clean checkout or download the CI artifact built for that exact commit and verify its accompanying `.sha256` manifest.

| Archive | Recorded metadata from supplied audit | Disposition |
|---|---|---|
| ZIP described in the supplied seventh audit (claimed HEAD `de33e2ddb8481fc31408d42573df79f7f800d95c`) | 576,323 bytes; SHA-256 `4a844140775d14af48b98ac8c6e96e2c5ac6b9307991c456ae30e75b7d96e5ee`; 116 entries (91 files and 25 directories: 62 project files plus 29 `.git` files); 45 `.git` entries (29 files and 16 directories); `.git/HEAD` reportedly points to `refs/heads/main`, whose value is `de33e2ddb8481fc31408d42573df79f7f800d95c`; `SOURCE_REVISION` reportedly contains the literal unexpanded placeholder `Git export-substitution placeholder`; all 116 entries reportedly have `create_system=0` / `external_attr=0x00000000` (no Unix mode metadata); the `install.sh` entry reports the same metadata; single timestamp `2026-10-30 15:46:32`. The supplied audit reports content equality with HEAD and mode-only differences. | Seventh-audit measurements transcribed from supplied text. The ZIP bytes were not attached; size, digest, entry list, Git metadata, timestamp, permission metadata, and claimed payload equality were not independently remeasured. Reported noncanonical; not an approved installation artifact. |

| ZIP described in the supplied sixth audit (claimed HEAD `e309173582763d152d8ab6552f16a277ed297f6e`) | 572,689 bytes; SHA-256 `f11b4cac497055bd5bfdadc93ad0bece1593f68f4af9481e26419cec80ed1ef1`; 116 entries (91 files and 25 directories: 62 project files plus 29 `.git` files); 45 `.git` entries including directories; the embedded Git HEAD reportedly points to `e309173582763d152d8ab6552f16a277ed297f6e` on `refs/heads/main`; SOURCE_REVISION reportedly contains the unexpanded Git export-substitution placeholder; all 116 entries reportedly have no Unix mode metadata (`external_attr=0x00000000`); single timestamp 2026-10-30 14:10:24. The supplied audit says tracked content matches HEAD and only permission metadata differs. | Sixth-audit measurements transcribed from supplied text only. The ZIP bytes were not attached; SHA, entry list, permission metadata, timestamp and claimed content equality were not independently remeasured. Reported noncanonical; not an approved installation artifact. |
| ZIP described in the supplied fifth audit (claimed HEAD `8b8cf29a1d21f2100234814b80fc4f5671e2b74a`) | 570,101 bytes; SHA-256 `dee424e555ca173773388101d407a6699d668eda6fe348a5aa75962ebae4c2be`; 116 entries (91 files and 25 directories: 62 project files plus 29 `.git` files); 45 `.git` entries including directories; `SOURCE_REVISION` contains the unexpanded Git export-substitution marker; all 116 entries reportedly have `external_attr=0x00000000`; single timestamp 2026-10-30 12:13:00. | Supplied fifth-audit measurements only; ZIP bytes not attached and not independently remeasured. Reported noncanonical; not an approved installation artifact. |
| ZIP described in the supplied third audit (embedded HEAD `b413e6df50f64ab16d1694d9b19dae97a078f56c`) | 565,429 bytes; SHA-256 `89fab35d7ecd18bb2b39bb74cbf7b799f8d76bc4c9d59970e7e94060f82dc374`; 116 entries (62 project files, 29 `.git` files, 25 directory entries); 45 `.git` entries including directories; `.git/HEAD` contains `ref: refs/heads/main`, with `refs/heads/main` pointing to commit `b413e6df50f64ab16d1694d9b19dae97a078f56c`; `SOURCE_REVISION` contains the unexpanded Git export-substitution placeholder; the `install.sh` entry reports `create_system=0` and `external_attr=0x00000000`. | Supplied measurements only; not independently remeasured because the ZIP bytes were not attached; reported noncanonical. Do not use this archive for installation. |
| ZIP described in the supplied 2026-10-30 audit | 561,513 bytes; SHA-256 `c905b5036d04bf1ec6c0b2929cba7bce4eb5405df9a6c4886ef677e65c829b8`; 116 entries (62 project files, 29 `.git` files, 25 directory entries); 45 `.git` entries including directories; `.git/HEAD` contains `ref: refs/heads/main`, with `refs/heads/main` pointing to commit `92ca0121917d63f4c9f87bf2a4adcacfd5c8bb56`; `SOURCE_REVISION` remains the unexpanded Git export-substitution marker; the `install.sh` entry reports `create_system=0` and `external_attr=0x00000000`. | Supplied measurements only; reported noncanonical; not independently remeasured in this session. Do not use this archive for installation. |
| Earlier ZIP from the 2026-10-28 audit | 494,995 bytes; SHA-256 prefix `00805455…`; 105 entries including 45 `.git` entries; embedded commit `cdfd3d8d5008e4b7405ce2433e29b8a0e34ffebe`. | Historical, distinct from the 561,513-byte archive above. |
| Historical ZIP(2) | 490,249 bytes; SHA-256 `505ab8bcadc4f7ad0459194e561d27e2d8f65627e859df35a8af7c385707046f`; 105 entries including 45 `.git` entries; embedded commit `8487ea4cd82e75ede71bcad7eaada6438c40adb0`. | Historical submitted archive. |
| Historical ZIP(10) | 475,881 bytes; SHA-256 `9b107f6a3579224944211349d46377e96ff48e26eb4bfa548c30276a86efbe6c`. | Historical; remaining metadata are recorded in its dated section below. |
| Historical ZIP(9) | 475,483 bytes; SHA-256 `931c5d75f8af22e9de5ebfa64341a4d1777a47e2a0e6ad882ba65f1b4bd13f6c`; 102 entries including 45 `.git` entries. | Historical submitted archive. |
| Historical ZIP(1) | 456,770 bytes; SHA-256 `69168ea0d90285a879baf08dfb7be0425db2cedb6539344d4ab603caf1f36094`; 101 entries including 45 `.git` entries; embedded commit `8c6cf467038bacbc8cba46a0c9dcfe54e13c467d`. | Historical; distinct from ZIP(9) and ZIP(10). |
| Earlier archive from the 2026-10-27 audit | 436,212 bytes; SHA-256 prefix `3f0f0ed5`; 96 entries; embedded commit `a631d195891ff6da74ae727ac3c531ffc77c50ed`. | Historical; separate attachment. |
| Another older archive | 493,030 bytes; SHA-256 prefix `45e3edaa…`; embedded revision prefix `c395611f…`. | Historical; not the 494,995-byte archive above. |

The repository's `scripts/package-source-zip.sh` remains the canonical packager. It packages committed `HEAD`, checks archive integrity, tracked-file completeness, the embedded 40-character revision, absence of `.git/`, and the exact expected executable-mode set. CI uploads the validated ZIP and a relative-path `.sha256` manifest after required checks pass. Do not hard-code a digest for a future artifact in this report; use the manifest generated alongside that exact commit.

## Follow-up verification — 2026-10-30

- **K-1 scope clarification:** `install.sh` resolves the source revision from `git rev-parse HEAD` and checks `git status` whenever `.git` is present; it reads `SOURCE_REVISION` only outside a Git work tree. Therefore, if the fifth audit's ZIP measurements are correct, the unmodified extraction is noncanonical and the lost executable modes make the Git work tree dirty. Restoring the nine tracked executable modes could make the Git-based provenance gate pass, because the included Git metadata supplies `HEAD`; removing Git metadata instead exposes the unexpanded export-substitution marker, which fails the 40-character check. The statement that the installer cannot run by any route is too absolute. This recovery possibility does not make the archive canonical or suitable for distribution; use the validated CI artifact.

- **K-1 extractor-dependent qualification (seventh audit):** restoring the nine tracked executable modes is sufficient only when the extractor has already created the 53 ordinary tracked files with their expected 0644 modes. The supplied seventh audit reports an extraction in which all 62 tracked files had noncanonical modes; that specific recovery normalized 53 ordinary files to 0644 and nine executable files to 0755. The number of modes needing repair therefore depends on the extractor and filesystem, and this recovery is not a recommendation to distribute the ad-hoc ZIP.

- **Y-1 reassessment:** The GitHub record for commit `b413e6df50f64ab16d1694d9b19dae97a078f56c` lists `scripts/test-installer-invariants.sh` as a changed path without a textual patch, while that commit's CHANGELOG says its executable bit was restored. This is consistent with a mode-only change in `b413e6df`; the nine-file `100755` inventory recorded for that tree can therefore be post-restoration. The supplied fifth audit does not establish a contradiction between those records. Calling the `b413e6df` tree “pre-correction” is unsupported without a separate measurement of its parent tree's file modes. The earlier eight-file count refers to a distinct, older snapshot.

## Follow-up audit — source ZIP handling and partition-count verification — 2026-10-28

**GitHub `main` immediately before this follow-up:** [`0d748ed82244a51ce49f53e9fc458df16eca4a38`](https://github.com/kUmutUK/nixos-hyprland-vfio/commit/0d748ed82244a51ce49f53e9fc458df16eca4a38). The recursive tree has 55 tracked file blobs and eight executable-mode files (`100755`); the executable list remains `install.sh`, `nixos/hooks/qemu`, and the six packaging/test/verifier scripts named in the prior snapshot below.

### Findings confirmed against source

- **The canonical source-archive helper is already defensive.** `.gitattributes` marks `SOURCE_REVISION` as `export-subst`; `git archive` expands the checkout placeholder to the packaged commit, omits `.git/`, and preserves Git executable modes. `scripts/package-source-zip.sh` verifies the 40-character revision, exact tracked-file inventory, ZIP integrity, and executable bits. CI invokes this helper and uploads its validated ZIP only after required checks pass.
- **The source-tree export-substitution marker is intentional, not a bad committed revision.** It is the expected placeholder in a normal Git checkout. It is invalid only when a distributor bypasses canonical packaging and ships a manually compressed working directory.
- **The exact ZIP described in the submitted audit was not attached to this turn.** Its reported size, SHA-256, `.git/` entries, and extracted permissions therefore could not be recalculated independently here. The source code proves how the canonical helper behaves, but not the metadata of an unavailable ZIP. Use the helper or the CI artifact associated with the exact commit; do not distribute the manually compressed archive.
- **A real documentation/verification gap was found in `INSTALLATION.md`.** The text claimed that exactly three partitions are verified, while the snippet only checked the three expected device nodes and their parent-disk identity. The guide now counts `lsblk` partition entries and fails closed unless the total is exactly three. The existing installer-invariant test suite now exercises the guard for three, two, and four partitions.
- **The report cannot safely pin the ZIP's digest inside itself.** Since the tracked report is included in the source ZIP, changing a digest recorded here would change the ZIP being hashed. CI now generates `nixos-hyprland-vfio-source.zip.sha256` using the relative archive filename and uploads the manifest beside the ZIP, so each artifact carries a digest for its exact bytes.
- **Hardware-specific configuration remains a deployment condition, not a proven source defect.** The committed UUID/PARTUUID, LUKS, EFI, swap, and Btrfs settings must be adapted for a different target machine as the guide states. This review did not run a physical VFIO transfer/recovery test or a full-system build for the new commit; neither is claimed as verified.

The remediation changes the install guide, its regression coverage, README packaging instructions, CI artifact metadata, and this report. GitHub Actions is the validation gate for the pushed commit; results must be read from that exact commit's run rather than inferred from earlier runs.


## Prior source-tree measurement — superseded audit snapshot — 2026-10-28

The pre-update GitHub `main` HEAD was [`1b652cb663feb7a60c62086b51f97a7d7611b804`](https://github.com/kUmutUK/nixos-hyprland-vfio/commit/1b652cb663feb7a60c62086b51f97a7d7611b804). Its recursive Git tree contains **55 tracked file blobs** and **8 files stored with mode `100755`**: `install.sh`, `nixos/hooks/qemu`, `scripts/package-source-zip.sh`, `scripts/test-installer-invariants.sh`, `scripts/test-manual-vm-bootstrap.sh`, `scripts/test-source-revision.sh`, `scripts/test-vfio-hook-driver-state.sh`, and `scripts/verify-source-revision.sh`. This count is from the Git tree rather than from a ZIP extraction.

the export-substitution placeholder in the checked-out `SOURCE_REVISION` file is intentional: `.gitattributes` declares `SOURCE_REVISION export-subst`, so `git archive` substitutes the packaged commit SHA into the ZIP. `scripts/package-source-zip.sh` packages committed `HEAD`, excludes `.git/`, compares the archive contents to the tracked tree, checks all executable bits, verifies ZIP integrity, and requires the embedded revision to equal the commit being packaged. Therefore, the reported `.git/` and lost-permissions issue is a defect in the manually created ZIP, not in the current canonical packaging script. The submitted ZIP bytes were not attached to this update, so its exact checksum and extracted metadata could not be independently recalculated here. Use the canonical script or a successful CI artifact for the exact commit; do not distribute the manually compressed archive.

That earlier update affected documentation and a CI comment only, so the 55/8 source-tree counts remained unchanged at that point.

## Earlier main/source baseline recorded during prior remediation — 2026-10-28

**GitHub `main` at the start of this remediation:** [`cdfd3d8d5008e4b7405ce2433e29b8a0e34ffebe`](https://github.com/kUmutUK/nixos-hyprland-vfio/commit/cdfd3d8d5008e4b7405ce2433e29b8a0e34ffebe).

**Last source HEAD with an explicitly cited successful standard CI run:** [`b3cd4b5924ebf85a5818b23e0f4cf8b9d479b336`](https://github.com/kUmutUK/nixos-hyprland-vfio/commit/b3cd4b5924ebf85a5818b23e0f4cf8b9d479b336). This is historical CI evidence for that exact SHA, not a validation result for the source revision at the start of this remediation or its descendant commits.

- The standard [Nix Flake Check run #983](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/40673243300) passed for the exact CI-validated source HEAD `b3cd4b5924ebf85a5818b23e0f4cf8b9d479b336`. Required checks include canonical ZIP validation, Bash/Python and VM regressions, ShellCheck, Nix flake evaluation, generated Hyprland Lua syntax, the selected LSFG-VK v1 package build, Statix, Deadnix, and a clean `flake.lock`. This result must not be presented as a run against the starting commit `cdfd3d8d` or this remediation commit.
- The complete NixOS toplevel including RT-Bore-LTO built successfully in [manual run #40571665471](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/40571665471) at commit `6e831df6dc26b08802da0fe69fc661d9780de082`. Later documentation-only commits did not change the `nixos/**` tree in that historical interval. This is not a claim that a full-system build ran for the current remediation.
- **User-supplied measurements for the ZIP under review before this remediation:** size **494,995 bytes**; SHA-256 prefix **`00805455…`**; **105 ZIP entries**, including **45 entries under `.git/`**; embedded Git `HEAD` **`cdfd3d8d5008e4b7405ce2433e29b8a0e34ffebe`**. The ZIP bytes were not attached to this editing session, so its size, digest, entries, and extracted permissions were not independently recalculated here; these values are recorded from the supplied audit.
- The previously documented **493,030-byte / `45e3edaa…` / `c395611f…`** archive describes a different, older ZIP and must not be confused with the file above.
- The packaging source itself already uses `git archive`, excludes `.git/`, compares archived files with the committed tree, validates tracked executable bits, and checks ZIP integrity. The reported executable-mode defect is a delivery defect in the manually compressed ZIP, not a defect in Git's tracked `100755` modes or the canonical helper. This remediation additionally validates that a canonical ZIP embeds the exact commit it packages, so the same commit can be checked after a no-`.git` archive is extracted.
- Rechecked the PCI slot-boundary guard: `scripts/pci-address.sh` and `scripts/sync-vm-xml.py` restrict slot addresses to `00`–`1f`; tests accept `1f` and reject `20`/ `ff`. SSH/local-password-hash behavior remains consistent with configuration and tests.



### Repository ruleset status

On 2026-10-28, the default-branch ruleset named `gpt` (`25819380`) was updated and its `rules` array is now empty. Therefore, this ruleset currently enforces no branch restrictions. The legacy branch-protection status-check enforcement also reports `off` with no required contexts. This matches the current repository settings; no request to re-enable a required-status-check rule is implied here.

**Scope boundary:** successful CI and a full-system build do not prove physical VFIO GPU handoff, Windows VM lifecycle, or Hyprland display recovery. Those remain target-hardware tests.

## Audit remediation — 2026-10-28

- Source revision is now pinned across clean install, README Path B, and `install.sh`. All routes record `/etc/nixos/.source-revision`; post-reboot VM preparation stops if the marker is missing or malformed, the checkout is at another commit, or the checkout is dirty. Canonical source ZIPs embed the exact commit via `SOURCE_REVISION`/Git `export-subst`, and the package helper validates it.
- Closed the VFIO service-state race: a unit captured inactive is queried again before allowing GPU handoff. If it became active/transitional, the hook attempts to stop it and confirms it is inactive; query failures and unknown states abort handoff. Mocked regression coverage exercises this race.
- The manual VM-bootstrap regression fixture now initializes a real clean temporary Git repository and writes a matching source-revision marker, so its existing missing-ISO, partial-disk, concurrent-XML, and successful-bootstrap cases run through the mandatory source verifier.
- Hardware UUID/PARTUUID, PCI BDF, and USB IDs remain machine-specific template values as documented. They are not changed to generic guesses; validating these values on the target machine remains a deployment prerequisite.
- Corrected `install.sh` and its regression test so `/etc/nixos/hashedPassword` is described as the local `localhost` account password hash. The current SSH configuration remains public-key-only; this hash does not enable SSH password authentication.
- The source ZIP helper now sets the published ZIP to mode `0644`. README and CONTRIBUTING validation instructions include the package helper and installer-lock checks, and the README tree lists both lock scripts.
- Current-state notes in `DEGISIKLIK_GECMISI.md` now describe the key-only SSH policy and the canonical ZIP helper. The 2026-10-16 section below is historical and must not be treated as current configuration guidance.
- Historical validation recorded for extracted source snapshot `8487ea4cd82e75ede71bcad7eaada6438c40adb0`: Bash syntax checks passed; the installer-lock, installer-invariants, installer-rollback, and VFIO driver-state tests passed; Python compilation, embedded-script extraction, LSFG-VK config, VM ISO-path tests (8 tests), VM XML invariants, JSON lock parsing, and XML parsing passed. For that older snapshot, the canonical package helper produced 51 tracked source files with `.git/` excluded, two tracked executable files encoded as `0755`, and the final ZIP file mode set to `0644`. Those are historical snapshot counts, not measurements of current `main` (55 tracked files and 8 executable files).
- Historical isolated validation of source snapshot `8487ea4cd82e75ede71bcad7eaada6438c40adb0` (2026-10-28; not the `c395611f` archive baseline): `python3 scripts/test-vm-xml-sync.py` passed independently (about 12 seconds); `bash scripts/test-manual-vm-bootstrap.sh` passed independently and also passed with stdout redirected (about 10 seconds). A separate aggregate invocation exceeded its outer command time limit, but no assertion failure was reproduced and the cause was not established; record that aggregate run as inconclusive rather than a confirmed test failure. Nix, ShellCheck, Statix, and Deadnix were unavailable in the local runner, so no full NixOS/RT-Bore-LTO build or physical VFIO/VM lifecycle validation is claimed.

### Historical submitted archive audit: `nixos-hyprland-vfio(2).zip` — 2026-10-28

This section preserves the exact measurements of a separate earlier ZIP inspected by a previous 2026-10-28 audit. It is not the latest archive described in the report opening. The older ZIP(1), ZIP(9), and ZIP(10) notes below are also historical; none of these measurements should be substituted for the latest archive metadata.

- Archive size: **490,249 bytes**; SHA-256: `505ab8bcadc4f7ad0459194e561d27e2d8f65627e859df35a8af7c385707046f`.
- The ZIP has **105 entries** (80 files and 25 directories), including **45 `.git/` entries** (29 files and 16 directories). The embedded Git `HEAD` and `origin/main` point to commit `8487ea4cd82e75ede71bcad7eaada6438c40adb0`.
- Its 51 tracked project files match that source snapshot. The discrepancy is packaging metadata: the ZIP entries do not carry Unix permission bits, and the extracted `install.sh` and `scripts/package-source-zip.sh` are mode `0644` although Git tracks both as `100755`. This can make the documented `./install.sh` invocation fail with a permission error after extraction.
- **Do not distribute this manually compressed archive.** This is not a tracked source-code defect: `scripts/package-source-zip.sh` and the CI workflow already create and validate the canonical archive using `git archive`, exclude `.git/`, and verify executable bits. For this audit, the canonical helper generated and validated a replacement with **51 tracked files**, no `.git/` entries, both executable files encoded as `0755`, and the ZIP file itself mode `0644`. There is no reason to change the installer content or Git modes for this packaging-only issue.
- The independent reruns listed in the audit remediation section above supersede the earlier timeout-only note for these two tests. The aggregate-run timing observation remains inconclusive, not a confirmed test failure.

## Historical repository validation — 2026-10-27

**Historical snapshot checked before the prior report-only update:** GitHub `main` pointed to [`2fac8309345355f2fac5c54591c5c8fe2972787f`](https://github.com/kUmutUK/nixos-hyprland-vfio/commit/2fac8309345355f2fac5c54591c5c8fe2972787f). The tracked `install.sh` mode is `100755`.

**Standard CI:** [GitHub Actions run #40566306710](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/40566306710) completed successfully for that exact SHA. The run passed canonical source ZIP creation/validation, XML and VM invariant tests, ShellCheck, the Nix flake evaluation step, the selected LSFG-VK package build, Statix, Deadnix, and upload of the validated archive.

**Verified canonical artifact for that snapshot:** the workflow uploaded `nixos-hyprland-vfio-source` (223,842 bytes; artifact digest `sha256:e4a367a1f00152ccb3569d672d9839921632c4b271f78b97f3800ef447e3ed78`). GitHub listed its expiration as **2026-11-10 19:09:51 UTC**. It was generated from the exact SHA above; it is not the same file as any manually compressed ZIP discussed below. The artifact is temporary, so use a new successful CI artifact for the exact commit being distributed.

**Verification boundaries:** the standard workflow runs `nix flake check --no-build`; that evaluates the flake but does not build the complete NixOS system. The separate full-system build workflow is manually dispatched. A successful full-system build for the snapshot above was not established by the standard CI result. Physical GPU passthrough and VM/Hyprland lifecycle behavior must likewise not be inferred from CI.

### Historical submitted archive audit: `nixos-hyprland-vfio(10).zip`

The previously submitted ZIP(10) audit reported:

- File size: **475,881 bytes**.
- SHA-256: `9b107f6a3579224944211349d46377e96ff48e26eb4bfa548c30276a86efbe6c`.
- Embedded commit: `19c87b8f22b92e47d9489be6994808be74eeefdc`.
- Entries under `nixos-hyprland-vfio/.git/`: **45**.
- Extracted `install.sh` mode: `0644`, although the tracked Git mode is `100755`.
- The submitted audit says all **48 tracked files** match the embedded commit.

**Verification boundary:** the ZIP(10) bytes were not attached to this workspace, so its byte count, hash, entry list, extracted mode, and 48-file content comparison were not independently recomputed here. The measurements above are retained as a record of the submitted audit, not as fresh measurements of the current repository.

**Delivery finding:** accepting the submitted measurements as accurate, ZIP(10) is a noncanonical delivery archive. Do not distribute that archive. The repository workflow already creates a canonical ZIP with `git archive`, rejects `.git/` entries, checks that the archive preserves `install.sh`'s Unix executable bit, and uploads the validated ZIP. This packaging defect does not justify changing the tracked installer content or its Git mode.

### Historical delivery audit: `nixos-hyprland-vfio(9).zip`

The earlier ZIP(9) audit reported the following measurements for `nixos-hyprland-vfio(9).zip`; these remain historical and do not describe ZIP(10):

- File size: **475,483 bytes**.
- SHA-256: `931c5d75f8af22e9de5ebfa64341a4d1777a47e2a0e6ad882ba65f1b4bd13f6c`.
- ZIP central-directory entry count: **102**.
- Entries under `nixos-hyprland-vfio/.git/`: **45** (29 file entries and 16 directory entries).
- Embedded commit reported by the audit: `d1e6c979aa25e8908b40dab12e5055a5d87900c7`.
- Extracted `install.sh` mode reported by the audit: `0644`; the Git tree at that commit records `install.sh` as `100755`.

**Verification boundary:** the ZIP(9) bytes were not available in this workspace, so the size, SHA-256, entry count, embedded metadata and extracted mode above are transcribed from the submitted audit rather than independently recomputed in this update. I independently checked the corresponding GitHub branch, tracked file mode, README instructions, workflow, and CI result.

**Delivery finding (based on the submitted ZIP audit):** the ZIP reportedly includes `.git/` metadata and does not preserve `install.sh`'s executable mode. Do not distribute that ad-hoc archive. This is a packaging/delivery defect, not a defect in the tracked installer file: the Git tree records mode `100755`, and `README.md` documents creating the source ZIP with `git archive`.

**Independent source/CI cross-check:** GitHub `main` was at `d1e6c979aa25e8908b40dab12e5055a5d87900c7` during this check. The current `.github/workflows/check.yml` creates a ZIP with `git archive`, rejects `.git/` entries, checks that the ZIP retains the Unix executable bit on `install.sh`, and uploads the validated file as the `nixos-hyprland-vfio-source` workflow artifact. GitHub Actions run [#969](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/40559643957) for that exact source commit completed successfully, including the archive validation and upload steps. This validates the repository's canonical packaging path for that commit; it does **not** validate the separate ZIP(9) bytes themselves.

**Historical report correction:** when the ZIP(9) section was written, older ZIP(1) measurements had been incorrectly presented as current. That earlier correction remains part of the history; ZIP(9) is now also a historical record and must not be attributed to ZIP(10).

### Cross-checks for the ZIP(9) audit

The submitted audit reports that Bash syntax checks, Python compilation, JSON/TOML/XML parsing, VM XML synchronization, installer invariants, and rollback tests passed. Its statement that the VM XML synchronization test passed with a longer timeout is recorded as a supplied result; the ZIP and per-test logs were not available here to repeat those exact checks against the extracted ZIP(9) snapshot.

Separately, the independently inspected GitHub Actions run #969 for source commit `d1e6c979aa25e8908b40dab12e5055a5d87900c7` succeeded. Its successful steps include XML and VM invariants, the manual VM bootstrap retry test, installer invariants and rollback, ShellCheck, VFIO hook regression tests, embedded-script checks, `nix flake check` (evaluation only), the selected LSFG-VK v1 package build, Statix, Deadnix, the lock-file guard, and canonical ZIP creation/validation/upload. This workflow does not perform a full NixOS system build or a physical GPU passthrough / VM shutdown-and-display-recovery test.

### Historical regression checks for the earlier ZIP(1) snapshot

The following repository regression tests were recorded for the earlier ZIP(1) snapshot, with `install.sh` restored to its tracked executable mode for source-level testing. They are historical results and are not claimed as reruns against ZIP(9):

- `scripts/test-installer-invariants.sh`
- `scripts/test-installer-rollback.sh`
- `scripts/test-vfio-hook-driver-state.sh`
- `scripts/test-vm-xml.py`
- `scripts/test-vm-xml-sync.py`
- `scripts/test-vm-diagnostic.py`
- `scripts/test-lsfg-v1-config.py`
- `scripts/test-extract-embedded-scripts.py`
- `scripts/test-vm-iso-paths.py`

Follow-up checks also passed: `bash -n` for `install.sh`, the QEMU hook and shell regression scripts; `python3 -m compileall -q scripts`; JSON parsing of `nixos/flake.lock`; and XML parsing of `vm-xml/win10.xml`.

An earlier combined test invocation exceeded its outer command time limit after the VM diagnostic test printed its success message. The diagnostic test was rerun alone and exited successfully; the remaining tests and follow-up checks were then run separately. The original aggregate command, per-test timestamps and complete exit-status trace were not preserved. This is a historical run and must not be conflated with the separate `test-installer-invariants.sh` timeout note below; there is no evidence that both notes describe the same invocation.

In the local environment used for that earlier ZIP(1) snapshot test run, Nix, ShellCheck, Statix, Deadnix, `xmllint`, and `virt-xml-validate` were not available; those historical local checks therefore did not claim a Nix evaluation/build or libvirt/QEMU semantic validation. Physical GPU passthrough and VM shutdown/display-recovery testing remain unverified. The SSH password-authentication setting remains a documented, network-dependent security risk; it was not changed automatically because doing so without verifying a working alternate access path could lock out a deployed host.

The tracked source already has the correct `install.sh` mode, and `.github/workflows/check.yml` already builds a canonical ZIP with `git archive` and rejects archives that include `.git/` or lose the executable mode. The source/workflow logic was not altered for a defect confined to this ad-hoc ZIP.

### Historical audit notes for earlier ZIP attachments (not the file measured above)

- Exact-byte record for the earlier `nixos-hyprland-vfio(1).zip` audit (not ZIP(9)): **456,770 bytes**, **101** ZIP entries, SHA-256 `69168ea0d90285a879baf08dfb7be0425db2cedb6539344d4ab603caf1f36094`, embedded `.git/shallow` commit `8c6cf467038bacbc8cba46a0c9dcfe54e13c467d`, and **45** `.git/` entries (29 files plus 16 directories). Its installer ZIP entry had `create_system=0` and `external_attr=0x00000000`, so no Unix permission bits were encoded. These are historical ZIP(1) measurements, not measurements of ZIP(9).
- A still earlier audit also recorded **436,212 bytes**, **96** entries, a SHA-256 beginning `3f0f0ed5`, and embedded commit `a631d195`. Those figures describe a separate earlier ZIP and must not be applied to ZIP(1) or ZIP(9).


An earlier review used baseline `e5d491b60f48a35a3cb0b4288c02a7e789a31e4d` and examined a different ZIP whose embedded shallow checkout pointed to `a631d195891ff6da74ae727ac3c531ffc77c50ed`. The following older measurements and CI references are retained as historical records only; they do not describe the 456,770-byte attachment measured at the top of this report.

- The supplied `nixos-hyprland-vfio.zip` contains 96 ZIP entries. There are 45 entries under `nixos-hyprland-vfio/.git/`, including 29 actual files plus directory entries, so the internal Git metadata is definitely included.
- The `nixos-hyprland-vfio/install.sh` ZIP entry uses DOS/FAT creator metadata (`create_system=0`) and carries no Unix permission bits (`external_attr` mode `0000`). Extracting this archive therefore does not preserve the executable bit required by the documented `./install.sh` command and may cause `Permission denied` on Unix. The embedded Git index records `install.sh` as `100755`; the tracked script content and Git mode are not the defect.
- The current source workflow `.github/workflows/check.yml` already has the correct defense: it generates the source archive using `git archive`, rejects `.git/` entries, and validates the Unix executable mode on `install.sh`. The README already documents the same canonical command. This audit does not justify changing the installer or weakening/replacing those checks; the problem is the supplied noncanonical ZIP.
- GitHub Actions run [#928](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/40478786307) succeeded for SHA `a631d195891ff6da74ae727ac3c531ffc77c50ed` and produced the canonical source artifact. That artifact cannot be the supplied ZIP because the run's archive validation excludes `.git/`, while this ZIP contains it. Run #928 is historical evidence for its exact SHA only, not for the later main revision.
- Remediation: after the desired source changes are committed, generate the ZIP from that exact commit with the README's `git archive` command, or use the CI artifact produced for that exact commit. Do not distribute a manually compressed checkout containing `.git/`.

- **Historical re-verification from an earlier review — 2026-10-27 (different ZIP):** At parent revision `5959a79dcba3a0b8c7db4743c9a4a57a1025e36b`, a separate attachment was measured as 96 entries with embedded Git HEAD `a631d195891ff6da74ae727ac3c531ffc77c50ed`. These figures were correct only for that older attachment and must not be applied to the current 456,770-byte ZIP described at the top of this report.
- GitHub Actions run [#953](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/40518482880) succeeded for parent SHA `5959a79dcba3a0b8c7db4743c9a4a57a1025e36b` and uploaded the validated `nixos-hyprland-vfio-source` artifact (artifact ID `12739669466`, SHA-256 `df7db0982c1ebeb7f65d0279368cb85946eef2de2eb5a3f373e4d1c59492125b`). This run applies only to that exact parent SHA. The documentation-only update below must receive its own CI run before its resulting artifact is considered validated.

## Manual validation parity and installer-test timeout follow-up — 2026-10-27

- Updated the README and CONTRIBUTING validation commands to ShellCheck `scripts/pci-address.sh`, and to run `statix check .` plus `deadnix .`, matching the required CI gates. The README repository map now also lists the shared PCI helper.
- Extended `scripts/test-installer-invariants.sh` so documentation drift for these commands and their CI counterparts fails the regression test.
- A separate supplied audit note reports that `test-installer-invariants.sh` passed independently but timed out once during a combined audit. Its exact command wrapper, elapsed time and exit/timeout trace were not preserved, so it cannot be equated with the earlier aggregate timeout described above. This remains a test-stability question rather than a confirmed test assertion failure; do not add arbitrary delays or relax timeouts without reproducing and recording the exact run.
- Use only the exact measurements in the opening `ZIP audit confirmation` section for the `nixos-hyprland-vfio(1).zip` attachment. The 96-entry / `a631d195…` figures belong to a separate historical ZIP and are not current attachment facts. CI already enforces canonical archive packaging; the ZIP-only permission defect does not justify changing the installer's tracked executable mode.
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
- Status update — 2026-10-29: the previously documented v1 scope decision has been superseded by a coordinated LSFG-VK v2 migration. The active flake builds the hash-pinned `.#lsfg-vk-v2` package; Home Manager emits `version = 2` / `[[profile]]` TOML; the installer backs up, deploys, and rolls back `nixos/lsfg-vk-v2.nix`; and CI now validates the v2 schema and builds the package. This does not itself prove that a target host has rebuilt or that frame generation works at runtime.
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

The current `nixos/flake.nix` selects `pkgs.cachyosKernels.linuxPackages-cachyos-rt-bore-lto` from the upstream `master` input; no kernel version is hard-coded in the flake expression. The checked-in `flake.lock` records the resolved input revisions for reproducibility; run a targeted `nix flake update` to move to a newer upstream revision. In the current lock graph, the CachyOS kernel flake has its own `nixpkgs` input, separate from the root system flake's `nixpkgs` input. The `pinned` overlay selects the CachyOS package from that kernel-flake package set; it does not align the system's nixpkgs revision with the kernel flake's revision. Upstream does not publish the RT-Bore-LTO LTO variant in its binary cache, so expect a local kernel build; the overlay cannot create a missing cache artifact. The earlier user-provided linker log named standard BORE-LTO, a different package derivation, and does not prove or disprove the RT-Bore-LTO build. This audit environment has no Nix CLI, so package evaluation and compilation were not run here.

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

- The privileged XML updater uses the already-resolved Python interpreter. XML parsing errors, an incomplete/extra PCI `hostdev` pair, or a PCI node whose source-address structure cannot be synchronized now abort before a VM XML backup/write. Added a preflight guard against running the checkout from `/etc/nixos` (which would overlap source and destination), trimmed monitor-name input before generating Hyprland defaults, and expanded the installer regression tests. Source ZIPs should be built with `scripts/package-source-zip.sh` so tracked executable modes remain intact and `.git/` is excluded; patch ZIP delivery independently stores executable modes in archive metadata.


## Historical configuration snapshot — 2026-10-16 (superseded; not current guidance)

> This dated snapshot records an earlier configuration and contains statements that became outdated. In particular, the OpenSSH password-authentication claim in the next bullet is false for the current `nixos/configuration.nix`: password and keyboard-interactive SSH authentication are disabled; public-key authentication is required.

- The current RT-Bore-LTO package follows `github:xddxdd/nix-cachyos-kernel/master`; the package version is not hard-coded in `flake.nix`. The lock file records the resolved upstream source revision for reproducibility, and a newer revision is selected by running `sudo nix flake update --flake /etc/nixos/nixos cachyos-kernel` followed by a review of the lock diff. Do not use `--accept-flake-config` simply to bypass the cache-trust prompt. The `nup` Fish alias targets only this CachyOS input and works from any directory.
- `LOW_LATENCY_LAYER=1` and `LOW_LATENCY_LAYER_REFLEX=1` are set through `environment.sessionVariables` so PAM-launched desktop sessions receive the system-wide Reflex setting. Affected applications may opt out with `DISABLE_LOW_LATENCY_LAYER=1`.
- Historical note only: this snapshot claimed OpenSSH password authentication was enabled. That claim is superseded: the current configuration disables password and keyboard-interactive SSH authentication, requires public keys, and uses `/etc/nixos/hashedPassword` only for the local `localhost` account password. The QEMU hook terminates only `seat0` rather than all sessions for the desktop user, preserving a remote SSH session. The existing GPU-node check still aborts and rolls back if a process retains the device.
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
- Historical validation for this correction set: the recorded command `bash -n install.sh scripts/test-installer-rollback.sh` syntax-checked only `install.sh`; Bash treats the second path as an argument to the first script, not as another file to parse. The separately recorded `bash scripts/test-installer-rollback.sh` test passed, which also establishes that the test script parsed and ran under Bash. Future multi-file syntax checks use one `bash -n` invocation per path, as shown in the README. Nix evaluation/build, ShellCheck, libvirt semantic validation, and real hardware/VM lifecycle checks were not performed here unless separately available in the target CI/host environment.

## Follow-up verification and fixes — parent `8e063bd3ddcf5774dba10553fe06be2cbcb15fdc` — 2026-10-27

### Findings rechecked against the uploaded archive and current source

- **VM XML/new-disk integration — confirmed by static control-flow inspection.** `install.sh` previously invoked `sync-vm-xml.py` even when no `win10` domain was registered and no deployed XML existed. The helper then created a fresh on-disk XML; both manual VM setup blocks treated any existing XML as an existing VM and disabled the new-disk branch if its disk was missing. The migration helper now synchronizes only a registered domain or an already deployed XML. When neither exists, it defers fresh XML creation to the documented VM-preparation flow, which classifies the VM before calling the helper. Existing disks remain protected; no disk is recreated, overwritten, re-owned or re-permissioned by this change.
- **Post-reboot repository path — confirmed from clean-install instructions.** The fresh-install flow cloned to `/tmp/repo` in the Live ISO, but the later VM-preparation block expected `~/nixos-hyprland-vfio` without creating it. The README and installation guide now clone to the persistent home-directory path if absent, reject a conflicting non-Git path, and use that same checkout for the rest of the block.
- **Archive measurement history — corrected.** The exact size/hash/entry-count/embedded-HEAD tuple for the supplied `nixos-hyprland-vfio(1).zip` remains in the opening section. The 436,212-byte / 96-entry / `a631d195…` data and older v7 figures are historical measurements from different ZIPs, not facts about the current attachment.
- **Machine-specific `hardware-configuration.nix` and deployment-specific SSH/IOMMU/libvirt ownership risks — not changed here.** The existing documentation already warns that hardware UUIDs must be regenerated for the target host and describes the SSH, IOMMU group and libvirt file-ownership risks. Replacing device UUIDs or changing access policy without the target machine could break boot or remote access; these were not treated as verified runtime defects.

### Proposed-tree validation record

The code changes were first tested in the extracted source snapshot. The core installer, guide and regression-test file contents matched the corresponding blobs on `main` at parent `8e063bd3ddcf5774dba10553fe06be2cbcb15fdc`; the current report and changelog were fetched from that parent before edits. Statuses below are from this proposed tree, not from a live target host.

| Command | Exit status | Elapsed time | Result |
| --- | ---: | ---: | --- |
| `bash scripts/test-installer-invariants.sh` | 0 | 16.518 s | Passed |
| `bash scripts/test-installer-rollback.sh` | 0 | 0.193 s | Passed |
| `bash scripts/test-vfio-hook-driver-state.sh` | 0 | 0.968 s | Passed |
| `python3 scripts/test-vm-xml.py` | 0 | 0.987 s | Passed |
| `python3 scripts/test-vm-xml-sync.py` (isolated; `timeout 45s`) | 0 | 21.66 s | Passed in isolated run; see aggregate-run note below |
| `python3 scripts/test-vm-diagnostic.py` | 0 | 7 s (shell `SECONDS` resolution) | Passed |
| `python3 scripts/test-lsfg-v1-config.py` | 0 | 1 s (shell `SECONDS` resolution) | Passed |
| `python3 scripts/test-extract-embedded-scripts.py` | 0 | 2 s (shell `SECONDS` resolution) | Passed |
| `python3 scripts/test-vm-iso-paths.py` | 0 | 7 s wall clock; 5.744 s for six unit tests | Passed |
| `bash -n install.sh`, `bash -n nixos/hooks/qemu`, and Bash regression-script syntax checks | 0 | Combined | Passed |
| `python3 -m compileall -q scripts` | 0 | Combined validation block | Passed |
| Parse `nixos/flake.lock` as JSON and `vm-xml/win10.xml` as XML | 0 | Combined validation block | Passed |

One aggregate test command exceeded the container's 300-second outer limit while waiting in `scripts/test-vm-xml-sync.py`, after the installer-invariants, rollback, VFIO driver-state and VM XML tests had printed success. The XML-sync test then passed in an isolated retry, measured at 21.66 seconds, and also passed on another isolated attempt. This reproduces variable aggregate behavior but does **not** identify the cause; it is not presented as a failed assertion or a proven product defect. Preserve the full runner trace and use an external per-test timeout on the next reproduction.

Nix evaluation/system build, ShellCheck, Statix, Deadnix, libvirt/QEMU semantic validation, and physical GPU/VM lifecycle testing were not run in this environment. No claim of a successful real-host VM or GPU handoff is made.

## Ninth audit cross-check — 2026-10-30

**Inspected upload:** `nixos-hyprland-vfio.zip`, 583,569 bytes; SHA-256 `98d5b073a12488f604dfc9f434f3f741d52defce055d30f22db44102ed1be25d`. Its embedded Git `HEAD` and `refs/heads/main` identify `65b0028cd76352daea9e5a01e4d7d9afb954b10b`, matching GitHub `main` at inspection time. The tracked source tree has 62 file blobs and 14,654 lines.

| Measurement | Observed result | Disposition |
|---|---|---|
| ZIP structure | 116 entries: 91 files and 25 directories. The `.git/` subtree contributes 45 entries (29 files and 16 directories). | Noncanonical distribution archive; local Git metadata should not be included. |
| Unix mode metadata | All 116 entries have `create_system=0` and `external_attr=0x00000000`. The nine Git-tracked executable files extract as mode `0644` with the tested extractor; Git records them as `100755`. | Confirmed uploaded-artifact defect: direct execution of `install.sh`, eight scripts/hooks is not preserved by this ZIP. |
| Source revision | `SOURCE_REVISION` contains the unexpanded Git export-substitution marker, not the archived commit SHA. | Confirmed uploaded-artifact provenance defect. |
| Embedded Git identity | `.git/HEAD` points to `refs/heads/main`; the packed branch ref identifies `65b0028cd76352daea9e5a01e4d7d9afb954b10b`. | Confirms the source snapshot; it does not make the archive canonical. |

**Classification:** these issues belong to the uploaded ZIP, not the tracked packager. After restoring the nine extracted working-copy mode bits to their committed Git modes, `scripts/package-source-zip.sh` independently generated and validated a canonical ZIP for source commit `65b0028cd76352daea9e5a01e4d7d9afb954b10b`: 62 tracked files, nine executable files, 71 ZIP entries, no `.git/`, the exact commit expanded into `SOURCE_REVISION`, executable entries encoded as Unix `0755`, and the ZIP itself mode `0644`. Its SHA-256 was `7abee4ca2a29e02cc3eea810c308f029603070c427a4758b3ceb399574b10a47` (283,401 bytes). This reproduction is for the inspected pre-update commit; use the CI artifact for the current commit when distributing the project.

The source tree's literal `Git export-substitution placeholder` is intentional: `.gitattributes` declares `SOURCE_REVISION export-subst`, and `git archive` expands it. No changes to `install.sh`, `scripts/package-source-zip.sh`, `vm-xml/win10.xml`, the active NixOS configuration, or kernel selection were needed.

Regression validation exercised XML/VM, LSFG-VK v2, Snapper, documentation, embedded-script, installer invariant/rollback/lock, source-revision, VFIO hook, and manual VM bootstrap tests. Nix evaluation/full system build and physical GPU/VM lifecycle remain separate verification gates; this report does not claim those were proven by static tests.
## Tenth audit cross-check — 2026-10-30

**Inspected upload:** `nixos-hyprland-vfio.zip`, 587,335 bytes; SHA-256 `6b0111ca7cfb442d84bdbc22c516efbde2e90c6ea5a1f88bf9076317d99b4b11`. The embedded Git `HEAD` and `refs/heads/main` identify `a627fcb13b15e71e90983a3a2ff391d38eb743e5`, which was also confirmed as the GitHub `main` head at inspection time. The tracked tree contains 62 files and 14,687 lines.

| Measurement | Observed result | Disposition |
|---|---|---|
| ZIP structure | 116 entries: 91 files and 25 directories. The `.git/` subtree contributes 45 entries (29 files and 16 directories). | Noncanonical distribution archive; local Git metadata must not be included. |
| Unix mode metadata | Every entry has `create_system=0` and `external_attr=0x00000000`. The nine Git-tracked executable files extract as mode `0644`; Git records them as `100755`. | Confirmed uploaded-artifact defect: direct execution of `install.sh` and the eight other executable scripts/hooks is not preserved. |
| Source revision | The supplied ZIP contains `SOURCE_REVISION` with the literal unexpanded Git export-substitution marker. | The placeholder is expected in a Git worktree because `.gitattributes` applies `export-subst`; canonical `git archive` expands it to the archived commit. The supplied ZIP did not use that path. |
| Embedded Git identity | `.git/HEAD` points to `refs/heads/main`; the packed branch ref identifies `a627fcb13b15e71e90983a3a2ff391d38eb743e5`. | Confirms the source snapshot, but does not make the uploaded archive canonical. |

**Installer defect confirmed and corrected:** the previous `sudo sed ... && log ...` expression did not guarantee termination when `sed` failed because the command appeared in an `&&` list. The installer now calls `update_qemu_hook_pci()`, which checks that both assignments exist exactly once, validates both BDF inputs, checks the write command's status, and verifies the exact resulting assignments. A failure is passed to `error`, stopping the installer before deployed VM XML synchronization continues; the existing deployment rollback trap remains responsible for restoring transaction targets.

**Regression coverage:** `scripts/test-installer-invariants.sh` extracts and executes the exact helper with a harmless `sudo` shim. It checks a successful update, a failed `sed` operation (including no file change), a missing assignment (rejected before writing), duplicate assignments, and invalid GPU/audio PCI input. The test does not replace a real-host test of sudo, filesystem permissions, libvirt or GPU handoff.

The previous `Ninth audit cross-check` section above remains a historical record of the earlier 583,569-byte upload; its measurements are not attributed to this newer archive. The packaging helper itself remains the canonical delivery mechanism: it derives the commit identity through `git archive`, validates all tracked files and executable modes, excludes `.git/`, and checks `SOURCE_REVISION` against the exact source commit.

No changes were made to `vm-xml/win10.xml`, active NixOS settings, kernel selection, or the desktop theme. Nix evaluation/full system build, ShellCheck/Statix/Deadnix, libvirt/QEMU semantic validation, and physical GPU/VM lifecycle testing remain separate verification gates and are not claimed by this static regression run.


## Eleventh audit and release-workflow repair — 2026-11-01

**Inspected source:** uploaded `nixos-hyprland-vfio.zip`; embedded Git HEAD `ae6e7b8faa52d8859db46a29994ddd3babbaa0dd`, matching the GitHub `main` head before this repair. The tracked source tree contains 65 files. The uploaded ZIP contains 119 entries and includes `.git/`; its ZIP entries do not retain Unix mode metadata. These are defects of the uploaded checkout ZIP, not of the tracked canonical source packager.

**Release workflow defects confirmed and fixed:**

- The previous-version `grep -E` expression lacked its closing quote and end anchor, making the embedded Bash invalid.
- A stray fragment after the first `Publish GitHub Release` step made the YAML invalid.
- A second copy of the release-notes, source-ZIP, checksum, tag, and publication steps was accidentally appended. The workflow now contains one publication pipeline.
- The semver filter now matches complete stable `vMAJOR.MINOR.PATCH` tags and excludes the current tag before version sorting.

**CI and documentation corrections:**

- Normal CI now runs pinned `actionlint` v1.7.7 against all files in `.github/workflows/`.
- README release prerequisites now match the workflow: normal CI must pass for the exact tagged commit; an ancestor full-system build is accepted only when every subsequent change is on the explicit release/documentation/CI metadata allowlist.
- `RELEASING.md` documents the same allowlist, including the updated CI workflow, report, changelog, contributor guide, and documentation-integrity test.
- `CONTRIBUTING.md` now includes `scripts/test-vm-xml-structure.py`, which normal CI already runs.
- README's repository map now lists `.git-cliff.toml`, `RELEASING.md`, and `release.yml`.
- `scripts/test-documentation-integrity.py` now guards these cross-file contracts and ensures each release stage appears exactly once.

**Archive provenance clarification:** the supplied ZIP included `.git/` and omitted ZIP Unix file-mode metadata. The working-tree placeholder in `SOURCE_REVISION` is intentional: `.gitattributes` applies `export-subst`, and the canonical `scripts/package-source-zip.sh` uses `git archive` to expand the actual commit and validates the expected tracked executable modes. No change to `SOURCE_REVISION`, `.gitattributes`, or the canonical package helper was required. Use the canonical package script or its matching CI artifact rather than a generic ZIP of the checkout.

**Scope preserved:** no changes were made to NixOS options, `flake.lock`, kernel inputs, VFIO hook behavior, PCI/USB identities, VM XML, Low Latency Layer / Reflex defaults, LSFG-VK configuration, or the desktop theme.

**Validation boundary:** local YAML parsing, Bash syntax checks for every embedded workflow `run` block, and the documentation-integrity regression passed in the preparation environment. The pinned `actionlint` invocation could not be executed locally because the environment could not resolve `proxy.golang.org`. The first GitHub Actions run downloaded and executed it, then stopped on two ShellCheck findings in `check.yml`; the follow-up changes document and fix those findings. Nix evaluation/full-system build and physical libvirt/QEMU/GPU lifecycle testing remain separate gates; this report does not claim to have independently reproduced them.


## ShellCheck follow-up — 2026-11-01

The first actionlint run reported `SC2016` on the intentional single-quoted nested Bash program and `SC2006` on backticks in a double-quoted `echo` message. The next run confirmed the narrowly scoped `SC2016` directive fixed the nested-quote warning and the `SC2006` warning was gone. It also reported `SC2016` for the literal backticks moved into a single-quoted `printf` argument. Those backticks have now been removed from the message text; the error condition and failure behavior are unchanged. The next GitHub Actions run must verify the final lint result.


## Twelfth audit update — 2026-11-01

This update records the independent measurements for the supplied archive and the current GitHub validation baseline.

- The supplied `nixos-hyprland-vfio(20261101-183521).zip` was measured directly: 605,596 bytes; SHA-256 `b096828af8b958ab0ec1a9178e0020e96e956d530098baa8b26992202b836335`; 119 entries; 45 entries under `.git/`; all entries use `create_system=0` and `external_attr=0x00000000`; `SOURCE_REVISION` contains the unexpanded Git export-substitution marker. The package fails the expected canonical provenance/permission contract. No installer or package-helper source change is warranted because the canonical helper and CI artifact pass their own checks.
- CI run #1078 was checked through the job-step API: every substantive step, including actionlint, canonical package generation, Nix evaluation, the LSFG-VK v2 build, ShellCheck, Statix, Deadnix, VM/XML and installer regressions, completed successfully for `da159dd20866fb026ce8bc3843af4d4f932649f9`.
- The run #1078 artifact was downloaded and inspected independently. Its outer digest matches the GitHub artifact digest, its embedded checksum file matches the inner source ZIP, the source tree contains 65 files, no `.git/` paths are present, the embedded revision matches the source commit, and all nine tracked executable files retain Unix mode `0755`.
- Git-cliff documents `--latest` as processing commits from the latest tag and `--current` as processing commits belonging to the tag at HEAD. The release workflow now uses the appropriate range for tag-push versus manual-dispatch events. The first release did not exercise the later-tag path; that path still needs confirmation on a subsequent pushed version tag.
- Maintenance commit `272f434e81bffa2bdf3f9462b14dd60ecb587f53` passed normal CI [run #1080](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/41345816882), including actionlint, documentation integrity, Nix evaluation, the LSFG-VK v2 package build, ShellCheck, Statix, and Deadnix. This report-only follow-up is checked by the push-triggered CI run for its own commit.

The physical GPU/VM lifecycle and a later-version tag-push release were not independently exercised in this update.

## Post-audit remediation — 2026-11-03

- **OptiScaler shared download cache:** removed the single shared `.part` path. Concurrent downloads now create independent temporary files with `NamedTemporaryFile` in the release cache directory, update a SHA-256 digest while writing, flush/fsync before publication, verify the advertised size and trusted digest, and atomically publish with `os.replace`. A `finally` block removes only the caller's own temporary file. The new barrier-synchronized concurrent-download test ensures both transfers overlap before either can publish and verifies that no partial files remain.
- **Hypridle lock ordering:** moved the lock timeout to 300 seconds and DPMS-off to 305 seconds. The display therefore powers off only after Hyprlock has been started; the previous 600-second lock listener is removed. The 150-second brightness action and 900-second suspend action remain unchanged.
- **Contributor validation:** added the pinned Actionlint check, ShellCheck for the Nix-generated VFIO hook, and the generated Hyprland Lua `luac -p` check. Added a target-host procedure to inspect the DRM `cardN` mapping before changing GameMode's `gpu_device`.
- **GameMode index:** kept `gpu_device = 1` unchanged. GameMode defines this as the DRM card number; without live target-host `/sys/class/drm` output, changing it to 0 would be an unsupported guess.
- **Build status:** the Hypridle edit changes `nixos/home.nix` and is tracked as a pending full-build path by the documentation-integrity guard. Full-system build #9 remains the previous successful baseline; a fresh full-system build is required before release. Normal CI is not substituted for that build.

## Supplied comprehensive audit cross-check — 2026-11-03

**Reviewed source snapshot:** the supplied report names `21c25633c2e5427c18b0b43e193d320e505a61e0`, which was confirmed as the `main` HEAD during this review. The supplied report labels itself `2026-11-04`; that date is later than this review's 3 November 2026 timestamp and should be corrected or explained in the source report before it is treated as a dated deliverable.

### Findings confirmed or corrected

- **CachyOS revision mismatch — confirmed and fixed.** The checked-in `nixos/flake.lock` resolves `cachyos-kernel` to `755712deee259ef7efbfe9154038a270c3d75a87`. The current-state index had copied the obsolete `02ba4db52e62e1fbece80402d369127ae77cbbeb` value. The index now directs readers to the lock file as the sole revision source, and `scripts/test-documentation-integrity.py` prevents a copied SHA from returning in the kernel status line.
- **Supplied ZIP — external artifact, not a source-packager defect.** The supplied audit reports a 709,375-byte archive with embedded `.git/` metadata, an unexpanded Git export-substitution marker, and missing Unix executable-mode metadata. The ZIP bytes were not present in this review, so its entry counts, modes, and byte-level measurements have not been independently remeasured here; those values remain audit-supplied rather than independently verified. The tracked `scripts/package-source-zip.sh` already uses `git archive`, checks the exact tracked-file inventory, verifies the embedded commit, rejects `.git/`, and validates all nine tracked executable modes. `.gitattributes` applies `export-subst` to `SOURCE_REVISION`, and normal CI creates, validates, manifests, and uploads the canonical `nixos-hyprland-vfio-source` artifact. Do not distribute or install from the reported checkout ZIP; use the artifact produced for the exact commit or run the helper from a clean checkout.
- **ICH9 history — already qualified.** The archive preface already states that the historical removal entry conflicts with the active backend-less ICH9 XML device and that the available history cannot establish when it returned. No XML change was made.
- **USB history — qualification added in the current-state index.** The unchanged archive's old `[1.2.0]` note says the machine-specific USB host devices were commented out; the current template actively lists `1532:0098` and `05ac:024f`, with `2a7a:8a47` absent. The current-state index now records that the available history does not identify when the two current IDs were re-enabled. The historical archive was left untouched because its immutable snapshot is outside the documented post-build allowlist. These IDs remain template defaults and must be checked against the target host with `lsusb`.
- **IOMMU kernel parameters — historical boundary clarified.** The current configuration does not set `amd_iommu=on` or `iommu=pt`. The history records the earlier addition but does not establish a later removal commit or rationale; the updated current-state text says so without inventing provenance.
- **GameMode `gpu_device = 1` — deliberately left unchanged.** The repository does not expose the target machine's live `/sys/class/drm` card mapping. The current-state note already records this as pending physical verification; changing the index based only on an expected `card0` ordering would be an unsupported hardware assumption.
- **CI step count and run identity — clarified.** `check.yml` defines 28 YAML steps. In run #1127, GitHub numbers the generated `Set up job` entry as step 1 and the 28 workflow-defined steps as 2–29; separate post-action records are also runner-generated. All 28 workflow-defined steps passed. The UI run number `1127` and URL/API run ID `41693786038` are distinct identifiers and are correctly used for their respective purposes.
- **Test diagnostic date — corrected.** The documentation-integrity test no longer says the current repair report must be the “latest 2026-10-30” report; the diagnostic now refers to the current report without pinning an obsolete date.
- **VM XML indentation — intentionally preserved.** The reported indentation difference is cosmetic and has previously been recorded as a conscious preservation choice. `vm-xml/win10.xml` was not reformatted.

### Change scope and validation boundary

This reconciliation changes documentation and the documentation-integrity regression only. It does not change `nixos/flake.lock`, kernel/boot parameters, GameMode settings, the QEMU/VFIO hook, VM XML, OptiScaler behavior, LSFG-VK, latency-layer defaults, or the desktop theme. A full-system build is therefore not the validation required for this documentation-only change; the required next gate is the normal CI workflow on the resulting commit. No claim is made that the noncanonical ZIP was repaired in place or that live DRM card numbering was measured.
