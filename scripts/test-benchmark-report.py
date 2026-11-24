#!/usr/bin/env python3
"""Unit tests for the MangoHud CSV summarizer."""
from pathlib import Path
import importlib.util
import tempfile
import unittest

SCRIPT = Path(__file__).with_name("benchmark-report.py")
SPEC = importlib.util.spec_from_file_location("benchmark_report", SCRIPT)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class BenchmarkReportTests(unittest.TestCase):
    def test_summary_calculates_average_low_fps_and_p99(self) -> None:
        fps = [100.0] * 98 + [50.0] * 2
        frametime = [10.0] * 98 + [30.0] * 2
        report = MODULE.summarize(fps, frametime)
        self.assertEqual(report["samples"], 100)
        self.assertAlmostEqual(report["average_fps"], 99.0)
        self.assertAlmostEqual(report["one_percent_low_fps"], 50.0)
        self.assertAlmostEqual(report["frametime_p99_ms"], 30.0)

    def test_reader_skips_mangohud_metadata_header(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            csv_path = Path(tmp) / "sample.csv"
            csv_path.write_text(
                "MangoHud version,0.7.x\nOS,Linux\nfps,frametime,gpu_load\n100,10,90\n50,30,95\n",
                encoding="utf-8",
            )
            fps, frametime = MODULE.read_samples(csv_path)
            self.assertEqual(fps, [100.0, 50.0])
            self.assertEqual(frametime, [10.0, 30.0])

    def test_missing_header_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            csv_path = Path(tmp) / "sample.csv"
            csv_path.write_text("no fps here\n", encoding="utf-8")
            with self.assertRaises(ValueError):
                MODULE.read_samples(csv_path)


if __name__ == "__main__":
    unittest.main()
