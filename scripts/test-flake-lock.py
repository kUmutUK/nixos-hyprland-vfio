#!/usr/bin/env python3
"""Validate that the committed flake lock graph contains the Serpantinum inputs.

This catches the exact regression from CI logs: a declared flake input that is
missing from root.inputs makes `nix build --no-update-lock-file` fail before
module evaluation. No network access or Nix installation is required.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FLAKE_PATH = ROOT / "nixos" / "flake.nix"
LOCK_PATH = ROOT / "nixos" / "flake.lock"
WORKFLOW_PATH = ROOT / ".github" / "workflows" / "check.yml"
SERPANTINUM_REV = "e0c1d79375bc7adfd01fecb8a4e319d521df1ea9"
WALLPAPER_REV = "4f5994aff60403f88d3f0378e6f9c9d0a00b0289"
WALLPAPER_NAR_HASH = "sha256-L3xRtDXH1ERwVIP+ztT6qn7YYh3aHpfpy1/nvyjvKIc="


def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def main() -> None:
    flake_text = FLAKE_PATH.read_text(encoding="utf-8")
    workflow_text = WORKFLOW_PATH.read_text(encoding="utf-8")
    try:
        lock = json.loads(LOCK_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"cannot read a valid nixos/flake.lock: {exc}")

    nodes = lock.get("nodes")
    require(isinstance(nodes, dict), "flake.lock nodes must be a JSON object")
    root_name = lock.get("root")
    require(root_name in nodes, "flake.lock root must refer to a node")
    root = nodes[root_name]
    root_inputs = root.get("inputs", {})

    # The declaration must be wired to both NixOS and Home Manager modules.
    require(
        re.search(r'(?m)^\s*serpantinum\.url\s*=\s*"github:ilyamiro/serpantinum/e0c1d79375bc7adfd01fecb8a4e319d521df1ea9"\s*;', flake_text)
        is not None,
        "flake.nix must declare the upstream Serpantinum input pinned to the reviewed immutable commit",
    )
    require(
        re.search(r'(?m)^\s*serpantinum\.inputs\.nixpkgs\.follows\s*=\s*"nixpkgs"\s*;', flake_text)
        is not None,
        "Serpantinum must follow the project's nixpkgs input to avoid a second package set",
    )
    require(root_inputs.get("serpantinum") == "serpantinum",
            "root.inputs.serpantinum is missing or points at the wrong lock node")

    shell = nodes.get("serpantinum")
    require(isinstance(shell, dict), "Serpantinum lock node is missing")
    locked = shell.get("locked", {})
    original = shell.get("original", {})
    require(locked.get("type") == "github", "Serpantinum must remain a GitHub source")
    require(locked.get("owner") == "ilyamiro" and locked.get("repo") == "serpantinum",
            "Serpantinum locked source must be ilyamiro/serpantinum")
    require(locked.get("rev") == SERPANTINUM_REV,
            "Serpantinum revision changed; update the expected pin intentionally after review")
    require(original.get("type") == "github" and original.get("owner") == "ilyamiro"
            and original.get("repo") == "serpantinum"
            and original.get("rev") == SERPANTINUM_REV,
            "Serpantinum original source must match the explicit immutable revision in flake.nix")
    # Pinning by full Git commit fixes source identity. Nix derives the source
    # narHash from this immutable source in the lock-bootstrap CI step; it is not
    # guessed or hard-coded into this test.
    require(re.fullmatch(r"[0-9a-f]{40}", locked.get("rev", "")) is not None,
            "Serpantinum must be pinned to a full immutable commit hash")

    shell_inputs = shell.get("inputs", {})
    require(shell_inputs.get("nixpkgs") == ["nixpkgs"],
            "Serpantinum must follow the root nixpkgs lock node")
    require(shell_inputs.get("serpantinum-wallpapers") == "serpantinum-wallpapers",
            "Serpantinum wallpaper transitive input is missing from its lock node")

    wallpapers = nodes.get("serpantinum-wallpapers")
    require(isinstance(wallpapers, dict), "Serpantinum wallpaper lock node is missing")
    require(wallpapers.get("flake") is False,
            "serpantinum-wallpapers must be locked as a non-flake source")
    wp_locked = wallpapers.get("locked", {})
    wp_original = wallpapers.get("original", {})
    require(wp_locked.get("type") == "github" and wp_locked.get("owner") == "ilyamiro"
            and wp_locked.get("repo") == "shell-wallpapers",
            "wallpaper source must be ilyamiro/shell-wallpapers")
    require(wp_locked.get("rev") == WALLPAPER_REV,
            "wallpaper source revision changed; review the update before changing this test")
    require(wp_locked.get("narHash") == WALLPAPER_NAR_HASH,
            "wallpaper content hash does not match the verified pinned source")
    require(wp_original.get("type") == "github" and wp_original.get("owner") == "ilyamiro"
            and wp_original.get("repo") == "shell-wallpapers",
            "wallpaper original source must match the upstream flake declaration")

    # The source archive cannot invent Nix's source-derived narHash. CI must
    # resolve metadata for the immutable pin before invoking --no-update-lock-file
    # builds, and the later drift guard must permit only those two derived fields.
    require(
        "Complete lock metadata for immutable inputs" in workflow_text
        and "nix flake lock" in workflow_text,
        "CI must complete source-derived lock metadata before read-only Nix builds",
    )
    require(
        workflow_text.index("Complete lock metadata for immutable inputs")
        < workflow_text.index("ShellCheck of the Nix-generated VFIO hook"),
        "CI must resolve the lock before building the generated VFIO hook",
    )
    require(
        "Unexpected flake.lock drift beyond calculated Serpantinum metadata." in workflow_text,
        "CI must retain the flake.lock drift guard after lock metadata generation",
    )

    # Check that every lock graph edge refers to a node that is actually present.
    for node_name, node in nodes.items():
        for input_name, edge in node.get("inputs", {}).items():
            if isinstance(edge, str):
                require(edge in nodes,
                        f"lock node {node_name!r} input {input_name!r} references missing node {edge!r}")
            elif isinstance(edge, list):
                require(bool(edge),
                        f"lock node {node_name!r} input {input_name!r} has an empty follows path")
                require(all(isinstance(part, str) and part for part in edge),
                        f"lock node {node_name!r} input {input_name!r} has an invalid follows path")
            else:
                fail(f"lock node {node_name!r} input {input_name!r} has invalid edge {edge!r}")

    print("PASS: flake.lock contains the pinned Serpantinum node and wallpaper dependency.")
    print("PASS: Serpantinum follows the root nixpkgs node and all lock graph edges resolve.")
    print("PASS: CI resolves pinned-source metadata before read-only Nix builds and guards other lock drift.")


if __name__ == "__main__":
    main()
