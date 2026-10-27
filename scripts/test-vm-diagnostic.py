#!/usr/bin/env python3
"""Regression tests for the temporary VM diagnostic XML helper."""
from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "scripts" / "prepare-vm-diagnostic.py"
VALID_XML = '''<?xml version="1.0" encoding="UTF-8"?>
<domain type="kvm">
  <name>win10</name>
  <devices>
    <video>
      <model type="none"/>
    </video>
  </devices>
</domain>
'''
DUPLICATE_VIDEO_XML = '''<domain type="kvm"><name>win10</name><devices>
  <video><model type="none"/></video>
  <video><model type="none"/></video>
</devices></domain>
'''
MULTIPLE_MIXED_VIDEO_XML = '''<domain type="kvm"><name>win10</name><devices>
  <video><model type="none"/></video>
  <video><model type="virtio"/></video>
</devices></domain>
'''
GRAPHICS_XML = '''<domain type="kvm"><name>win10</name><devices>
  <graphics type="vnc" listen="127.0.0.1"/>
  <video><model type="none"/></video>
</devices></domain>
'''


def run_helper(source: Path, output: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(HELPER), "--input", str(source), "--output", str(output)],
        text=True,
        capture_output=True,
        check=False,
    )


def write_source(directory: Path, content: str, name: str = "source.xml") -> Path:
    path = directory / name
    path.write_text(content, encoding="utf-8")
    return path


def assert_rejected(directory: Path, content: str, output_name: str, expected: str) -> None:
    source = write_source(directory, content, f"{output_name}.input.xml")
    output = directory / f"{output_name}.output.xml"
    result = run_helper(source, output)
    if result.returncode == 0:
        raise AssertionError(f"invalid input was accepted: {output_name}")
    combined = result.stdout + result.stderr
    if expected not in combined:
        raise AssertionError(
            f"{output_name}: expected diagnostic {expected!r}; got {combined!r}"
        )
    if output.exists():
        raise AssertionError(f"{output_name}: rejected input unexpectedly created output XML")


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="test-vm-diagnostic-") as temporary:
        directory = Path(temporary)

        source = write_source(directory, VALID_XML)
        original = source.read_text(encoding="utf-8")
        output = directory / "diagnostic.xml"
        result = run_helper(source, output)
        if result.returncode != 0:
            raise AssertionError(f"valid input was rejected: {result.stdout}{result.stderr}")
        if not output.is_file():
            raise AssertionError("valid input did not produce the diagnostic XML")
        if source.read_text(encoding="utf-8") != original:
            raise AssertionError("helper modified the production input XML")
        if os.stat(output).st_mode & 0o777 != 0o600:
            raise AssertionError("diagnostic XML must be created with mode 0600")

        # A dangling output symlink must be rejected without creating its referent.
        dangling_link = directory / "dangling-output.xml"
        dangling_target = directory / "must-not-be-created.xml"
        dangling_link.symlink_to(dangling_target.name)
        dangling_result = run_helper(source, dangling_link)
        if dangling_result.returncode == 0:
            raise AssertionError("helper accepted a dangling output symlink")
        if "symbolic link" not in dangling_result.stderr:
            raise AssertionError(
                f"dangling output symlink was rejected for the wrong reason: {dangling_result.stderr!r}"
            )
        if not dangling_link.is_symlink():
            raise AssertionError("helper removed or replaced the user-provided output symlink")
        if dangling_target.exists():
            raise AssertionError("helper unexpectedly created the dangling symlink referent")

        root = ET.parse(output).getroot()
        graphics = root.findall("./devices/graphics")
        videos = root.findall("./devices/video")
        if len(graphics) != 1:
            raise AssertionError(f"expected one diagnostic graphics device, found {len(graphics)}")
        listen = graphics[0].find("listen")
        if graphics[0].get("type") != "vnc" or listen is None or listen.get("address") != "127.0.0.1":
            raise AssertionError("diagnostic VNC must listen on loopback only")
        if len(videos) != 1 or videos[0].find("model") is None or videos[0].find("model").get("type") != "virtio":
            raise AssertionError("diagnostic XML must contain exactly one virtio video model")

        assert_rejected(
            directory,
            DUPLICATE_VIDEO_XML,
            "duplicate-video",
            "expected exactly one <devices><video> block, found 2",
        )
        assert_rejected(
            directory,
            MULTIPLE_MIXED_VIDEO_XML,
            "mixed-video",
            "expected exactly one <devices><video> block, found 2",
        )
        assert_rejected(
            directory,
            GRAPHICS_XML,
            "existing-graphics",
            "input already has a graphics device",
        )
        assert_rejected(
            directory,
            "<domain><devices><video>",
            "malformed",
            "input XML is not well-formed",
        )
        assert_rejected(
            directory,
            '<not-domain type="kvm"><name>win10</name><devices><video><model type="none"/></video></devices></not-domain>',
            "wrong-root",
            "input XML root must be <domain>",
        )

    print("OK: VM diagnostic helper preserves production XML, rejects invalid XML/video layouts and output symlinks, and creates loopback-only VNC output.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
