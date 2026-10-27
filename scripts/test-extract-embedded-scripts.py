#!/usr/bin/env python3
"""Regression tests for embedded-script extraction boundaries and termination."""
from __future__ import annotations

from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
EXTRACTOR = ROOT / "scripts" / "extract-embedded-scripts.py"


def load_extractor():
    spec = spec_from_file_location("extract_embedded_scripts", EXTRACTOR)
    if spec is None or spec.loader is None:
        raise AssertionError("could not load embedded-script extractor")
    module = module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    extractor = load_extractor()

    # A source-backed Nix attribute has no text block. Its next attribute must
    # not be captured merely because that later attribute embeds a script.
    lines = [
        '  home.file."source-backed" = {',
        "    source = ../scripts/existing-helper;",
        "  };",
        '  home.file."inline-script" = {',
        "    text = ''",
        "      #!/usr/bin/env bash",
        "      printf 'OK'",
        "    '';",
        "  };",
    ]
    if extractor.extract(lines, 0) is not None:
        raise AssertionError("source-backed attribute incorrectly captured a later script body")
    extracted = extractor.extract(lines, 3)
    if extracted is None or not extracted.startswith("#!/usr/bin/env bash\n") or "printf 'OK'" not in extracted:
        raise AssertionError(f"valid script body was not extracted from its own attribute: {extracted!r}")

    # Unterminated indented strings must fail rather than consume the rest of
    # home.nix as if it were script content.
    malformed_blocks = [
        (
            [
                '  home.file."broken" = {',
                "    text = ''",
                "      #!/usr/bin/env bash",
                "  };",
            ],
            0,
            False,
        ),
        (
            [
                'gamemodeNotifyScript = pkgs.writeShellScriptBin "notify" \'\'',
                "#!/usr/bin/env bash",
                "echo broken",
            ],
            0,
            True,
        ),
    ]
    for bad_lines, index, direct in malformed_blocks:
        try:
            extractor.extract(bad_lines, index, direct=direct)
        except ValueError:
            pass
        else:
            raise AssertionError("extractor accepted an unterminated Nix indented string")

    # Keep CI's existing seven-script contract and ensure the true file still
    # extracts successfully after the stricter boundary checks.
    with tempfile.TemporaryDirectory(prefix="embedded-extractor-test-") as tmp:
        result = subprocess.run(
            [sys.executable, str(EXTRACTOR), tmp],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode != 0:
            raise AssertionError(f"real home.nix extraction failed: {result.stderr}")
        paths = [Path(item) for item in result.stdout.split("\0") if item]
        if len(paths) != 7:
            raise AssertionError(f"expected 7 embedded Bash scripts, got {len(paths)}")

    print("OK: embedded extractor respects Nix attribute boundaries, rejects unterminated blocks, and extracts all seven scripts.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
