#!/usr/bin/env python3
"""Create a temporary loopback-only VNC/virtio display XML for first-boot diagnosis.

The production XML is never modified. Pass the deployed /var/lib/libvirt/win10.xml
as input so the diagnostic copy preserves that host's synchronized PCI addresses.
"""
from __future__ import annotations

import argparse
import os
import re
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

VIDEO_NONE = re.compile(
    r"(?P<indent>^[ \t]*)<video>\s*<model\s+type=\"none\"\s*/>\s*</video>",
    re.MULTILINE,
)

GRAPHICS = '''    <!-- TEMPORARY DIAGNOSTICS ONLY: VNC is loopback-only. Re-define the production XML after testing. -->
    <graphics type="vnc" port="-1" autoport="yes" listen="127.0.0.1">
      <listen type="address" address="127.0.0.1"/>
    </graphics>
    <video>
      <model type="virtio" heads="1" primary="no"/>
    </video>'''


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path, help="deployed production domain XML")
    parser.add_argument("--output", required=True, type=Path, help="new diagnostic XML path (must not exist)")
    args = parser.parse_args()

    source = args.input.expanduser().resolve()
    requested_output = args.output.expanduser()
    # Check the caller-supplied path before resolving it: Path.resolve() follows
    # symlinks, including dangling symlinks, and could redirect output elsewhere.
    if requested_output.is_symlink():
        parser.error(f"output path must not be a symlink: {requested_output}")
    output = requested_output.resolve()
    if source == output:
        parser.error("input and output must be different paths; production XML is never overwritten")
    if not source.is_file():
        parser.error(f"input XML does not exist or is not a file: {source}")
    if os.path.lexists(output):
        parser.error(f"output already exists; inspect/remove it explicitly first: {output}")
    if not output.parent.is_dir():
        parser.error(f"output directory does not exist: {output.parent}")

    original = source.read_text(encoding="utf-8")

    # Validate the XML structure before a text-preserving substitution. The
    # regex below intentionally keeps the original formatting, but it must not
    # silently accept a second video device or an already-present graphics
    # device. Parse errors are reported before any output file is created.
    try:
        original_root = ET.fromstring(original)
    except ET.ParseError as exc:
        parser.error(f"input XML is not well-formed: {exc}")
    devices = original_root.find("./devices")
    if devices is None:
        parser.error("input XML has no <devices> section")
    if original_root.find(".//graphics") is not None:
        parser.error("input already has a graphics device; refusing to add a duplicate")
    video_nodes = devices.findall("video")
    if len(video_nodes) != 1:
        parser.error(f"expected exactly one <devices><video> block, found {len(video_nodes)}")
    model = video_nodes[0].find("model")
    if model is None or model.get("type") != "none":
        parser.error('the single <video> block must contain <model type="none"/>')

    updated, count = VIDEO_NONE.subn(
        lambda match: GRAPHICS.replace("    ", match.group("indent"), 1), original
    )
    if count != 1:
        parser.error(
            'expected exactly one text-formatted <video><model type="none"/></video> block; '
            f"found {count} matching blocks"
        )

    # Validate generated XML without serializing the tree, preserving original
    # XML comments and layout.
    try:
        ET.fromstring(updated)
    except ET.ParseError as exc:
        parser.error(f"generated XML is not well-formed: {exc}")

    output.parent.mkdir(parents=False, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=f".{output.name}.", suffix=".tmp", dir=output.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(updated)
        os.chmod(temporary, 0o600)
        os.replace(temporary, output)
    except BaseException:
        try:
            os.unlink(temporary)
        except OSError:
            pass
        raise

    print(f"Diagnostic XML written: {output}")
    print("Next: virsh define this file, start win10, inspect virsh vncdisplay/logs.")
    print("After testing: virsh define the original production XML again.")
    print("VNC listens on 127.0.0.1 only; use an SSH tunnel for a remote viewer.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
