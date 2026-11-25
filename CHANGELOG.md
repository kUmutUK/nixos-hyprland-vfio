# Changelog

This file summarizes notable changes in English. The separate Turkish release-by-release history file formerly kept at `docs/archive/DEGISIKLIK_GECMISI.md` was removed from the current tree on 15 November 2026; its last committed version remains available [in Git history at the pre-removal commit](https://github.com/kUmutUK/nixos-hyprland-vfio/blob/a0fa8ca557c53810230eb8d42b2edd1e79365460/docs/archive/DEGISIKLIK_GECMISI.md). The root `DEGISIKLIK_GECMISI.md` is an English current-state index. Dated third-level headings under `[Unreleased]` are editorial event labels, not dated release sections; the top-level `[Unreleased]` bucket itself remains undated. The retained external-audit sequence begins at audit five because records for audits 1–4 are not retained; the broad 3 November 2026 cross-check is intentionally unnumbered.

## [Unreleased]

### Integrate Helium Browser on NixOS — 2026-11-25

- Add Helium 0.22.4.1 for x86-64 from the official Linux AppImage, pinned to GitHub's published SHA-256 digest. The local Nix expression uses Nixpkgs `appimageTools`, carries the upstream desktop entry/icon, and exposes a `helium` package output for CI and manual builds.
- Add the browser to `environment.systemPackages`; request Ozone Wayland auto-detection only when both NixOS Wayland environment variables are present. No `--no-sandbox` flag is added. Brave remains installed and no default-browser/MIME, Waybar, or mpvpaper rules are changed.
- The Nix wrapper is community-maintained; upstream publishes the AppImage but does not list Nix as an officially maintained packaging format. Normal CI's package build, a fresh full-system build, and target-host desktop/runtime validation are still required. No activation or physical test is claimed.

### Publish all CachyOS kernel outputs to Cachix — 2026-11-25

- Change the manual cache publisher from the kernel's default `out` output to all declared outputs using Nix's `^*` selector. The workflow first consumes the existing project cache read-only, then builds and supplies the `out`, `modules`, and `dev` paths as a whitespace-separated `pathsToPush` list, with each output's runtime closure.
- The existing cache run published the default output only. Re-run the manual cache workflow after this change is merged to backfill the split outputs for the current lock; then verify all three paths and the full-system dry-build before another activation.
- No kernel options, flake inputs, VM XML, PCI/USB identities, UUIDs, or runtime preferences are changed.

### Make Cachix signature trust daemon-owned — 2026-11-25

- Keep the Cachix and Nix Community URLs in the flake's `extra-substituters`, but remove the duplicated `extra-trusted-public-keys` flake setting. Nix restricts changes to `trusted-public-keys` for untrusted clients; the signing keys remain in the root-managed NixOS daemon configuration at `nix.settings.trusted-public-keys`.
- Correct the cache verification guidance: querying a path directly from the remote store proves that the cache advertises it, but does not prove that the active daemon accepts its signature or will substitute it. Document a no-build dry-run of the exact kernel flake output and the expected fetch-versus-build distinction.
- No kernel options, inputs, VM XML, PCI/USB identities, UUIDs, or runtime preferences are changed. No new host rebuild or physical validation is claimed; the full-system build gate remains separate.

### Fix Home Manager's standalone-flake script path — 2026-11-25

- Resolve the Waybar AMDGPU helper from the flake-local `scripts/` directory when deployed as a standalone flake, with the repository-root `scripts/` directory retained as the full-checkout fallback. This aligns `home.nix` with the resolver already used by `configuration.nix`.
- Add a documentation-integrity regression assertion for both path branches and the exact `builtins.readFile` reference. The failure it addresses was recorded on main commit `3b1c6a1` in Full NixOS System Build run [45507035118](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/45507035118).
- No UUID, PCI identity, VM XML, kernel selection, GameMode behavior, or runtime preference is changed. This source fix still requires its own Normal CI and a fresh full-system build after merge.

### Serpantinum desktop shell integration — 2026-11-25

- **Shell replacement:** the Hyprland session shell is now [Serpantinum](https://github.com/ilyamiro/serpantinum) (locked at `2295c61f466fe46830bc16565af4c246081286da`, 2.5.3, with its own pinned nested inputs). Its NixOS module is enabled for system prerequisites (the PAM service for its lock screen, Ski as the default file manager, and `mkDefault` fallbacks for shared services that the explicit settings in this repository override), and its Home Manager module is configured in `home.nix` — Turkish UI, Istanbul weather location, the previous Waybar layout mapped onto the shell's bar modules, JetBrainsMono Nerd Font with Matugen theming, notifications with DND off, and both the shell's idle scheduler and dock disabled. The shell's Nixpkgs input is deliberately not followed from the root system so it builds against the Quickshell/Qt revision upstream tests.
- **Session wiring:** `serpantinumd` runs as a `systemd --user` service bound to `graphical-session.target` instead of an `exec-once`. `hyprland.lua` no longer autostarts Waybar, Dunst, or `nm-applet`; those packages (plus Rofi and wlogout) stay installed in the system profile as an explicit manual fallback. Hyprlock and hypridle remain the lock/idle authority, mpvpaper keeps the live wallpaper, and Pypr scratchpads are unchanged. The clipboard watchers become the dual text/image `wl-paste` variant the shell itself deploys, still backed by cliphist.
- **Keybinds:** `SUPER+A` (launcher) and `SUPER+B` (clipboard) now open the Serpantinum overlays instead of Rofi; new overlays are bound on the previously free `SUPER+M/N/W/O/I/U/T` and `SUPER+SHIFT+B` (bar autohide); bare `Print` opens the shell's screenshot editor; `SUPER+1..0` focus is routed through `serpantinum msg workspace` while the silent-move `SUPER+SHIFT+1..0` keeps the previous `follow = false` dispatch; `XF86Audio*` keys use the `serpantinum volume` CLI. Existing window/focus/resize/scratchpad binds are untouched.
- **Allowlist and regression updates:** `docs/SERPANTINUM.md` documents the replacement map, keybind table, settings model, and update/fallback procedure and is added as the 76th matching path to the `RELEASING.md`/release-workflow documentation allowlists and the documentation-integrity verification set; the README repository map advances to 92 tracked files. The clipboard regression assertion now pins the Serpantinum clipboard overlay with the dual watchers instead of the retired Rofi picker.
- **Validation boundary:** `nix flake check --no-build`, the generated Lua `luac -p` check, nixfmt/statix/deadnix, actionlint, ShellCheck, and the full Python/Bash regression suites pass locally on this branch; the new input's `narHash` was cross-checked with an independent NAR serialization. Exact-source Normal CI [run 45501996041](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/45501996041) subsequently passed on exact commit `de403decfb40b9702ce755bd70678f831a2ea3cb`. Normal CI is evaluation-only: no full-system build of the Serpantinum closure, and no target-host activation or runtime session validation (bar, overlays, notification routing, audio/gamma daemons), has been performed. Run the manual full-system build before merging this into a release line.

### Standalone flake script paths and deployment layout — 2026-11-25

- **Pure-evaluation path fix:** NixOS now prefers the `scripts/` directory staged inside the standalone deployed flake and falls back to the repository-root `scripts/` directory in a full checkout. This covers the embedded host-profile, automated VM backup, and VM backup script paths without using `--impure`.
- **Installation guidance:** clean install and manual migration instructions copy the root helper scripts into `/etc/nixos/nixos/scripts/`. The VM templates remain separate at `/etc/nixos/vm-xml/` (or in the persistent checkout's `vm-xml/`); they are not part of Nix flake evaluation.
- **Validation boundary:** documentation-integrity coverage is added. A fresh NixOS full-system build and target-host activation are still required for this NixOS configuration change; no physical validation is claimed.

### Additional host performance, backup, and benchmark tools — 2026-11-24

- **Shared gaming profiles:** Desktop, Gaming, Low-Latency, and VM modes coordinate the existing PPD and scx-loader controls. GameMode stores the selected manual profile, temporarily enters Gaming, and restores the previous profile when the final GameMode client exits.
- **ADIOS and kernel options:** expose compiled ADIOS as an opt-in NVMe choice while retaining `none` as default; BBRv3 is explicitly selected through the pinned CachyOS kernel package option. KCFI is opt-in; AutoFDO remains disabled.
- **Offline VM backup:** validate converted qcow2 data, publish and verify SHA-256 sidecars, and apply retention only to verified copies. The weekly timer remains disabled until an external target and matching filesystem UUID are configured. USBGuard remains audit-safe by default.
- **Audio and benchmarks:** prioritize the analog audio output over monitor HDMI without removing the monitor no-suspend rule. Add local MangoHud CSV capture/reporting for average FPS, 1% low, and frametime p99.
- **Current CI workflow:** Normal CI #1765 [run](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/45483814217) passed all 30 workflow-defined steps on exact feature commit `15358cc68ba23853c7c6053fab5b003ccde9af89`; the runner-generated `Set up job` entry is not part of the YAML-defined count. The benchmark capture command is exercised end-to-end against a temporary MangoHud CSV.
- **Validation boundary:** a fresh full NixOS system build remains pending for the kernel derivation and NixOS runtime changes. GPU Waybar rendering, headset routing, external-disk backup, real USB enforcement, and CS2 measurements are not claimed until tested.

### Merged Flake update and owner-confirmed UWSM validation — 2026-11-24

- Weekly Flake update PR #30 merged. The root Nixpkgs revision is `2786a2a72088ecf32aea5b3ec52099e6a7cff78f`, the nested CachyOS Nixpkgs revision is `616ae05a769a23c143b19746b6a3b06366a9a28f`, and CachyOS source is `306480b9096055a06503167f975c027e244dd839`.
- The owner confirms the Flake update/rebuild and UWSM validation were completed without issue. This is an owner report, not an independently retained CI or boot transcript; the feature branch still requires its own exact-source build.

### AMDGPU Waybar telemetry — 2026-11-24

- **Read-only GPU status module:** add a Waybar custom module backed by the kernel AMDGPU sysfs interface. It reports GPU load, VRAM usage, Edge/Junction temperature where exposed, current graphics clock, power, and fan RPM; clicking opens AMD-enabled nvtop in Kitty. No sysfs controls or GPU performance settings are written.
- **VFIO behavior:** the module displays an unavailable state when no AMD DRM card is exposed, rather than treating a GPU bound to vfio-pci as a script failure. The reader is tested against absent, populated, and partial-sensor fixtures.
- **JSON output:** the reader uses jq to escape displayed text and multi-line tooltips correctly for Waybar.
- **Validation boundary:** mock-sysfs regression tests and CI cover formatting/reader behavior. The Waybar rendering, RX 6700 XT sensor availability, and nvtop launch still require activation and a target-host check; this commit does not claim physical validation or a full-system build.

### Normal CI repository-map and release-allowlist reconciliation — 2026-11-24

- **CI #45454656731 failure (job 138660757443):** XML/workflow checks and formatting passed; the documentation-integrity step failed on exactly two assertions. The README repository map still said 80 tracked files after the new Btrfs/kernel guide brought the Git tree to 81, and the new standalone documentation path was absent from the exact release/documentation/CI allowlists.
- **Correction:** update the README inventory count and repository map; add `docs/BTRFS-AND-KERNEL-MANAGEMENT.md` as one literal documentation-only path to both `RELEASING.md` and the release workflow, and mirror it in the documentation-integrity verification set. The exhaustive allowlist expectation advances from 69 to 70 paths; no wildcard or broad documentation exemption is introduced.
- **Validation boundary:** this is documentation/allowlist/test metadata only. No NixOS module, kernel, Flake input/lock, Btrfs mount, Snapper, hardware identity, or VM XML changes are included. The new CI run must confirm the corrected assertions.

### Hyprpolkitagent service path and startup fix — 2026-11-24

- **Root cause:** the reference host reported `hyprpolkitagent` absent from its process list, followed by Polkit's `No session for cookie` error when Btrfs Assistant invoked pkexec. The repository had attempted to start `${pkgs.hyprpolkitagent}/bin/hyprpolkitagent` as an unmanaged child in the Hyprland Lua startup callback. The locked Nixpkgs package installs this executable under `libexec`, so the configured path was wrong.
- **Managed session agent:** Home Manager now defines `hyprpolkitagent.service` with the verified `${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent` path, session.slice placement, restart-on-failure, and graphical-session lifetime. The existing startup environment importer now starts the unit only after importing `WAYLAND_DISPLAY` and the D-Bus activation environment. The obsolete direct-process command and binding are removed.
- **Regression coverage and validation boundary:** documentation-integrity checks pin the libexec path, user-service startup, Wayland environment guard, and removal of the old invalid /bin path. This corrects the configuration source; the service and graphical Polkit dialog still require the next Home Manager/NixOS activation and an interactive target-host check. No filesystem, Snapper, kernel, Flake lock, or VM identity settings changed.

### Btrfs Assistant launcher and declarative kernel-management guidance — 2026-11-24

- **Btrfs Assistant 2.3.x launch path:** the reference host's direct `btrfs-assistant` invocation ran the Qt UI as the unprivileged desktop user. The user's read-only `btrfs subvolume list /` reproduced `Operation not permitted`, while the same command under sudo enumerated the existing subvolumes successfully; this is an authorization boundary, not evidence of filesystem damage. The 2.3.x package ships `btrfs-assistant-launcher`, which invokes the existing Polkit/pkexec authorization path. Home Manager's Fish alias now maps `btrfs-assistant` to that launcher, and the new guide explains the distinction. Do not run the GUI with sudo.
- **Upstream 3.0.0 packaging boundary:** 3.0.0 replaces the 2.3.x launcher model with a rootless UI plus a D-Bus-activated privileged helper and changes the package's installed files/services. The currently locked Nixpkgs package remains 2.3.2; no unsafe version-only override is introduced. A 3.0.0 upgrade needs a complete NixOS package integration for its helper, D-Bus activation, systemd unit, and Polkit policy before it can replace 2.3.2.
- **CachyOS Kernel Manager:** no Arch-style kernel-manager GUI is added. The selected RT-Bore-LTO kernel remains declared by `boot.kernelPackages` in `nixos/flake.nix`; `nup` updates only the CachyOS Flake input and `nrs` performs the explicit rebuild/switch. No kernel setting, Flake lock, Snapper policy, Btrfs mount, or automatic maintenance schedule is changed by this guidance update.
- **Validation boundary:** documentation-integrity assertions pin the launcher alias and Flake-management guidance. The GUI launch still needs a user-session check through `btrfs-assistant-launcher`; no target-host GUI success is claimed by this commit.

### Removed CachyOS LTS recovery specialisation — 2026-11-24

- **Single-kernel system build:** removed the optional `specialisation.lts-kernel` boot entry that added `linux-cachyos-lts` (6.18.x) as a second kernel configuration. The default RT-Bore-LTO x86_64-v3 kernel remains unchanged; the LTS variant is no longer part of the configured system build.


### UWSM session experiment (branch `experiment/uwsm-session`) — 2026-11-24

- **Compositor under systemd user management:** on the experiment branch only, the greetd session wrapper starts Hyprland with `uwsm start -- <Hyprland>`, so the compositor runs as the systemd user unit `wayland-wm@Hyprland.service` in a uwsm-prepared environment, and session shutdown stops that unit and unexports the session environment. `HYPRLAND_CONFIG` is still exported inside the wrapper before `uwsm start`; uwsm saves the calling environment and applies it to the session, so the Lua config path still does not depend on `environment.d` or a pre-imported user environment.
- **Failure semantics:** if `uwsm start` exits non-zero (for example the user manager or its D-Bus socket is not reachable from greetd), the wrapper falls back to the previous direct Hyprland exec, so this change cannot lose the graphical login. `uwsm check may-start` is deliberately unused: its login-shell-parent and tty-foreground checks target shell-profile autostart, not a display-manager session command, and would always fail under tuigreet.
- **Deliberately untouched during the experiment:** the manual environment import and unit starts in `home.nix` (`systemdEnvironmentCommand`) and the `hyprland.start` exec list stay exactly as on main, so the session-wrapper change is the only variable; uwsm's own environment export and `wayland-session` target activation now run in parallel with them. Removing the now-duplicated manual import is a follow-up for after host validation, not part of this branch.
- **Status and merge criteria:** branch-only until the reference host validates it. After login, `systemctl --user status wayland-wm@Hyprland.service` must show the compositor unit active (not the fallback path); Waybar, Dunst, Rofi, the Pypr scratchpads, and the Hyprlock path must work; one full Windows-VM start/stop with GPU handback must pass; and a normal logout must leave no lingering `wayland-wm@` units. Merging to `main` additionally requires the usual pending-build gate (a full NixOS system build on the merged commit) because this changes host session behavior.

### CI read-only kernel cache consumption — 2026-11-24

- **Kernel-phase substitution in CI:** the `CachyOS Kernel Build (manual)` and `Full NixOS System Build` workflows now append the project Cachix cache as `extra-substituters`/`extra-trusted-public-keys` in `/etc/nix/nix.conf` (public key pinned inside the workflow files, not fetched at run time) and restart `nix-daemon` before building. This supersedes the activation wave's note that CI does not consume the new substituter: on a cache hit the kernel phase downloads the artifact the `cache.yml` workflow already built instead of recompiling it for roughly 2.5 hours. Gate semantics are unchanged — a substitution is bit-identical for the same store path, and any kernel configuration or input change produces a different store path that misses the cache and compiles locally, so the workflows still catch kernel breakage. Both workflow files are in the verification-metadata allowlist, and host behavior is unchanged.
- **Validation boundary:** read-only consumption needs no `CACHIX_AUTH_TOKEN` (public cache, public key). If the cache is unreachable at run time, nix falls back to the remaining substituters and the kernel compiles locally, so a Cachix outage cannot fail CI on its own.

### Cachix kernel cache activated — 2026-11-24

- **N1 closed (cache live and consumed):** Cachix cache workflow run #3 (147 minutes on the GitHub runner) built the locked kernel — `linux-cachyos-rt-bore-lto-7.3.5` from the PR #30 merged lock (CachyOS source `306480b9096055a06503167f975c027e244dd839`, nested Nixpkgs `616ae05a769a23c143b19746b6a3b06366a9a28f`) — and published it with its runtime closure to the public Cachix cache `kumutuk-nixos-hyprland-vfio`. The substituter URL and public key `kumutuk-nixos-hyprland-vfio.cachix.org-1:wgWsd619A9+2Mj+iEDABPbnIB1YqJnVJWt2D7Bv9JTQ=` are now wired into the `nixConfig` block of `nixos/flake.nix` and the `nix.settings` substituters/trusted-public-keys lists of `nixos/hosts/nixos/configuration.nix`, ahead of `cache.nixos.org` and the Nix Community cache, so the locked kernel downloads instead of compiling for hours. The kernel narinfo is served and was verified reachable before these entries were committed; the README activation section and the flake-cache bullet now describe the live cache.
- **Validation boundary:** host-side substitution takes effect at the next `nixos-rebuild` on the target host. The `configuration.nix` change is runtime-affecting and stays pending the next full-system build per the pending-build gate, together with the rest of the pending configuration changes since the last completed full-system build and the PR #30 lock refresh (the 7.3.5 kernel has no completed full-system build yet). CI and the cache workflow build without accepting the flake's `nixConfig`, so they do not consume the new substituter.

### Cachix kernel-only push re-scope — 2026-11-24

- **N1 final shape (kernel-only push):** the manual Cachix workflow (`.github/workflows/cache.yml`, now named "CachyOS kernel binary cache (manual)") builds and publishes only the selected RT-Bore-LTO kernel and its runtime closure — not the system toplevel, LSFG-VK v2, or MAKO Renderer — so the project's 5 GB Cachix allocation stays focused on the one component no upstream cache publishes. The write-token guard, the flake.lock-untouched guard, and the disk-space reports are retained; `cachix-action` moves from the v16 push-everything daemon setup to the pinned v17 digest with `pathsToPush` limited to the kernel output. This supersedes the full-push "Binary cache push (manual)" description in the earlier 2026-11-24 waves below. Activation itself remains the maintainer's three steps (create the cache, add the `CACHIX_AUTH_TOKEN` secret, dispatch once); the substituter/trusted-public-key commit into `nixos/flake.nix` and `nixos/hosts/nixos/configuration.nix` lands only after the first successful push.
- **Validation boundary:** the kernel-only workflow has never run — no cache content and no substituter entry exist yet. Offline documentation-integrity assertions now pin the kernel-only scope (kernel build target, `pathsToPush`, no toplevel/LSFG/MAKO references in the workflow); the README activation section matches. The workflow file is CI-only tooling outside the NixOS closure, so no full-system build gate applies to it.

### Btrfs Assistant GUI and compsize spelling fix — 2026-11-24

- **compsize spelling fix (evaluation blocker):** the system package list carried `compsite`, an attribute that exists in neither the pinned Nixpkgs revision (`d00708e7`) nor Nixpkgs master, so any rebuild evaluating the system profile would have failed with a missing-attribute error before activation. The intended `compsize` (the Btrfs compression-report tool behind the `btrfs-cmp` shell alias) is confirmed present in the pinned revision. The typo entered with the LTS specialisation wave and never reached evaluation because full-system Nix builds stay gated, so no target-host activation was affected.
- **Btrfs Assistant GUI:** `btrfs-assistant` 2.3.2 (Qt 6, from the pinned revision) joins the system profile as the GUI for the already-declared `services.snapper` configs: root/home snapshot browsing and diffs need no extra setup because `ALLOW_USERS` already includes `localhost`, and privileged operations ride the package's polkit action/daemon. Its built-in balance/scrub scheduling is cron-shaped for traditional distros and stays unused — maintenance remains declarative via `services.btrfs.autoScrub` and snapper timelines. Runtime GUI behavior on the target host is unverified pending the next full-system build and activation.
- **CachyOS Kernel Manager (checked, not applicable):** the CachyOS GUI is not packaged in the pinned Nixpkgs revision or on master, and NixOS kernel selection here is already declarative: the primary RT-Bore-LTO kernel, the `lts-kernel` specialisation boot entry, and the `nup` alias that updates only the `cachyos-kernel` flake input cover the GUI's role. No equivalent package was added.
- **Validation boundary:** offline documentation-integrity assertions now pin the corrected spelling and the GUI package; the `configuration.nix` changes stay pending the next full-system build and target-host activation per the pending-build gate.

### Windows 11 template, virtiofs share, and USBGuard wave — 2026-11-24

- **Windows 11 template (V7):** `vm-xml/win11.xml` mirrors the validated dual-guest win10 topology (GPU/USB passthrough, disk roles, `tpm-crb` swtpm 2.0, ICH9→PipeWire audio) with the post-ESU migration differences: the MS-keys Secure Boot OVMF image `edk2-x86_64-secure-code.fd`, `secure-boot`/`enrolled-keys` firmware features, SMM on, its own UUID seed (`baf3246e-2397-416f-836c-6c34dd219060`), its own `win11_VARS.fd` NVRAM, and its own `/mnt/media/win11.qcow2` disk + `Win11_24H2_English_x64.iso` installer paths. `scripts/test-vm-xml.py` gains `--guest win11` and enforces the Secure Boot/SMM/TPM/identity rules; the structure suite adds twelve win11/virtiofs cases. The template has never been booted: it stays outside the release allowlist and the changed-XML gate now watches the whole `vm-xml/` directory.
- **Read-only virtiofs host share (V1):** both templates carry a `<filesystem type='mount' accessmode='passthrough'>` device — `/mnt/media/win-share` on the host, tag `host-share` in the guest, `<readonly/>` enforced by the validator. libvirt spawns the Rust `virtiofsd` from `systemd.services.libvirtd.path`; a tmpfiles rule creates the share directory at boot. The win10 XML change intentionally enters the pending `vm_xml_validated` attestation flow: define/boot with the share (virtio-fs driver from the VirtIO ISO) before the next release dispatch.
- **USBGuard audit-safe (M3):** the daemon runs with `implicitPolicyTarget = "allow"` and `presentDevicePolicy = "keep"` — unmatched devices are logged, not blocked, so activation cannot lock out the keyboard or the passed-through mouse. The README documents the enforcement path (`usbguard generate-policy`, review, switch to `"block"`, rebuild). The desktop user is granted IPC access.
- **Cachix activation (N1, prepared):** the `Binary cache push (manual)` workflow was already fully wired; the README now carries the three-step activation section (create the Cachix cache, add the `CACHIX_AUTH_TOKEN` secret, run the workflow and commit the printed substituter keys).
- **Validation boundary:** all offline regression suites (29 VM XML structure cases including win11/virtiofs), YAML validation, and canonical ZIP packaging (80 tracked files, 13 executable) pass locally on the committed tree; the win10 virtiofs change stays pending the VM XML attestation, and the configuration.nix changes stay pending the next full-system build and target-host activation.


### VFIO health, scheduler option, and pre-commit wave — 2026-11-24

- **VFIO/VM health script:** `scripts/vfio-health.sh` reports the resolved IOMMU groups and the current driver of both GPU PCI functions, scans the vfio hook log for ERROR/CRITICAL lines since the last VM release record, and runs a read-only `qemu-img check` over the Windows disk. Read-only, never touches the VM; exits non-zero on anomalies (ungrouped/unbound function, hook errors after the last release, corrupt disk). `scripts/test-vfio-health.sh` regression-tests nine cases over a fake `/sys` tree with a stub `qemu-img`; CI gains a check step (the workflow now defines all 29 workflow-defined steps; GitHub's runner-generated `Set up job` entry remains outside the YAML-defined count) and shellcheck covers both scripts.
- **sched_ext policy option:** the scx-loader default scheduler moved from a hardcoded string in `configuration.nix` to `kumutuk.host.schedScheduler` in `host-settings.nix` — an enum (`scx_bpfland` default, plus `scx_lavd`, `scx_rusty`, `scx_flash`, `scx_p2pq`, `scx_cake`) whose values all ship in the `scx.rustscheds` package set the service already installs. Trying another policy is a one-line host-settings change; `scxctl stop` still falls back to the kernel BORE. install.sh does not rewrite this value; the default behavior is unchanged.
- **Clipboard history menu:** the `wl-paste --watch cliphist store` watcher gains its missing consumer: `mainMod + B` opens a Rofi menu over the history and decodes the chosen entry back to the clipboard (`cliphist list | rofi -dmenu | cliphist decode | wl-copy`).
- **Pre-commit hooks:** `.pre-commit-config.yaml` mirrors the CI gates (nixfmt, shellcheck with CI's file list, statix, deadnix, `bash -n`) using `language: system` hooks from the dev shell; `pre-commit` joins the flake devShell so `nix develop ./nixos --command pre-commit run --all-files` works with the pinned tools. CI does not run pre-commit; the file is contributor convenience.
- **Validation boundary:** all offline regression suites (including the new VFIO health test), YAML validation, and canonical ZIP packaging (79 tracked files, 13 executable) pass locally on the committed tree; `host-settings.nix`, `configuration.nix`, `home.nix`, and `flake.nix` changes stay pending the next full-system build and target-host activation per the pending-build gate. Documentation-integrity assertions now pin the scheduler option, the health script's guards, the clipboard bind, and this changelog entry.

### LTS recovery kernel, gamescope session, and VM backup wave — 2026-11-24

- **LTS recovery boot entry (specialisation):** `specialisation.lts-kernel` evaluates the same host with the CachyOS LTS kernel (`linuxPackages-cachyos-lts` from the pinned nix-cachyos-kernel overlay, no LTO, plain x86-64). It appears as an additional systemd-boot entry; the primary entry and default boot order are unchanged, and `boot.kernelPackages` uses `mkForce` so the override applies only inside the specialisation. This implements the known-good boot belt the README recommends for testing new RT-Bore-LTO revisions. Target-host boot of the LTS entry remains unverified pending the next full-system build and activation.
- **Gamescope Steam session:** `programs.steam.gamescopeSession` adds one console-style entry to the greetd session list (default login stays Hyprland; the desktop layer is untouched). Games page-flip at 2560x1440 fullscreen with immediate flips and a grabbed cursor; the CS2 per-game gamescope launch line is unnecessary inside this session.
- **GameMode power-profile wrapper:** GameMode `custom.start`/`custom.end` switch power-profiles-daemon to `performance` while a game runs and back to `balanced` on exit — the profile half of CachyOS's game-performance wrapper. Best-effort: a failed switch is logged and never blocks the game. The mpvpaper watchdog remains the single authority for the live-wallpaper service.
- **BBR3 congestion control:** `tcp_bbr` joins `boot.kernelModules` and sysctl selects `bbr` with the `fq` pacing qdisc. CachyOS kernels ship BBRv3; if a future kernel drops it, systemd-sysctl logs an error and traffic stays on cubic. WARP's userspace path is unaffected.
- **I/O scheduler udev rules:** rotational disks get BFQ, NVMe namespaces get `none` (CachyOS 60-ioschedulers style); SATA SSDs keep the kernel default. Mostly explicit defaults; the real value is automatic correct selection when a media HDD is added. `none` on NVMe hides queue stats from some telemetry tools (documented in the configuration comment).
- **Night colour (wlsunset):** Home Manager `services.wlsunset` runs as a systemd user service with Istanbul coordinates and a 4000K night temperature (matches the Europe/Istanbul timezone; adjust per location).
- **VM disk backup script:** `scripts/backup-vm.sh` creates a compressed qcow2 copy of the Windows guest disk (`/mnt/media/win10new.qcow2` by default) with fail-closed guards: only a "shut off" VM, never overwrites, publishes via atomic rename from a `.part` file, and reports the SHA-256. `scripts/test-backup-vm.sh` regression-tests all guards with stub `virsh`/`qemu-img` binaries; CI runs it as a new check step and shellcheck covers both scripts. Back up to a mounted external disk, not the media partition.
- **Gaming guide (docs/GAMING.md):** documents NTSync behavior and the per-game `PROTON_NO_NTSYNC=1` opt-out, declarative GE Proton selection, the Gamescope session, the GameMode/PPD profile switching, and the 12G shader cache.
- **Renovate configuration (.github/renovate.json):** proposes GitHub Actions digest updates only (`enabledManagers: github-actions`), automerge off; flake inputs stay with the weekly flake-update workflow. Inert until the Renovate GitHub App is installed on the repository.
- **nix-output-monitor** joins `nh`/`nvd` in the system profile (live rebuild progress via `nom`).
- **Validation boundary:** all offline regression suites, the new backup-script test, YAML/JSON syntax checks, and the canonical ZIP packaging pass locally; runtime-affecting changes (`configuration.nix`, `home.nix`) remain pending the next full-system build and target-host activation/boot validation, per the existing pending-build gate. Documentation-integrity assertions now pin the LTS specialisation, BBR sysctls, I/O scheduler rules, gamescope session, GameMode profile scripts, wlsunset, the gaming guide, and this changelog entry.

### Host gaming and maintenance feature wave — 2026-11-24

- **NTSync:** `boot.kernelModules` now loads the mainline `ntsync` driver, and a udev rule grants the default `users` group 0660 access to `/dev/ntsync` so Steam/Proton 10+ can use kernel-side Windows game-synchronization primitives. Wine keeps its userspace fallback when the module is absent, so this is an optimization, not a dependency. The VFIO handoff is unaffected: ntsync owns no PCI device. Runtime module availability (`modinfo ntsync`) and the in-game effect on the target host remain unverified pending the next full-system build and activation.
- **Mesa shader cache:** `MESA_SHADER_CACHE_MAX_SIZE=12G` (system-wide environment variables) keeps large games from evicting compiled shaders out of Mesa's default on-disk cache and recompiling them on later launches (startup stutter). 12G follows the CachyOS gaming recommendation; the cache is per-user under `~/.cache`, and DXVK/Proton keep separate caches inside prefixes.
- **GE Proton, declaratively:** `programs.steam.extraCompatPackages = [ pkgs.proton-ge-bin ]` pins a GE Proton build through nixpkgs and the flake lock instead of manual `protonup-qt` downloads. Valve Proton remains the global default; GE stays a per-game selection in Steam's compatibility menu, and protonup-qt remains available for ad-hoc installs.
- **S.M.A.R.T. monitoring:** `services.smartd.enable = true` with `notifications.mail.enable = false` (no mail transport on this host). smartd auto-detects the NVMe system disk and the media disk and reports to the journal.
- **fwupd:** `services.fwupd.enable = true` enables LVFS firmware updates through `fwupdmgr` for UEFI/NVMe devices.
- **ESP boot-entry bound:** `boot.loader.systemd-boot.configurationLimit = 20` caps boot entries so generations cannot fill the 1 GiB ESP. Store generations remain governed by the weekly 30-day `nix.gc`, and snapper snapshots are independent of the ESP.
- **Rebuild tooling:** `nh` (nixos-rebuild helper with generation diffs) and `nvd` (side-by-side generation diffing) join the system profile. The fish aliases are unchanged.
- **fstrim rationale:** the intentional `services.fstrim.enable = false` now carries its rationale in a comment: every Btrfs mount already uses `discard=async` with LUKS `allowDiscards`, so freed extents are trimmed continuously and a weekly fstrim pass would add I/O without reclaiming more.
- **Scheduled full-system builds:** the full-system-build workflow keeps manual `workflow_dispatch` and adds a weekly Tuesday 05:00 UTC schedule on `main` (one day after the Monday 04:00 UTC flake-update PR). Manual dispatch remains the release gate for exact commits; the scheduled run only surfaces locked-input/kernel breakage between dispatches. The workflow is renamed from "Full NixOS System Build (manual)" to "Full NixOS System Build", RELEASING step 3 is updated, and the workflow file joins the release ancestor-build allowlist as release-only CI metadata that does not change the installed NixOS toplevel or selected kernel.
- **Validation boundary:** these are runtime-affecting `nixos/hosts/nixos/configuration.nix` changes after full-system Build #22 (`d845ccf`). All offline regression suites pass locally; a fresh full-system build and target-host activation/boot validation are required before the next release, per the existing pending-build gate. Documentation-integrity assertions now pin the new settings, the workflow schedule, and this changelog entry.

### v1.6.0 re-publication and current-source reconciliation record — 2026-11-20

- **Re-published release identity:** the currently published v1.6.0 GitHub Release is ID `452397681`, published by Release run #54 ([run 44696855597](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/44696855597)) on 20 November 2026 from exact tag/source commit `d845ccfb5dec3daf705b59bc29f2e5f14e4ee767`. The release asset is a 510,143-byte source ZIP with SHA-256 `977b1eed45673c022946cb04b997c4172c3c5c9b122d32838a3cd02a0a4fe057`; the asset was downloaded and independently re-hashed to that value on 20 November 2026. The earlier 19 November publication (Release #52, run 44594826628, commit `3c518e45d979db3234f7628ccbf3979a0057dcf2`, 505,012-byte ZIP, SHA-256 `80aa8e731e26e2ca81d3536f738f84203d7c2edfbfffc824b879bcf504d3d63b`) and attempts #50, #51, and #53 (commit `ff655f61e39da2d22d4e85960e500b6eccb9b2db`) were superseded; none is the current published tag/source.
- **Full-system Build #22:** manual Full NixOS System Build #22 ([run 44623962158](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/44623962158)) succeeded on 19 November 2026 for exact source commit `d845ccfb5dec3daf705b59bc29f2e5f14e4ee767`, on the 19 November refreshed locked inputs (CachyOS `10e8df08ad828225575f448e6b49ae092132d9a8`, nested Nixpkgs `d00708e733dc47417b440d7537b0349f1ee66e22`, root Nixpkgs `04906337b6d53e8bb0eaf0470ae9f070a4d4eb55`). Build #22 supersedes Build #21 as the latest completed full-system build; it is the build baseline for the current `main`/re-published tag source. Physical-host activation, boot, and VM lifecycle on that exact source remain unverified.
- **Exact-commit Normal CI for the re-published source:** push-triggered Normal CI #1683 ([run 44622481259](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/44622481259)) passed all 27 workflow-defined steps on `d845ccfb5dec3daf705b59bc29f2e5f14e4ee767`.
- **Release #54 attestation boundary:** Release #54 accepted `TARGET_HOST_VALIDATED=true` for exact source `d845ccfb5dec3daf705b59bc29f2e5f14e4ee767`. This is a maintainer declaration; the supporting host transcript is not committed. Its dispatch also supplied `VM_XML_VALIDATED=true`; because `vm-xml/win10.xml` changed between v1.5.9 and this source (the ICH9 PipeWire backend binding), the separate changed-XML gate ran and the input was accepted as a maintainer attestation — it is not independent guest-boot evidence, and installed-NixOS `vdb` guest boot, guest networking, and saved-state/managed-save restore remain unverified.
- **Status-index reconciliation:** the current-status blocks in README, CONTRIBUTING, INSTALLATION, the repair report, the Turkish current-state index, and the installer banner now record the re-published release identity (run #54 / `d845ccf`), Build #22, and exact-commit CI #1683 instead of the superseded 19 November narrative. The retained historical 19 November records (Release #52 identity, Build #21, CI #1669/#1663, the audited main baseline and its 6-commit/15-path and 20/26-commit distances) are preserved unchanged below as dated history.
- The v1.6.0 re-publication did not change the source tree content: the ZIP equals `git archive` output for `d845ccfb5dec3daf705b59bc29f2e5f14e4ee767` (SOURCE_REVISION embedded by `export-subst`).

### Windows guest audio can use host headphones and GPU monitor audio — 2026-11-19

- The VM's ICH9 emulated sound device now uses libvirt's PipeWire backend and targets the reference host's Realtek ALC897 Analog Stereo sink (`alsa_output.pci-0000_0d_00.4.analog-stereo`). The passed-through RX 6700 XT HDMI/DP audio function is retained as a second, separate Windows output for the monitor.
- The host PipeWire service is switched to system-wide mode so the unprivileged `qemu-libvirtd` process can connect to its socket. The `localhost` and `qemu-libvirtd` accounts are added to the dedicated `pipewire` group; QEMU is not changed to run as root.
- Windows can select the headphone or monitor endpoint independently. This XML does not automatically duplicate a single stream to both outputs. The new host audio routing is statically configured but still requires a full-system NixOS rebuild, a fresh login/reboot for group membership, and live playback verification. No physical audio validation is claimed.
- The ICH9 `<sound>` device now explicitly references PipeWire backend ID `1` through its nested `<audio id='1'/>` element. VM XML regression tests reject a missing reference or an ID that does not resolve to exactly one backend.
- The VM UUID, disk paths, firmware/NVRAM paths, PCI/USB passthrough identities, and VFIO hook are unchanged.

### CachyOS kernel input moved to the upstream release branch — 2026-11-19

- The `cachyos-kernel` flake input now tracks `github:xddxdd/nix-cachyos-kernel/release` instead of `master`. The flake follows the upstream `release` branch, and `nixos/flake.lock` records the resolved revision of the CachyOS `release` input. Both upstream branches pointed at the same revision (`10e8df08ad828225575f448e6b49ae092132d9a8`) when the switch was made, so the locked revision and narHash in `nixos/flake.lock` are unchanged; only the tracked `original.ref` moved from `master` to `release`.
- The documentation-integrity and installer-invariant suites now cross-check the `release` branch: `flake.nix`, `flake.lock`, README, INSTALLATION, the Turkish current-state index, the repair report, and the CHANGELOG Unreleased section all record the `release` input consistently. A fresh full-system build on the `release`-tracked tree is still required before the next release; no kernel version is hard-coded anywhere.

### Post-v1.6.0 repository consistency and installer parity fixes — 2026-11-19

- **Pre-update source/CI baseline:** the audited `main` snapshot was `9e399dcbe96a82a91d03e95fe2251f4e437eadb7`; Normal CI #1669 (run `44603757865`) passed all 27 workflow-defined steps on that exact SHA before this documentation/test reconciliation. This commit must pass its own push-triggered CI. The original v1.6.0 publication at that time was Release #52 (Release ID `451804552`), exact tag/source commit `3c518e45d979db3234f7628ccbf3979a0057dcf2`; GitHub asset metadata listed a 505,012-byte source ZIP with SHA-256 `80aa8e731e26e2ca81d3536f738f84203d7c2edfbfffc824b879bcf504d3d63b` (not independently re-hashed in that review). The exact tag source passed Normal CI #1663 (run `44593727498`). The audited main baseline was six commits and 15 changed paths after v1.6.0; `install.sh` changed by 36 insertions and one deletion. Full-system Build #21 on `672d255d4a921c097dd69eae817e8dc9699380d6` was 20 commits and 39 changed paths behind the v1.6.0 tag and 26 commits and 39 changed paths behind the audited main baseline. These 19 November identities are retained as the dated historical record; the current published release and build state are recorded in the "v1.6.0 re-publication" section above.
- **Owner-reported local full-system build and VM check (16 November 2026):** the owner separately reported a from-scratch local NixOS build and ordinary VM start/shutdown, but did not provide an exact source SHA, derivation, or booted generation/kernel. This is historical owner-reported evidence, not GitHub Build #21.
- **Installer evidence boundary:** Release #52 accepted `TARGET_HOST_VALIDATED=true` for exact tag source `3c518e45d979db3234f7628ccbf3979a0057dcf2`. This is a maintainer attestation; the supporting host transcript is not committed, so it is not independently reproducible. The audited main baseline is six commits and 15 changed paths after v1.6.0; `install.sh` changed by 36 insertions and one deletion. The added x86-64-v3 feature preflight in the audited main installer is outside that attestation. Earlier #50 and #51 attempts used the same version number on different commits and were superseded; their logs are historical, not the current release's provenance.
- **Installer hardware paths:** correct the fallback paths printed by `install.sh` to the actual `/etc/nixos/nixos/hosts/nixos/hardware-configuration.nix` and `/mnt/etc/nixos/nixos/hosts/nixos/hardware-configuration.nix` targets.
- **Optional monitor output:** pressing Enter keeps the detected monitor; typing `none`, `off`, or `disabled` explicitly stores an empty `monitorOutput`, matching the existing Home Manager behavior that disables mpvpaper.
- **Rollback layout:** align the regression fixture with the deployed `hosts/nixos/` tree and cover restoration of `host-settings.nix`, machine hardware configuration, and `mako-renderer.nix`. When this run created the deployment root, rollback removes only empty `hosts/nixos` and `hosts` parents; non-empty/untracked content remains untouched.
- **VFIO hook PATH:** document `pkgs.gnused` as required because the hook calls `sed`, and test it alongside `pkgs.gawk`.
- **Attestation boundary:** Release #52 also supplied `vm_xml_validated=true`, but `vm-xml/win10.xml` was unchanged between v1.5.9 and v1.6.0, so the changed-XML release gate did not trigger. That input is not evidence of a new semantic-validation or guest-boot result.
- No storage UUID/PARTUUID, VM XML, PCI/USB identity, flake lock, GameMode setting, or other intentional runtime preference is changed by this update.

### Documentation consistency fixes from the repository deep analysis — 2026-11-19

- **README manual migration (Path B):** correct "copy all six required Nix/flake files" to seven; the adjacent copy loop already deploys seven sources including `host-settings.nix`. INSTALLATION's pointer ("seven-file migration instructions") now matches. The documentation-integrity assertion pins the corrected wording and rejects the stale six/five variants.
- **README manual install (Path A):** fix the generated hardware-configuration copy source to `/mnt/etc/nixos/hardware-configuration.nix`. `nixos-generate-config` writes its output at the `/mnt/etc/nixos` root, not into a `hosts/nixos/` subtree; the previous source path failed under `set -Eeuo pipefail`. INSTALLATION's matching claim about the generated `configuration.nix` location is corrected the same way, and a regression assertion now rejects the wrong path on both pages.
- **CONTRIBUTING target-machine chronology:** disambiguate the two "latest" labels — the 16 November "Latest target-machine update" is the local full-system build/ordinary VM check, while the 9 November entry is the latest clean-install/VM-lifecycle validation. The chronology paragraph now states this explicitly instead of using "latest" for both.
- **INSTALLATION host-settings table:** rename the first row from the pre-restructure local variable name `hyprlandMonitorMode` to the actual `kumutuk.host` option `monitorMode`; the trailing "select a fixed mode in ..." sentence is updated the same way.
- **DEGISIKLIK_GECMISI.md title:** rename the top-level heading to "Current-State Index (English)" to match how CHANGELOG and KURULUM describe the file; the old "Historical Change Log Index" title contradicted that description.
- **VFIO hook wrapper comment (superseded correction):** the earlier analysis incorrectly concluded that the hook did not use `sed`; the current source calls `sed` when mapping DRM device nodes, so `pkgs.gnused` is required and is now documented and tested as such.
- **docs/MIGRATION-GUIDE.md:** replace the unverifiable "31 offline Python/Bash suites" count with the concrete 19 `scripts/test-*` files that normal CI runs.
- All offline regression suites pass after these changes; no NixOS runtime setting, VM XML, or hook behavior changed.

### v1.5.9 release preparation and current-source reconciliation (historical; superseded by v1.6.0) — 2026-11-19

- Reconcile the latest published release as v1.5.8 (Release run #48, exact tag commit `672d255d4a921c097dd69eae817e8dc9699380d6`) and preserve the exact GitHub source-archive metadata.
- Record successful current-main Normal CI #1643 [run 44536357001](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/44536357001) on `5f541211258511cc31b96160b6eb66fbe61a6499` separately from Full-system Build #21 [run 43982447714](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/43982447714) on exact v1.5.8 tag commit `672d255d4a921c097dd69eae817e8dc9699380d6`.
- Compare current `main` with Build #21: four commits and 36 changed paths later, including runtime-affecting host-layout and installer changes. Require a fresh full-system build on current `main` before v1.5.9.
- Record the unresolved Release #48 manual-attestation discrepancy; do not describe the `install.sh` live migration or installed NixOS `vdb` guest path as tested without evidence.
- Correct the allowlist chronology (53→56, then 56→61), host-settings module comments, and new-host GPU architecture notes; extend documentation-integrity checks to prevent these status regressions.

### Hosts/ layout restructure and repository modernization — 2026-11-19

- **Repository layout:** move `nixos/configuration.nix`, `nixos/home.nix`, `nixos/hardware-configuration.nix`, and `nixos/hooks/qemu` to `nixos/hosts/nixos/`, following the dafitt/dotfiles-inspired hosts/ pattern. `nixos/flake.nix` now imports `./hosts/nixos/configuration.nix`. The deployed target tree under `/etc/nixos/nixos` keeps the same layout.
- **Host-specific values (kumutuk.host):** the five desktop values (`monitorOutput`, `monitorMode`, `wallpaperVideo`, `gitName`, `gitEmail`) move from home.nix's `let` block to a new `nixos/hosts/nixos/host-settings.nix` options module; home.nix reads them through `osConfig.kumutuk.host` with unchanged fallback literals for standalone use. `install.sh` now rewrites `host-settings.nix` option defaults instead of patching home.nix.
- **install.sh:** required-source list, deployment copy, stateVersion targets, backup/rollback transaction paths, hook deployment, and apply_var target updated for the hosts/ layout; hardware-configuration and hook paths under `/etc/nixos/nixos/hosts/nixos/` are documented accordingly.
- **CI:** `check.yml` ShellCheck line updated for the new hook path; `release.yml` ancestor-build allowlist extended with the new `.github/workflows/cache.yml`, `.github/workflows/flake-update.yml`, and `docs/MIGRATION-GUIDE.md` paths. Two new workflows: `cache.yml` (manual Cachix binary-cache push for the system toplevel, kernel, and pinned packages) and `flake-update.yml` (weekly automated flake.lock update PR; never merges automatically).
- **New-host template:** add `nixos/hosts/.template/` (configuration.nix + host-settings.nix) documenting the AMD/VFIO assumptions a new machine must review before reuse.
- **direnv:** add `.envrc` (`use flake ./nixos`) and ignore `.direnv/`.
- **Docs and tests:** README, INSTALLATION.md, CONTRIBUTING.md, RELEASING.md, DISCLAIMER.md, DEGISIKLIK_GECMISI.md, CHANGELOG.md, and docs/ guides updated to the new paths; README's manual migration loops copy seven sources including `host-settings.nix`; all affected Python/Bash regression suites (installer invariants, documentation integrity, LSFG-VK v2, MAKO, VM XML, VFIO hook driver-state, embedded-script extraction) point at the new locations.
- **Scope:** this is a structural, path-level reorganization. No NixOS runtime setting, kernel parameter, VM XML, or VFIO hook behavior changed. `nixos/flake.lock` is untouched. A fresh full-system build is required before the next release (all moved NixOS files are pending-build paths).


### Current-source and release-gate reconciliation — 2026-11-17

- Update the current published-release record to v1.5.7 (Release run #47, exact tag commit `b384eba5b3b37a14b870aeeec5c2ed4b1009335a`), with Normal CI #1609 confirmed on that exact commit and GitHub asset metadata recorded without claiming an independent ZIP re-hash.
- **B5 exact-CI finding is resolved:** Normal CI #1609 passed on exact `b384eba5b3b37a14b870aeeec5c2ed4b1009335a`. Also record Normal CI #1619 as passing on pre-update `main` `e07894e9d63d077b6b11db3e0a189fce6e927875`.
- Correct Build #20's scope: it passed on `46d2b809e4fe9530dde58c85450b3544cf5d1ed0`, but the current-main comparison contains 45 commits and 23 changed paths, including NixOS configuration, `install.sh`, helper scripts, and `vm-xml/win10.xml`. Build #20 must not be described as validating current main.
- Preserve the separate owner-reported local full-system build and ordinary VM start/shutdown result; its exact source SHA, derivation, and booted generation/kernel remain unrecorded. `install.sh` remains untried.
- Add a separate `vm_xml_validated` Release dispatch attestation when the VM template differs from the previous stable tag. This VM-specific assertion requires libvirt/QEMU semantic validation and real Windows plus installed-NixOS `vdb` guest boots; generic `target_host_validated` cannot replace it. The production VM XML and machine-specific identifiers remain unchanged.


### Ten-finding contradiction-report reconciliation — 2026-11-16

- Cross-check the supplied audit against GitHub records at intake commit `b384eba5b3b37a14b870aeeec5c2ed4b1009335a`. The comparison with the preceding confirmed CI commit `0c02d4554edb9d49495a26cfe25553d30c0af1a5` contains only six documentation files and `scripts/test-documentation-integrity.py`; no NixOS runtime, VM XML, hardware identity, or QEMU/VFIO hook path changed. The reported ZIP measurements remain attributed to the supplied report because its bytes were not attached for independent remeasurement.
- Confirm that Release runs #42 and #45 both successfully created/published `v1.5.5` from different commits. The logs show the two tag object IDs and targets; the reason and exact timing for the tag no longer existing before run #45 remain unknown. The published release/tag was not modified.
- Confirm the exact 42-path `RELEASING.md`/workflow match at the 11 November v1.5.2 commit and the current exact 53-path match. The earlier 10 November 43-path statement is not tied to an exact tree here, so its 43→42 transition remains unexplained.
- Resolve the 66→65 file count through the single deleted path `docs/archive/DEGISIKLIK_GECMISI.md` between the cited 66-file and 65-file source snapshots. Confirm that Git ref `v1.3.9` resolves even though the current changelog still lacks its release heading.
- At the time of the initial audit, exact CI for `b384eba5` had not yet been located; the subsequent check found passing Normal CI #1609 on that exact SHA, resolving B5. Keep B7 unreproduced, B8–B10 qualified as historical records, and the Build #14 outcome unknown.
- Correct the archive-directory description: `README.md` is the index and `HISTORICAL-AUDITS.md` is the only retained historical audit register. No runtime configuration or published release asset is changed.

### Owner-reported local full-system build and VM check (16 November 2026)

- The owner reports that a from-scratch full NixOS system build completed successfully on the target machine and that the VM started and shut down successfully. This is an owner-reported result, not a GitHub Actions run; the exact source SHA, build command/derivation, and booted generation/kernel identity were not recorded.
- The owner explicitly confirms that `install.sh` has not been tried. No live installer migration or rollback result exists; CI's syntax, ShellCheck, and mocked rollback tests are not live-target validation.
- The successful ordinary VM start/shutdown report does not by itself validate the separate NixOS `vdb` guest path, guest networking, libvirt saved-state/managed-save restore, or physical GPU/display handback.

### Documentation CI reconciliation — 2026-11-16

- After the v1.5.6 release/tag snapshot, documentation-integrity CI #1601 exposed two stale text assertions. They were corrected without changing NixOS configuration, VM XML, hardware identifiers, or runtime scripts.
- Normal CI [#1602](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/43946085543) passed all 27 workflow-defined steps on exact source commit `0c02d4554edb9d49495a26cfe25553d30c0af1a5`.

### Earlier complete Normal CI #1599 result — 2026-11-16

- Normal CI [#1599](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/43934512654) completed successfully on exact commit `95930e6a41935f7c7fd64cf5bce2d3543f66891b`. VM XML invariants, structural tests, path/sync/diagnostic/ISO validation, and mocked VM bootstrap retry checks passed. This remains automated regression coverage, not a real installed-guest boot or saved-state restore.

### Automated VM validation passed — 2026-11-16
- On exact source commit `95930e6a41935f7c7fd64cf5bce2d3543f66891b`, Normal CI [#1599](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/43934512654) completed successfully. The `XML well-formedness and VM invariants` step ran the VM XML validator, 14 structural regression tests, custom-path validation, XML synchronization, diagnostic XML, and ISO-path checks; the manual VM bootstrap retry regression also passed its retry/failure-cleanup scenarios.
- This is automated VM/XML regression coverage, separate from the owner-reported live VM start/shutdown check above. It does not validate the standard installed NixOS `vdb` guest boot, guest networking, or saved-state/managed-save restore.


### VM bootstrap fixture and host-specific disk paths — 2026-11-16
- Clarified that the checked-in Windows disk and installer-media paths under `/mnt/media` are host-specific, while the fresh-VM bootstrap intentionally auto-creates only its canonical `/var/lib/libvirt/images/win10new.qcow2` path. The manual bootstrap regression now maps the template's two host storage roots into an isolated temporary fixture without changing the committed VM XML.


### VM XML optional USB passthrough — 2026-11-16
- Kept the two documented machine-specific USB IDs as required entries while allowing additional numeric USB hostdevs only when their source sets `startupPolicy='optional'`. Added structural and documentation regressions for optional devices, non-optional extras, invalid IDs, and duplicate ID pairs.


### Full-system Build #20 and current validation boundary — 2026-11-15

- Complete manual Full NixOS System Build #20 [run](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/43653123079) passed on exact source commit `46d2b809e4fe9530dde58c85450b3544cf5d1ed0`. The workflow evaluated the locked flake, built the complete NixOS system and selected RT-Bore-LTO kernel, and verified the lock file was unchanged.
- Build #20 used the current CachyOS source `c9620070e884d55c5b5566e3fd46611ee24c4d3b`, its nested Nixpkgs package set `82566dfe91ca5e12bc10b36272280628142f651d`, and root system Nixpkgs `d4f25a3e562008648d45bcf2d70bcc7422cad84e`. The four commits from that build baseline to the last pre-update CI snapshot `03beec8eefd41ed386353abbf00bc04630be79b9` touched only documentation and the documentation-integrity test.
- The 16 November owner-reported local full-system build and ordinary VM start/shutdown check are recorded in the dated entry above; this is separate from the GitHub Actions Full-system Build #20 baseline.
- The prior Normal CI [#1566](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/43696760003) passed all 27 workflow-defined steps on that pre-update snapshot; GitHub's generated `Set up job` entry is not included. Normal CI #1600 remains the exact-commit check for the v1.5.6 release tag; the later main-branch check #1602 passed on `0c02d4554edb9d49495a26cfe25553d30c0af1a5`.
- The compile/build gate is closed. Exact Build #20 kernel activation/boot, `install.sh` live migration/rollback (not tried), real VFIO saved-state/managed-save restore, and complete dual-guest Windows/NixOS validation remain unverified; do not treat Build #20 or mocked tests as hardware evidence.

### General clean-install guide refinements — 2026-11-15

- Extend the optional Live ISO SSH section with Android Termux setup, wake-lock and battery-optimization guidance, while retaining server-side tmux reconnection instructions.
- Add a read-only check for both intentional kernel configuration workarounds, capture `nixos-install` output in `/tmp/install.log` with `pipefail`, and show how to set optional media-volume ownership only after confirming it is mounted.
- Keep the clean-install procedure generic: retain the generated machine-specific hardware configuration, UUID mapping checks, and explicit disk/LUKS formatting confirmations. No NixOS runtime configuration, machine UUID, VM XML, or installer behavior is changed.

### Flake input refresh — 2026-11-15

- Refresh `nixos/flake.lock`: the CachyOS source advances from the 14 November snapshot `f5e1fb8f1185cb51ef6d433e27ab7b60f54cd0e0` to `c9620070e884d55c5b5566e3fd46611ee24c4d3b`; its nested `nixos-unstable-small` Nixpkgs input advances from `ac9af266ee64ddb2eafeb4b250cac6a88147b43a` to `82566dfe91ca5e12bc10b36272280628142f651d`. The root system `nixos-unstable` Nixpkgs input remains `d4f25a3e562008648d45bcf2d70bcc7422cad84e` and is resolved separately through `nodes.root.inputs.nixpkgs`.
- At the time of the lock-refresh entry, Build #19 was the latest full-system result; that compile gate was subsequently closed by Build #20 on 15 November. Build #20 uses the refreshed CachyOS/root/nested Nixpkgs inputs and the kernel-only x86-64-v3 profile. Physical-host boot validation remains a separate open item.
- Make the documentation-integrity regression compare the current locked revisions with README, CONTRIBUTING, INSTALLATION, and the repair report, preventing stale “current input” claims after future lock updates. Normal CI #1557 caught the stale documentation; it did not run a full-system build.
### Deep source-audit reconciliation — 2026-11-15

- Align README storage requirements with the live installation procedure: 16 GiB swap, 817 GiB allocated system partitions, an 818 GiB minimum disk, and approximately 114.5 GiB remaining for media on a 931.5 GiB disk.
- Correct the release-status index to describe the actual manual `target_host_validated=true` exception for post-build non-allowlisted paths, including `install.sh`, without weakening exact-commit Normal CI, the ancestor full-system-build requirement, or the tag-triggered restriction.
- Resolve root Nixpkgs through `nodes.root.inputs.nixpkgs`; distinguish the root `nixos-unstable` revision from the CachyOS kernel flake's nested `nixos-unstable-small` package-set revision. Extend the regression to check both nodes and both labels.
- Record the supplied audit ZIP identity and the exact-commit CI result. Correct the historical 3 November suspend-timeout note; the current Home Manager timeout is 3600 seconds.
- Keep the `builtins.fetchGit` to flake-input/hash migration as a separate dependency-graph improvement; this reconciliation does not change NixOS runtime configuration or the lock file.

### Manual target-host attestation includes validated installer changes — 2026-11-15
- Correct the new regression's success criterion: the extracted gate block does not include the later informational success message, so an allowlisted documentation-only case is asserted by its successful exit and absence of errors. Restore the exact README CI wording contract and keep the tag-triggered restriction on one searchable line.

- Keep `install.sh` outside the automatic ancestor-build allowlist, so post-build installer changes remain non-allowlisted rather than being mistaken for release-only changes.
- Restore the intended manual override: a **manual Release from `main`** with `target_host_validated=true` may waive the post-build changed-path rejection, including an `install.sh` change, only when the exact current source (including the installer) was used for a clean installation and the host boot, Windows VM start/shutdown, GPU handback, and Hyprland recovery were verified.
- Preserve the hard boundaries: exact-commit Normal CI and a successful ancestor full-system build are still mandatory; an unchecked box or tag-triggered release still requires a new full-system build for a post-build installer change.
- Replace the installer-gate regression with a behavioral test of the actual changed-path/attestation block: manual main-branch attestation accepts the installer change, while no attestation and tag-triggered execution reject it; allowlisted documentation-only changes continue to pass.
- Reconcile the 15 November source-review chronology: main commit `322d0d7` passed Normal CI #1554 with 27 workflow-defined steps after the earlier README inventory failure in #1553 was fixed. This follow-up is newer than that CI run and must receive its own result.

### Repository documentation cleanup — 2026-11-15

- Remove nine superseded one-off audit and fix snapshots from `docs/archive/`; retain `HISTORICAL-AUDITS.md` as the only retained historical audit register alongside the `README.md` directory index.
- Remove the separate Turkish release-by-release archive from the current tree; its exact prior contents remain recoverable from Git history.
- Keep all active CI regression tests. Update the README repository map to the current 65 tracked files; the earlier 75-file count remains only in dated historical snapshots.
- Explicitly include the legacy `KURULUM.md` compatibility pointer in the exact documentation-only ancestor-build allowlist so its retired-history reference can be corrected without a new full-system build.
- Permit the nine one-off archive paths and the retired Turkish release-history path in the release ancestor-build gate only when Git reports them as deleted, never when edited or reintroduced.


### VFIO preparation rollback driver verification — 2026-11-15

- Verify that each touched GPU/audio PCI function is actually bound to its expected host driver after a failed VM preparation; a successful reprobe command alone is not treated as recovery.
- If ordinary rollback does not restore a touched function, invoke the existing suspend/remove/rescan recovery path, which remains disabled unless explicitly enabled with `VFIO_ALLOW_SUSPEND_RECOVERY=1`. Recheck both expected drivers before returning the rollback result and log a critical diagnostic when recovery remains incomplete.
- Extend the VFIO regression suite with failed-reprobe, fallback-recovery, and final driver-binding assertions. These are mocked tests; they do not establish a physical GPU lifecycle result.


### Main-branch hardening and documentation policy — 2026-11-15

- Remove the catch-all `allowInsecurePredicate = _: true` from the separately imported CachyOS package set. No specific insecure dependency has been established; Nixpkgs' default rejection remains in force instead of silently permitting every insecure package in that set. Add a future exception only for a named dependency with a documented reason and regression coverage.
- Clarify the deliberate public-repository disclosure of the reference host's Btrfs, LUKS, EFI, swap, and optional `/mnt/media` storage identifiers. MAC addresses, serial numbers, machine IDs, and broader host inventories remain private.
- Mark the initial global x86-64-v3/ZSTD performance profile and the earlier v1.5.4 release-visibility 404 as superseded historical observations; the later kernel-only profile, LZ4 follow-up, and Release #38 state remain authoritative.

### Installer machine-specific Home Snapper preflight — 2026-11-14

- Remove the fallback to the repository's reference-host `hardware-configuration.nix` when the target's machine-generated file is missing. The installer now requires a generated file in `/etc/nixos` or the flake directory and stops before backups with an actionable message otherwise.
- Make the Home Snapper validator require an explicit hardware-configuration path, and add regression cases for missing host files, repository-template rejection, and selection of either valid machine-generated location.
- Keep `install.sh` experimental: these offline tests do not replace a live migration/rollback test on a disposable NixOS/libvirt host.

### VFIO saved-state restore output-failure rollback — 2026-11-14

- If libvirt cannot receive the buffered domain XML after VFIO preparation has succeeded, explicitly run the preparation rollback before returning failure. This restores the host-driver/desktop recovery path instead of leaving the host prepared for a restore that libvirt rejected.
- Extend the VFIO hook regression to simulate a failed XML output operation after successful preparation and assert that rollback runs once and the temporary XML buffer is removed. This is mocked coverage, not a physical saved-state/managed-save test.

### Linux performance-guide verification — 2026-11-14

- Add a read-only README checklist for checking the running kernel, ZRAM/disk-swap order, ZSwap state, systemd-oomd, active sched_ext policy, and systemd boot critical chain. The NixOS-equivalent configuration choices from the supplied guide were already present; this adds verification guidance, not new runtime settings.

### ZRAM capacity — 2026-11-14

- Set `zramSwap.memoryPercent = 100`, allowing logical ZRAM swap capacity up to all detected RAM (about 32 GB on the 32 GB reference host). This is a capacity limit, not an eager reservation of 32 GB physical RAM; backing memory is consumed as compressed pages are stored. Keep LZ4, ZRAM priority 100, encrypted disk swap priority 10, and disabled ZSwap unchanged.

### Restrict x86-64-v3 to the kernel — 2026-11-14

- Remove the global Nixpkgs `gcc.arch = "x86-64-v3"` / `gcc.tune = "znver3"` target from the system host platform.
- Restore `nixpkgs.hostPlatform = system` where `system = "x86_64-linux"`, keeping general NixOS/userland derivations on the generic x86-64 baseline.
- Preserve `processorOpt = "x86_64-v3"` only on the CachyOS RT-Bore-LTO kernel; RT, BORE, ThinLTO, the pinned CachyOS Nixpkgs input, and the kernel-module compatibility helper remain unchanged.
- Standard x86-64 binary substitutes can now be used for matching userland derivations where available; the custom kernel still needs its own build and an x86-64-v3-capable CPU. Full-system build and target-host boot validation remain pending.

### 14 November audit follow-up — release and build records

- Confirm that the supplied source archive's embedded revision `f6689bcd5234f29a7cfcfc4151d161727b0658bc` is the exact commit targeted by the annotated `v1.5.4` tag. Normal Nix Flake Check #1526 (run ID `43624282232`) passed on that commit, and Release workflow #38 (run ID `43625112235`) published Release ID `445492077`.
- The published canonical source ZIP is recorded by GitHub as 477,863 bytes with SHA-256 `dca1f4ccd365df64d416a029f13ea821a58e4e05cf21a81c4d5bc3d2d65b5e6c`, matching the supplied audit's values. These are GitHub asset metadata values; no independent binary re-hash is claimed.
- Correct the earlier v1.5.4 visibility note: its release object and both source ZIP/checksum assets are retrievable. v1.5.4 was the latest confirmed release at the time of this 14 November entry; v1.5.5 and v1.5.6 were published later and are recorded above.
- Correct the Build #19 history: Full NixOS System Build #19 (run ID `43101226875`) completed successfully on exact source commit `6242439da7e944d297dbe5f44fdff8e79fe4689c` on 11 November. It built the complete NixOS system and selected kernel using CachyOS input `9df32f70be3550911f178b3ba9ad784996a4e80c`.
- At the time of Release #38, the then-current CachyOS input was `f5e1fb8f1185cb51ef6d433e27ab7b60f54cd0e0`; the 15 November refresh superseded it with `c9620070e884d55c5b5566e3fd46611ee24c4d3b` and root Nixpkgs `d4f25a3e562008648d45bcf2d70bcc7422cad84e`. Build #19 predates the 14 November x86-64-v3 performance-profile changes and both refreshed inputs. Release #38 used #19 as the successful ancestor build and accepted later changes to `nixos/hosts/nixos/configuration.nix`, `nixos/flake.lock`, `nixos/flake.nix`, and `nixos/hosts/nixos/home.nix` through explicit `TARGET_HOST_VALIDATED=true` maintainer attestation. The attestation is not a new full-system build; a fresh build is still required to validate the current profile.
- Reconcile the README's hypridle timeout (3600 seconds), distinguish the explicit LZ4/priority-100 ZRAM choices from NixOS' ZSTD/priority-5 module defaults, and correct CONTRIBUTING's stale CachyOS lock statement.
- Correct the Brave integration note: `brave-origin` is included in `environment.systemPackages`, and the Waybar/MPRIS/mpvpaper rules target that repository-installed package. Also document the libvirt 10.10.0 TPM-profile floor and USB hostdev address caveat. The VM XML template, runtime Nix settings, flake lock, and hardware identities are unchanged.

### Initial Linux performance-guide application — superseded intermediate state (2026-11-14)

- This section records an intermediate configuration only. Its initial global x86-64-v3 host-platform choice was superseded by the `Restrict x86-64-v3 to the kernel` correction above; its initial ZSTD compressor was superseded by the LZ4 follow-up below. Do not read the settings in this section as the current configuration.
- Set the Nixpkgs host platform to x86-64-v3 / Zen 3 and derive an x86-64-v3 CachyOS RT-Bore-LTO kernel package set from the exact Nixpkgs revision followed by the kernel flake; keep RT, BORE, ThinLTO, and the LTO module compatibility helper.
- Enable `scx-loader` with `scx_bpfland`, configure systemd-oomd to monitor root and user slices, and leave EarlyOOM disabled so only one userspace OOM policy is active.
- Preserve ZSTD ZRAM at priority 100 and encrypted disk swap at priority 10; do not enable ZSwap, remove the explicit swappiness=180 override, disable Ananicy-cpp, and disable NetworkManager-wait-online because the host has no network filesystems.
- Record the x86-64-v3 CPU portability boundary and the required fresh manual full-system build. This commit does not claim a completed kernel build, host activation, benchmark, or VM lifecycle test.

### Low-latency ZRAM follow-up — 2026-11-14

- Change the selected ZRAM compressor from ZSTD to LZ4 for faster compression/decompression, retaining priority 100, encrypted disk swap priority 10, and disabled ZSwap. This is a configuration change only; runtime activation and comparative frametime measurements are not claimed.

### Normal CI runtime reduction — 2026-11-14

- Remove the Nix-generated VFIO hook derivation/ShellCheck step from routine CI: building that wrapper pulled in the x86-64-v3 dependency closure (multi-GiB) solely to lint generated shell. Keep ShellCheck on the source `nixos/hosts/nixos/hooks/qemu` and the VFIO driver-state regression test; Nix flake evaluation and package checks remain. The current workflow defines all 27 workflow-defined steps. Historical run records correctly retain their former 28-step counts.

### Supplied source-tree audit reconciliation — 2026-11-14

- Bind the 14 November source snapshot `e068b1e5626900d586ba60c8ce83910d32b7ce12` to its exact Normal CI [#1519](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/43620026886), which passed on that SHA. The workflow's canonical packager validated 75 tracked files, 9 executable files, the embedded source revision, and exclusion of `.git`; this corrects the supplied report's claim that no exact-commit CI record exists.
- The supplied audit reports a separate 472,243-byte intake ZIP / SHA-256 `ee0a8e9136013f7357e9eada973e12d646af1b46ca26885a415f1217c1854cbc`. That binary was not attached to this review, so its byte count, digest, and `create_system=0` metadata were not independently remeasured here. The canonical helper now rewrites every archive entry to Unix `create_system=3` metadata with explicit 0644/0755 file modes, then validates the normalized output.
- At the time of this earlier audit pass, the `v1.5.4` annotated tag pointed to the `e068b1e` commit and Release workflow [#37](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/43620383782) completed, but the GitHub Releases collection and `/releases/tags/v1.5.4` lookup returned 404 despite the successful `gh release create` log. This was a temporary visibility observation, superseded by the later Release workflow [#38](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/43625112235), which published v1.5.4 from `f6689bcd5234f29a7cfcfc4151d161727b0658bc`; the release object and both source ZIP/checksum assets are now retrievable. The current release status is recorded in the later 14 November audit follow-up above.
- Release #37 accepted later system-affecting changes to `nixos/hosts/nixos/configuration.nix`, `nixos/flake.lock`, `nixos/flake.nix`, and `nixos/hosts/nixos/home.nix` through the explicit maintainer `target_host_validated=true` attestation. This is not a new full-system build. Full-system Build #19 subsequently completed on 11 November; its exact run, commit, and pre-14-November CachyOS input are recorded in the later audit follow-up above.
- Add explicit `v1.4.0`–`v1.4.6` release headings using the published tag/release metadata. Clarify that `.git-cliff.toml`'s `initial_tag` is a fallback when no matching SemVer tag exists, not a filter that hides existing tags. Clarify the archive's 19 October state-snapshot date versus its older [1.0.0]–[1.3.8] release-history span. Add the canonical source-packaging helper to the release allowlist: it builds and validates source archives and does not change the installed NixOS toplevel or selected kernel.
- Make the LSFG-VK DLL path derive from `config.home.homeDirectory` while retaining the intentional `localhost` account identity. Make the installer stop before backups or writes when `hashedPassword` is missing, empty, or not root:root/0600. Clarify the historical 7.3.3 BTF issue versus the current 7.3.4 lock; no kernel option or hardware identity is changed by that comment-only edit.
- Existing Home Snapper ordering remains: `@home` must be mounted before creating `@home/.snapshots`; the shared strict checker and installer-specific allow-missing transaction path remain covered by existing regressions. The live installer and fresh full-system build are still unverified.
### Independent audit cross-check and preflight fixes — 2026-11-11

- Correct the v1.4.9 snapshot narrative: the published tag / Release #25 targets `a20962f`; Normal CI #1309 belongs to preceding `ad231d7`. The 410,138-byte archive is reproducible from the latter, while the 411,239-byte published asset belongs to the tag target. Only the original local copy's acquisition history is unknown.
- Correct the dated repair-report claims about manual git-cliff dispatch and USB-ID chronology; clarify the historical v1.5.1 release note, separate Build #9's commit from the reviewed snapshot, and correct the 42-path allowlist count and Build #19 dispatch instructions.
- Fix the Home Snapper preflight so installer mode permits only a genuinely absent `/home/.snapshots` path; existing invalid paths and Btrfs verification errors remain fail-closed. Add regression coverage for all three states.
- Re-indent every line of the temporary VM diagnostic XML block and add a non-default-indentation regression.
- Strengthen documentation checks: use “five” for CI #1395–#1399, remove an unused placeholder, and compare the lock icon by Unicode code point.
- Two audit claims were not reproduced: the reported “anual” occurrences are correct “manual” substrings, and the seven omitted paths are deliberately excluded by the exact 42-path allowlist. No runtime NixOS setting, flake lock, VM XML, hardware identity, or published release asset was changed.
- Reconcile the 12 November source-tree audit: keep this entry under `[Unreleased]`, assert its containing section, and validate every README contents anchor against generated GitHub heading anchors.

### Owner-reported target-system build verification — 2026-11-11

- The owner confirms that the current NixOS system build was checked successfully on the target machine. The local check's exact source SHA/derivation was not supplied, so this owner-reported result is not mapped to a specific Git ref. A separate GitHub Actions Build #19 later completed successfully on exact commit `6242439da7e944d297dbe5f44fdff8e79fe4689c` (run ID `43101226875`); it is recorded independently in the 14 November audit follow-up.

### Rev 2 audit provenance corrections — 2026-11-11

- **v1.4.6 asset provenance:** GitHub Release API metadata lists `nixos-hyprland-vfio.zip` (402,118 bytes, SHA-256 `05ffe97e...`) and no manifest asset. Release run #20's successful job log records `scripts/package-source-zip.sh` producing `nixos-hyprland-vfio-source.zip`, validating 73 tracked files and 9 executable files, then creating a separate `.sha256` manifest. The differing name/manifest inventory is verified; the supplied audit's 397,725-byte byte-reproduction result was not rerun here. Preserve the published asset as immutable historical material and do not call its provenance canonical.
- **v1.5.2 release attestation:** Release run #32 (run ID `43012396764`) completed successfully by `workflow_dispatch` on exact commit `418bb687ec4f4d539e3ccc2d839baf242552c018`. Its publish-job log records `TARGET_HOST_VALIDATED: true`, names the five post-Build #18 paths outside the allowlist, and records the maintainer attestation for that exact SHA. This is an operator assertion, not an independent test or a new full-system build. VG27AQ1A rule-specific activation/persistence remains unverified.
- **IOMMU history:** `iommu=pt` appears in the tracked configuration by `5a417ef` (19 April 2026) and was already present in the parent of `ed6ca666`; `ed6ca666` added only `amd_iommu=on`. `0c035b2c` later removed both IOMMU options along with six other kernel parameters. A checkout-only Git-diff regression now guards this chronology.
- Move the 11 November independent-audit/preflight entry into this `[Unreleased]` section; correct the UUID paragraph indentation in `RELEASING.md`.

### Independent source-provenance and CI reconciliation — 2026-11-11

- At the 11 November 2026 snapshot, v1.5.2 was the latest published release: Release ID `441604359`, Release run [#32](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/43012396764), exact tag commit `418bb687ec4f4d539e3ccc2d839baf242552c018`, Normal CI [#1396](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/43012004213), canonical ZIP 451,101 bytes, SHA-256 `11c0b38fc3de7c8f99a089018ad89131e175ca323c6652a19573f13f40b082c6`.
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
- The owner reported that a temporary user-level rule with the same property removed the 2–3 second audio delay after pausing and resuming video. Release #32's job log records `TARGET_HOST_VALIDATED=true` and a general maintainer attestation for the exact release commit, but it does not document a rule-specific sink test or post-reboot persistence check. The earlier wording that the source had not been activated is therefore too categorical; the precise remaining gap is rule-specific functional/persistence evidence.
- The change touches `nixos/hosts/nixos/configuration.nix`, which remains outside the successful Build #18 ancestor baseline and the literal release allowlist. Build #19 or the documented explicit target-host release attestation is still required; normal CI alone is not a full-system build.

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
- Preserve 9–11 November host continuity as unknown. The root Btrfs UUID, LUKS UUID, EFI filesystem UUID, swap PARTUUID, and optional `/mnt/media` filesystem UUID are intentionally published in this public repository because they are the storage references used by the committed, machine-specific NixOS configuration; they are not authentication credentials. Keep MAC addresses, serial numbers, machine IDs, and broader host inventories in a private local record; do not add them to this repository.
- Clarify the GPU/audio IOMMU split: `0000:0b:00.0` was recorded in group 18 and `0000:0b:00.1` in group 19. Different group numbers alone do not prove an isolation defect or establish intra-device isolation; group membership and PCIe/ACS topology require separate review.
- H1 is already corrected in the archived [1.2.2] entry and dated preface: pinned Nixpkgs defines Hyprland `0.56.2` / hyprlock `0.9.6`; `0.54.3 / 0.9.5` is marked as the incorrect earlier statement. H3 and H4 remain documented historical anomalies; no old release description is rewritten and no missing Build #14 event is inferred.
- **Second reconciliation CI failure:** Nix Flake Check [#1383](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/42998196145) failed on `36c13be1558d70822edf9432fe6cca3507f6d8e5` at the documentation-integrity assertion `README must distinguish the immutable v1.5.0 release ZIP from later main-branch documentation`. Commit `edf78e8` restored `The v1.5.0 asset will not be rewritten`; [#1384](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/42998456098) then passed on exact commit `edf78e8559a289dda5da01467ce0082da2c38188`.

## [v1.5.9] - 2026-11-19

### Release and validation provenance

- Published by Release workflow run #49 ([run 44548011675](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/44548011675), 19 November 2026) from exact tag/source commit `d8484ab9083d9c9c71551b0147fa2591e2dbd8a1`.
- GitHub Release metadata records the canonical source ZIP as 496,851 bytes with SHA-256 `5639e8b2fff7140b52a84e93756c2c3e0a8b6311a33d43aebcae430526601c84`; the asset was independently re-hashed to that value on 19 November 2026.
- The tag range over v1.5.8 included the hosts/ layout restructure, the host-settings module, the 61-path release allowlist repair, deprecated xorg alias replacements, and the release-preparation documentation sequence.
- Superseded the same day by v1.6.0.

## [v1.6.0] - 2026-11-20

### Release and validation provenance

- **Current publication (20 November 2026):** the currently published v1.6.0 GitHub Release is ID `452397681`, published by Release workflow run #54 ([run 44696855597](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/44696855597)) from exact tag/source commit `d845ccfb5dec3daf705b59bc29f2e5f14e4ee767`. GitHub Release metadata records the canonical source ZIP as 510,143 bytes with SHA-256 `977b1eed45673c022946cb04b997c4172c3c5c9b122d32838a3cd02a0a4fe057`; the asset was downloaded and independently re-hashed to that value on 20 November 2026. The v1.6.0 tag object now targets `d845ccfb5dec3daf705b59bc29f2e5f14e4ee767` (created by github-actions on the 20 November re-publication dispatch; the earlier tag object was deleted before it).
- The exact re-published source commit `d845ccfb5dec3daf705b59bc29f2e5f14e4ee767` is covered by successful push-triggered Normal CI #1683 ([run 44622481259](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/44622481259)) and by manual Full NixOS System Build #22 ([run 44623962158](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/44623962158)), which built the complete system and selected kernel on the 19 November refreshed locked inputs and verified the lock was not rewritten. Physical-host activation, boot, and VM lifecycle on this exact source remain unverified.
- Release #54 accepted `TARGET_HOST_VALIDATED=true` for exact source `d845ccfb5dec3daf705b59bc29f2e5f14e4ee767`; this is a maintainer declaration without a committed transcript. Its dispatch also supplied `VM_XML_VALIDATED=true`, and because `vm-xml/win10.xml` changed between v1.5.9 and this source (the ICH9 sound device now binds to the PipeWire backend), the separate changed-XML gate ran and accepted the input as a maintainer attestation. It is not independent guest-boot evidence: installed-NixOS `vdb` guest boot, guest networking, and saved-state/managed-save restore remain unverified.
- **Original publication (19 November 2026; superseded):** v1.6.0 was first published by Release workflow run #52 ([run 44594826628](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/44594826628)) from exact tag/source commit `3c518e45d979db3234f7628ccbf3979a0057dcf2` (GitHub Release ID `451804552`, 505,012-byte ZIP, SHA-256 `80aa8e731e26e2ca81d3536f738f84203d7c2edfbfffc824b879bcf504d3d63b`; not independently re-hashed in that review). Attempts #50 (commit `93b8929f5aff5eec17a40afc3f3e91c3443a5c11`), #51 (commit `a5beea31d09d6ebbe1e974c7b58d66b3b46cf699`), and #53 (commit `ff655f61e39da2d22d4e85960e500b6eccb9b2db`) were superseded. Their workflow logs remain historical evidence for the exact commits they processed; none is the current published tag/source.
- The original Release #52 accepted `TARGET_HOST_VALIDATED=true` for its exact tag commit. It also received `VM_XML_VALIDATED=true`, and `vm-xml/win10.xml` was unchanged between v1.5.9 and that source, so the changed-XML gate did not trigger and the input was not proof of a new guest boot.
- The release notes for the re-published v1.6.0 record the v1.5.9..v1.6.0 range: the ICH9 PipeWire audio backend binding, Windows audio routing to headphones and monitor, release-provenance and installer-preflight reconciliation, flake-update PR retry-safety fixes, installer/rollback/release status reconciliation, analysis-found documentation contradiction fixes, and validation-note alignment.

## [v1.5.8] - 2026-11-16

### Release and validation provenance

- Published by Release workflow [#48](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/43969320702) from exact annotated tag commit `672d255d4a921c097dd69eae817e8dc9699380d6`.
- Full NixOS System Build #21 [run](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/43982447714) completed successfully on the exact release commit. Release #48's job log records both manual host and VM XML validation inputs as true; the current repository's contemporaneous validation record conflicts with those assertions, so they are retained as unresolved maintainer attestations rather than independent test evidence.
- GitHub Release metadata records the canonical source ZIP as 479,536 bytes with SHA-256 `8b6d86972c6d01c8102b5072a1cc5d0c970fff6ef4eb26d27edf1e5e0a82f201`. The ZIP was not independently downloaded and re-hashed during this review.

### Bug fixes

- Reconcile validation records and gate VM XML changes.
- Restore v1.3.9 documentation assertion syntax.

### Documentation and tests

- Keep nested Nixpkgs identity explicit in the install guide and preserve the explicit dual-guest validation release gate.
- Restore reviewed-source index anchors and retain historical validation records alongside current status.
- Clarify the retained archive audit register and reconcile the ten-finding contradiction audit.
- Restore dated host-validation labels, align B5 exact-CI assertion wording, and make legacy changelog assertions explicit.

## [v1.5.7] - 2026-11-16

### Documentation

- Preserve historical clean-install validation and target-host validation history labels.
- Align validation notes with integrity checks and retain the explicit installer test boundary.
- Clarify the untried installer status and record the owner-reported local build/VM check.
- Reconcile the audit against the published source and CI records.

### Tests

- Retain release provenance and update the archive inventory assertion.

## [v1.5.6] - 2026-11-16

Published as [GitHub Release v1.5.6](https://github.com/kUmutUK/nixos-hyprland-vfio/releases/tag/v1.5.6) by Release run [#46](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/43936167712). Tag commit: `c4e93db604904529654d3b1b8c53db0754ee3dd9`; exact-commit Normal CI [#1600](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/43935632624) passed. GitHub asset metadata: source ZIP 468,500 bytes, SHA-256 `e1ea3edc75bd061b7460cf3c760ac7e5041b6407ce14f0a6f5c0cc37de0c8eed`.

### Bug fixes
- Preserve executable mode for the VM bootstrap regression test.
- Support libvirt XML quote and host-path variants.
- Allow optional USB passthrough devices in VM XML checks.

### Documentation and tests
- Record successful automated VM regression coverage and clarify guest USB ports versus host USB device IDs.
- Isolate host-specific VM media paths in the bootstrap fixture.
- Accept both TPM profile quote styles and both XML attribute quote styles.

## [v1.5.5] - 2026-11-15

Published as [GitHub Release v1.5.5](https://github.com/kUmutUK/nixos-hyprland-vfio/releases/tag/v1.5.5) by Release run [#45](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/43720459493). The current annotated tag targets commit `045fd0a3cc56344a01cfa0a275f84c29d213fcbf`. Release ID `446090535`; GitHub asset metadata: source ZIP 464,867 bytes, SHA-256 `4939f78991420e696e121c21471a46726cfbd9687185247b8d2c3d4db2ad4b44`.

### Features
- Set the configured ZRAM logical capacity to 32 GB on the reference host.

### Bug fixes and validation
- Reconcile deep-audit findings, flake-lock identity, release-gate policy, and VFIO rollback checks.
- Preserve executable modes for the VFIO hook and its regressions.
- Require the machine hardware configuration for installer Snapper preflight.

### Documentation
- Record Build #20 and the remaining physical-host validation boundary.
- Expand clean-install guidance and reconcile current flake-lock inputs.

## [v1.5.4] - 2026-11-14

### Release and validation boundary — 2026-11-14

- Published [v1.5.4](https://github.com/kUmutUK/nixos-hyprland-vfio/releases/tag/v1.5.4), Release ID `445492077`, from annotated tag commit `f6689bcd5234f29a7cfcfc4151d161727b0658bc`; Release workflow [#38](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/43625112235) completed successfully.
- Normal Nix Flake Check [#1526](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/43624282232) passed on that exact commit. GitHub Release metadata records the canonical source ZIP as 477,863 bytes with SHA-256 `dca1f4ccd365df64d416a029f13ea821a58e4e05cf21a81c4d5bc3d2d65b5e6c`; this is the platform-reported digest, not an independent re-hash in this review.
- The v1.5.4 flake applies x86-64-v3 to both the Nixpkgs host platform and selected RT-Bore-LTO kernel. The later 14 November `main` correction removes the userland-wide target and retains x86-64-v3 only for the kernel. That correction is not included in the immutable v1.5.4 ZIP.
- Release #38 used Full NixOS System Build #19 as an ancestor build and an explicit `TARGET_HOST_VALIDATED=true` maintainer attestation for later runtime-affecting Nix changes. The attestation is not a fresh full-system build of the v1.5.4 profile. Build #19 itself succeeded on 11 November using the earlier CachyOS input `9df32f70be3550911f178b3ba9ad784996a4e80c`; the current kernel-only-v3 profile and current lock still require a new full-system build and target-host boot validation.

### Highlights

- Apply the Linux performance-guide changes recorded in the release notes, including the initial global x86-64-v3 compiler target, ZRAM LZ4 selection, ZSwap disablement, and scheduler/OOM policy adjustments. The later kernel-only-v3 correction is recorded under `[Unreleased]`.
- Normalize canonical source ZIP Unix file metadata and strengthen source-archive preflight validation.

## [v1.5.3] - 2026-11-12

### Release and validation boundary — 2026-11-12

- Published [v1.5.3](https://github.com/kUmutUK/nixos-hyprland-vfio/releases/tag/v1.5.3), Release ID `442930112`, from exact tag commit `a6e538b5d5a7b3328255e37adbfa4965b6dfd954`; Release workflow [#35](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/43219936790) completed successfully.
- Normal Nix Flake Check [#1420](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/43219426864) passed on that exact commit. GitHub Release metadata records the canonical source ZIP as 468,376 bytes with SHA-256 `15b1ec380a7ec2a636cf9aa1da4b7bd80218daac8844f722fe0d8f57669b745b`.
- This is the latest release object currently returned by the GitHub Releases API. The later v1.5.4 tag / Release #37 visibility discrepancy is documented under [Unreleased]; no v1.5.4 asset digest is inferred.

## [v1.5.2] - 2026-11-11

### Release and validation boundary — 2026-11-11

- Published [v1.5.2](https://github.com/kUmutUK/nixos-hyprland-vfio/releases/tag/v1.5.2), Release ID `441604359`, with Release workflow run [#32](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/43012396764) from exact tag commit `418bb687ec4f4d539e3ccc2d839baf242552c018`.
- Normal Nix Flake Check [#1396](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/43012004213) passed on that exact tag commit. The canonical source ZIP is 451,101 bytes with SHA-256 `11c0b38fc3de7c8f99a089018ad89131e175ca323c6652a19573f13f40b082c6`.
- The release contains the device-specific VG27AQ1A DisplayPort WirePlumber idle-resume rule. Release #32's job log confirms a general `TARGET_HOST_VALIDATED=true` maintainer attestation for the exact release commit; this does not independently verify the rule's sink-specific behavior or persistence after reboot.
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
- The 23-commit range includes runtime-affecting changes to `install.sh`, `nixos/hosts/nixos/configuration.nix`, `nixos/hosts/nixos/hardware-configuration.nix`, and `nixos/hosts/nixos/home.nix`. Release run #23 passed the gate through the explicit `target_host_validated=true` maintainer attestation after the owner-reported 9 November clean install, boot, normal Windows VM start/shutdown, GPU handback, and Hyprland recovery. This attestation is not a GitHub full-system build result.
- `nixos/hosts/nixos/home.nix` sets `render.cm_auto_hdr = 0`, disabling Hyprland's automatic fullscreen HDR switch. It does not force HDR or 10-bit output. The recorded clean-install/VM test did not separately validate HDR transitions, 10-bit output, or display flicker.
- The previous published release was [v1.4.6](https://github.com/kUmutUK/nixos-hyprland-vfio/releases/tag/v1.4.6), release run #20 on 6 November 2026; its published ZIP asset is recorded as 402,118 bytes with SHA-256 `05ffe97ee342a4b233f56bc7ae0e455f3b91a1c87df86c42e57e0441e9089e76`; Release #20's job log instead records the differently named canonical helper output and a separate checksum manifest. The unresolved asset/workflow mismatch is documented in the 11 November Rev 2 audit note.
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
- Build #13 covers the previously pending 5 November changes to `nixos/hosts/nixos/configuration.nix`, `install.sh`, and `nixos/hosts/nixos/home.nix`; the full-system build gate is now CLOSED for this exact source snapshot. No VM XML, PCI/USB identity, kernel selection, or desktop preference was changed by this verification follow-up.
- At the time of this historical build-baseline record, v1.4.2 was the latest published release from commit `9661091e35aed98b18483ff6d25a54fe0653c877` (run #7). It was superseded by v1.4.4, published by run #15 from the later reviewed source snapshot above. CI/build success does not add a new physical saved-state-restore result.

### GameMode priority and installer source preflight — 2026-11-05
- Corrected the GameMode comment and documentation-integrity regression: the configured positive `renice = 10` magnitude is negated by GameMode and applied as nice `-10`, raising CPU scheduling priority. The numeric setting itself is unchanged.
- Added `nixos/hosts/nixos/hooks/qemu` to the installer's initial required-source preflight through a separate runtime-source list, preserving the six-file Nix deployment loop. Expanded installer invariant and MAKO integration checks to cover the hook being present, non-empty, and required.
- These changes touch `nixos/hosts/nixos/configuration.nix` and `install.sh`, which remain outside the release ancestor-build allowlist. The previously required fresh build is now satisfied by exact-HEAD full-system build #13; normal CI #1233 also passed on that commit. `gpu_device = 1`, VM XML, VFIO behavior, and other hardware-specific settings remain unchanged.

### Conservative frame-generation fallback profiles — 2026-11-05
- Reduced the Genshin Impact LSFG-VK v2 fallback profile from 3x to 2x; Wuthering Waves remains at 2x. MAKO Adaptive remains the preferred first per-game Frame Generation path to validate, with LSFG-VK retained as the alternative.
- Added regression coverage for both 2x LSFG-VK profiles and clarified that the MAKO-first preference is not a measured RX 6700 XT performance ranking. Frame Generation remains opt-in per game; CS2, global AMD low-latency settings, Reflex, MAKO packaging, and OptiScaler behavior are unchanged.
- This updates `nixos/hosts/nixos/home.nix`; the earlier full-system build #11 did not cover the change. Exact-HEAD full-system build #13 and normal CI #1233 subsequently passed on `1dbb7d5407f5b478cee14da5d52dc0c1822d4e8b`, closing the build gate for this profile update.

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
- Because this change modifies `nixos/hosts/nixos/home.nix`, it starts a new full-system build gate. Build #10 on `480972a` predates this change; a build covering the updated Home Manager source is required before release.

### Source-tree audit hardening — 2026-11-04
- Fixed the VM XML sync regression test so its mocked `lspci` executable is created in a `TemporaryDirectory` and cleaned up on every exit; normal CI now rejects a dirty or untracked checkout after validation.
- Aligned the current-state audit section order, qualified the historical four/five-file preflight wording, and corrected the Home Manager customization line range in INSTALLATION.
- The archive measurements quoted in the supplied audit remain report-supplied in this source-only pass because the ZIP bytes were not attached. The supplied twelfth-audit text names `e080015ca3593d4f185888f86379268a20706639` in its package summary but says `e0880015` in section 2.1; its 760,112-byte/126-entry/45-`.git` inventory is therefore not independently verified. The separate 54-`.git` count remains an unresolved report-supplied outlier, not a new source-tree measurement. The supported distribution remains the canonical output of `scripts/package-source-zip.sh`, published by CI/release automation.
- Reconciled the historical gaps against Git: `iommu=pt` was present by 19 April; `ed6ca666` added only `amd_iommu=on` on 9 October, and `0c035b2c` removed both IOMMU parameters on 13 October; ICH9 audio was removed on 12 October and restored on 23 October; the old `2a7a:8a47` USB hostdev was disabled on 9 October and replaced by the active `1532:0098` / `05ac:024f` entries on 16 October. Exact commits and the documented rationale are recorded in the current-state index and Turkish archive preface.
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
- Reconciled the current-state index with the historical archive's explicit USB and IOMMU chronology. USB: `f46b8ac8` commented out the old `2a7a:8a47` hostdev on 9 October, and `fbd105c8` replaced it with active `1532:0098` and `05ac:024f` entries on 16 October. IOMMU: `iommu=pt` was already present in the tracked configuration by 19 April 2026 (`5a417ef`); the parent of `ed6ca666` also already contained it. The 9 October `ed6ca666` diff added only `amd_iommu=on`. The 13 October `0c035b2c` diff removed both IOMMU parameters as part of a broader cleanup that also removed six other kernel parameters; `91c4d58e` clarified the resulting no-parameter state on 15 October. The former “history unknown” wording is withdrawn.
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
- The `nixos/hosts/nixos/home.nix` idle-timer change is a system-configuration change. Full-system build #9 remains the previous verified baseline; a fresh full-system build is required before release. The current `gpu_device = 1` value was deliberately preserved because the target host's live DRM card mapping cannot be measured through this repository update.

### Exact-HEAD full-build baseline refresh — 2026-11-03
- Promoted manual full-system build #9 (`ab89f350803d47eb16499c613b110da05a57673f`) to the verified baseline. The complete NixOS toplevel/selected-kernel build, flake evaluation, and unchanged-`flake.lock` check all passed on that exact commit (4 h 46 min 26 s).
- Diagnosed normal CI #1124: its documentation-integrity regression still compared changes against the superseded `ca6edf2` baseline and incorrectly rejected `nixos/hosts/nixos/configuration.nix`, `nixos/flake.lock`, and `nixos/hosts/nixos/home.nix`, even though full-system build #9 covered that exact tree. Updated the test to track the newest verified full-build baseline while retaining its ancestry and changed-path gate.
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
- Recorded the verified current kernel defaults: `boot.kernelParams` contains `amd_pstate=active`, `nowatchdog`, and `nmi_watchdog=0`; `usbcore.autosuspend=-1`, `kvm.ignore_msrs=1`, `amdgpu.ppfeaturemask`, `amd_iommu=on`, and `iommu=pt` are not active defaults. The IOMMU history is now resolved from the commit diffs: `iommu=pt` was already present in the 19 April tracked configuration (`5a417ef`) and in the parent of `ed6ca666`; the 9 October `ed6ca666` change added only `amd_iommu=on`. The 13 October `0c035b2c` change removed both IOMMU parameters, alongside six other kernel parameters, because `amd_iommu=on` was not documented across all kernel versions and `iommu=pt` does not prove firmware activation; `91c4d58e` clarified the no-parameter state on 15 October.
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

## [v1.4.6] - 2026-11-06

- Published Release ID `436371622` from tag commit `a6dd4544319fafa7ec517e73b31ad29a1b4010b3`. GitHub Release API lists a 402,118-byte asset with SHA-256 `05ffe97ee342a4b233f56bc7ae0e455f3b91a1c87df86c42e57e0441e9089e76`; the asset name/manifest differs from the helper output retained in Release #20's job log, so canonical asset provenance remains qualified.

## [v1.4.5] - 2026-11-05

- Published Release ID `435306537` from tag commit `994b05c888fbb52295d93e8ef74e41bac66c5e65`. The listed asset is 392,212 bytes, SHA-256 `f97fb12bdfbaaff4d32e7ab57bbc9251fababcd126a8ef7644947844924de9e0`.

## [v1.4.4] - 2026-11-05

- Published Release ID `435237316`; its tag points to `7f923a2c7aa59721bc00728faccbc073e06c697a`. The listed 388,000-byte asset has SHA-256 `7621fcdccfe327e9e59f453947b9f7903cd0f477b73cde8f4aa5ee513061e0ff`, identical to v1.4.3. The generated release-body heading also says v1.4.3; retain that as a historical notes-generation anomaly rather than attributing a different source snapshot.

## [v1.4.3] - 2026-11-05

- Published Release ID `440298465` on 10 November 2026 (the annotated tag was created on 5 November) from the same `7f923a2c7aa59721bc00728faccbc073e06c697a` target as v1.4.4. Its 388,000-byte asset digest is identical to v1.4.4; this release entry was restored/published later and is not a new source snapshot.

## [v1.4.2] - 2026-11-05

- Published Release ID `434925955` from tag commit `9661091e35aed98b18483ff6d25a54fe0653c877`. The listed asset is 380,135 bytes, SHA-256 `ef3b430ccff66f3c1905516be018991585e5945ceccdd2b06eaaf1545fdd06fd`. Its generated release-body heading starts at v1.4.1, a retained version-heading mismatch.

## [v1.4.1] - 2026-11-04

- Published Release ID `433672805` from tag commit `480972a235655f6d1e9ec6137f85ad3f30b8655a`. The listed asset is 354,216 bytes, SHA-256 `c430c3f339ee98559ae6f9599782c39e1ee371ba4c021ab7837523f8e8152f6e`. Its generated release-body heading starts at v1.4.0, a retained version-heading mismatch.

## [v1.4.0] - 2026-11-01

- Published Release ID `430849590` from tag commit `ca6edf2a381118fbd81aeccb82287f234f44a257`. The listed asset is 301,189 bytes, SHA-256 `2bd2c437ed10bb78468067cce6b49757368d8d4cee1e2b41b5e299fa65b86ee0`. Its generated release-body heading starts at v1.3.9, a retained version-heading mismatch.

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
- Switched the selected kernel from standard CachyOS BORE-LTO to `linuxPackages-cachyos-rt-bore-lto`. The version is not hard-coded: the flake followed the upstream `master` branch at the time of that switch (the tracked branch moved to the upstream `release` branch on 19 November 2026) and the lock can be updated for newer upstream revisions with `nix flake update cachyos-kernel`. Upstream does not publish the RT-Bore-LTO ThinLTO build in its binary cache, so it is expected to compile locally. The project owner has since reported a successful local RT-Bore-LTO build and VM/Hyprland recovery cycle on the target machine.
- Enabled the Vulkan low-latency layer and Reflex system-wide through PAM session variables `LOW_LATENCY_LAYER=1` and `LOW_LATENCY_LAYER_REFLEX=1`. Applications with compatibility issues can opt out with `DISABLE_LOW_LATENCY_LAYER=1` in their Steam launch options. **Superseded on 2026-10-29:** the global `LOW_LATENCY_LAYER_REFLEX=1` default was removed; Reflex is opt-in per compatible game.
- Enabled password SSH for the `localhost` user on TCP 22 while keeping root SSH login disabled, restricting allowed users, and applying Fail2ban to private LAN sources too. Updated the VFIO hook to terminate only the local `seat0` sessions so remote SSH sessions are not killed by `loginctl terminate-user`; a busy GPU still triggers the existing fail-closed handoff check. **Superseded on 2026-10-30:** password and keyboard-interactive authentication are now disabled; public-key authentication is required.
- Historical lock snapshots: an earlier tree resolved CachyOS upstream `master` to `02ba4db52e62e1fbece80402d369127ae77cbbeb`; the immediately preceding 14 November snapshots used `9df32f70be3550911f178b3ba9ad784996a4e80c` and then `f5e1fb8f1185cb51ef6d433e27ab7b60f54cd0e0`. The 15 November lock now resolves CachyOS to `c9620070e884d55c5b5566e3fd46611ee24c4d3b` and root Nixpkgs to `d4f25a3e562008648d45bcf2d70bcc7422cad84e`; always read active values from `nixos/flake.lock` rather than copying a SHA into configuration.
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
- Translated English-named project documentation, installer comments/messages, and VFIO hook diagnostics/recovery messages into English. The root `KURULUM.md` and `DEGISIKLIK_GECMISI.md` are English compatibility/current-state pointers; the original Turkish release-by-release history was then preserved in `docs/archive/DEGISIKLIK_GECMISI.md` until that archived file was removed from the current tree on 15 November 2026. Comments embedded in installation command examples are translated too. Turkish OCR translation notifications remain intentional application UI.
- Replaced stale archive-document wording with English historical audit summaries so old findings are not mistaken for current defects. The original Turkish release-by-release changelog was intentionally preserved at `docs/archive/DEGISIKLIK_GECMISI.md` at that historical point; it was removed from the current tree on 15 November 2026, and its last committed version remains linked in this file's introduction.
- Corrected migration instructions for the required `hashedPassword` file and the VM XML fallback source; updated the related regression test, and guarded against the old undeclared IOMMU path variable recurring. Retracted the false OVMF template mismatch claim, marked old commit hashes as historical, and removed stale guidance to refresh the pinned CachyOS lock for routine installs. The input ZIP did not encode the executable bit for `install.sh`; this follow-up fix bundle restores Unix mode `100755`.
- Corrected the installer and documentation to distinguish the VFIO hook source under `/etc/nixos/nixos/hosts/nixos/hooks` from the active NixOS-generated libvirt hook, which is refreshed only by a successful rebuild/activation. Clarified that the installer writes but does not automatically define the VM XML, and that timestamped installer backups are not pruned automatically. Translated the remaining Turkish installer risk/compatibility prompts into English and updated their regression assertions; corrected the README's Nix formatting command to format each `.nix` file explicitly.
- Made the password-hash checklist preserve existing valid hashes, aligned the Turkish install guide's root-password command with the post-install stage, and translated the last Turkish comment in active Nix code. The repair bundle encodes `install.sh` as executable in the ZIP itself.
- Hardened the VM XML regression test to require exactly two distinct PCI hostdev addresses matching the QEMU hook, and clarified hook recovery logging when GPU display and GPU audio driver restoration differ.
- Corrected disk-size units in `KURULUM.md` and `README.md` (the `sgdisk` `G` suffix means GiB), added whole-disk, mounted-volume, and minimum-capacity checks before the destructive partition-table wipe, and narrowed the documented GPU target to RX 6700 XT/Navi 22. The fix-only patch ZIP stores `install.sh` with Unix mode `100755`; the originally uploaded full-project ZIP did not preserve that mode.
- Corrected the README Hyprland mouse-wheel entry to describe workspace cycling, matching `nixos/hosts/nixos/home.nix`; corrected the repository tree caption for the historical archive and documented the preserved Turkish changelog as an explicit language-policy exception. Updated the current changelog and current-state index dates to 2026-10-21.

### Validation
- Bash syntax checks passed for the installer, QEMU hook, and VFIO regression test.
- Python compilation checks passed for the scripts.
- VM XML invariants test passed.
- VFIO driver-state and service-state regression tests passed.
- Installer partial-deployment rollback regression test passed.
- The project owner reports a successful NixOS rebuild, local RT-Bore-LTO ThinLTO kernel build, Windows VM startup and normal shutdown, and return to the Hyprland host session on the target machine. This is owner-reported hardware validation and was not independently reproduced in the review container; it does not guarantee compatibility on other hardware. The review environment lacked Nix, ShellCheck, and libvirt/QEMU tools, so independent flake evaluation/build, ShellCheck, and semantic VM validation were not performed here. The checked-in `flake.lock` of that review pinned the CachyOS `master` input at `02ba4db52e62e1fbece80402d369127ae77cbbeb` (the tracked CachyOS input is the `release` branch as of 19 November 2026); newer upstream revisions still require an intentional input update. RT-Bore-LTO ThinLTO is not published in the upstream binary cache and therefore requires a local build.


## Historical releases

The detailed Turkish release entries were formerly retained below a dated status preface in `docs/archive/DEGISIKLIK_GECMISI.md`; that archive was removed from the current tree on 15 November 2026, and its last committed version remains available through the Git-history link in the introduction. This English changelog intentionally avoids restating historical claims as if they were re-tested against the current tree; use the root `DEGISIKLIK_GECMISI.md` as a current-state index.
