#!/usr/bin/env python3
"""Regression checks for current documentation, archive notes, and VM requirements."""

from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
README = (ROOT / "README.md").read_text(encoding="utf-8")
AUDIT = (ROOT / "docs/AUDIT-2026-10-28-VM-XML-VFIO.md").read_text(encoding="utf-8")
ARCHIVE = (ROOT / "docs/archive/DEGISIKLIK_GECMISI.md").read_text(encoding="utf-8")
CHANGELOG = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
STATE_INDEX = (ROOT / "DEGISIKLIK_GECMISI.md").read_text(encoding="utf-8")
REPAIR = (ROOT / "docs/REPAIR-AND-VALIDATION-REPORT.md").read_text(encoding="utf-8")
errors = []


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


for heading in (
    "# Follow-up audit: source ZIP, deployed VM XML, and VFIO driver recovery",
    "## Executive result",
    "## Evidence and reasoning",
    "## Regression and validation record",
):
    require(AUDIT.count(heading) == 1, f"audit report must contain exactly one {heading!r}")
require("$Format:%H# Follow-up audit" not in AUDIT, "audit report still contains the broken ZIP sentence/heading splice")

map_start = README.find("## Repository map")
map_end = README.find("## Validation", map_start)
require(map_start >= 0 and map_end > map_start, "README repository map section is missing")
if map_start >= 0 and map_end > map_start:
    repo_map = README[map_start:map_end]
    for required_path in (
        "AUDIT-2026-10-28-VM-XML-VFIO.md",
        "test-vm-xml-paths.py",
        "test-documentation-integrity.py",
        "lsfg-vk-v2.nix",
    ):
        require(required_path in repo_map, f"README repository map omits {required_path}")

requirements_start = README.find("## Requirements")
requirements_end = README.find("## Installation", requirements_start)
require(requirements_start >= 0 and requirements_end > requirements_start, "README requirements section is missing")
if requirements_start >= 0 and requirements_end > requirements_start:
    requirements = README[requirements_start:requirements_end]
    require("| Guest memory |" in requirements and "16 GiB" in requirements, "README must document the template's 16 GiB guest memory")
    require("| Guest CPU |" in requirements and "6 vCPUs" in requirements, "README must document the template's 6 vCPUs")
    require("| VM devices |" in requirements and "ICH9" in requirements and "iTCO" in requirements, "README must document ICH9 audio and the iTCO watchdog")

vm = ET.parse(ROOT / "vm-xml/win10.xml").getroot()
memory = vm.find("memory")
vcpu = vm.find("vcpu")
sound = vm.find("./devices/sound")
watchdog = vm.find("./devices/watchdog")
require(memory is not None and memory.get("unit") == "KiB" and (memory.text or "").strip() == "16777216", "VM XML memory no longer matches the documented 16 GiB")
require(vcpu is not None and (vcpu.text or "").strip() == "6", "VM XML vCPU count no longer matches the documented 6 vCPUs")
require(sound is not None and sound.get("model") == "ich9", "VM XML sound model no longer matches the README")
require(watchdog is not None and watchdog.get("model", "").lower() == "itco" and watchdog.get("action") == "reset", "VM XML watchdog no longer matches the README")

require("## [Unreleased]" in CHANGELOG, "CHANGELOG must use the undated [Unreleased] heading")
require(not re.search(r"(?m)^## (?:Unreleased|Previous unreleased changes)\s*[—-]\s*\d{4}-\d{2}-\d{2}", CHANGELOG), "CHANGELOG still gives an Unreleased heading a date")
require("rollback of the 2026-10-23 password-enabled SSH setting" in CHANGELOG, "CHANGELOG must state the SSH password-authentication rollback")
require("PasswordAuthentication" in CHANGELOG and "KbdInteractiveAuthentication" in CHANGELOG, "CHANGELOG must describe both disabled SSH password and keyboard-interactive authentication")
require("Superseded on 2026-10-29" in CHANGELOG, "the old system-wide Reflex entry must be marked superseded")
require("Superseded on 2026-10-30" in CHANGELOG, "the old password-enabled SSH entry must be marked superseded")
require("Current configuration notes — 2026-10-30" in STATE_INDEX, "current-state index date is stale")

require("Tarihsel anlık görüntü notu — 2026-10-19" in ARCHIVE, "archive note must be explicitly historical")
require("geçersiz kılındı" in ARCHIVE and "Bu ayar güncel değildir" in ARCHIVE, "archive note must mark old Reflex and SSH policies as superseded")
require("ile etkinleştirilmiştir. Uyumsuz" not in ARCHIVE, "archive must not present the old Reflex setting as current")
require(not re.search(r"parola girişi yalnız.*kullanıcısına izin verir", ARCHIVE), "archive must not present the old SSH password policy as current")

require("Current canonical source ZIP and artifact provenance — 2026-10-30" in REPAIR, "repair report must centralize current ZIP provenance")
require("554,516 bytes" in REPAIR and "65ab86f1" in REPAIR, "repair report must label supplied current-ZIP measurements")
require("the exact bytes were not attached" in REPAIR.lower(), "repair report must preserve the independent-verification boundary")

if errors:
    for error in errors:
        print(f"FAIL: {error}", file=sys.stderr)
    raise SystemExit(1)

print("OK: audit integrity, README map and VM requirements, changelog supersession, and ZIP provenance checks passed.")
