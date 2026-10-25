#!/usr/bin/env python3
"""Regression checks for the LSFG-VK v2 package/configuration contract."""
from __future__ import annotations

import json
import re
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
flake = (ROOT / "nixos/flake.nix").read_text(encoding="utf-8")
lock = json.loads((ROOT / "nixos/flake.lock").read_text(encoding="utf-8"))
config = (ROOT / "nixos/configuration.nix").read_text(encoding="utf-8")
home = (ROOT / "nixos/home.nix").read_text(encoding="utf-8")
package_text = (ROOT / "nixos/lsfg-vk-v2.nix").read_text(encoding="utf-8")

# The legacy module is v1-only and must not silently return via the lock graph.
if "lsfg-vk-flake" in flake or "lsfg-vk-flake" in lock["nodes"]:
    raise SystemExit("FAIL: obsolete v1-only lsfg-vk-flake input remains.")
if "services.lsfg-vk" in config:
    raise SystemExit("FAIL: old LSFG-VK v1 module options remain active.")
if "lsfgVkV2 = pkgs.callPackage ./lsfg-vk-v2.nix" not in config:
    raise SystemExit("FAIL: NixOS config does not instantiate the pinned v2 package.")
manifest = '"${lsfgVkV2}/share/vulkan/implicit_layer.d/VkLayer_LSFGVK_frame_generation.json"'
if manifest not in config:
    raise SystemExit("FAIL: v2 implicit layer manifest is not registered under /etc/vulkan.")
packages_start = config.find("environment.systemPackages = with pkgs; [")
if packages_start < 0:
    raise SystemExit("FAIL: environment.systemPackages block was not found.")
packages_end = config.find("\n  ];", packages_start)
if packages_end < 0 or "lsfgVkV2" not in config[packages_start:packages_end]:
    raise SystemExit("FAIL: the v2 package is not in environment.systemPackages.")

# Source must remain immutable and upstream source must not be patched.
required = [
    'url = "https://git.lsfg-vk.dev/lsfg-vk.git";',
    'rev = "21fbd1bc4e94ebc076cc0a86f09e3107b83f0c96";',
    'hash = "sha256-YwCvbxdRhPz2daEIEMOciA/i4nhk/hY0Tj7l9t9oOWI=";',
    '"-DLSFGVK_BUILD_LAYER=ON"',
    '"-DLSFGVK_BUILD_UI=ON"',
    '"-DLSFGVK_BUILD_CLI=ON"',
    '"-DLSFGVK_MANAGED=ON"',
    "license = licenses.cc-by-nc-nd-40;",
]
for item in required:
    if item not in package_text:
        raise SystemExit(f"FAIL: LSFG-VK v2 package is missing required pin/build/license setting: {item}")
if re.search(r"(?m)^\s*(patches|prePatch|postPatch)\s*=|substituteInPlace", package_text):
    raise SystemExit("FAIL: upstream LSFG-VK source must not be patched under CC BY-NC-ND 4.0.")

# Parse the exact generated TOML fragment rather than just searching for keywords.
marker = "\"lsfg-vk/conf.toml\".text = ''\n"
if marker not in home:
    raise SystemExit("FAIL: Home Manager no longer defines the LSFG-VK TOML config as expected.")
start = home.index(marker) + len(marker)
end = home.find("\n    '';", start)
if end < 0:
    raise SystemExit("FAIL: could not find the end of the generated LSFG-VK TOML string.")
toml_text = home[start:end]
try:
    data = tomllib.loads(toml_text)
except tomllib.TOMLDecodeError as exc:
    raise SystemExit(f"FAIL: generated LSFG-VK conf.toml is invalid TOML: {exc}") from exc
if data.get("version") != 2:
    raise SystemExit("FAIL: generated LSFG-VK config must target schema version 2.")
profiles = {entry.get("name"): entry for entry in data.get("profile", [])}
expected = {"Genshin Impact", "Benchmark", "Counter-Strike 2", "vkcube", "Wuthering Waves"}
if set(profiles) != expected:
    raise SystemExit(f"FAIL: expected LSFG-VK profiles {sorted(expected)}, got {sorted(profiles)}.")
if not {"GenshinImpact.exe", "GenshinImpact"}.issubset(set(profiles["Genshin Impact"].get("active_in", []))):
    raise SystemExit("FAIL: Genshin profile must include its executable/process aliases.")
if not {"Client-Win64-Shipping.exe", "Client-Win64-Shipping"}.issubset(set(profiles["Wuthering Waves"].get("active_in", []))):
    raise SystemExit("FAIL: Wuthering Waves profile must include its executable/process aliases.")
if profiles["Counter-Strike 2"].get("active_in") != ["cs2", "cs2.exe"]:
    raise SystemExit("FAIL: the CS2 profile no longer has the reviewed Linux/Windows process aliases.")

print("OK: LSFG-VK package, pinned v2 source, Vulkan manifest, and generated TOML are consistent.")
