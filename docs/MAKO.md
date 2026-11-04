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

## Recommended per-game baseline for this RX 6700 XT

These are conservative starting values for the repository's RX 6700 XT (RDNA2), RADV, and 170 Hz display. They are **not measured performance results**: this integration has not been independently runtime-qualified on that GPU. Judge each game with its real FPS, frametimes, responsiveness, and image quality rather than output FPS alone.

MAKO profiles are saved by `mako-ui` in the user's configuration. The Nix package does not currently declare or overwrite those user profiles. Apply these values in the UI; do not copy guessed profile JSON into `home.nix`.

### System-wide policy

- Keep the current NixOS `LOW_LATENCY_LAYER=1` default and its AMD Anti-Lag interface. Leave `LOW_LATENCY_LAYER_REFLEX` unset globally; do not force Reflex on an AMD system.
- Keep frame generation opt-in per game. Installing MAKO or registering LSFG-VK's manifest must not mean that every game uses frame generation.
- MAKO uses a private Vulkan implicit-layer path. Do not assume the global `low_latency_layer` is loaded inside a game started through `mako-launch`; inspect the game's actually loaded layers before attributing latency behavior to it.

### Per-game starting choice

| Game / use | Preferred starting path | Initial choice |
| --- | --- | --- |
| Counter-Strike 2 | Native rendering | No MAKO, LSFG-VK, or OptiScaler Frame Generation. Keep the existing AMD low-latency default. |
| Genshin Impact | MAKO Adaptive, after per-game validation | Target 170 FPS; maximum adaptive multiplier 2x initially. Try a 3x ceiling only if the measured real FPS and image quality justify it. |
| Wuthering Waves | MAKO Adaptive, after per-game validation | Target 170 FPS; maximum adaptive multiplier 2x initially. Consider 3x only after comparing responsiveness and interpolation artifacts. |
| Other single-player games | MAKO Adaptive, game by game | Start at a 2x ceiling and change one setting at a time. Keep frame generation off when native performance is already preferable. |
| MAKO fallback | Existing LSFG-VK v2 profiles | Keep the current Genshin 3x and Wuthering Waves 2x profiles as alternatives; use LSFG-VK only when MAKO Frame Generation is not active for that game. |
| OptiScaler | Optional game-local upscaling / compatibility path | Use only for a compatible offline single-player title. It is not a global setting; do not combine its Frame Generation with MAKO or LSFG-VK Frame Generation. |

The 170 FPS value is an **Adaptive target**, not a promise that the game will output 170 FPS. At a 60 FPS real-frame rate, a 2x ceiling can produce about 120 output FPS; a 3x ceiling permits more generated frames but can increase latency or visible interpolation artifacts. Adaptive chooses within the selected ceiling; it is not the same as forcing a fixed multiplier.

### MAKO v4.6.0 profile values

For Genshin Impact and Wuthering Waves, use this as the first comparison profile:

| MAKO control | Starting value |
| --- | --- |
| Enable Frame-gen | On (Restart), then select Adaptive |
| Target FPS | 170 |
| Match Display Refresh Rate | Off unless the game is launched through Gamescope and MAKO is receiving valid Gamescope refresh feedback. Otherwise set Target FPS manually to 170. |
| Maximum Adaptive Multiplier | 2x initially; test 3x separately if required |
| Steady Base Cap | Off |
| Fractional Adaptive | Off initially |
| Real Frame Priority | Automatic |
| Base FPS Cap | Off initially |
| Smooth Cadence | Off initially; compare separately only if cadence needs work |
| Allow FP16 | On (Restart); keep the lighter model disabled for the first quality comparison |
| Lighter FG Model / Ultra Performance | Off |
| Flow Scale | 100% initially |
| GPU Headroom | Off initially. If supported AMD telemetry confirms sustained GPU saturation and unstable pacing, test a 10% reserve as a separate comparison. |
| MAKO Scaling / Shaders / HDR | Off for the first FG comparison; add them one at a time only when needed |

Use the exact executable detected by **Detect Running Game…** or saved under **Matched Processes**. For a basic profile, `mako-launch %command%` is the launch prefix; when the UI shows a complete profile-specific launch option (for example, with shaders), copy the full command shown by the UI. Compare V-Sync on/off and Fullscreen/Borderless per game; neither choice is universal.

### Choosing between MAKO, LSFG-VK, and OptiScaler

Use one Frame Generation provider per game. For an LSFG-VK comparison, remove the MAKO launch prefix and use the existing LSFG-VK profile; do not leave MAKO Frame Generation active. For an OptiScaler Frame Generation comparison, disable both MAKO Frame Generation and the matching LSFG-VK profile first. OptiScaler remains subject to the upstream anti-cheat warning and is not for online or anti-cheat-protected games.

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
