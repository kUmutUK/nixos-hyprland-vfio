#!/usr/bin/env python3
"""Validate file-backed CD-ROM sources in a libvirt domain XML before defining it."""

from __future__ import annotations

import argparse
import os
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Callable

Reporter = Callable[[str], None]


def validate_vm_iso_paths(xml_path: str | Path, report: Reporter = print) -> int:
    """Return 0 when all file-backed CD-ROM paths exist, otherwise return nonzero."""
    try:
        root = ET.parse(xml_path).getroot()
    except (OSError, ET.ParseError) as exc:
        report(f"ERROR: Cannot read valid VM XML '{xml_path}': {exc}")
        return 2

    devices = root.find("./devices")
    cdroms = devices.findall("./disk[@device='cdrom']") if devices is not None else []
    if not cdroms:
        report(f"ERROR: No CD-ROM devices found in VM XML: {xml_path}")
        return 2

    errors = 0
    file_sources_checked = 0
    for index, disk in enumerate(cdroms, start=1):
        source = disk.find("source")
        if source is None:
            report(f"ERROR: CD-ROM #{index} has no <source> element.")
            errors += 1
            continue

        source_file = source.get("file")
        if source_file is not None:
            source_file = source_file.strip()
            if not source_file:
                report(f"ERROR: CD-ROM #{index} has an empty source file path.")
                errors += 1
            elif not os.path.isabs(source_file):
                report(
                    f"ERROR: CD-ROM #{index} source path must be absolute: {source_file}"
                )
                errors += 1
            elif not os.path.isfile(source_file):
                report(
                    f"ERROR: CD-ROM #{index} source file does not exist or is not a regular file: "
                    f"{source_file}"
                )
                errors += 1
            else:
                file_sources_checked += 1
                report(f"OK: CD-ROM #{index} source file exists: {source_file}")
            continue

        # Physical CD-ROM devices are valid but have no filesystem path to check.
        source_dev = source.get("dev")
        if source_dev:
            report(
                f"INFO: CD-ROM #{index} uses host device '{source_dev}'; "
                "filesystem existence check skipped."
            )
            continue

        report(
            f"ERROR: CD-ROM #{index} has neither a file-backed nor a device-backed source."
        )
        errors += 1

    if errors:
        report(f"ERROR: VM ISO/source preflight failed ({errors} problem(s)); VM was not defined.")
        return 1

    if file_sources_checked:
        report(f"VM ISO/source preflight passed ({file_sources_checked} file path(s) checked).")
    else:
        report("VM CD-ROM source preflight passed; no file-backed source paths required checking.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Check file-backed CD-ROM source paths in a libvirt domain XML."
    )
    parser.add_argument("vm_xml", type=Path, help="Path to the exact VM XML that will be defined")
    args = parser.parse_args()
    return validate_vm_iso_paths(args.vm_xml)


if __name__ == "__main__":
    sys.exit(main())
