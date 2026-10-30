#!/usr/bin/env python3
"""Regression checks for current documentation, archive notes, and VM requirements."""

from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
README = (ROOT / "README.md").read_text(encoding="utf-8")
INSTALLATION = (ROOT / "INSTALLATION.md").read_text(encoding="utf-8")
CONTRIBUTING = (ROOT / "CONTRIBUTING.md").read_text(encoding="utf-8")
AUDIT = (ROOT / "docs/AUDIT-2026-10-28-VM-XML-VFIO.md").read_text(encoding="utf-8")
ARCHIVE = (ROOT / "docs/archive/DEGISIKLIK_GECMISI.md").read_text(encoding="utf-8")
CHANGELOG = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
STATE_INDEX = (ROOT / "DEGISIKLIK_GECMISI.md").read_text(encoding="utf-8")
CONFIG = (ROOT / "nixos/configuration.nix").read_text(encoding="utf-8")
FLAKE = (ROOT / "nixos/flake.nix").read_text(encoding="utf-8")
HOME_NIX = (ROOT / "nixos/home.nix").read_text(encoding="utf-8")
REPAIR = (ROOT / "docs/REPAIR-AND-VALIDATION-REPORT.md").read_text(encoding="utf-8")
errors = []


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


readme_top = "\n".join(README.splitlines()[:8])
require("docs/REPAIR-AND-VALIDATION-REPORT.md" in readme_top and "docs/AUDIT-2026-10-28-VM-XML-VFIO.md" not in readme_top, "README must point to the latest 2026-10-30 repair report, not the older audit")
require("- [License](#license)" in README and "## License" in README, "README contents must link to the License section")


for heading in (
    "# Follow-up audit: source ZIP, deployed VM XML, and VFIO driver recovery",
    "## Executive result",
    "## Evidence and reasoning",
    "## Regression and validation record",
):
    require(AUDIT.count(heading) == 1, f"audit report must contain exactly one {heading!r}")
require("$Format:%H# Follow-up audit" not in AUDIT, "audit report still contains the broken ZIP sentence/heading splice")
require("$Format:%H# Repair and validation report" not in REPAIR, "repair report still contains the pasted heading in the ZIP-provenance cell")

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
    require("| Desktop environment |" in requirements and "Hyprland 0.55 or newer" in requirements and "native Lua API" in requirements, "README must state the Hyprland 0.55+ Lua requirement")
    require("| GPU |" in requirements and "gfx1031" in requirements and "gfx1030" in requirements and "10.3.0" in requirements, "README must distinguish the RX 6700 XT native target from its ROCm compatibility override")
    require("| Host memory |" in requirements and "32 GiB is recommended" in requirements and "not a hard minimum" in requirements, "README must document the qualified 32 GiB host-memory recommendation")
    require("| Guest memory |" in requirements and "16 GiB" in requirements, "README must document the template's 16 GiB guest memory")
    require("| Guest CPU |" in requirements and "6 vCPUs" in requirements, "README must document the template's 6 vCPUs")
    require("| VM devices |" in requirements and "ICH9" in requirements and "iTCO" in requirements and "e1000e" in requirements, "README must document ICH9 audio, e1000e networking, and the iTCO watchdog")

vm = ET.parse(ROOT / "vm-xml/win10.xml").getroot()
memory = vm.find("memory")
vcpu = vm.find("vcpu")
sound = vm.find("./devices/sound")
watchdog = vm.find("./devices/watchdog")
network_model = vm.find("./devices/interface/model")
require(memory is not None and memory.get("unit") == "KiB" and (memory.text or "").strip() == "16777216", "VM XML memory no longer matches the documented 16 GiB")
require(vcpu is not None and (vcpu.text or "").strip() == "6", "VM XML vCPU count no longer matches the documented 6 vCPUs")
require(sound is not None and sound.get("model") == "ich9", "VM XML sound model no longer matches the README")
require('`audio type="none"`' in README and "has no host audio backend" in README, "README must explain that the ICH9 sound device has no host audio backend")
require("passed-through GPU HDMI/DP audio function" in README, "README must identify the passed-through GPU audio function as the guest audio path")
audio = vm.find("./devices/audio")
require(audio is not None and audio.get("type") == "none", "VM XML audio backend changed; update the README and review the intended guest audio path")
require("nix build .#lsfg-vk-v2" in README and "nix build .#lsfg-vk` command" not in README, "README must use the current LSFG-VK v2 flake output")
require("packages.${system}.lsfg-vk-v2 =" in FLAKE and "packages.${system}.lsfg-vk =" not in FLAKE, "README package command must match the declared flake output")
require(watchdog is not None and watchdog.get("model", "").lower() == "itco" and watchdog.get("action") == "reset", "VM XML watchdog no longer matches the README")
require(network_model is not None and network_model.get("type") == "e1000e", "VM XML network model no longer matches the README")
usb_ids = set()
for hostdev in vm.findall("./devices/hostdev"):
    if hostdev.get("type") == "usb":
        vendor_node = hostdev.find("./source/vendor")
        product_node = hostdev.find("./source/product")
        if vendor_node is not None and product_node is not None:
            vendor = vendor_node.get("id", "").removeprefix("0x").lower()
            product = product_node.get("id", "").removeprefix("0x").lower()
            usb_ids.add((vendor, product))
require(usb_ids == {("1532", "0098"), ("05ac", "024f")}, "VM XML must contain only the two documented active USB passthrough IDs")
require("lsusb -d 1532:0098" in README and "lsusb -d 05ac:024f" in README and "intended connected devices" in README, "README must require verification of both machine-specific USB passthrough IDs")

require("## [Unreleased]" in CHANGELOG, "CHANGELOG must use the undated [Unreleased] heading")
require(not re.search(r"(?m)^## (?:Unreleased|Previous unreleased changes)\s*[—-]\s*\d{4}-\d{2}-\d{2}", CHANGELOG), "CHANGELOG still gives an Unreleased heading a date")
require("rollback of the 2026-10-23 password-enabled SSH setting" in CHANGELOG, "CHANGELOG must state the SSH password-authentication rollback")
require("PasswordAuthentication" in CHANGELOG and "KbdInteractiveAuthentication" in CHANGELOG, "CHANGELOG must describe both disabled SSH password and keyboard-interactive authentication")
require("Superseded on 2026-10-29" in CHANGELOG, "the old system-wide Reflex entry must be marked superseded")
require("Superseded on 2026-10-30" in CHANGELOG, "the old password-enabled SSH entry must be marked superseded")
readme_bash_loop = re.search(
    r"(?ms)^  for f in \\\n(?P<body>.*?)^  do\n    bash -n \"\$f\"",
    README,
)
contrib_bash_loop = re.search(
    r"(?ms)^  for f in (?P<body>[^;\n]+); do\n    bash -n \"\$f\"",
    CONTRIBUTING,
)
require(readme_bash_loop is not None and contrib_bash_loop is not None, "README and CONTRIBUTING must both expose a full Bash syntax-check loop")
if readme_bash_loop is not None and contrib_bash_loop is not None:
    readme_bash_files = {line.strip().removesuffix("\\").strip() for line in readme_bash_loop.group("body").splitlines() if line.strip()}
    contributing_bash_files = set(contrib_bash_loop.group("body").split())
    require(readme_bash_files == contributing_bash_files, "README and CONTRIBUTING Bash syntax-check file lists have drifted")
require("Current configuration notes — 2026-10-30" in STATE_INDEX, "current-state index date is stale")
require("2026-10-28 entry" in STATE_INDEX and "2026-10-27 entry" not in STATE_INDEX, "root index must point to the 2026-10-28 CHANGELOG section")
require("copy all five required Nix/flake files" in README and "four flake files" not in README, "README must describe the five-file migration accurately")
require("four Nix source files required at the time" in CHANGELOG and "fifth required source file" in CHANGELOG, "CHANGELOG must distinguish the historical four-file preflight from the current five-file source tree")

require("Tarihsel anlık görüntü notu — 2026-10-19" in ARCHIVE, "archive note must be explicitly historical")
require("a dated status preface was added" in (ROOT / "docs/archive/README.md").read_text(encoding="utf-8"), "archive index must not claim the dated preface is byte-for-byte original")
require("geçersiz kılındı" in ARCHIVE and "Bu ayar güncel değildir" in ARCHIVE, "archive note must mark old Reflex and SSH policies as superseded")
require("ile etkinleştirilmiştir. Uyumsuz" not in ARCHIVE, "archive must not present the old Reflex setting as current")
require(not re.search(r"parola girişi yalnız.*kullanıcısına izin verir", ARCHIVE), "archive must not present the old SSH password policy as current")

require("Supplied ZIP provenance and canonical packaging — 2026-10-30" in REPAIR, "repair report must identify the supplied ZIP measurements as noncanonical provenance")
require("565,429 bytes" in REPAIR and "89fab35d7ecd18bb2b39bb74cbf7b799f8d76bc4c9d59970e7e94060f82dc374" in REPAIR and "b413e6df50f64ab16d1694d9b19dae97a078f56c" in REPAIR, "repair report must record the third supplied ZIP without conflating it with the earlier archive")
require("Y-1 reassessment" in REPAIR and "post-restoration" in REPAIR and "nine-file" in REPAIR, "repair report must qualify the executable-mode chronology rather than call it a proven contradiction")
require("historical note under release `[1.3.5]` about `amd_iommu=on`" in STATE_INDEX, "root history index must point to the correct historical section")
require("historical note under release `[1.3.6]` about `amd_iommu=on`" not in STATE_INDEX, "root history index retains the wrong amd_iommu section reference")
require("Aşağıdaki `[1.3.5]` bölümünde `amd_iommu=on`" in ARCHIVE and "Aşağıdaki `[1.3.6]` bölümünde `amd_iommu=on`" not in ARCHIVE, "archive header must point to the section that actually records amd_iommu=on")
require("### Earlier unreleased work (2026-10-28)" not in CHANGELOG, "CHANGELOG still has an empty same-level group heading")
require("approximately lines 9–15" in INSTALLATION and "approximately lines 4–12" not in INSTALLATION, "INSTALLATION must point to the current home.nix let-block line range")
wallpaper = re.search(r'(?m)^\s*wallpaperVideo\s*=\s*"\$\{config\.home\.homeDirectory\}/Downloads/([^"]+)"\s*;', HOME_NIX)
require(wallpaper is not None and f"~/Downloads/{wallpaper.group(1)}" in INSTALLATION, "INSTALLATION wallpaper default must match the exact home.nix filename")
require("installer backups are not automatically pruned" in CHANGELOG, "CHANGELOG must describe current backup retention rather than the historical five-backup policy")
require("verified current kernel defaults" in CHANGELOG and "does not establish a single removal commit" in CHANGELOG, "CHANGELOG must distinguish current kernel parameters from historical notes without inventing a removal history")
require("amdgpu.ppfeaturemask" in CHANGELOG and "amdgpu.featuremask" not in CHANGELOG, "CHANGELOG must use the documented amdgpu.ppfeaturemask parameter name")
require("older `[1.2.0]` archive entry" in CHANGELOG and "`2a7a:8a47` is absent" in CHANGELOG and "does not establish the exact commit or date" in CHANGELOG, "CHANGELOG must state current USB passthrough IDs and qualify the missing reactivation history")
require("561,513 bytes" in REPAIR and "c905b5036d04bf1e" in REPAIR and "116 entries" in REPAIR, "repair report must record the supplied ZIP measurements")
require("570,101 bytes" in REPAIR and "dee424e555ca173773388101d407a6699d668eda6fe348a5aa75962ebae4c2be" in REPAIR and "8b8cf29a1d21f2100234814b80fc4f5671e2b74a" in REPAIR, "repair report must record the fifth audit as supplied, unverified provenance")
require("install.sh` resolves the source revision from `git rev-parse HEAD`" in REPAIR and "too absolute" in REPAIR, "repair report must distinguish the Git-worktree and SOURCE_REVISION provenance paths")
require("bytes were not attached" in REPAIR.lower(), "repair report must preserve the independent-verification boundary")
require("554,516 bytes" not in REPAIR[:2500] and "65ab86f1" not in REPAIR[:2500], "repair report's current provenance row still contains stale measurements")
require("v0.2.0" in ARCHIVE and "948a561" in ARCHIVE, "archive note must distinguish the historical upstream revision from v0.2.0")
latency_vars = re.search(r"environment\.sessionVariables\s*=\s*\{(.*?)\};", CONFIG, re.DOTALL)
require(latency_vars is not None and re.search(r'(?m)^\s*LOW_LATENCY_LAYER\s*=\s*"1";', latency_vars.group(1)), "current configuration must opt in to low_latency_layer v0.2.0")
require(latency_vars is not None and not re.search(r"(?m)^\s*LOW_LATENCY_LAYER_REFLEX\s*=", latency_vars.group(1)), "Reflex must remain unset globally")

require("services.input-remapper.enable = true" in README and "input-remapper" in CONFIG and "services.input-remapper.enable" not in CONFIG, "README must disclose that input-remapper is installed but its daemon is not enabled")
require("Inspect active layers with:" in README and README.find("VK_LOADER_DEBUG=layer vulkaninfo") > README.find("Inspect active layers with:") and README.find("**CS2 / Source 2 note:**") > README.find("VK_LOADER_DEBUG=layer vulkaninfo"), "README layer-inspection command must follow its introduction before the separate CS2 note")
require("[0-9]+x[0-9]+(@[0-9.]+)?" in HOME_NIX, "WuWa monitor parser must accept resolutions with or without a refresh-rate suffix")
require('Description = "Stop the live wallpaper while Brave windows or GameMode are active."' in HOME_NIX, "mpvpaper watchdog description must cover Brave and GameMode")
package_start = CONFIG.find("environment.systemPackages = with pkgs; [")
package_end = CONFIG.find("\n  ];", package_start)
require(package_start >= 0 and package_end > package_start, "system package list must remain discoverable for the Steam ownership check")
if package_start >= 0 and package_end > package_start:
    require("\n    steam\n" not in CONFIG[package_start:package_end], "Steam must not be redundantly listed in environment.systemPackages")
require("programs.steam.enable = true;" in CONFIG, "Steam must remain enabled through programs.steam.enable")

if errors:
    for error in errors:
        print(f"FAIL: {error}", file=sys.stderr)
    raise SystemExit(1)

print("OK: audit integrity, README/flake output, VM device/audio requirements, changelog supersession, and ZIP provenance checks passed.")
