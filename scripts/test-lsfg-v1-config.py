#!/usr/bin/env python3
"""Validate the LSFG-VK v1 configuration embedded in Home Manager."""
from __future__ import annotations

import re
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HOME_CONFIG = ROOT / "nixos" / "home.nix"


def main() -> int:
    source = HOME_CONFIG.read_text(encoding="utf-8")
    match = re.search(
        r"    \"lsfg-vk/conf\.toml\"\.text = ''\n(.*?)\n    '';",
        source,
        re.DOTALL,
    )
    if match is None:
        raise SystemExit("FAIL: could not find the lsfg-vk/conf.toml Home Manager source block")

    try:
        config = tomllib.loads(match.group(1))
    except tomllib.TOMLDecodeError as exc:
        raise SystemExit(f"FAIL: embedded LSFG-VK TOML is invalid: {exc}") from exc

    if config.get("version") != 1:
        raise SystemExit("FAIL: this configuration intentionally targets LSFG-VK schema version 1")

    games = config.get("game")
    if not isinstance(games, list):
        raise SystemExit("FAIL: expected one or more [[game]] records")

    profiles = {game.get("exe"): game for game in games}
    aliases = ("Client-Win64-Shipping.exe", "Client-Win64-Shipping")
    missing = [alias for alias in aliases if alias not in profiles]
    if missing:
        raise SystemExit(f"FAIL: WuWa LSFG profile is missing common Proton/Wine aliases: {missing}")

    def selected_settings(profile: dict[str, object]) -> dict[str, object]:
        return {key: value for key, value in profile.items() if key != "exe"}

    if selected_settings(profiles[aliases[0]]) != selected_settings(profiles[aliases[1]]):
        raise SystemExit("FAIL: WuWa process aliases must use identical LSFG settings")

    settings = selected_settings(profiles[aliases[0]])
    if settings.get("multiplier") != 2 or settings.get("flow_scale") != 0.9:
        raise SystemExit("FAIL: WuWa LSFG profile values changed unexpectedly")

    if "wuwa" in profiles:
        raise SystemExit("FAIL: generic exe='wuwa' does not match the common game process names")

    print("OK: LSFG-VK v1 TOML is valid and WuWa common process aliases share the intended profile.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
