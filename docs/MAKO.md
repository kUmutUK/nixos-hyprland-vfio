# MAKO Renderer on NixOS

This repository pins the official **MAKO Renderer v4.6.0** Linux archive as an optional Home Manager package. It uses the desktop Renderer archive, not the separate MAKO Decky ZIP or the automatically generated source archive.

- Upstream project: https://github.com/eugeniosegala/MAKO
- Pinned release: https://github.com/eugeniosegala/MAKO/releases/tag/render-v4.6.0
- Archive: `MAKO-Renderer-v4.6.0-linux.tar.xz`
- SHA-256: `66224414e2d94f7cb019226735b3b6d26b9be7103c5334250522f7260213be56`

The Nix derivation verifies the release archive through its fixed-output hash, retains the upstream 64-bit and 32-bit Vulkan layers and their manifests, and patches only the host-side binaries in `bin/`. The Vulkan renderer libraries are left in the upstream package layout so Steam/Proton can load them in the game runtime. The Nix package deliberately omits the upstream user-local installer and uninstaller; Home Manager owns the installed files.

## What it provides

MAKO Renderer is a Vulkan layer and renderer with:

- Fixed and Adaptive LSFG frame generation.
- LS1 spatial scaling and the open MAKO Scaler.
- Bundled shader effects and optional vkBasalt post-processing.
- Per-game profiles and a host configuration UI.
- Both 64-bit and 32-bit x86 game-process layers.

The open MAKO Scaler and bundled shaders do not require Lossless Scaling. MAKO Frame Generation and LS1 scaling require a separate, user-owned installation of the default public Lossless Scaling version through Steam. MAKO does not distribute or modify `Lossless.dll` or proprietary model resources. Check the upstream documentation and the terms for your own copy.

The release targets x86_64 Linux. That describes the package architecture, not a guarantee that every GPU/API/game combination works. The repository's RX 6700 XT (Navi 22 / RADV) has not been independently runtime-qualified with MAKO by this integration. Validate each selected game and compare frametimes, latency, and image quality.

## Install and launch

The package is added to the existing Home Manager `home.packages` list. After deploying the repository's updated NixOS files and successfully rebuilding the system, open **MAKO Renderer Configuration** from the application menu or run:

```bash
mako-ui
```

Create a profile and match the game's actual process/executable name, not its Steam display title. To enable MAKO for one native Steam or Proton game, add this to that game's **Properties → General → Launch Options**:

```text
mako-launch %command%
```

Keep `%command%` exactly as written. This is per-game opt-in; installing the package or opening the UI does not activate MAKO globally. If Steam cannot resolve the command from its inherited `PATH`, use the full path printed by `command -v mako-launch`.

Do not run the upstream graphical installer from the package: Nix/Home Manager owns this installation. Do not install a second copy into `~/.local` alongside the Nix package.

## Interaction with LSFG-VK, OptiScaler, and latency layers

- Keep existing LSFG-VK v2 profiles and the OptiScaler manager unchanged. This integration does not edit Steam launch options or inject MAKO into games automatically.
- Use only one frame-generation provider for a game. Do not stack MAKO Frame Generation with LSFG-VK Frame Generation or OptiScaler Frame Generation. MAKO's launcher has guards for competing LSFG-VK layer entries, but that is not a reason to run multiple frame-generation paths.
- MAKO's launcher uses a private Vulkan implicit-layer path for its application layer chain. Consequently, do not assume the repository's globally registered `low_latency_layer` will be available inside a game launched through `mako-launch`. The global `LOW_LATENCY_LAYER=1` NixOS setting is not changed by this package; verify the layers actually loaded by the selected game before drawing conclusions about latency.
- Gamescope remains outside MAKO's application-layer chain according to the upstream launcher documentation. Test any specific Gamescope/overlay combination independently.
- The repository's CS2 launch command, global latency-layer default, LSFG-VK configuration, and existing OptiScaler per-game files are not modified.

The host archive does not prepare Flatpak runtimes. Flatpak games need the matching MAKO Flatpak extension and the upstream Flatpak setup procedure; `mako-launch` alone is not a substitute.

## Update and validation

Update the version, release URL, and SRI hash together in `nixos/mako-renderer.nix`. Obtain the SHA-256 from the official GitHub release metadata and do not accept an unverified repack. The normal CI checks the package integration and builds `.#mako-renderer`; a full NixOS system build is still required after this Home Manager/NixOS source change.

A successful package build proves that the pinned archive can be unpacked and packaged. It does not prove that MAKO works with every Proton title or that frame pacing, VRR, latency, or the RX 6700 XT runtime path has been hardware-tested.

## Upstream documentation

- [MAKO Renderer README and desktop installation guide](https://github.com/eugeniosegala/MAKO/blob/render-v4.6.0/engine/README.md)
- [Official installation and usage details](https://github.com/eugeniosegala/MAKO/blob/render-v4.6.0/engine/dist/MAKO-Renderer-README.txt)
- [Flatpak setup guide](https://github.com/eugeniosegala/MAKO/blob/render-v4.6.0/engine/docs/FLATPAK-GUIDE.md)
- [Third-party notices](https://github.com/eugeniosegala/MAKO/blob/render-v4.6.0/THIRD_PARTY_NOTICES.md)
