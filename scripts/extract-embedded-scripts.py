#!/usr/bin/env python3
"""Extract Bash scripts embedded in nixos/home.nix into standalone files.

The extractor recognizes selected Nix indented-string blocks without requiring
a Nix parser, resolves the relevant Nix escapes, and writes each script to the
requested output directory. It prints each emitted path to stdout, separated by
NUL bytes, so the output can be piped safely into ShellCheck with `xargs -0`.

Usage:
    python3 scripts/extract-embedded-scripts.py <output-directory>

This tool exists because embedded scripts previously escaped CI coverage. Earlier
regressions included a Nix escape turning `\\f` into `tr -d 'f'`, and a MANPAGER
setting that Git did not read.
"""

import argparse
import os
import re
import sys

# Locations of embedded Bash scripts in home.nix. Regex structure matters:
# A plain string match also matches `pgrep -f "hypr/scripts/..."` inside a script
# and can incorrectly extract the next block.
MARKERS = [
    re.compile(r'^\s*"hypr/scripts/[^"]+"\s*=\s*\{'),
    re.compile(r'^\s*home\.file\."[^"]+"\s*=\s*\{'),
]

# `gamemodeNotifyScript = pkgs.writeShellScriptBin "gamemode-notify" ''`
# form: there is no `text = ''`; the body begins after the assignment line.
DIRECT_MARKER = re.compile(r'^\s*gamemodeNotifyScript\s*=')

CLOSER = "''"


def extract(lines, index, direct=False):
    """Return the indented-string body associated with the marker at index."""
    if direct:
        start = index  # The body starts immediately after the assignment line.
    else:
        # Search only inside this Nix attribute block. Without this boundary
        # check a `home.file` entry that uses `source = ...` (rather than
        # `text = ''`) could accidentally capture the following script block,
        # making the same embedded script get emitted twice and breaking CI's
        # exact-count guard.
        marker_indent = len(lines[index]) - len(lines[index].lstrip())
        start = None
        for k in range(index + 1, len(lines)):
            if "text = ''" in lines[k]:
                start = k
                break
            stripped = lines[k].lstrip()
            indent = len(lines[k]) - len(stripped)
            if stripped.startswith("};") and indent <= marker_indent:
                return None
        if start is None:
            return None

    body = []
    for line in lines[start + 1:]:
        if line.strip().startswith(CLOSER):
            break
        body.append(line)

    if not body:
        return None

    # Nix indented strings remove the common indentation from the body.
    indent = min(
        (len(x) - len(x.lstrip()) for x in body if x.strip()), default=0
    )
    text = "\n".join(x[indent:] if x.strip() else "" for x in body)

    # Reduce Nix interpolations to plain executable command names.
    # The source shebang is `#!${pkgs.bash}/bin/bash`; because `#!` is at
    # the beginning of the line, only replace the path.
    text = text.replace("${pkgs.bash}/bin/bash", "/usr/bin/env bash", 1)
    text = text.replace("${config.home.homeDirectory}", "/home/localhost")
    # Fix: the old pattern `\$\{pkgs\.([\w.-]+)\}/bin/` captured only the package name
    # and dropped `/bin/` and the executable name:
    #     ${pkgs.libnotify}/bin/notify-send  ->  "libnotifynotify-send"
    #     ${pkgs.dbus}/bin/dbus-monitor      ->  "dbusdbus-monitor"
    #     ${pkgs.systemd}/bin/busctl         ->  "systemdbusctl"
    # These were not valid command names, so ShellCheck never
    # checked them; CI looked green while the scripts were not actually
    # being checked. The second capture group preserves the executable name:
    #     ${pkgs.libnotify}/bin/notify-send  ->  notify-send
    # The extracted output is therefore a valid executable shell script.
    text = re.sub(
        r"\$\{pkgs\.[\w.-]+\}/bin/([\w.+-]+)",
        lambda m: m.group(1),
        text,
    )
    # Nix escapes: `''${` becomes `${`; a standalone `''` becomes an empty string.
    text = text.replace("''${", "${").replace(CLOSER, "")

    # `gamemodeNotifyScript` is an explicit `writeShellScriptBin` body. Nix
    # adds the shebang to its generated executable, so the source block itself
    # legitimately has none. The extractor's output must still be recognized
    # as Bash by ShellCheck, so add one for this explicit direct-script marker.
    # Do not do this for generic markers: their source shebang is how main()
    # distinguishes shell scripts from config files such as TOML/MangoHud.
    if direct and not text.startswith("#!"):
        text = "#!/usr/bin/env bash\n" + text

    return text


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Extract Bash scripts embedded in nixos/home.nix into standalone "
            "executable files."
        ),
        epilog=(
            "The paths of extracted scripts are written to stdout, separated "
            "by NUL bytes, for safe use with xargs -0."
        ),
    )
    parser.add_argument(
        "output_directory",
        help="directory in which to write extracted scripts",
    )
    args = parser.parse_args()
    outdir = args.output_directory
    home_nix = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "nixos",
        "home.nix",
    )
    lines = open(home_nix, encoding="utf-8").read().split("\n")
    os.makedirs(outdir, exist_ok=True)

    count = 0
    def emit(text):
        nonlocal count
        count += 1
        path = os.path.join(outdir, "embedded_%02d.sh" % count)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(text)
        os.chmod(path, 0o755)
        sys.stdout.write(path + "\0")

    for idx, line in enumerate(lines):
        if DIRECT_MARKER.match(line):
            # Use the current enumerate index so each matching marker is handled
            # at its own position, even if more direct-script blocks are added.
            text = extract(lines, idx, direct=True)
            if text:
                emit(text)
            continue

        for marker in MARKERS:
            if not marker.match(line):
                continue
            text = extract(lines, idx)
            # Is it a real Bash script? These begin with a shebang. Config files such as
            # MangoHud.conf and lsfg-vk conf.toml are excluded this way.
            if text and text.lstrip().startswith("#!"):
                emit(text)
            break
    sys.stderr.write("extracted %d script(s)\n" % count)
    return 0


if __name__ == "__main__":
    sys.exit(main())
