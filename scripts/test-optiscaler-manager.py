#!/usr/bin/env python3
"""Offline regression tests for scripts/optiscaler_manager.py."""

from concurrent.futures import ThreadPoolExecutor
from contextlib import nullcontext
import argparse
import hashlib
import json
import os
from pathlib import Path
import threading
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
        conflicting_api = {
            **asset,
            "digest": "sha256:" + ("0" * 64),
        }
        with self.assertRaisesRegex(manager.ManagerError, "conflicts with the repository-pinned"):
            manager.expected_digest("v0.9.4", conflicting_api)

    def test_xdg_paths_must_be_non_empty_and_absolute(self):
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            with patch.object(manager.Path, "home", return_value=home):
                with patch.dict(
                    os.environ,
                    {"XDG_CACHE_HOME": "", "XDG_STATE_HOME": "relative/state"},
                ):
                    self.assertEqual(
                        manager.cache_root(),
                        home / ".cache" / "optiscaler-manager",
                    )
                    self.assertEqual(
                        manager.state_root(),
                        home / ".local/state" / "optiscaler-manager",
                    )

                cache_override = home / "custom-cache"
                state_override = home / "custom-state"
                with patch.dict(
                    os.environ,
                    {
                        "XDG_CACHE_HOME": str(cache_override),
                        "XDG_STATE_HOME": str(state_override),
                    },
                ):
                    self.assertEqual(
                        manager.cache_root(),
                        cache_override / "optiscaler-manager",
                    )
                    self.assertEqual(
                        manager.state_root(),
                        state_override / "optiscaler-manager",
                    )

    def test_confirmation_reports_closed_stdin_as_manager_error(self):
        with patch("builtins.input", side_effect=EOFError):
            with self.assertRaisesRegex(manager.ManagerError, "stdin reached EOF"):
                manager.read_confirmation("confirm: ")

    def test_status_reports_rollback_only_when_transaction_backup_exists(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            game = root / "game"
            game.mkdir()
            (game / "game.exe").write_text("exe", encoding="utf-8")
            state_file = root / "state.json"
            state = {
                "schema": 1,
                "game_dir": str(game),
                "version": "v1",
                "asset": "OptiScaler.7z",
                "proxy": "dxgi.dll",
                "files": {},
                "originals": {},
                "rollback_available": True,
            }
            state_file.write_text(json.dumps(state), encoding="utf-8")
            backups = root / "backups"
            args = argparse.Namespace(game_dir=str(game))
            with patch.object(manager, "select_game_dir", return_value=game), \
                 patch.object(manager, "game_state_file", return_value=state_file), \
                 patch.object(manager, "backup_root", return_value=backups), \
                 patch.object(manager, "game_operation_lock", return_value=nullcontext()):
                with patch("builtins.print") as printed:
                    manager.command_status(args)
                output = " ".join(" ".join(str(x) for x in call.args) for call in printed.call_args_list)
                self.assertIn("Rollback available: no", output)
                self.assertIn("transaction backup is missing", output)

                rollback = backups / "rollback"
                rollback.mkdir(parents=True)
                (rollback / "transaction.json").write_text("{}", encoding="utf-8")
                with patch("builtins.print") as printed:
                    manager.command_status(args)
                output = " ".join(" ".join(str(x) for x in call.args) for call in printed.call_args_list)
                self.assertIn("Rollback available: yes", output)

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


    def test_concurrent_release_downloads_use_distinct_temporary_files(self):
        content = b"verified OptiScaler archive"
        digest = hashlib.sha256(content).hexdigest()
        barrier = threading.Barrier(2)

        class BlockingResponse:
            def __init__(self):
                self.first_read = True

            def __enter__(self):
                return self

            def __exit__(self, *_args):
                return False

            def read(self, _size=-1):
                if self.first_read:
                    self.first_read = False
                    barrier.wait(timeout=10)
                    return content
                return b""

        with tempfile.TemporaryDirectory() as temporary:
            cache = Path(temporary) / "cache"
            asset = {
                "name": "Optiscaler_1.0.0.7z",
                "digest": f"sha256:{digest}",
                "size": len(content),
                "browser_download_url": "https://github.com/example/OptiScaler.7z",
            }
            with (
                patch.object(manager, "cache_root", return_value=cache),
                patch.object(manager, "stable_release", return_value=({"tag_name": "v1.0.0"}, asset)),
                patch.object(manager, "urlopen", side_effect=lambda *_args, **_kwargs: BlockingResponse()),
            ):
                with ThreadPoolExecutor(max_workers=2) as executor:
                    futures = [executor.submit(manager.download_release) for _ in range(2)]
                    results = [future.result(timeout=15) for future in futures]

            archive = cache / "v1.0.0" / asset["name"]
            self.assertEqual(results[0], results[1])
            self.assertEqual(archive.read_bytes(), content)
            self.assertEqual(list(archive.parent.glob("*.part")), [])
            self.assertEqual([path.name for path in archive.parent.iterdir()], [asset["name"]])

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

    def test_first_install_rollback_restores_original_and_cleans_backups(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            game = root / "Game"
            game.mkdir()
            (game / "game.exe").write_text("exe", encoding="utf-8")
            (game / "dxgi.dll").write_text("pre-existing-proxy", encoding="utf-8")
            payload = self.make_payload(root / "payload", "1")
            with patch.object(manager, "state_root", lambda: root / "state"):
                manager.apply_payload(game, payload, "v0.9.4", "asset.7z", "dxgi.dll", True)
                state_file = manager.game_state_file(game)
                backups = manager.backup_root(game)
                self.assertTrue(state_file.exists())
                self.assertTrue(backups.exists())

                manager.restore_transaction(game, backups / "rollback", state_file)
                self.assertFalse(state_file.exists())
                self.assertFalse(backups.exists())
                self.assertEqual((game / "dxgi.dll").read_text(), "pre-existing-proxy")
                self.assertFalse((game / "OptiScaler.ini").exists())

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


    def test_update_restores_original_when_new_payload_drops_file(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            game = root / "Game"
            game.mkdir()
            (game / "game.exe").write_text("exe", encoding="utf-8")
            original_path = game / "OptiScaler" / "upscaler.bin"
            original_path.parent.mkdir()
            original_path.write_text("original-upscaler", encoding="utf-8")

            first = self.make_payload(root / "first", "1")
            second = self.make_payload(root / "second", "2")
            second.pop("OptiScaler/upscaler.bin")
            second.pop("OptiScaler.ini")

            with patch.object(manager, "state_root", lambda: root / "state"):
                manager.apply_payload(
                    game, first, "v0.9.4", "first.7z", "dxgi.dll", True
                )
                self.assertEqual(original_path.read_text(), "upscaler-1")

                manager.apply_payload(
                    game, second, "v1.0.0", "second.7z", "dxgi.dll", False
                )
                updated = manager.load_state(manager.game_state_file(game))
                self.assertEqual(original_path.read_text(), "original-upscaler")
                self.assertFalse((game / "OptiScaler.ini").exists())
                self.assertNotIn("OptiScaler/upscaler.bin", updated["files"])
                self.assertNotIn("OptiScaler/upscaler.bin", updated["originals"])
                self.assertEqual((game / "dxgi.dll").read_text(), "proxy-2")

                # The one-step rollback must still recover the previous managed
                # payload and its original-file mapping; a later remove must then
                # restore the pre-manager game file.
                manager.restore_transaction(
                    game, manager.backup_root(game) / "rollback",
                    manager.game_state_file(game),
                )
                restored = manager.load_state(manager.game_state_file(game))
                self.assertEqual(restored["version"], "v0.9.4")
                self.assertEqual(
                    (game / "OptiScaler" / "upscaler.bin").read_text(),
                    "upscaler-1",
                )
                manager.remove_installation(game)
                self.assertEqual(original_path.read_text(), "original-upscaler")
                self.assertFalse((game / "dxgi.dll").exists())

    def test_missing_obsolete_original_backup_aborts_before_update_mutation(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            game = root / "Game"
            game.mkdir()
            (game / "game.exe").write_text("exe", encoding="utf-8")
            original_path = game / "OptiScaler" / "upscaler.bin"
            original_path.parent.mkdir()
            original_path.write_text("original-upscaler", encoding="utf-8")

            first = self.make_payload(root / "first", "1")
            second = self.make_payload(root / "second", "2")
            second.pop("OptiScaler/upscaler.bin")
            with patch.object(manager, "state_root", lambda: root / "state"):
                manager.apply_payload(
                    game, first, "v0.9.4", "first.7z", "dxgi.dll", True
                )
                state_file = manager.game_state_file(game)
                rollback_dir = manager.backup_root(game) / "rollback"
                previous_state = state_file.read_text(encoding="utf-8")
                previous_dll = (game / "dxgi.dll").read_text(encoding="utf-8")
                backup = manager.backup_root(game) / "originals" / "OptiScaler" / "upscaler.bin"
                backup.unlink()

                with self.assertRaisesRegex(
                    manager.ManagerError, "Original-file backup is unavailable"
                ):
                    manager.apply_payload(
                        game, second, "v1.0.0", "second.7z", "dxgi.dll", False
                    )

                self.assertEqual(state_file.read_text(encoding="utf-8"), previous_state)
                self.assertEqual(manager.load_state(state_file)["version"], "v0.9.4")
                self.assertEqual((game / "dxgi.dll").read_text(), previous_dll)
                self.assertEqual(
                    (game / "OptiScaler" / "upscaler.bin").read_text(),
                    "upscaler-1",
                )
                self.assertTrue(rollback_dir.is_dir())
                self.assertTrue((rollback_dir / "transaction.json").is_file())


    def test_missing_rollback_backup_is_refused_before_targets_are_changed(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            game = root / "Game"
            game.mkdir()
            (game / "game.exe").write_text("exe", encoding="utf-8")
            with patch.object(manager, "state_root", lambda: root / "state"):
                first = self.make_payload(root / "first", "1")
                second = self.make_payload(root / "second", "2")
                manager.apply_payload(game, first, "v1", "first.7z", "dxgi.dll", False)
                manager.apply_payload(game, second, "v2", "second.7z", "dxgi.dll", False)
                state_file = manager.game_state_file(game)
                rollback_dir = manager.backup_root(game) / "rollback"
                (rollback_dir / "files" / "dxgi.dll").unlink()

                with self.assertRaisesRegex(manager.ManagerError, "Rollback backup is unavailable"):
                    manager.restore_transaction(game, rollback_dir, state_file)

                self.assertEqual((game / "dxgi.dll").read_text(), "proxy-2")
                self.assertEqual((game / "OptiScaler.ini").read_text(), "config-2")
                self.assertEqual(manager.load_state(state_file)["version"], "v2")

    def test_missing_original_backup_is_refused_before_removal_mutates_game(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            game = root / "Game"
            game.mkdir()
            (game / "game.exe").write_text("exe", encoding="utf-8")
            (game / "dxgi.dll").write_text("pre-existing-proxy", encoding="utf-8")
            payload = self.make_payload(root / "payload", "1")
            with patch.object(manager, "state_root", lambda: root / "state"):
                manager.apply_payload(game, payload, "v1", "asset.7z", "dxgi.dll", True)
                state_file = manager.game_state_file(game)
                (manager.backup_root(game) / "originals" / "dxgi.dll").unlink()

                with self.assertRaisesRegex(manager.ManagerError, "Original-file backup is unavailable"):
                    manager.remove_installation(game)

                self.assertEqual((game / "dxgi.dll").read_text(), "proxy-1")
                self.assertEqual((game / "OptiScaler.ini").read_text(), "config-1")
                self.assertTrue(state_file.is_file())

    def test_original_backup_failure_preserves_previous_rollback_and_game(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            game = root / "Game"
            game.mkdir()
            (game / "game.exe").write_text("exe", encoding="utf-8")
            (game / "dxgi.dll").write_text("original-proxy", encoding="utf-8")
            (game / "custom.dll").write_text("original-custom", encoding="utf-8")
            with patch.object(manager, "state_root", lambda: root / "state"):
                first = self.make_payload(root / "first", "1")
                manager.apply_payload(game, first, "v1", "first.7z", "dxgi.dll", True)
                state_file = manager.game_state_file(game)
                rollback_dir = manager.backup_root(game) / "rollback"
                previous_rollback = (rollback_dir / "files" / "dxgi.dll").read_text()

                second = self.make_payload(root / "second", "2")
                custom_payload = root / "second" / "custom.dll"
                custom_payload.write_text("managed-custom", encoding="utf-8")
                second["custom.dll"] = custom_payload
                original_copy_atomic = manager.copy_atomic

                def fail_original_backup(source, destination):
                    if source == game / "custom.dll":
                        raise OSError("simulated original-file backup failure")
                    return original_copy_atomic(source, destination)

                with patch.object(manager, "copy_atomic", side_effect=fail_original_backup):
                    with self.assertRaisesRegex(
                        manager.ManagerError, "Could not preserve original game-file backup"
                    ):
                        manager.apply_payload(
                            game, second, "v2", "second.7z", "dxgi.dll", True
                        )

                current = manager.load_state(state_file)
                self.assertEqual(current["version"], "v1")
                self.assertTrue(current["rollback_available"])
                self.assertEqual((game / "dxgi.dll").read_text(), "proxy-1")
                self.assertEqual((game / "OptiScaler.ini").read_text(), "config-1")
                self.assertEqual((game / "custom.dll").read_text(), "original-custom")
                self.assertTrue(rollback_dir.is_dir())
                self.assertEqual(
                    (rollback_dir / "files" / "dxgi.dll").read_text(),
                    previous_rollback,
                )

    def test_per_game_operation_lock_rejects_concurrent_access_and_releases(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            game = root / "Game"
            other_game = root / "OtherGame"
            game.mkdir()
            other_game.mkdir()
            with patch.object(manager, "state_root", lambda: root / "state"):
                lock_path = (
                    root / "state" / "locks" /
                    f"{manager.game_identity(game)}.lock"
                )
                with manager.game_operation_lock(game):
                    self.assertTrue(lock_path.is_file())
                    self.assertEqual(lock_path.stat().st_mode & 0o777, 0o600)
                    with self.assertRaisesRegex(
                        manager.ManagerError, "already running for"
                    ):
                        with manager.game_operation_lock(game):
                            self.fail("a concurrent operation unexpectedly acquired the same game lock")
                    # Locks are per-game: an unrelated game can still be managed.
                    with manager.game_operation_lock(other_game):
                        pass
                # The lock is released when the command exits its context.
                with manager.game_operation_lock(game):
                    pass

    def test_state_write_failure_rolls_back_the_payload_and_original_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            game = root / "Game"
            game.mkdir()
            (game / "game.exe").write_text("exe", encoding="utf-8")
            (game / "dxgi.dll").write_text("pre-existing-proxy", encoding="utf-8")
            payload = self.make_payload(root / "payload", "1")
            with patch.object(manager, "state_root", lambda: root / "state"):
                state_file = manager.game_state_file(game)
                original_atomic_json = manager.atomic_json

                def fail_install_state(path, value):
                    if path == state_file:
                        raise OSError("simulated final state-file write failure")
                    original_atomic_json(path, value)

                with patch.object(manager, "atomic_json", side_effect=fail_install_state):
                    with self.assertRaisesRegex(OSError, "simulated final state-file write failure"):
                        manager.apply_payload(game, payload, "v1", "asset.7z", "dxgi.dll", True)

                self.assertEqual((game / "dxgi.dll").read_text(), "pre-existing-proxy")
                self.assertFalse((game / "OptiScaler.ini").exists())
                self.assertFalse(state_file.exists())
                self.assertFalse(manager.backup_root(game).exists())

    def test_remove_io_failure_restores_the_pre_remove_game_state(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            game = root / "Game"
            game.mkdir()
            (game / "game.exe").write_text("exe", encoding="utf-8")
            (game / "dxgi.dll").write_text("original-dxgi", encoding="utf-8")
            (game / "OptiScaler.ini").write_text("original-ini", encoding="utf-8")
            payload = self.make_payload(root / "payload", "1")
            with patch.object(manager, "state_root", lambda: root / "state"):
                manager.apply_payload(game, payload, "v1", "asset.7z", "dxgi.dll", True)
                state_file = manager.game_state_file(game)
                original_copy_atomic = manager.copy_atomic

                def fail_second_original(source, destination):
                    if source.name == "OptiScaler.ini" and "originals" in source.parts:
                        raise OSError("simulated restore-copy failure")
                    return original_copy_atomic(source, destination)

                with patch.object(manager, "copy_atomic", side_effect=fail_second_original):
                    with self.assertRaisesRegex(OSError, "simulated restore-copy failure"):
                        manager.remove_installation(game)

                self.assertEqual((game / "dxgi.dll").read_text(), "proxy-1")
                self.assertEqual((game / "OptiScaler.ini").read_text(), "config-1")
                self.assertTrue(state_file.is_file())

    def test_rollback_copy_failure_restores_current_install(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            game = root / "Game"
            game.mkdir()
            (game / "game.exe").write_text("exe", encoding="utf-8")
            with patch.object(manager, "state_root", lambda: root / "state"):
                first = self.make_payload(root / "first", "1")
                second = self.make_payload(root / "second", "2")
                manager.apply_payload(game, first, "v1", "first.7z", "dxgi.dll", False)
                manager.apply_payload(game, second, "v2", "second.7z", "dxgi.dll", False)
                state_file = manager.game_state_file(game)
                rollback_dir = manager.backup_root(game) / "rollback"
                original_copy_atomic = manager.copy_atomic
                calls = 0

                def fail_second_rollback_copy(source, destination):
                    nonlocal calls
                    if ".rollback-recovery-" not in str(source):
                        calls += 1
                        if calls == 2:
                            raise OSError("simulated second rollback copy failure")
                    return original_copy_atomic(source, destination)

                with patch.object(manager, "copy_atomic", side_effect=fail_second_rollback_copy):
                    with self.assertRaisesRegex(OSError, "second rollback copy failure"):
                        manager.restore_transaction(game, rollback_dir, state_file)

                self.assertEqual((game / "dxgi.dll").read_text(), "proxy-2")
                self.assertEqual((game / "OptiScaler.ini").read_text(), "config-2")
                self.assertEqual(manager.load_state(state_file)["version"], "v2")
                self.assertTrue(rollback_dir.is_dir())
                self.assertFalse(list(rollback_dir.parent.glob(".rollback-recovery-*")))

    def test_rollback_state_write_failure_restores_current_install(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            game = root / "Game"
            game.mkdir()
            (game / "game.exe").write_text("exe", encoding="utf-8")
            with patch.object(manager, "state_root", lambda: root / "state"):
                first = self.make_payload(root / "first", "1")
                second = self.make_payload(root / "second", "2")
                manager.apply_payload(game, first, "v1", "first.7z", "dxgi.dll", False)
                manager.apply_payload(game, second, "v2", "second.7z", "dxgi.dll", False)
                state_file = manager.game_state_file(game)
                rollback_dir = manager.backup_root(game) / "rollback"
                original_atomic_json = manager.atomic_json

                def fail_rollback_state(path, value):
                    if path == state_file:
                        raise OSError("simulated rollback state-file write failure")
                    return original_atomic_json(path, value)

                with patch.object(manager, "atomic_json", side_effect=fail_rollback_state):
                    with self.assertRaisesRegex(OSError, "rollback state-file write failure"):
                        manager.restore_transaction(game, rollback_dir, state_file)

                self.assertEqual((game / "dxgi.dll").read_text(), "proxy-2")
                self.assertEqual((game / "OptiScaler.ini").read_text(), "config-2")
                self.assertEqual(manager.load_state(state_file)["version"], "v2")
                self.assertTrue(rollback_dir.is_dir())

    def test_rollback_recovery_failure_keeps_manual_snapshot(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            game = root / "Game"
            game.mkdir()
            (game / "game.exe").write_text("exe", encoding="utf-8")
            with patch.object(manager, "state_root", lambda: root / "state"):
                first = self.make_payload(root / "first", "1")
                second = self.make_payload(root / "second", "2")
                manager.apply_payload(game, first, "v1", "first.7z", "dxgi.dll", False)
                manager.apply_payload(game, second, "v2", "second.7z", "dxgi.dll", False)
                state_file = manager.game_state_file(game)
                rollback_dir = manager.backup_root(game) / "rollback"
                original_copy_atomic = manager.copy_atomic
                calls = 0

                def fail_rollback_and_recovery(source, destination):
                    nonlocal calls
                    if ".rollback-recovery-" in str(source):
                        if source.name == "dxgi.dll":
                            raise OSError("simulated recovery snapshot copy failure")
                    else:
                        calls += 1
                        if calls == 2:
                            raise OSError("simulated rollback application failure")
                    return original_copy_atomic(source, destination)

                with patch.object(manager, "copy_atomic", side_effect=fail_rollback_and_recovery):
                    with self.assertRaisesRegex(manager.ManagerError, "Preserve the recovery snapshot") as caught:
                        manager.restore_transaction(game, rollback_dir, state_file)

                snapshots = list(rollback_dir.parent.glob(".rollback-recovery-*"))
                self.assertEqual(len(snapshots), 1)
                self.assertTrue((snapshots[0] / "files" / "dxgi.dll").is_file())
                self.assertTrue((snapshots[0] / "files" / "OptiScaler.ini").is_file())
                self.assertIn(str(snapshots[0]), str(caught.exception))
                self.assertTrue(rollback_dir.is_dir())

    def test_remove_recovery_failure_keeps_manual_snapshot(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            game = root / "Game"
            game.mkdir()
            (game / "game.exe").write_text("exe", encoding="utf-8")
            (game / "dxgi.dll").write_text("original-dxgi", encoding="utf-8")
            (game / "OptiScaler.ini").write_text("original-ini", encoding="utf-8")
            payload = self.make_payload(root / "payload", "1")
            with patch.object(manager, "state_root", lambda: root / "state"):
                manager.apply_payload(game, payload, "v1", "asset.7z", "dxgi.dll", True)
                state_file = manager.game_state_file(game)
                recovery_root = manager.backup_root(game)
                original_copy_atomic = manager.copy_atomic

                def fail_remove_and_recovery(source, destination):
                    source_text = str(source)
                    if ".remove-transaction-" in source_text and source.name == "OptiScaler.ini":
                        raise OSError("simulated removal snapshot restore failure")
                    if "originals" in source.parts and source.name == "OptiScaler.ini":
                        raise OSError("simulated original-file restore failure")
                    return original_copy_atomic(source, destination)

                with patch.object(manager, "copy_atomic", side_effect=fail_remove_and_recovery):
                    with self.assertRaisesRegex(manager.ManagerError, "Preserve the recovery snapshot") as caught:
                        manager.remove_installation(game)

                snapshots = list(recovery_root.glob(".remove-transaction-*"))
                self.assertEqual(len(snapshots), 1)
                self.assertTrue((snapshots[0] / "files" / "dxgi.dll").is_file())
                self.assertTrue((snapshots[0] / "files" / "OptiScaler.ini").is_file())
                self.assertIn(str(snapshots[0]), str(caught.exception))
                self.assertTrue(state_file.is_file())

    def test_load_state_rejects_non_object_json_roots(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "state.json"
            for encoded in ("[]", "null", "1", "true", '"not-an-object"'):
                with self.subTest(json_root=encoded):
                    path.write_text(encoded, encoding="utf-8")
                    with self.assertRaisesRegex(manager.ManagerError, "JSON object"):
                        manager.load_state(path)

    def test_load_state_validates_nested_schema_paths_hashes_and_flags(self):
        valid = {"schema": 1, "game_dir": "/games/example", "version": "v1", "asset": "OptiScaler.7z",
                 "proxy": "dxgi.dll", "files": {"dxgi.dll": "a" * 64},
                 "originals": {"dxgi.dll": "originals/dxgi.dll"}, "rollback_available": True}
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "state.json"
            path.write_text(json.dumps(valid), encoding="utf-8")
            self.assertEqual(manager.load_state(path), valid)
            uppercase = dict(valid)
            uppercase["files"] = {"dxgi.dll": "A" * 64}
            path.write_text(json.dumps(uppercase), encoding="utf-8")
            self.assertEqual(
                manager.load_state(path)["files"]["dxgi.dll"],
                "a" * 64,
            )
            invalid_documents = []
            for field, value in (("files", []), ("proxy", "steam_api64.dll"), ("rollback_available", "yes"), ("schema", True)):
                bad = dict(valid)
                bad[field] = value
                invalid_documents.append((field, bad))
            bad = dict(valid)
            bad["files"] = {"../outside.dll": "a" * 64}
            invalid_documents.append(("unsafe managed path", bad))
            bad = dict(valid)
            bad["files"] = {"dxgi.dll": "not-a-sha256"}
            invalid_documents.append(("invalid digest", bad))
            bad = dict(valid)
            bad["originals"] = {"dxgi.dll": "../outside.dll"}
            invalid_documents.append(("unsafe backup mapping", bad))
            for label, document in invalid_documents:
                with self.subTest(document=label):
                    path.write_text(json.dumps(document), encoding="utf-8")
                    with self.assertRaises(manager.ManagerError):
                        manager.load_state(path)

    def test_archive_links_and_special_files_are_rejected_before_extraction(self):
        with tempfile.TemporaryDirectory() as temporary:
            archive = Path(temporary) / "release.7z"
            archive.write_bytes(b"archive")
            entries = (("symbolic-link mode", "Attributes = A_ lrwxrwxrwx"),
                       ("hard-link metadata", "Hard Link = target.dll"),
                       ("special-file mode", "Attributes = A_ prwxr-xr-x"),
                       ("reparse point", "Reparse Point = target"))
            for label, metadata in entries:
                listing = (f"Path = {archive}\nType = 7z\n----------\n"
                           f"Path = payload/{label.replace(' ', '_')}.dll\nSize = 1\n{metadata}\n")
                completed = type("Completed", (), {"returncode": 0, "stdout": listing, "stderr": ""})()
                with self.subTest(member_type=label), \
                     patch.object(manager, "find_7z", return_value="7z"), \
                     patch.object(manager.subprocess, "run", return_value=completed) as run, \
                     patch.object(manager.tempfile, "TemporaryDirectory") as temp_directory:
                    with self.assertRaisesRegex(manager.ManagerError, "refusing extraction"):
                        manager.extract_payload(archive, "dxgi.dll")
                    run.assert_called_once()
                    temp_directory.assert_not_called()
    def test_archive_without_complete_size_metadata_is_refused_before_extraction(self):
        with tempfile.TemporaryDirectory() as temporary:
            archive = Path(temporary) / "release.7z"
            archive.write_bytes(b"archive")
            listing = (
                f"Path = {archive}\nType = 7z\n----------\n"
                "Path = payload.dll\nPacked Size = 1\n"
            )
            completed = type("Completed", (), {"returncode": 0, "stdout": listing, "stderr": ""})()
            with patch.object(manager, "find_7z", return_value="7z"), \
                 patch.object(manager.subprocess, "run", return_value=completed), \
                 patch.object(manager.tempfile, "TemporaryDirectory") as temporary_directory:
                with self.assertRaisesRegex(manager.ManagerError, "omitted or duplicated uncompressed member sizes"):
                    manager.extract_payload(archive, "dxgi.dll")
                temporary_directory.assert_not_called()

    def test_archive_size_limit_is_checked_before_extraction(self):
        with tempfile.TemporaryDirectory() as temporary:
            archive = Path(temporary) / "release.7z"
            archive.write_bytes(b"archive")
            listing = (
                f"Path = {archive}\nType = 7z\n----------\n"
                "Path = payload.dll\nSize = 4294967297\nPacked Size = 1\n"
            )
            completed = type("Completed", (), {"returncode": 0, "stdout": listing, "stderr": ""})()
            with patch.object(manager, "find_7z", return_value="7z"), \
                 patch.object(manager.subprocess, "run", return_value=completed), \
                 patch.object(manager.tempfile, "TemporaryDirectory") as temporary_directory:
                with self.assertRaisesRegex(manager.ManagerError, "4 GiB extracted-size safety limit"):
                    manager.extract_payload(archive, "dxgi.dll")
                temporary_directory.assert_not_called()

    def test_game_directory_must_contain_an_executable(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            with self.assertRaises(manager.ManagerError):
                manager.select_game_dir(str(folder))
            (folder / "game.EXE").write_text("exe", encoding="utf-8")
            self.assertEqual(manager.select_game_dir(str(folder)), folder.resolve())


if __name__ == "__main__":
    unittest.main(verbosity=2)
