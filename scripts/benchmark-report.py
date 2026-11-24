#!/usr/bin/env python3
"""Summarize MangoHud CSV FPS and frametime samples without uploading data."""
from __future__ import annotations

import argparse
import csv
import math
from pathlib import Path
from statistics import fmean


def percentile(values: list[float], percent: float) -> float:
    ordered = sorted(values)
    if not ordered:
        raise ValueError("no numeric samples")
    position = (len(ordered) - 1) * percent / 100.0
    lower = math.floor(position)
    upper = math.ceil(position)
    if lower == upper:
        return ordered[lower]
    fraction = position - lower
    return ordered[lower] * (1.0 - fraction) + ordered[upper] * fraction


def read_samples(path: Path) -> tuple[list[float], list[float]]:
    lines = path.read_text(encoding="utf-8-sig", errors="replace").splitlines()
    header_index = None
    header: list[str] = []
    for index, line in enumerate(lines):
        row = next(csv.reader([line]))
        names = [item.strip().lower() for item in row]
        if "fps" in names and "frametime" in names:
            header_index = index
            header = names
            break
    if header_index is None:
        raise ValueError("MangoHud CSV header containing fps and frametime was not found")

    fps_values: list[float] = []
    frametimes: list[float] = []
    reader = csv.reader(lines[header_index + 1 :])
    for row in reader:
        if len(row) <= max(header.index("fps"), header.index("frametime")):
            continue
        try:
            fps = float(row[header.index("fps")].strip())
            frametime = float(row[header.index("frametime")].strip())
        except (ValueError, TypeError):
            continue
        if math.isfinite(fps) and fps > 0 and math.isfinite(frametime) and frametime >= 0:
            fps_values.append(fps)
            frametimes.append(frametime)
    if not fps_values:
        raise ValueError("MangoHud CSV contains no valid FPS/frametime samples")
    return fps_values, frametimes


def summarize(fps_values: list[float], frametimes: list[float]) -> dict[str, float | int]:
    if len(fps_values) != len(frametimes) or not fps_values:
        raise ValueError("FPS and frametime sample arrays must be non-empty and equal length")
    worst_count = max(1, math.ceil(len(fps_values) * 0.01))
    lows = sorted(fps_values)[:worst_count]
    return {
        "samples": len(fps_values),
        "average_fps": fmean(fps_values),
        "one_percent_low_fps": fmean(lows),
        "frametime_p99_ms": percentile(frametimes, 99),
        "average_frametime_ms": fmean(frametimes),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv_file", type=Path)
    args = parser.parse_args()
    report = summarize(*read_samples(args.csv_file))
    print(f"Samples: {report['samples']}")
    print(f"Average FPS: {report['average_fps']:.2f}")
    print(f"1% low FPS: {report['one_percent_low_fps']:.2f}")
    print(f"Frametime p99: {report['frametime_p99_ms']:.3f} ms")
    print(f"Average frametime: {report['average_frametime_ms']:.3f} ms")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
