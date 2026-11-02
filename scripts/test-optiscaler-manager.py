#!/usr/bin/env python3
"""Offline regression tests for scripts/optiscaler_manager.py."""

import hashlib
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import optiscaler_manager as manager


class OptiScalerManagerTests(unittest.TestCase):
    def test_pinned_release_digest(self):
        asset = {
            "name": "Optiscaler_0.9.4-final.20260718._MM.7z",
            "digest": None,
        }
        self.assertEqual(
            manager.expected_digest("v0.9.4", asset),
            "575cb4df866116093df75af607e37fd70e10f5163e0f23fd5c804142e80ef0ad",
        )

    def test_unknown_release_fails_closed_without_digest(self):
        with self.assertRaises(manager.ManagerError):
            manager.expected_digest(
                "v0.9.5",
                {"name": "Optiscaler_0.9.5.7z", "digest": None},
            )

    def test_api_digest_is_accepted_and_override_must_match(self):
        digest = "a" * 64
        asset = {"name": "Optiscaler_1.0.0.7z", "digest": f"sha256:{digest}"}
        self.assertEqual(manager.expected_digest("v1.0.0", asset), digest)
        self.assertEqual(manager.expected_digest("v1.0.0", asset, digest), digest)
        with self.assertRaises(manager.ManagerError):
            manager.expected_digest("v1.0.0", asset, "b" * 64)

    def test_manual_digest_is_validated(self):
        digest = "c" * 64
        self.assertEqual(
            manager.expected_digest(
                "v1.0.0", {"name": "Optiscaler_1.0.0.7z", "digest": None}, digest
            ),
            digest,
        )
        with self.assertRaises(manager.ManagerError):
            manager.expected_digest(
                "v1.0.0", {"name": "Optiscaler_1.0.0.7z", "digest": None}, "not-a-hash"
            )

    def test_archive_paths_reject_traversal_and_absolute_paths(self):
        self.assertEqual(
            manager.validate_archive_member("./OptiScaler/OptiScaler.dll"),
            "OptiScaler/OptiScaler.dll",
        )
        for unsafe in ("../outside.dll", "folder/../../outside.dll", "/etc/passwd", r"C:\Windows\system.ini"):
            with self.subTest(path=unsafe), self.assertRaises(manager.ManagerError):
                manager.validate_archive_member(unsafe)

    def test_unsupported_proxy_is_not_in_allowlist(self):
        self.assertIn("dxgi.dll", manager.SUPPORTED_PROXIES)
        self.assertNotIn("steam_api64.dll", manager.SUPPORTED_PROXIES)

    def make_payload(self, root: Path, version: str):
        root.mkdir(parents=True, exist_ok=True)
        dll = root / "OptiScaler.dll"
        ini = root / "OptiScaler.ini"
        dll.write_text(f"proxy-{version}", encoding="utf-8")
        ini.write_text(f"config-{version}", encoding="utf-8")
        extra_dir = root / "OptiScaler"
        extra_dir.mkdir(exist_ok=True)
        (extra_dir / "upscaler.bin").write_text(f"upscaler-{version}", encoding="utf-8")
        return {
            "dxgi.dll": dll,
            "OptiScaler.ini": ini,
            "OptiScaler/upscaler.bin": extra_dir / "upscaler.bin",
        }

    def test_conflicts_are_refused_unless_explicitly_backed_up(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            game = root / "Game"
            game.mkdir()
            (game / "game.exe").write_text("exe", encoding="utf-8")
            (game / "dxgi.dll").write_text("reshade-proxy", encoding="utf-8")
            payload = self.make_payload(root / "payload", "1")
            with patch.object(manager, "state_root", lambda: root / "state"):
                with self.assertRaises(manager.ManagerError):
                    manager.apply_payload(game, payload, "v0.9.4", "asset.7z", "dxgi.dll", False)
                self.assertEqual((game / "dxgi.dll").read_text(), "reshade-proxy")

                manager.apply_payload(game, payload, "v0.9.4", "asset.7z", "dxgi.dll", True)
                self.assertEqual((game / "dxgi.dll").read_text(), "proxy-1")
                manager.remove_installation(game)
                self.assertEqual((game / "dxgi.dll").read_text(), "reshade-proxy")
                self.assertFalse((game / "OptiScaler.ini").exists())
                self.assertFalse((game / "OptiScaler" / "upscaler.bin").exists())

    def test_update_rollback_and_remove_restore_expected_states(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            game = root / "Game"
            game.mkdir()
            (game / "game.exe").write_text("exe", encoding="utf-8")
            with patch.object(manager, "state_root", lambda: root / "state"):
                first = self.make_payload(root / "first", "1")
                second = self.make_payload(root / "second", "2")
                manager.apply_payload(game, first, "v0.9.4", "first.7z", "dxgi.dll", False)
                self.assertEqual((game / "dxgi.dll").read_text(), "proxy-1")

                manager.apply_payload(game, second, "v1.0.0", "second.7z", "dxgi.dll", False)
                self.assertEqual((game / "dxgi.dll").read_text(), "proxy-2")

                state_file = manager.game_state_file(game)
                manager.restore_transaction(game, manager.backup_root(game) / "rollback", state_file)
                restored = manager.load_state(state_file)
                self.assertEqual(restored["version"], "v0.9.4")
                self.assertEqual((game / "dxgi.dll").read_text(), "proxy-1")
                self.assertEqual((game / "OptiScaler.ini").read_text(), "config-1")

                manager.remove_installation(game)
                self.assertFalse(state_file.exists())
                self.assertFalse((game / "dxgi.dll").exists())
                self.assertFalse((game / "OptiScaler.ini").exists())

    def test_game_directory_must_contain_an_executable(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            with self.assertRaises(manager.ManagerError):
                manager.select_game_dir(str(folder))
            (folder / "game.EXE").write_text("exe", encoding="utf-8")
            self.assertEqual(manager.select_game_dir(str(folder)), folder.resolve())


if __name__ == "__main__":
    unittest.main(verbosity=2)
