#!/usr/bin/env python3
"""Regression tests for the VM XML validator's selectable input paths."""
from __future__ import annotations

import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VALIDATOR = ROOT / "scripts" / "test-vm-xml.py"
TEMPLATE = ROOT / "vm-xml" / "win10.xml"
HOOK = ROOT / "nixos" / "hooks" / "qemu"
TIMEOUT_SECONDS = 10


def fail(message: str) -> int:
    print(f"FAIL: {message}", file=sys.stderr)
    return 1


def run_validator(xml_path: Path, hook_path: Path, *options: str) -> subprocess.CompletedProcess[str]:
    command = [
        sys.executable,
        str(VALIDATOR),
        "--xml-path",
        str(xml_path),
        "--hook-path",
        str(hook_path),
        *options,
    ]
    try:
        return subprocess.run(
            command,
            text=True,
            capture_output=True,
            check=False,
            timeout=TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired:
        return subprocess.CompletedProcess(command, 124, "", "validator timed out")


def main() -> int:
    template_xml = TEMPLATE.read_text(encoding="utf-8")
    hook_text = HOOK.read_text(encoding="utf-8")

    with tempfile.TemporaryDirectory(prefix="vm-xml-path-test-") as temp:
        temp_path = Path(temp)
        xml_path = temp_path / "deployed-win10.xml"
        hook_path = temp_path / "deployed-qemu-hook"
        shutil.copyfile(TEMPLATE, xml_path)
        shutil.copyfile(HOOK, hook_path)

        # The validator must read the supplied paths, not silently fall back to
        # the repository defaults.
        result = run_validator(xml_path, hook_path, "--allow-custom-usb-ids")
        if result.returncode != 0:
            return fail(f"custom paths were rejected: {result.stdout}{result.stderr}")

        # A deployed XML may intentionally use local USB IDs. Their structure and
        # numeric values remain checked, while the template's exact IDs are optional.
        custom_xml = (
            template_xml.replace('id="0x1532"', 'id="0x1234"', 1)
            .replace('id="0x0098"', 'id="0x5678"', 1)
            .replace('id="0x05AC"', 'id="0x4321"', 1)
            .replace('id="0x024F"', 'id="0x8765"', 1)
        )
        if custom_xml == template_xml:
            return fail("test fixture could not customize the template USB IDs")
        xml_path.write_text(custom_xml, encoding="utf-8")

        result = run_validator(xml_path, hook_path, "--allow-custom-usb-ids")
        if result.returncode != 0:
            return fail(f"custom numeric USB IDs were rejected in deployed mode: {result.stdout}{result.stderr}")

        result = run_validator(xml_path, hook_path)
        if result.returncode == 0 or "USB passthrough IDs" not in result.stderr:
            return fail("the default-template mode did not reject customized USB IDs")

        # A mismatched hook must fail even when both input paths point outside
        # the source tree.
        match = re.search(r'^GPU_PCI="([^"]+)"$', hook_text, re.MULTILINE)
        if match is None:
            return fail("could not find GPU_PCI in the test hook")
        mismatched_hook = hook_text[:match.start(1)] + "ffff:ff:1f.7" + hook_text[match.end(1):]
        hook_path.write_text(mismatched_hook, encoding="utf-8")
        result = run_validator(xml_path, hook_path, "--allow-custom-usb-ids")
        if result.returncode == 0 or "addresses must match" not in result.stderr:
            return fail("the validator did not reject a mismatched deployed hook")

    print("OK: VM XML validator honors supplied XML/hook paths, supports local USB IDs, and rejects PCI mismatches.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
