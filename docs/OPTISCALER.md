# OptiScaler on NixOS with Steam/Proton

OptiScaler is an **optional, per-game Windows DLL proxy** that can redirect supported game upscaler/Frame Generation interfaces to alternatives such as FSR or XeSS. It is not a NixOS package, a Vulkan layer, or a replacement for LSFG-VK. The files belong beside the selected game's Windows executable and are loaded by Proton for that game only.

This guide targets the repository's AMD Radeon RX 6700 XT (Navi 22 / RDNA2), RADV, and Steam/Proton setup. The optional [OptiScaler Manager](OPTISCALER-MANAGER.md) can check/download/verify a stable release and install it into one explicitly selected game executable directory after interactive confirmation. It is never run by NixOS or Home Manager, and it does not add a global DLL override or change system configuration. Manual installation steps remain below.

## Pinned upstream release

The guide is based on the official stable **OptiScaler v0.9.4**, published on 18 July 2026:

- Release: https://github.com/optiscaler/OptiScaler/releases/tag/v0.9.4
- Official manual installation: https://github.com/optiscaler/OptiScaler/wiki/Manual-Installation
- General installation warning: https://github.com/optiscaler/OptiScaler/wiki/Installation

The official release asset is:

```text
Optiscaler_0.9.4-final.20260718._MM.7z
SHA-256 575cb4df866116093df75af607e37fd70e10f5163e0f23fd5c804142e80ef0ad
```

Download only from the official GitHub release above. Verify the archive before extracting it:

```bash
sha256sum Optiscaler_0.9.4-final.20260718._MM.7z
```

Compare the output with the SHA-256 value shown above. Do not continue if it differs. Avoid unofficial repacks and untrusted third-party installers/managers; the upstream project explicitly warns about impersonation sites and unofficial managers. **The OptiScaler Manager included in this repository is itself an independent, nonofficial third-party helper**: it is maintained here, is not developed by or affiliated with OptiScaler upstream, and is not endorsed by upstream. Use the manual procedure below when you prefer not to use a third-party manager. The helper's source, checksum policy, safeguards, and offline tests are documented in [OptiScaler Manager](OPTISCALER-MANAGER.md).

## Per-game installation

1. Check the upstream [General Compatibility List](https://github.com/optiscaler/OptiScaler/wiki/General-Compatibility-List) and the [FSR4 Compatibility List](https://github.com/optiscaler/OptiScaler/wiki/FSR4-Compatibility-List) for that exact game and graphics API before changing files.
2. Extract the verified archive somewhere temporary.
3. Find the actual directory containing the game's main Windows executable. For Unreal Engine titles, this is commonly a game-specific `Binaries/Win64` directory; do not put the files in the generic `Engine` directory.
4. Back up any existing proxy files in that directory before copying anything. In particular, do not overwrite a pre-existing `dxgi.dll` from ReShade, Special K, another mod, or the game itself without first understanding how it is loaded.
5. Copy the OptiScaler release files into the selected executable directory. The v0.9+ release already bundles Fakenvapi and Nukem's DLSS-G-to-FSR3 component; do not download random replacement DLLs for those components.
6. Rename `OptiScaler.dll` to `dxgi.dll` for a game that can use the DXGI proxy route. Keep the configuration file named exactly `OptiScaler.ini`; do not rename it. The upstream lists other proxy names (`winmm.dll`, `d3d12.dll`, `dbghelp.dll`, `version.dll`, `wininet.dll`, and `winhttp.dll`) for game-specific compatibility cases. Use an alternate name only when the upstream compatibility notes for that game call for it.
7. In that game's Steam **Properties → General → Launch Options**, add:

```text
WINEDLLOVERRIDES="dxgi=n,b" %command%
```

Keep any existing launch options after the environment assignment; do not replace unrelated options. This override is per game, not a global Steam or NixOS environment setting.

If the game already uses a DXGI proxy, stop and resolve the conflict first. The upstream manual guide documents alternate supported proxy names and their matching Wine overrides; changing the filename without changing the corresponding override will not load OptiScaler.

## RX 6700 XT / RADV expectations

- The RX 6700 XT is **RDNA2**. OptiScaler v0.9.4's FSR 4.1.1 notes list RDNA4 (FP8) and RDNA3 desktop GPUs (INT8) as the officially supported classes. Unsupported GPUs fall back to OptiScaler's internal FSR3 upscaler. Therefore, do not treat FSR 4.1.1 as officially supported on this GPU and do not force `Fsr4ForceEnableInt8` as a supposed RDNA2 enablement switch.
- For this card, start with game-supported **FSR 3.1** or **XeSS** options and verify image quality and frame times in the target game. Availability still depends on the game's API, implementation, and OptiScaler's compatibility entry.
- OptiScaler's release notes say Linux FSR 4.1.1 needs recent Proton/VKD3D-Proton support. They also warn that the DX12-to-Vulkan FSR 4 path may have a substantial performance drop on RADV compared with AMDVLK. Treat that path as experimental, not as a recommended default for this RADV system.
- The v0.9.4 notes also describe FSR4-FG requirements such as Mesa 25.2+ and a Windows 11 Wine prefix. Those requirements do not turn RDNA2 into an officially supported FSR 4.1.1 GPU.

Do not copy FSR4 settings from RDNA3/RDNA4 guides to this RX 6700 XT. Check the game's compatibility notes and confirm the active upscaler in the OptiScaler overlay; the upstream release specifically warns that an unsupported FSR4.1.1 selection may silently be using the FSR3 fallback.

## Frame Generation and this repository's gaming stack

OptiScaler's game-level Frame Generation route, MAKO Frame Generation, and LSFG-VK are separate mechanisms. **Do not enable these Frame Generation methods simultaneously in the same game.** Choose exactly one provider, test it alone, and compare frame pacing rather than assuming that stacking them increases smoothness.

- Keep the repository's LSFG-VK v2 package and per-game profiles unchanged.
- If testing OptiScaler Frame Generation in a particular game, disable both MAKO Frame Generation and that game's LSFG-VK profile before comparing results.
- The global `LOW_LATENCY_LAYER=1` and unset-by-default `LOW_LATENCY_LAYER_REFLEX` choices remain unchanged. Do not add Reflex or OptiScaler-specific variables globally for this optional tool.
- This guide does not alter the CS2 launch command or recommend injecting OptiScaler into CS2.

## Safety and rollback

The upstream OptiScaler installation guide warns not to use the mod with online games because it may trigger anti-cheat software and lead to bans. **Do not use OptiScaler in online or anti-cheat-protected games.** Keep testing to offline/single-player games where the game's publisher and mod policy permit it. No anti-cheat compatibility or account-safety guarantee is implied.

To remove it, close the game, remove only the OptiScaler files that you added to that game's executable directory, and restore any pre-installation files from your backup. Do not bulk-delete DLLs from the game folder: some similarly named files may belong to the game or other mods. Remove the `WINEDLLOVERRIDES` launch option from that game's Steam properties when OptiScaler has been removed.

## Verification in game

The upstream default overlay key is `Insert`; the performance overlay uses `Page Up` and cycles modes with `Page Down`. These can be changed in `OptiScaler.ini` or in the overlay. If the game crashes, remove the per-game launch override, restore the backed-up proxy files, and consult the game's compatibility entry before trying another proxy filename.

For logs, upstream recommends setting `LogToFile=true` in `OptiScaler.ini`, reproducing the issue, then reviewing the generated log. Keep logs limited to the affected game and avoid sharing unrelated personal paths or account information.

## Upstream references

- [OptiScaler v0.9.4 release and changelog](https://github.com/optiscaler/OptiScaler/releases/tag/v0.9.4)
- [Manual Installation](https://github.com/optiscaler/OptiScaler/wiki/Manual-Installation)
- [Automated Installation](https://github.com/optiscaler/OptiScaler/wiki/Automated-Installation)
- [Installation and anti-cheat warning](https://github.com/optiscaler/OptiScaler/wiki/Installation)
- [General Compatibility List](https://github.com/optiscaler/OptiScaler/wiki/General-Compatibility-List)
- [FSR4 Compatibility List](https://github.com/optiscaler/OptiScaler/wiki/FSR4-Compatibility-List)
