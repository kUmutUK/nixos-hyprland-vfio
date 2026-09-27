# 📜 Changelog

All notable changes to this project will be documented here.

This project follows:
- Keep a Changelog
- Semantic Versioning

---

# [1.1.2] - 2026-09-27

## 🐛 Fixed

- **`home.nix` xdg.configFile paths broke `install.sh` installs.** The two
  hypr scripts (`wuwa-auto.sh`, `auto-translate.sh`) were deployed via a
  path relative to the repo root (`../.config/hypr/scripts/...`). This
  only resolves correctly when `home.nix` is evaluated from inside a full
  repo checkout. `install.sh` copies `home.nix` alone into `/etc/nixos/`
  without the `.config/` directory, so on an installer-based setup the
  relative path pointed at a file that doesn't exist and `nixos-rebuild`
  would fail evaluation. Fixed by inlining both scripts' contents directly
  in `home.nix` (no external file dependency at all now).
- **`install.sh` didn't apply the user's GPU PCI address to the actual
  hook.** The installer asks for `GPU PCI` / `GPU Audio` addresses and
  patches `configuration.nix`'s `gpuPCI`/`gpuAudio` — but those two
  variables aren't read by anything; the real VFIO behavior comes from
  `GPU_PCI`/`GPU_AUDIO` hardcoded in `hooks/qemu`. On any machine whose GPU
  isn't at `0000:0b:00.0`/`.1`, the installer silently produced a broken
  VFIO setup despite asking for and appearing to accept the correct
  addresses. `install.sh` now also sed-patches the copied `hooks/qemu`.
- **`hooks/qemu` `prepare`: no failure detection or rollback.** If
  `bind_vfio` silently failed (errors were swallowed), the script still
  logged "GPU vfio-pci'ye bağlandı" and returned success — after already
  stopping greetd and unbinding the VT/EFI framebuffer. The VM could then
  fail to start with the host left headless and no automatic recovery.
  Added `device_bound_to_vfio()` verification; on failure the hook now
  rolls back (restores the host driver, VT console, EFI framebuffer,
  greetd) and exits non-zero so libvirt aborts the domain start instead of
  proceeding with a half-configured system.
- **`hooks/qemu` `release`: recovery check only verified the GPU, not
  audio.** After the `suspend_rescan_recovery` fallback, only `$GPU_PCI`
  was re-checked for a real driver. If the recovery fixed the GPU function
  but left the audio function driverless, the hook had no way to know and
  logged nothing. Now both functions are verified independently.

---



## 🐛 Fixed

- **Removed stale duplicate `etc/libvirt/hooks/qemu`.** The repo carried two
  divergent copies of the qemu hook script. The one actually deployed by
  `configuration.nix` (`nixos/hooks/qemu`) was already fixed, but the
  leftover root-level copy still had the old bugs: it tried to bind the
  GPU's audio function to the `amdgpu` driver (silently failing and leaving
  audio driverless after every VM session), and had no `TARGET_VM` filter,
  so *any* libvirt VM would blank the host display. Deleted to avoid anyone
  copying the wrong file.
- **`wuwa-auto.sh` keybind (`SUPER+Y`) was a no-op.** The script existed
  under `.config/hypr/scripts/` but was never deployed to
  `~/.config/hypr/scripts/` by home-manager, so the keybind referenced a
  file that didn't exist. Now deployed via `xdg.configFile` and marked
  executable.
- **`auto-translate.sh` was dead code** — present in the repo but wired to
  no keybind and never deployed. Now deployed the same way and bound to
  `SUPER+ALT+T`.
- Removed dead static `.config/hypr/hyprland.conf`, `hyprlock.conf`,
  `hypridle.conf`, `waybar/config.jsonc`, `waybar/style.css`, and
  `gtk/gtk.css` — these were fully superseded by the strings/options
  home-manager already generates from `home.nix` and could mislead someone
  into editing a file that has no effect.
- `nixos/hooks/qemu`: the GPU reset step now verifies (via `setpci`) whether
  the device actually responds after the reset attempt and logs a warning
  if not, instead of silently continuing regardless of outcome. Added
  `pciutils` to `environment.systemPackages` so `setpci` is available to
  the hook.
- `nixos/hooks/qemu`: on `release`, if the quiet unbind/rebind doesn't
  restore a real driver to the GPU (checked via `device_has_real_driver`),
  the hook now falls back to a community-reported `remove` + `rtcwake`
  suspend + PCI `rescan` recovery sequence before giving up and logging
  that a host reboot may be needed.
- `nixos/hooks/qemu`: `stop_hyprland()` no longer hardcodes `/dev/dri/card0`
  when checking whether the GPU is still in use. It now resolves the DRM
  card node from `$GPU_PCI` via sysfs (`gpu_drm_card()`), so the check
  stays correct even if card numbering changes (e.g. an iGPU is added, or
  the board enumerates devices in a different order).

## 📚 Documentation

- Added a "Known Limitations" section to the README documenting that the
  RX 6000 series (including the RX 6700 XT this repo is tested on) is not
  covered by `gnif/vendor-reset`'s supported device list, so the reset-bug
  mitigation in the qemu hook is best-effort only — no automated fix is
  claimed for this generation of GPU.

---

# [1.1.0] - 2026-05-19

## ✨ Added

### 🎮 Gaming
- low_latency_layer implementation
- RADV_ANTILAG support
- lsfg-vk integration
- NVIDIA spoofing layer

### 🧰 Development
- install.sh automation script
- shell.nix development shell
- improved validation workflow

### 📚 Documentation
- rewritten README
- expanded KURULUM.md
- improved CONTRIBUTING.md

---

## 🔄 Changed

- improved markdown structure
- fixed formatting issues
- synchronized repo layout
- clarified VFIO workflow

---

# [1.0.0] - 2026-05-12

## 🎉 Initial Release

### Core Features
- Hyprland Wayland setup
- VFIO single-GPU passthrough
- CachyOS BORE kernel integration
- PipeWire low-latency audio
- GameMode + MangoHud + Gamescope
- Ollama ROCm support
- Snapper snapshots
- AppArmor security
- Waydroid support
- Looking Glass integration
