#!/usr/bin/env python3
"""Regression checks for current documentation, archive notes, and VM requirements."""

from pathlib import Path
import json
import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
INSTALLER = (ROOT / "install.sh").read_text(encoding="utf-8")
INSTALLER_TEST = (ROOT / "scripts/test-installer-invariants.sh").read_text(encoding="utf-8")
README = (ROOT / "README.md").read_text(encoding="utf-8")
DISCLAIMER = (ROOT / "DISCLAIMER.md").read_text(encoding="utf-8")
INSTALLATION = (ROOT / "INSTALLATION.md").read_text(encoding="utf-8")
CONTRIBUTING = (ROOT / "CONTRIBUTING.md").read_text(encoding="utf-8")
RELEASING = (ROOT / "RELEASING.md").read_text(encoding="utf-8")
RELEASE_WORKFLOW = (ROOT / ".github/workflows/release.yml").read_text(encoding="utf-8")
CLIFF_CONFIG = (ROOT / ".git-cliff.toml").read_text(encoding="utf-8")
CHECK_WORKFLOW = (ROOT / ".github/workflows/check.yml").read_text(encoding="utf-8")
VFIO_HOOK = (ROOT / "nixos/hooks/qemu").read_text(encoding="utf-8")
VFIO_HOOK_TEST = (ROOT / "scripts/test-vfio-hook-driver-state.sh").read_text(encoding="utf-8")
AUDIT = (ROOT / "docs/AUDIT-2026-10-28-VM-XML-VFIO.md").read_text(encoding="utf-8")
ARCHIVE = (ROOT / "docs/archive/DEGISIKLIK_GECMISI.md").read_text(encoding="utf-8")
ARCHIVE_INDEX = (ROOT / "docs/archive/README.md").read_text(encoding="utf-8")
CHANGELOG = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
STATE_INDEX = (ROOT / "DEGISIKLIK_GECMISI.md").read_text(encoding="utf-8")
CONFIG = (ROOT / "nixos/configuration.nix").read_text(encoding="utf-8")
FLAKE = (ROOT / "nixos/flake.nix").read_text(encoding="utf-8")
FLAKE_LOCK = json.loads((ROOT / "nixos/flake.lock").read_text(encoding="utf-8"))
HOME_NIX = (ROOT / "nixos/home.nix").read_text(encoding="utf-8")
REPAIR = (ROOT / "docs/REPAIR-AND-VALIDATION-REPORT.md").read_text(encoding="utf-8")
OPTISCALER_DOC = (ROOT / "docs/OPTISCALER.md").read_text(encoding="utf-8")
OPTISCALER_MANAGER_DOC = (ROOT / "docs/OPTISCALER-MANAGER.md").read_text(encoding="utf-8")
OPTISCALER_MANAGER_SCRIPT = (ROOT / "scripts/optiscaler_manager.py").read_text(encoding="utf-8")
OPTISCALER_MANAGER_TEST = (ROOT / "scripts/test-optiscaler-manager.py").read_text(encoding="utf-8")
VM_XML_SYNC = (ROOT / "scripts/sync-vm-xml.py").read_text(encoding="utf-8")
VM_XML_SYNC_TEST = (ROOT / "scripts/test-vm-xml-sync.py").read_text(encoding="utf-8")
MANUAL_VM_BOOTSTRAP_TEST = (ROOT / "scripts/test-manual-vm-bootstrap.sh").read_text(encoding="utf-8")
SOURCE_REVISION_PLACEHOLDER = "$" + "Format:%H" + "$"
errors = []


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


readme_top = "\n".join(README.splitlines()[:8])
require("docs/REPAIR-AND-VALIDATION-REPORT.md" in readme_top and "docs/AUDIT-2026-10-28-VM-XML-VFIO.md" not in readme_top, "README must point to the current repair report, not the older audit")
require("- [License](#license)" in README and "## License" in README, "README contents must link to the License section")
require(".git-cliff.toml" in README and "RELEASING.md" in README and ".github/workflows/release.yml" in README, "README repository map must include the release configuration, guide, and workflow")
require("Normal CI must pass for the exact tagged commit" in README, "README must require successful CI for the exact tagged commit")
require("successful full NixOS system build must exist for that commit or an ancestor" in README, "README must describe the permitted ancestor full-system build")
cachyos_locked = FLAKE_LOCK.get("nodes", {}).get("cachyos-kernel", {}).get("locked", {})
cachyos_revision = cachyos_locked.get("rev")
require(
    isinstance(cachyos_revision, str) and re.fullmatch(r"[0-9a-f]{40}", cachyos_revision) is not None,
    "flake.lock must contain a full resolved CachyOS kernel revision",
)
kernel_state_note = next(
    (line for line in STATE_INDEX.splitlines() if line.startswith("- The active kernel package")),
    "",
)
require(
    "the exact resolved source revision is recorded only in `nixos/flake.lock`" in kernel_state_note
    and re.search(r"\b[0-9a-f]{40}\b", kernel_state_note) is None,
    "current-state kernel note must use flake.lock as the sole revision source instead of copying a SHA",
)
require(
    "available history does not identify a later removal commit or its rationale" in STATE_INDEX,
    "current-state index must qualify the undocumented historical IOMMU-parameter removal",
)
require(
    "available history does not identify when or in which commit the two current entries were re-enabled" in STATE_INDEX
    and "verify both connected devices with `lsusb`" in STATE_INDEX,
    "current-state index must distinguish historical USB comments from the active template defaults",
)

require("scripts/test-vm-xml-structure.py" in CONTRIBUTING, "CONTRIBUTING validation commands must include the CI VM XML structure test")
require("Expected exactly one assignment for" in INSTALLER and "n != 1" in INSTALLER, "installer apply_var must reject ambiguous assignments inside its atomic writer")
require("apply_var updates one assignment" in INSTALLER_TEST and "duplicate assignments" in INSTALLER_TEST, "installer invariants must test unique, missing, and duplicate Home Manager assignments")
require("domain is not None and domain != template_domain" in VM_XML_SYNC, "VM XML sync must reject a --domain name that differs from the template domain")
require("VM domain/template mismatch" in VM_XML_SYNC_TEST, "VM XML sync regressions must prove mismatched domain names fail without writing")
require("def snapshot_file_set" in OPTISCALER_MANAGER_SCRIPT and "def restore_file_set" in OPTISCALER_MANAGER_SCRIPT, "OptiScaler must share snapshot/restore helpers for multi-file recovery")
require(".rollback-recovery-" in OPTISCALER_MANAGER_SCRIPT and ".remove-transaction-" in OPTISCALER_MANAGER_SCRIPT and "Preserve the recovery snapshot at" in OPTISCALER_MANAGER_SCRIPT, "OptiScaler must retain named recovery snapshots when automatic restoration also fails")
require(all(name in OPTISCALER_MANAGER_TEST for name in (
    "test_rollback_copy_failure_restores_current_install",
    "test_rollback_state_write_failure_restores_current_install",
    "test_rollback_recovery_failure_keeps_manual_snapshot",
    "test_remove_recovery_failure_keeps_manual_snapshot",
    "test_original_backup_failure_preserves_previous_rollback_and_game",
    "test_per_game_operation_lock_rejects_concurrent_access_and_releases",
)), "OptiScaler tests must cover rollback and removal recovery failures")
require("scripts/test-vm-xml-structure.py" in CHECK_WORKFLOW, "CI must continue to run the VM XML structure regression test")
require("DEGISIKLIK_GECMISI.md" in RELEASING and "DEGISIKLIK_GECMISI.md" in RELEASE_WORKFLOW and "CONTRIBUTING.md" in RELEASING and "CHANGELOG.md" in RELEASING and "docs/REPAIR-AND-VALIDATION-REPORT.md" in RELEASING and "docs/OPTISCALER.md" in RELEASING and "docs/OPTISCALER.md" in RELEASE_WORKFLOW and "INSTALLATION.md" in RELEASING and "INSTALLATION.md" in RELEASE_WORKFLOW and ".github/workflows/check.yml" in RELEASING and "scripts/test-documentation-integrity.py" in RELEASING, "RELEASING allowlist documentation must match release.yml")
require("grep -E '^v(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$' |" in RELEASE_WORKFLOW, "release workflow must use a closed stable-semver regex when finding previous tags")
require("stable `vMAJOR.MINOR.PATCH` form" in RELEASING and "numeric components must not contain" in RELEASING, "release guide must document the strict stable tag format")
cliff_tag_match = re.search(r'(?m)^tag_pattern = "([^"]+)"$', CLIFF_CONFIG)
release_tag_match = re.search(r'\[\[ ! "\$release_tag" =~ (.*?) \]\]', RELEASE_WORKFLOW)
previous_tag_match = re.search(r"grep -E '([^']+)' \|", RELEASE_WORKFLOW)
expected_stable_tag_pattern = r"^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$"
cliff_tag_pattern = (
    cliff_tag_match.group(1).replace("\\\\", "\\")
    if cliff_tag_match is not None
    else None
)
release_tag_pattern = release_tag_match.group(1) if release_tag_match else None
previous_tag_pattern = previous_tag_match.group(1) if previous_tag_match else None
require(
    cliff_tag_pattern == expected_stable_tag_pattern
    and release_tag_pattern == expected_stable_tag_pattern
    and previous_tag_pattern == expected_stable_tag_pattern,
    "git-cliff, release validation, and previous-tag selection must use the same strict vMAJOR.MINOR.PATCH pattern",
)
for valid_tag in ("v0.0.1", "v1.3.9", "v1.4.0", "v10.20.300"):
    require(
        re.fullmatch(expected_stable_tag_pattern, valid_tag) is not None,
        f"strict stable-semver pattern must accept {valid_tag}",
    )
for invalid_tag in ("1.4.0", "v01.4.0", "v1.04.0", "v1.4.00", "v1.4", "v1.4.0-rc.1", "v1.4.0+build.1"):
    require(
        re.fullmatch(expected_stable_tag_pattern, invalid_tag) is None,
        f"strict stable-semver pattern must reject {invalid_tag}",
    )

for step_name in ("Find previous version tag", "Generate release notes with git-cliff", "Use curated notes for the first tagged release", "Verify release notes", "Build and validate canonical source ZIP", "Create SHA-256 manifest", "Create annotated tag for manual releases", "Publish GitHub Release"):
    require(RELEASE_WORKFLOW.count(f"- name: {step_name}") == 1, f"release workflow must contain exactly one {step_name!r} step")
require("actionlint" in CHECK_WORKFLOW and "go run github.com/rhysd/actionlint/cmd/actionlint@v1.7.7" in CHECK_WORKFLOW, "normal CI must run the pinned actionlint validator")
require(
    "go run github.com/rhysd/actionlint/cmd/actionlint@v1.7.7" in CONTRIBUTING
    and "nixosConfigurations.nixos.config.virtualisation.libvirtd.hooks.qemu.vfio" in CONTRIBUTING
    and 'shellcheck -S warning "$hook_path"' in CONTRIBUTING
    and "luac -p" in CONTRIBUTING,
    "CONTRIBUTING local validation must mirror Actionlint, generated-hook ShellCheck, and generated-Lua syntax CI gates",
)
require(
    "args: ${{ github.event_name == 'push' && '--current --strip header' || '--latest --strip header' }}" in RELEASE_WORKFLOW,
    "tag pushes must use git-cliff --current while manual main-branch releases use --latest",
)
require(
    "Last completed full-system build baseline — 2026-11-03" in REPAIR,
    "repair report must label the last completed full-system build baseline and avoid a duplicated heading",
)
repair_baseline_match = re.search(
    r"(?m)^\*\*Verified full-system build baseline:\*\* GitHub `main` at `([0-9a-f]{40})`",
    REPAIR,
)
index_baseline_match = re.search(
    r"(?m)^- Last completed full-system build baseline \(2026-11-03\): GitHub `main` at `([0-9a-f]{40})`",
    STATE_INDEX,
)
reviewed_snapshot_match = re.search(
    r"(?m)^\*\*Reviewed source snapshot:\*\* GitHub `main` at `([0-9a-f]{40})`",
    REPAIR,
)
index_reviewed_snapshot_match = re.search(
    r"(?m)^- Reviewed source snapshot \(2026-11-03\): GitHub `main` at `([0-9a-f]{40})`",
    STATE_INDEX,
)
ci_run_match = re.search(
    r"(?m)^- \*\*Normal CI for the reviewed snapshot:\*\* \[run #(\d+)\]\(https://github\.com/kUmutUK/nixos-hyprland-vfio/actions/runs/(\d+)\) completed successfully for the exact reviewed snapshot `([0-9a-f]{40})`",
    REPAIR,
)
build_run_match = re.search(
    r"\[manual run #(\d+)\]\(https://github\.com/kUmutUK/nixos-hyprland-vfio/actions/runs/(\d+)\) completed successfully for the \*\*same exact commit\*\* `([0-9a-f]{40})`",
    REPAIR,
)
require(repair_baseline_match is not None, "repair report must contain the full SHA of the last successful full-system build")
require(index_baseline_match is not None, "current-state index must contain the full SHA of the last successful full-system build")
require(reviewed_snapshot_match is not None, "repair report must identify the separately reviewed source snapshot")
require(index_reviewed_snapshot_match is not None, "current-state index must identify the separately reviewed source snapshot")
require(ci_run_match is not None, "repair report must link successful normal CI for the reviewed source snapshot")
require(build_run_match is not None, "repair report must link the last successful full-system build")
if repair_baseline_match and index_baseline_match:
    build_sha = repair_baseline_match.group(1)
    require(index_baseline_match.group(1) == build_sha,
            "current-state index and repair report must identify the same full-system build baseline")
    require(build_run_match is not None and build_run_match.group(3) == build_sha,
            "the documented manual full-system build must match the full-system build baseline SHA")
if reviewed_snapshot_match and index_reviewed_snapshot_match and ci_run_match:
    reviewed_sha = reviewed_snapshot_match.group(1)
    require(index_reviewed_snapshot_match.group(1) == reviewed_sha,
            "current-state index and repair report must identify the same reviewed source snapshot")
    require(ci_run_match.group(3) == reviewed_sha,
            "the normal-CI run must cover the exact reviewed source snapshot")
require("[#" + (ci_run_match.group(1) if ci_run_match else "") + "]" in STATE_INDEX,
        "current-state index must reference the same normal-CI run as the repair report")
require("run #" + (build_run_match.group(1) if build_run_match else "") in STATE_INDEX,
        "current-state index must reference the same full-system build as the repair report")
require("manual run #9" in REPAIR and "full-system build baseline" in REPAIR and "ab89f350803d47eb16499c613b110da05a57673f" in REPAIR,
        "repair report must identify the successful exact-HEAD full-system build baseline")
require("run #9" in STATE_INDEX and "69 tracked file blobs" in STATE_INDEX and "ab89f350803d47eb16499c613b110da05a57673f" in STATE_INDEX,
        "current-state index must match the latest full-system build baseline")
require("run #1120" in REPAIR and "run #1120" in STATE_INDEX and "8d1e4585c9cd3f690c1df80ee531008c7e9d30ef" in STATE_INDEX,
        "current-state index must preserve the distinct reviewed-snapshot normal-CI record")
require(
    "run #1127" in REPAIR and "13258097729" in REPAIR and "331,775 bytes" in REPAIR
    and "d34c8c3545da92d5d9dae97afb4e627edd0c167f" in REPAIR,
    "repair report must record pre-remediation main CI #1127 and its current-at-the-time artifact",
)
require(
    "[#1127]" in STATE_INDEX and "13258097729" in STATE_INDEX and "run #1120" in STATE_INDEX,
    "current-state index must distinguish pre-remediation main CI from the historical reviewed-snapshot CI",
)
require(
    "Maintainer-reported target-host verification" in REPAIR
    and "normal Windows 10 VM launch and shutdown" in REPAIR
    and "A libvirt saved-state restore remains unverified" in REPAIR,
    "repair report must record the maintainer-reported normal VFIO lifecycle without claiming saved-state restore",
)
require("run #1124" in REPAIR and "stale" in REPAIR and "target-host" in REPAIR,
        "repair report must explain the stale-baseline CI failure and retain the physical validation boundary")

# The full-system baseline is the last source snapshot for which a complete
# NixOS toplevel/selected-kernel build is documented. Normal CI does not
# silently upgrade that build record. Subsequent changes must stay within the
# explicit release allowlist or documented pending-build paths.
verification_metadata_paths = {
    ".git-cliff.toml",
    ".github/workflows/check.yml",
    ".github/workflows/release.yml",
    "CHANGELOG.md",
    "CONTRIBUTING.md",
    "DEGISIKLIK_GECMISI.md",
    "README.md",
    "INSTALLATION.md",
    "RELEASING.md",
    "docs/REPAIR-AND-VALIDATION-REPORT.md",
    "docs/OPTISCALER.md",
    "docs/OPTISCALER-MANAGER.md",
    "scripts/optiscaler_manager.py",
    "scripts/test-optiscaler-manager.py",
    "scripts/sync-vm-xml.py",
    "scripts/test-vm-xml-sync.py",
    "scripts/test-manual-vm-bootstrap.sh",
    "scripts/test-installer-invariants.sh",
    "scripts/test-vfio-hook-driver-state.sh",
    "scripts/test-documentation-integrity.py",
}
for path in verification_metadata_paths:
    require(path in RELEASE_WORKFLOW, f"release workflow must keep {path!r} in the full-build ancestor allowlist")
require("fetch-depth: 0" in CHECK_WORKFLOW, "normal CI must fetch full Git history for the verified-baseline ancestry check")
current_head = os.environ.get("GITHUB_SHA")
if not current_head:
    try:
        head_result = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, check=True, capture_output=True, text=True)
        current_head = head_result.stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        current_head = None
require(current_head is not None and re.fullmatch(r"[0-9a-f]{40}", current_head or "") is not None,
        "documentation verification test must be run from a Git checkout with a resolvable HEAD")
if current_head and repair_baseline_match:
    shallow_result = subprocess.run(
        ["git", "rev-parse", "--is-shallow-repository"],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    if shallow_result.returncode == 0 and shallow_result.stdout.strip() == "true":
        # Source ZIPs intentionally do not carry full Git history. Static checks still
        # run, while the ancestry/diff check is deferred to normal CI (fetch-depth: 0).
        print("SKIP: verified-baseline ancestry/diff check requires full Git history; normal CI fetches it.")
    else:
        verified_sha = repair_baseline_match.group(1)
        ancestor = subprocess.run(["git", "merge-base", "--is-ancestor", verified_sha, current_head], cwd=ROOT, capture_output=True, text=True)
        require(ancestor.returncode == 0, "documented verified baseline must be an ancestor of the current checkout HEAD")
        if ancestor.returncode == 0:
            if reviewed_snapshot_match:
                reviewed_sha = reviewed_snapshot_match.group(1)
                reviewed_ancestor = subprocess.run(["git", "merge-base", "--is-ancestor", reviewed_sha, current_head], cwd=ROOT, capture_output=True, text=True)
                require(reviewed_ancestor.returncode == 0, "reviewed normal-CI source snapshot must be an ancestor of the current checkout HEAD")
            changed = subprocess.run(["git", "diff", "--name-only", verified_sha, current_head], cwd=ROOT, check=True, capture_output=True, text=True).stdout.splitlines()
            full_build_pending_paths = {"nixos/hooks/qemu", "install.sh", "nixos/home.nix"}
            unexpected = sorted(set(changed) - verification_metadata_paths - full_build_pending_paths)
            require(
                not unexpected,
                "changes after the last successful full-system build must stay within the release/documentation/CI allowlist or an explicitly documented pending-build path; unexpected: "
                + ", ".join(unexpected),
            )
            pending = sorted(set(changed) & full_build_pending_paths)
            if pending:
                require(
                    "fresh full-system build is required before release" in REPAIR,
                    "system-affecting pending paths must require a new manual full-system build before release",
                )
            if "nixos/hooks/qemu" in pending:
                require(
                    "A real saved-state restore and complete graphics lifecycle test on the target host are also still required" in REPAIR,
                    "a QEMU hook change must document target-host saved-state verification",
                )
                require(
                    "nixos/hooks/qemu" not in RELEASING and "nixos/hooks/qemu" not in RELEASE_WORKFLOW,
                    "the changed QEMU hook must remain outside the ancestor-build release allowlist until a new full-system build passes",
                )
            if "install.sh" in pending:
                require(
                    "install.sh" in REPAIR and "fresh full-system build is required before release" in REPAIR,
                    "installer changes must be documented as requiring a fresh full-system build",
                )
                require(
                    "install.sh" in RELEASING and "remain gated by a new full-system build" in RELEASING and "install.sh" not in RELEASE_WORKFLOW,
                    "install.sh must remain outside the ancestor-build release allowlist while the release guide documents its full-build gate",
                )
            if "nixos/home.nix" in pending:
                require(
                    "nixos/home.nix" in REPAIR and "fresh full-system build is required before release" in REPAIR,
                    "Home Manager changes must be documented as requiring a fresh full-system build",
                )



for heading in (
    "# Follow-up audit: source ZIP, deployed VM XML, and VFIO driver recovery",
    "## Executive result",
    "## Evidence and reasoning",
    "## Regression and validation record",
):
    require(AUDIT.count(heading) == 1, f"audit report must contain exactly one {heading!r}")
require("$Format:%H# Follow-up audit" not in AUDIT, "audit report still contains the broken ZIP sentence/heading splice")
require("$Format:%H# Repair and validation report" not in REPAIR, "repair report still contains the pasted heading in the ZIP-provenance cell")
require(REPAIR.count("## Seventh audit cross-check — 2026-10-30") == 1, "repair report must contain exactly one seventh-audit cross-check section")
require(REPAIR.count("## Ninth audit cross-check — 2026-10-30") == 1, "repair report must contain exactly one ninth-audit cross-check section")
require(REPAIR.count("## Tenth audit cross-check — 2026-10-30") == 1, "repair report must contain exactly one tenth-audit cross-check section")
require("587,335 bytes" in REPAIR and "6b0111ca7cfb442d84bdbc22c516efbde2e90c6ea5a1f88bf9076317d99b4b11" in REPAIR and "a627fcb13b15e71e90983a3a2ff391d38eb743e5" in REPAIR, "repair report must record the latest attached ZIP identity")
require("Tenth audit cross-check" in REPAIR and "45 entries (29 files and 16 directories)" in REPAIR and "create_system=0" in REPAIR, "latest upload report must preserve the independently measured ZIP metadata")
require("DEGISIKLIK_GECMISI.md" in CHANGELOG and "DEGISIKLIK_GECISI_GECMISI.md" not in CHANGELOG, "CHANGELOG must use the correct root current-state filename")
require("### Tenth audit follow-up — 2026-10-30" in CHANGELOG, "CHANGELOG must record the tenth audit follow-up")
require("$Format:%H# Changelog" not in CHANGELOG and "placeholder. Its embedded" not in CHANGELOG, "CHANGELOG must not contain the malformed heading/source-revision splice")
require("6b0111ca7cfb442d84bdbc22c516efbde2e90c6ea5a1f88bf9076317d99b4b11" in CHANGELOG and "587,335-byte ZIP" in CHANGELOG, "CHANGELOG must identify the most recently inspected supplied ZIP")
require("583,569 bytes" in REPAIR and "98d5b073a12488f604dfc9f434f3f741d52defce055d30f22db44102ed1be25d" in REPAIR and "65b0028cd76352daea9e5a01e4d7d9afb954b10b" in REPAIR, "repair report must record the independently measured current ZIP identity")
require("283,401 bytes" in REPAIR and "7abee4ca2a29e02cc3eea810c308f029603070c427a4758b3ceb399574b10a47" in REPAIR and "nine executable files" in REPAIR, "repair report must distinguish the verified canonical reproduction from the uploaded ZIP")
require("45 entries (29 files and 16 directories)" in REPAIR and "create_system=0" in REPAIR and "external_attr=0x00000000" in REPAIR, "repair report must record the uploaded ZIP metadata and embedded Git subtree")
require(REPAIR.count("## Supplied ZIP provenance and canonical packaging — 2026-10-30") == 1, "repair report must contain exactly one supplied-ZIP provenance section")
require("| ZIP described in the supplied seventh audit" in REPAIR and SOURCE_REVISION_PLACEHOLDER in REPAIR, "seventh ZIP provenance row must include the complete archive identity record")
require(not re.search(r"(?m)^; all 116 entries", REPAIR), "repair report contains an orphaned ZIP metadata continuation")

map_start = README.find("## Repository map")
map_end = README.find("## Validation", map_start)
require(map_start >= 0 and map_end > map_start, "README repository map section is missing")
if map_start >= 0 and map_end > map_start:
    repo_map = README[map_start:map_end]
    for required_path in (
        "AUDIT-2026-10-28-VM-XML-VFIO.md",
        "OPTISCALER-MANAGER.md",
        "optiscaler_manager.py",
        "test-optiscaler-manager.py",
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
require("update_qemu_hook_pci()" in INSTALLER and "if ! update_qemu_hook_pci" in INSTALLER, "installer must use the checked QEMU hook PCI updater and fail closed on error")
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
require("Current configuration notes — 2026-11-03" in STATE_INDEX, "current-state index date is stale")
require("2026-10-28 entry" in STATE_INDEX and "2026-10-27 entry" not in STATE_INDEX, "root index must point to the 2026-10-28 CHANGELOG section")
require("copy all five required Nix/flake files" in README and "four flake files" not in README, "README must describe the five-file migration accurately")
require(
    "The helper synchronizes `/var/lib/libvirt/win10.xml` only when `win10` is registered" in README
    and "if neither condition is met, it writes no VM XML" in README
    and "Fresh XML generation is deferred to the documented post-install VM-preparation flow" in README,
    "README must distinguish existing VM synchronization from deferred new-VM XML generation",
)
require(
    "On a new VM, it starts from the repository template." not in README
    and "only a genuinely new, unregistered VM starts from the reviewed template." not in README,
    "README retains a stale claim that install.sh creates XML from the template for a new VM",
)
require(
    "For a new, unregistered VM with no deployed XML, the helper writes no VM XML." in DISCLAIMER
    and "Fresh XML generation is deferred to the documented post-install VM-preparation flow" in DISCLAIMER
    and "For a new domain, the repository XML template is used." not in DISCLAIMER,
    "DISCLAIMER must describe deferred new-VM XML generation rather than the old template behavior",
)
require(
    'assertion = lib.versionAtLeast config.programs.hyprland.package.version "0.55.0";' in CONFIG,
    "configuration must enforce the Hyprland Lua API minimum during evaluation",
)
require("four Nix source files required at the time" in CHANGELOG and "fifth required source file" in CHANGELOG, "CHANGELOG must distinguish the historical four-file preflight from the current five-file source tree")

require("ilk snapshot: 2026-10-19" in ARCHIVE and "önsöz son güncelleme: 2026-10-30" in ARCHIVE, "archive note must distinguish its snapshot date from the preface update date")
require("Bu 19 Ekim snapshot'ındaki XML yazma açıklaması güncel değildir" in ARCHIVE, "archive preface must mark the old installer XML-writing statement as superseded")
require("Aşağıdaki `[1.3.8]` kaydı" in ARCHIVE and "hangi commit/tarihte geri eklendiğini" in ARCHIVE, "archive preface must qualify the unresolved ICH9 history")
require("not byte-for-byte identical to the original changelog" in ARCHIVE_INDEX and "historical Turkish release entries" in ARCHIVE_INDEX, "archive index must distinguish preserved release entries from the added preface")
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
require("### Eighth audit follow-up — 2026-10-30" in CHANGELOG, "CHANGELOG must record the eighth audit follow-up")
require("### Ninth audit follow-up — 2026-10-30" in CHANGELOG, "CHANGELOG must record the ninth audit follow-up")
require("Historical pre-v2 design note (superseded 2026-10-29)" in CHANGELOG and "That statement no longer describes the current configuration" in CHANGELOG, "CHANGELOG must clearly supersede the old LSFG-VK v1 decision")
require("byte-for-byte unchanged copy" in CHANGELOG and "preserved unchanged in" not in CHANGELOG, "CHANGELOG must describe the archive preface accurately")
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
hypridle_start = HOME_NIX.index("listener = [")
hypridle_listeners = HOME_NIX[hypridle_start:HOME_NIX.index("\n      ];", hypridle_start)]
lock_timeout_pos = hypridle_listeners.find("timeout = 300;")
lock_command_pos = hypridle_listeners.find(
    'on-timeout = "${pkgs.hyprlock}/bin/hyprlock";',
    lock_timeout_pos,
)
dpms_timeout_pos = hypridle_listeners.find("timeout = 305;")
dpms_command_pos = hypridle_listeners.find(
    'on-timeout = "${pkgs.hyprland}/bin/hyprctl dispatch dpms off";',
    dpms_timeout_pos,
)
require(
    lock_timeout_pos >= 0 and lock_command_pos > lock_timeout_pos
    and dpms_timeout_pos > lock_command_pos and dpms_command_pos > dpms_timeout_pos
    and "timeout = 600;" not in hypridle_listeners,
    "Hypridle must lock at 300 seconds before DPMS powers the display off at 305 seconds",
)
require(
    "gpu_device = 1;" in CONFIG and "gpu_device = 1" in CONTRIBUTING
    and "/sys/class/drm/card[0-9]*" in CONTRIBUTING and "cardN" in CONTRIBUTING,
    "GameMode's target-host DRM card index must stay documented and be verified on the target host before changing it",
)

package_start = CONFIG.find("environment.systemPackages = with pkgs; [")
package_end = CONFIG.find("\n  ];", package_start)
require(package_start >= 0 and package_end > package_start, "system package list must remain discoverable for the Steam ownership check")
if package_start >= 0 and package_end > package_start:
    require("\n    steam\n" not in CONFIG[package_start:package_end], "Steam must not be redundantly listed in environment.systemPackages")
require("programs.steam.enable = true;" in CONFIG, "Steam must remain enabled through programs.steam.enable")

require("docs/OPTISCALER.md" in README and "OptiScaler" in README, "README must link the optional OptiScaler Proton guide")
require("docs/OPTISCALER.md" in INSTALLATION, "installation guide must point to the optional per-game OptiScaler instructions")
require("OptiScaler v0.9.4" in OPTISCALER_DOC and "575cb4df866116093df75af607e37fd70e10f5163e0f23fd5c804142e80ef0ad" in OPTISCALER_DOC, "OptiScaler guide must pin the official stable release asset and SHA-256")
require('WINEDLLOVERRIDES="dxgi=n,b" %command%' in OPTISCALER_DOC, "OptiScaler guide must include the official Proton DXGI override")
require("RX 6700 XT" in OPTISCALER_DOC and "RDNA2" in OPTISCALER_DOC and "FSR 4.1.1" in OPTISCALER_DOC, "OptiScaler guide must explain the target GPU FSR 4.1.1 limitation")
require("anti-cheat" in OPTISCALER_DOC.lower() and "do not use" in OPTISCALER_DOC.lower(), "OptiScaler guide must retain the upstream anti-cheat warning")
require("LSFG-VK" in OPTISCALER_DOC and "simultaneously" in OPTISCALER_DOC.lower(), "OptiScaler guide must warn against stacking frame-generation paths")
require("OptiScaler" not in CONFIG and "OptiScaler" not in HOME_NIX, "OptiScaler must remain an optional game-local tool, not a global NixOS/Home Manager injection")
require("docs/OPTISCALER-MANAGER.md" in README and "OptiScaler Manager" in README, "README must link the optional OptiScaler manager guide")
require("docs/OPTISCALER-MANAGER.md" in INSTALLATION and "scripts/optiscaler_manager.py" in OPTISCALER_MANAGER_DOC, "installation and manager guides must point to the optional helper")
require("scripts/optiscaler_manager.py" in OPTISCALER_MANAGER_DOC and "scripts/test-optiscaler-manager.py" in OPTISCALER_MANAGER_DOC, "manager guide must document the helper and its offline test")
require("releases/latest" in OPTISCALER_MANAGER_SCRIPT and "prerelease" in OPTISCALER_MANAGER_SCRIPT.lower() and "draft" in OPTISCALER_MANAGER_SCRIPT.lower(), "OptiScaler manager must query only the official stable-release endpoint")
require("PINNED_SHA256" in OPTISCALER_MANAGER_SCRIPT and "575cb4df866116093df75af607e37fd70e10f5163e0f23fd5c804142e80ef0ad" in OPTISCALER_MANAGER_SCRIPT, "OptiScaler manager must retain the pinned v0.9.4 SHA-256")
require("validate_archive_member" in OPTISCALER_MANAGER_SCRIPT and "MAX_EXTRACTED_BYTES" in OPTISCALER_MANAGER_SCRIPT and "total_size" in OPTISCALER_MANAGER_SCRIPT, "OptiScaler manager must validate archive paths and preflight the extracted-size limit")
require("require_regular_backup" in OPTISCALER_MANAGER_SCRIPT and "safe_backup_path" in OPTISCALER_MANAGER_SCRIPT, "OptiScaler manager must validate backup files and reject unsafe backup paths before mutation")
require("def game_operation_lock" in OPTISCALER_MANAGER_SCRIPT and "fcntl.flock" in OPTISCALER_MANAGER_SCRIPT and "LOCK_EX | fcntl.LOCK_NB" in OPTISCALER_MANAGER_SCRIPT, "OptiScaler must use a fail-fast per-game file lock")
for command_name in ("command_install", "command_status", "command_rollback", "command_remove"):
    command_match = re.search(rf"(?ms)^def {command_name}\(.*?(?=^def |\Z)", OPTISCALER_MANAGER_SCRIPT)
    require(command_match is not None and "with game_operation_lock(game_dir):" in command_match.group(0),
            f"OptiScaler {command_name} must hold the per-game operation lock")
require("Could not preserve original game-file backup" in OPTISCALER_MANAGER_SCRIPT and
        OPTISCALER_MANAGER_SCRIPT.index("Could not preserve original game-file backup") <
        OPTISCALER_MANAGER_SCRIPT.index('old_rollback = backup_dir / ".rollback-previous"'),
        "OptiScaler must finish original-file backups before rotating the previous rollback")
require("automatic restoration was " in OPTISCALER_MANAGER_SCRIPT and "incomplete" in OPTISCALER_MANAGER_SCRIPT and "remove-transaction-" in OPTISCALER_MANAGER_SCRIPT, "OptiScaler manager must retain recovery data and roll back partial install/removal failures")
require("--confirm-offline-singleplayer" in OPTISCALER_MANAGER_SCRIPT and "Type INSTALL" in OPTISCALER_MANAGER_SCRIPT, "OptiScaler manager must require explicit offline-game and interactive install confirmation")
require("--replace-existing" in OPTISCALER_MANAGER_SCRIPT and "rollback_available" in OPTISCALER_MANAGER_SCRIPT and "remove_installation" in OPTISCALER_MANAGER_SCRIPT, "OptiScaler manager must require explicit conflict replacement and provide rollback/removal")
require("scripts/test-optiscaler-manager.py" in CONTRIBUTING and "scripts/test-optiscaler-manager.py" in CHECK_WORKFLOW, "OptiScaler manager regression tests must be documented and run in normal CI")
require("python3 scripts/test-optiscaler-manager.py" in README, "README full validation sequence must run the OptiScaler manager regression suite")
require("independent, nonofficial third-party helper" in OPTISCALER_DOC and "not developed by or affiliated with OptiScaler upstream" in OPTISCALER_DOC, "OptiScaler guide must identify the repository manager as independent and nonofficial")
require("symbolic links, hard links, reparse points" in OPTISCALER_MANAGER_DOC and "Unix special files" in OPTISCALER_MANAGER_DOC and "state JSON root" in OPTISCALER_MANAGER_DOC, "manager guide must document pre-extraction member types and state validation")
require("def parse_archive_listing" in OPTISCALER_MANAGER_SCRIPT and '"Symbolic Link"' in OPTISCALER_MANAGER_SCRIPT and '"Hard Link"' in OPTISCALER_MANAGER_SCRIPT and '"Reparse Point"' in OPTISCALER_MANAGER_SCRIPT and "def validate_state_document" in OPTISCALER_MANAGER_SCRIPT, "manager must preflight archive links and validate state")
require(
    "tempfile.NamedTemporaryFile" in OPTISCALER_MANAGER_SCRIPT
    and "dir=destination_dir" in OPTISCALER_MANAGER_SCRIPT
    and "os.replace(partial, destination)" in OPTISCALER_MANAGER_SCRIPT
    and "test_concurrent_release_downloads_use_distinct_temporary_files" in OPTISCALER_MANAGER_TEST,
    "OptiScaler downloads must use per-transfer cache temp files and a concurrent regression test",
)
require(all(name in OPTISCALER_MANAGER_TEST for name in ("test_archive_links_and_special_files_are_rejected_before_extraction", "test_load_state_rejects_non_object_json_roots", "test_load_state_validates_nested_schema_paths_hashes_and_flags")), "manager tests must cover archive entry types and malformed state JSON")
require("def pci_class_code" in VM_XML_SYNC and "lspci" in VM_XML_SYNC and '"0300", "0302", "0380"' in VM_XML_SYNC and '"0401", "0403"' in VM_XML_SYNC and "same PCI domain:bus:slot" in VM_XML_SYNC, "manual VM XML sync must verify PCI classes and same-slot pairing")
require('cat > "$MOCK_BIN/lspci"' in MANUAL_VM_BOOTSTRAP_TEST and "class=0300" in MANUAL_VM_BOOTSTRAP_TEST and "class=0403" in MANUAL_VM_BOOTSTRAP_TEST, "manual VM bootstrap regression must mock lspci after the sync helper gained PCI-class checks")
require("different physical slots" in VM_XML_SYNC_TEST and "gpu_class=gpu_class" in VM_XML_SYNC_TEST and "audio_class=audio_class" in VM_XML_SYNC_TEST, "VM XML sync tests must reject wrong PCI classes and different slots")
require("scripts/sync-vm-xml.py" in RELEASING and "scripts/test-vm-xml-sync.py" in RELEASING and "scripts/sync-vm-xml.py" in RELEASE_WORKFLOW and "scripts/test-vm-xml-sync.py" in RELEASE_WORKFLOW, "release policy must document the out-of-flake VM XML sync helper and test allowlist")
require("## Audit finding fixes — 2026-11-03" in REPAIR, "repair report must record the new audit findings")
require("run #41603404803" in REPAIR and "3105ea2c90a17584e11a9776d0767f1de5d59221" in REPAIR and "Previous normal-CI reference (superseded)" in REPAIR and "current normal-CI verification for the reviewed snapshot is run #1120" in REPAIR, "repair report must distinguish the superseded parent CI from the reviewed-snapshot CI")
require("actions/runs/41608022759" in REPAIR and "8d1e4585c9cd3f690c1df80ee531008c7e9d30ef" in REPAIR and "artifact ID `13217103984`" in REPAIR, "repair report must record the reviewed-snapshot CI and canonical artifact")
require("OptiScaler-specific scope" in REPAIR and "Separately, the VFIO saved-state hook change" in REPAIR, "repair report must distinguish OptiScaler-only changes from the separate VFIO hook change")
require('if [ "$ACTION" = "restore" ]; then' in VFIO_HOOK and 'restore_vfio_state || exit 1' in VFIO_HOOK and "prepare_vfio" in VFIO_HOOK, "VFIO hook must route libvirt saved-state restore through the same preparation path")
require("RESTORE_XML_FILE" in VFIO_HOOK and 'cat -- "$RESTORE_XML_FILE"' in VFIO_HOOK, "VFIO restore hook must buffer and return the original XML only after successful preparation")
require('restore_vfio_state < "$RESTORE_INPUT" > "$RESTORE_OUTPUT"' in VFIO_HOOK_TEST and 'cmp -s "$RESTORE_INPUT" "$RESTORE_OUTPUT"' in VFIO_HOOK_TEST and "MOCK_PREPARE_STATUS=1" in VFIO_HOOK_TEST, "VFIO hook regression must test unchanged restore XML and fail-closed behavior")
require("scripts/test-vfio-hook-driver-state.sh" in CHECK_WORKFLOW and "scripts/test-vfio-hook-driver-state.sh" in CONTRIBUTING, "VFIO restore regression test must remain part of CI and contributor validation")
require("restore begin" in README and "restore begin" in STATE_INDEX and "target host" in README, "README/current-state index must describe saved-state restore support and its hardware validation boundary")
require(
    all(name in OPTISCALER_MANAGER_TEST for name in (
        "test_update_rollback_and_remove_restore_expected_states",
        "test_archive_paths_reject_traversal_and_absolute_paths",
        "test_first_install_rollback_restores_original_and_cleans_backups",
        "test_missing_rollback_backup_is_refused_before_targets_are_changed",
        "test_missing_original_backup_is_refused_before_removal_mutates_game",
        "test_state_write_failure_rolls_back_the_payload_and_original_files",
        "test_remove_io_failure_restores_the_pre_remove_game_state",
        "test_archive_size_limit_is_checked_before_extraction",
        "test_archive_without_complete_size_metadata_is_refused_before_extraction",
    )),
    "OptiScaler manager tests must cover missing backups, state-write rollback, partial removal recovery, and pre-extraction limits",
)
require("preflights every required backup" in OPTISCALER_MANAGER_DOC and "before extraction" in OPTISCALER_MANAGER_DOC, "OptiScaler manager guide must document backup preflight and pre-extraction size checks")
require("Before rotating an existing one-step rollback" in OPTISCALER_MANAGER_DOC and "per-game `flock` lock" in OPTISCALER_MANAGER_DOC, "OptiScaler manager guide must document atomic original backups and per-game command serialization")
require("docs/OPTISCALER-MANAGER.md" in RELEASING and "scripts/optiscaler_manager.py" in RELEASING and "scripts/test-optiscaler-manager.py" in RELEASING, "release guide must allowlist the standalone OptiScaler helper and its tests")
require("scripts/test-vfio-hook-driver-state.sh" in RELEASING and "scripts/test-vfio-hook-driver-state.sh" in RELEASE_WORKFLOW, "release ancestor allowlist must include the hook test script but not the system-affecting hook itself")

if errors:
    for error in errors:
        print(f"FAIL: {error}", file=sys.stderr)
    raise SystemExit(1)

print("OK: audit integrity, README/flake output, VM device/audio requirements, changelog supersession, and ZIP provenance checks passed.")
