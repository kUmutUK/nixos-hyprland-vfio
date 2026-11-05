#!/usr/bin/env python3
"""Static integrity checks for the pinned MAKO Renderer package integration."""

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = (ROOT / "nixos/mako-renderer.nix").read_text(encoding="utf-8")
HOME = (ROOT / "nixos/home.nix").read_text(encoding="utf-8")
FLAKE = (ROOT / "nixos/flake.nix").read_text(encoding="utf-8")
README = (ROOT / "README.md").read_text(encoding="utf-8")
DOC = (ROOT / "docs/MAKO.md").read_text(encoding="utf-8")
CHANGELOG = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
INSTALLER = (ROOT / "install.sh").read_text(encoding="utf-8")
INSTALLER_TEST = (ROOT / "scripts/test-installer-invariants.sh").read_text(encoding="utf-8")
WORKFLOW = (ROOT / ".github/workflows/check.yml").read_text(encoding="utf-8")
CONTRIBUTING = (ROOT / "CONTRIBUTING.md").read_text(encoding="utf-8")

errors: list[str] = []


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


expected_archive = "MAKO-Renderer-v4.6.0-linux.tar.xz"
expected_hash = "sha256-ZiJEFOLZT3ywGSJnNbO20mub5xA8UzQlBSL3JgITvlY="
expected_sha256 = "66224414e2d94f7cb019226735b3b6d26b9be7103c5334250522f7260213be56"

require('version = "4.6.0";' in PACKAGE, "MAKO package version must remain pinned to the reviewed v4.6.0 release")
require(expected_archive in PACKAGE and "releases/download/render-v" in PACKAGE, "MAKO package must use the official Linux Renderer release asset, not Decky/source archives")
require(expected_hash in PACKAGE and expected_sha256 in DOC, "MAKO archive hash must match the documented official SHA-256")
require("dontAutoPatchelf = true;" in PACKAGE and 'autoPatchelf --no-recurse "$out/bin"' in PACKAGE,
        "MAKO packaging must patch host binaries only and preserve the Vulkan-layer library payloads")
require("lib32/libmako-render.so" in PACKAGE and "lib/libmako-render.so" in PACKAGE,
        "MAKO package install checks must require both 32-bit and 64-bit renderer libraries")
require("mako-launch" in PACKAGE and "mako-ui" in PACKAGE and "VkLayer_MAKO_render.json" in PACKAGE,
        "MAKO package must retain its launcher, configuration UI, and Vulkan manifest")
require("mako-installer" in PACKAGE and "uninstaller.desktop" in PACKAGE,
        "Nix must not expose a second mutable user-local installer/uninstaller")
require("license = licenses.gpl3Plus;" in PACKAGE and 'platforms = [ "x86_64-linux" ];' in PACKAGE,
        "MAKO package metadata must record GPL-3.0-or-later and the published x86_64 Linux platform")

require("makoRenderer = pkgs.callPackage ./mako-renderer.nix { };" in HOME,
        "Home Manager must instantiate the pinned MAKO package")
require("home.packages = with pkgs; [" in HOME and "    makoRenderer" in HOME,
        "MAKO must be available through the existing Home Manager package set")
require('makoRendererPackage = pkgs.callPackage ./mako-renderer.nix { };' in FLAKE
        and 'packages.${system} = {' in FLAKE
        and 'mako-renderer = makoRendererPackage;' in FLAKE,
        "flake must expose a direct build target for the MAKO package")

required_sources = "configuration.nix home.nix flake.nix flake.lock lsfg-vk-v2.nix mako-renderer.nix"
require(f"REQUIRED_NIXOS_SOURCE_FILES=({required_sources})" in INSTALLER
        and "REQUIRED_NIXOS_RUNTIME_FILES=(hooks/qemu)" in INSTALLER,
        "installer preflight must require the six Nix sources and separate QEMU runtime hook")
require('"$NIXOS_FLAKE_DIR/mako-renderer.nix"' in INSTALLER,
        "installer rollback/backup transaction must include the MAKO package expression")
require(f"REQUIRED_NIXOS_SOURCE_FILES=({required_sources})" in INSTALLER_TEST
        and "REQUIRED_NIXOS_RUNTIME_FILES=(hooks/qemu)" in INSTALLER_TEST,
        "installer regression harness must cover the six deployed Nix sources and QEMU runtime hook")

require("### MAKO Renderer for Proton games" in README and "docs/MAKO.md" in README,
        "README must describe and link the optional MAKO integration")
require("mako-launch %command%" in DOC and "mako-ui" in DOC,
        "MAKO guide must document the UI and per-game launch command")
require("## Recommended per-game baseline for this RX 6700 XT" in DOC,
        "MAKO guide must include a system-specific per-game profile baseline")
require(all(item in DOC for item in (
    "LOW_LATENCY_LAYER=1",
    "LOW_LATENCY_LAYER_REFLEX",
    "Counter-Strike 2",
    "Genshin Impact",
    "Wuthering Waves",
    "Target FPS",
    "Maximum Adaptive Multiplier",
    "Allow FP16",
    "GPU Headroom",
    "170 FPS",
    "not measured performance results",
)), "MAKO guide must document conservative AMD/170 Hz settings and distinguish them from hardware-tested results")
require("MAKO Frame Generation" in DOC and "LSFG-VK Frame Generation" in DOC and "OptiScaler Frame Generation" in DOC,
        "MAKO guide must keep the three frame-generation providers mutually exclusive")
require("Do not stack MAKO Frame Generation with LSFG-VK Frame Generation or OptiScaler Frame Generation" in DOC,
        "MAKO guide must prevent competing frame-generation paths")
require("LOW_LATENCY_LAYER=1" in DOC and "private Vulkan implicit-layer path" in DOC,
        "MAKO guide must explain the per-game global latency-layer interaction")
require("RX 6700 XT" in DOC and "not been independently runtime-qualified" in DOC,
        "MAKO guide must not claim unperformed RX 6700 XT runtime validation")
require("MAKO Renderer integration" in CHANGELOG,
        "Unreleased changelog must record the MAKO integration")

require("python3 scripts/test-mako-renderer.py" in WORKFLOW
        and "Build the pinned LSFG-VK v2 and MAKO packages" in WORKFLOW
        and ".#mako-renderer" in WORKFLOW,
        "normal CI must run MAKO integration checks and build the pinned package")
require("python3 scripts/test-mako-renderer.py" in CONTRIBUTING
        and ".#mako-renderer" in CONTRIBUTING,
        "contributor validation instructions must include the MAKO test and build")
require("mako-renderer.nix" in README and README.count("for file in configuration.nix home.nix flake.nix flake.lock lsfg-vk-v2.nix mako-renderer.nix; do") == 2,
        "README manual deployment loops must copy the new package expression")

if errors:
    for error in errors:
        print(f"FAIL: {error}", file=sys.stderr)
    raise SystemExit(1)

print("OK: pinned MAKO Renderer archive, package layout, Home Manager/flake wiring, installer transaction, docs, and CI contract are consistent.")
