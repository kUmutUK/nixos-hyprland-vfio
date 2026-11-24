# Gaming guide

How the host-side gaming stack in this repository is wired, and which knobs
are per-game. This guide documents the behavior introduced and pinned by the
2026-11-24 feature waves; the README keeps provenance and validation records,
and INSTALLATION.md keeps the machine setup steps.

## NTSync (kernel-side game synchronization)

`boot.kernelModules` loads the mainline `ntsync` driver and a udev rule grants
the `users` group 0660 access to `/dev/ntsync`. Proton 10+ and recent Wine
builds detect the device automatically and move the Windows synchronization
primitives (the `WaitForSingleObject` family) into the kernel, which reduces
spin-wait latency and improves frame-time consistency. Older Proton versions
silently keep the userspace implementation; nothing breaks when the module is
absent, so NTSync is an optimization, not a dependency.

- Diagnostics: `WINEDEBUG=+ntsync` in a game's launch options logs whether the
  ntsync path is used; `modinfo ntsync` checks module availability on the
  running kernel.
- Per-game opt-out for a game that misbehaves with ntsync: set
  `PROTON_NO_NTSYNC=1 %command%` in the game's Steam launch options.
- VFIO: ntsync owns no PCI device; the Windows VM's GPU handoff is unaffected.

## GE Proton (declarative, per game)

`programs.steam.extraCompatPackages = [ pkgs.proton-ge-bin ]` installs the
nixpkgs GE Proton binary package (GE-Proton11-12 at the currently locked
nixpkgs revision) as a Steam compatibility tool. Select it per game: Steam →
game Properties → Compatibility → force the use of a specific Steam Play
compatibility tool → GE-Proton. Valve's Proton remains the global default, and
`protonup-qt` remains available for ad-hoc, unpinned installs outside the
flake. GE updates arrive with the flake lock: the weekly `nup` (flake update)
plus a rebuild upgrades GE Proton together with everything else.

## Gamescope Steam session (console experience)

`programs.steam.gamescopeSession` adds one additional entry to the greetd
session list; the default login remains Hyprland, and the desktop layer
(Waybar, mpvpaper, Pyprland) is untouched. Log out and pick the Gamescope +
Steam session for a console-style session: Gamescope is the only compositor,
games get direct fullscreen page flips at 2560x1440 with immediate flips and a
grabbed cursor, and MangoHud/GameMode still apply through launch options.
The CS2 `gamescope -f -w 1440 -h 1440 -W 2560 -H 1440 -S stretch ...` launch
line is unnecessary inside this session — Gamescope already is the session;
use `gamemoderun mangohud %command%` there instead.

## GameMode and the power profile

GameMode raises scheduling priority (`renice = 10`), I/O priority, and the AMD
GPU performance level while a game runs, and switches the
power-profiles-daemon profile to `performance` on game start and back to
`balanced` on exit (GameMode `custom.start`/`custom.end`). The switch is
best-effort: if it fails, `gamemoded` logs an error and the game runs anyway.
The mpvpaper watchdog — not GameMode — remains the single authority for the
live-wallpaper service.

## AMD GPU Waybar telemetry

The `custom/amdgpu` Waybar module reads the kernel's AMDGPU sysfs interface
without changing power, clocks, fan policy, or performance state. It reports
GPU busy percentage, VRAM used/total, Edge and Junction temperatures when
exposed, the current graphics clock, average/instantaneous power, and fan RPM.
The optional sensor fields are shown as unavailable when the driver does not
export them. The module refreshes every two seconds; clicking it opens the
AMD-enabled `nvtop` TUI in Kitty.

The reader selects the first AMD DRM card exposed under
`/sys/class/drm/card*/device`. On a single-GPU VFIO host, the module reports
telemetry as unavailable when no AMD DRM card is present (for example while
the GPU is bound to `vfio-pci`). It does not write to sysfs. The underlying
interfaces are documented in the
[Linux kernel AMDGPU monitoring documentation](https://www.kernel.org/doc/html/latest/gpu/amdgpu/thermal.html).

## Shader cache sizing

`MESA_SHADER_CACHE_MAX_SIZE=12G` (system-wide environment) keeps large games
from evicting compiled shaders from Mesa's on-disk cache; eviction would force
recompiles and startup stutter on later launches. The cache is per-user under
`~/.cache` and can reach 12 GiB; DXVK/Proton keep their separate caches inside
game prefixes.

## VM backup and health checks

`scripts/backup-vm.sh` creates a compressed, SHA-256-reported copy of the
Windows guest's qcow2 disk while the VM is shut off; see the script header for
the fail-closed guards. Back up to a mounted external disk, not to the media
partition that stores the live image. Snapper snapshots protect the host
Btrfs system only — the Windows disk has no other backup path.

`scripts/vfio-health.sh` is the read-only counterpart for between VM runs: it
reports the resolved IOMMU groups and the current driver behind both GPU PCI
functions, scans the vfio hook log for ERROR/CRITICAL lines since the last VM
release record, and runs a read-only `qemu-img check` over the Windows disk.
It exits non-zero when a check flags an anomaly (a function with no driver
bound, a missing IOMMU group, hook errors after the last release, or a
corrupt disk image) and never writes anywhere. Run it any time, including
while the VM runs — vfio-pci on both functions is reported as the healthy
in-VM state, not an anomaly.

## Host file share and the Windows 11 template

Both VM templates mount the host directory `/mnt/media/win-share` in the guest
as a read-only virtiofs share (`host-share`). This is the fast path for game
installers, save files, and ISO handoffs: no 9p/SMB overhead, and the
validator enforces the `<readonly/>` element so the guest can never write host
files. Windows needs the virtio-fs driver from the VirtIO driver ISO once;
after that the share appears as a read-only drive.

`vm-xml/win11.xml` exists for the post-ESU Windows migration: the same
GPU-passthrough topology with the MS-keys Secure Boot OVMF firmware, SMM, and
swtpm TPM 2.0 (already enabled host-side). Nothing about the win10 gaming VM
changes; the win11 template is a separate domain with its own disk and
identity, defined only when you choose to migrate. Keep the Windows guest on
the virtio `vda` disk with the VirtIO drivers for the lowest gaming latency in
either guest.
