#!/usr/bin/env python3
"""Syntax-check every embedded Python heredoc in the release workflow."""

from pathlib import Path
import re
import textwrap


ROOT = Path(__file__).resolve().parent.parent
WORKFLOW_PATH = ROOT / ".github" / "workflows" / "release.yml"


def main() -> None:
    workflow = WORKFLOW_PATH.read_text(encoding="utf-8")
    command_pattern = re.compile(
        r"(?m)^[ \t]*python3 -[^\n]*<<'PY'[ \t]*$"
    )
    block_pattern = re.compile(
        r"(?m)^(?P<indent>[ \t]*)python3 -[^\n]*<<'PY'[ \t]*\n"
        r"(?P<body>.*?)"
        r"^(?P=indent)PY[ \t]*$",
        re.DOTALL,
    )

    command_count = len(command_pattern.findall(workflow))
    blocks = list(block_pattern.finditer(workflow))
    if command_count == 0 or len(blocks) != command_count:
        raise SystemExit(
            "release.yml Python heredocs are missing or have unmatched PY delimiters: "
            f"{command_count} command(s), {len(blocks)} complete block(s)"
        )

    for index, match in enumerate(blocks, start=1):
        source = textwrap.dedent(match.group("body"))
        try:
            compile(source, f"{WORKFLOW_PATH}:python-heredoc-{index}", "exec")
        except SyntaxError as exc:
            raise SystemExit(
                f"release.yml embedded Python block {index} has invalid syntax: "
                f"line {exc.lineno}: {exc.msg}"
            ) from exc

    print(
        "OK: syntax-compiled "
        f"{len(blocks)} embedded Python heredoc block(s) from release.yml."
    )


if __name__ == "__main__":
    main()
