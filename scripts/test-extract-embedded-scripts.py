#!/usr/bin/env python3
"""Regression tests for ShellCheck-aware Nix interpolation extraction."""

from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
EXTRACTOR = ROOT / "scripts" / "extract-embedded-scripts.py"


def load_extractor():
    spec = spec_from_file_location("extract_embedded_scripts", EXTRACTOR)
    if spec is None or spec.loader is None:
        raise AssertionError("could not load embedded-script extractor")
    module = module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    extractor = load_extractor()

    # Raw camelCase interpolation must be annotated, but real shell variable
    # references and Nix-escaped shell parameter expansions must not be.
    source = (
        'run ${closeNotificationCommand} 9999 >/dev/null\n'
        'LAST_MAIN="$TEXT_MAIN"\n'
        'GEOMETRY="\'\'${WUWA_GEOMETRY_MAIN:-$DEFAULT_GEOMETRY_MAIN}"\n'
    )
    annotated = extractor.annotate_nix_interpolations_for_shellcheck(source)
    lines = annotated.splitlines()

    nix_line = next(i for i, line in enumerate(lines) if "${closeNotificationCommand}" in line)
    if nix_line == 0 or lines[nix_line - 1] != (
        "# shellcheck disable=SC2154  # Nix interpolation, not a shell variable"
    ):
        raise AssertionError("bare camelCase Nix interpolation was not annotated")

    shell_assignment = next(i for i, line in enumerate(lines) if line.startswith("LAST_MAIN="))
    if shell_assignment > 0 and "shellcheck disable=SC2154" in lines[shell_assignment - 1]:
        raise AssertionError("real UPPER_CASE shell variable was incorrectly annotated")

    escaped_shell_var = next(i for i, line in enumerate(lines) if "''${WUWA_GEOMETRY_MAIN" in line)
    if escaped_shell_var > 0 and "shellcheck disable=SC2154" in lines[escaped_shell_var - 1]:
        raise AssertionError("Nix-escaped shell parameter expansion was incorrectly annotated")
    resolved = annotated.replace("''${", "${")
    if "${WUWA_GEOMETRY_MAIN:-$DEFAULT_GEOMETRY_MAIN}" not in resolved:
        raise AssertionError("Nix-escaped shell parameter expansion did not remain shell syntax")

    # Also cover the actual project source so the real failing command remains
    # annotated in the extracted script that CI passes to ShellCheck.
    with tempfile.TemporaryDirectory(prefix="embedded-shellcheck-test-") as tmp:
        result = subprocess.run(
            [sys.executable, str(EXTRACTOR), tmp],
            check=True,
            capture_output=True,
            text=True,
        )
        paths = [Path(p) for p in result.stdout.split("\0") if p]
        if len(paths) != 7:
            raise AssertionError(f"expected 7 embedded scripts, got {len(paths)}")
        matches = []
        for path in paths:
            output_lines = path.read_text(encoding="utf-8").splitlines()
            for i, line in enumerate(output_lines):
                if "${closeNotificationCommand}" in line:
                    matches.append((output_lines, i))
        if len(matches) != 2:
            raise AssertionError(
                f"expected both closeNotificationCommand uses, found {len(matches)}"
            )
        for output_lines, index in matches:
            if index == 0 or output_lines[index - 1] != (
                "# shellcheck disable=SC2154  # Nix interpolation, not a shell variable"
            ):
                raise AssertionError("actual extracted Nix interpolation is not annotated")

    print("embedded extractor interpolation tests OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
