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
UUID_GUIDE = (ROOT / "docs/UUID-AND-MACHINE-IDENTITY.md").read_text(encoding="utf-8")
OPTISCALER_DOC = (ROOT / "docs/OPTISCALER.md").read_text(encoding="utf-8")
OPTISCALER_MANAGER_DOC = (ROOT / "docs/OPTISCALER-MANAGER.md").read_text(encoding="utf-8")
OPTISCALER_MANAGER_SCRIPT = (ROOT / "scripts/optiscaler_manager.py").read_text(encoding="utf-8")
OPTISCALER_MANAGER_TEST = (ROOT / "scripts/test-optiscaler-manager.py").read_text(encoding="utf-8")
VM_XML_SYNC = (ROOT / "scripts/sync-vm-xml.py").read_text(encoding="utf-8")
VM_XML_SYNC_TEST = (ROOT / "scripts/test-vm-xml-sync.py").read_text(encoding="utf-8")
MANUAL_VM_BOOTSTRAP_TEST = (ROOT / "scripts/test-manual-vm-bootstrap.sh").read_text(encoding="utf-8")
VM_XML_VALIDATOR = (ROOT / "scripts/test-vm-xml.py").read_text(encoding="utf-8")
VM_XML_STRUCTURE_TEST = (ROOT / "scripts/test-vm-xml-structure.py").read_text(encoding="utf-8")
errors = []


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def extract_release_allowlists(
    releasing: str, workflow: str
) -> tuple[list[str], list[str]] | None:
    """Parse the documented and workflow release path lists exactly once."""
    marker = "**Exact release allowlist (literal paths only):**"
    if marker not in releasing:
        return None
    documented_block = releasing.partition(marker)[2].partition("\n\n")[0]
    documented_paths = re.findall(r"`([^`]+)`", documented_block)
    workflow_match = re.search(
        r"(?m)^\s*(\S[^\n]*?\.github/workflows/release\.yml)\)\s*$",
        workflow,
    )
    if workflow_match is None:
        return None
    workflow_paths = workflow_match.group(1).strip().split("|")
    if not documented_paths or not workflow_paths or any(not item for item in workflow_paths):
        return None
    return documented_paths, workflow_paths




release_allowlists = extract_release_allowlists(RELEASING, RELEASE_WORKFLOW)
if release_allowlists is None:
    documented_release_path_list: list[str] = []
    workflow_release_path_list: list[str] = []
else:
    documented_release_path_list, workflow_release_path_list = release_allowlists
documented_release_paths = set(documented_release_path_list)
workflow_release_paths = set(workflow_release_path_list)
require(
    release_allowlists is not None
    and len(documented_release_path_list) == len(documented_release_paths)
    and len(workflow_release_path_list) == len(workflow_release_paths)
    and documented_release_paths == workflow_release_paths
    and len(workflow_release_paths) == 42,
    "RELEASING.md and release.yml must contain the same unique exhaustive 42-path literal allowlist",
)
require(
    "no wildcard rules or blanket exemptions" in RELEASING
    and "changed path matches the exact literal allowlist documented in RELEASING.md" in RELEASE_WORKFLOW,
    "release policy must state that documentation/CI labels do not grant blanket path exemptions",
)
require(
    "40-path" not in CHANGELOG
    and "scripts/test-release-workflow-python.py" in CHECK_WORKFLOW
    and "scripts/test-release-workflow-python.py" in RELEASING
    and "scripts/test-release-workflow-python.py" in RELEASE_WORKFLOW
    and "scripts/test-release-workflow-python.py" in CONTRIBUTING
    and "scripts/test-release-workflow-python.py" in README,
    "the changelog must avoid a stale fixed path count and the release Python syntax test must be wired into CI, contributor docs, and both allowlists",
)






readme_top = "\n".join(README.splitlines()[:8])
require("docs/REPAIR-AND-VALIDATION-REPORT.md" in readme_top and "docs/AUDIT-2026-10-28-VM-XML-VFIO.md" not in readme_top, "README must point to the current repair report, not the older audit")
require("2026-11-04 source-tree cross-checks" in readme_top, "README must identify the current 2026-11-04 source-tree cross-check")
require(
    "NixOS-only first-start smoke test when the Windows disk is unavailable" in README
    and "/mnt/media/nixos-test.qcow2" in README
    and "90 GiB virtual capacity" in README
    and "/mnt/media/nixos-minimal-26.05.iso" in README
    and "The source template was not modified" in README
    and "validation of the unmodified dual-guest" in README,
    "README must preserve the scope and non-destructive boundary of the 11 November NixOS-only smoke test",
)
require(
    "2026-11-11" in REPAIR
    and "domxml-to-native qemu-argv" in REPAIR
    and "virsh define --validate" in REPAIR
    and "bus 1/device 2" in REPAIR
    and "installed guest boot" in REPAIR
    and "real Windows and installed-NixOS guest boot tests" in RELEASING,
    "the 11 November target test record must retain the tested steps, USB-address caveat, and remaining release gate",
)
require(
    "README.md#nixos-only-first-start-smoke-test-when-the-windows-disk-is-unavailable" in INSTALLATION
    and "NixOS-only VFIO first-start test" in STATE_INDEX
    and "NixOS-only VFIO first-start smoke test" in CHANGELOG,
    "README, installation guide, Turkish status index, and Unreleased changelog must cross-reference the NixOS-only smoke-test record",
)
require(
    "v1.5.0 source-archive snapshot note" in README
    and "8818bd86dd55f8b456708902f16b01bf2052fbd8" in README
    and "The v1.5.0 asset will not be rewritten" in README,
    "README must distinguish the immutable v1.5.0 release ZIP from later main-branch documentation",
)
require(
    "411,239 bytes" in REPAIR
    and "56c3d8dfde3eb0b224803ccefa1b624b831a15eca02aaf62d5c4fd4907ff8a3e" in REPAIR
    and "independent download-and-rehash" in REPAIR
    and "owner subsequently reported" in REPAIR
    and "410,138-byte / SHA-256" in REPAIR
    and "Only the acquisition/custody history of the original audit-time local copy remains unknown" in REPAIR,
    "v1.4.9 provenance must record the current GitHub asset digest and the owner-reported independent rehash while preserving the old local-copy boundary",
)
require(
    "VMXML-E-CDROM-SATA" in VM_XML_VALIDATOR
    and "VMXML-E-CDROM-SATA" in VM_XML_STRUCTURE_TEST,
    "VM XML structural tests must use a stable diagnostic code instead of English-message matching",
)
require(
    "EXPERIMENTAL: NOT END-TO-END TESTED ON A TARGET HOST" in INSTALLER
    and "EXPERIMENTAL — NOT END-TO-END TESTED" in README
    and all(
        "No end-to-end run of `install.sh` against a live NixOS/libvirt target host has been completed."
        in document
        for document in (
            README, INSTALLATION, CONTRIBUTING, DISCLAIMER,
            CHANGELOG, STATE_INDEX, REPAIR,
        )
    )
    and "The 9 November owner-reported clean-install/VM result does not establish that `install.sh` was used or tested." in README
    and "mocked installer-invariant/rollback tests" in README,
    "install.sh must be labeled experimental and static/mock coverage must not be presented as live target-host validation",
)
require(
    "docs/UUID-AND-MACHINE-IDENTITY.md" in README
    and "docs/UUID-AND-MACHINE-IDENTITY.md" in INSTALLATION
    and "[UUID and machine-identity safeguards](docs/UUID-AND-MACHINE-IDENTITY.md)" in STATE_INDEX,
    "README, installation guide, and status index must link the UUID safety guide",
)
require(
    "A filesystem UUID, a PARTUUID, and a LUKS UUID are different identifiers." in UUID_GUIDE
    and "intentional, not placeholders" in UUID_GUIDE
    and "Do not edit, regenerate, swap, or replace the committed host identifiers" in UUID_GUIDE,
    "UUID guide must distinguish host storage identifiers and warn against casual changes",
)
require(
    "Genuinely new VM" in UUID_GUIDE
    and "Existing VM" in UUID_GUIDE
    and "keeps the existing UUID, MAC, disk path" in UUID_GUIDE
    and "Do not manually replace the UUID in an existing `win10` domain" in UUID_GUIDE,
    "UUID guide must distinguish fresh VM identity from preservation of an existing domain",
)
require(
    "fresh UUID/MAC for a new XML" in INSTALLATION
    and "preserves the registered/on-disk identity" in INSTALLATION,
    "installation guide must warn that VM identity is fresh only for a new domain and preserved for existing VMs",
)
require("- [License](#license)" in README and "## License" in README, "README contents must link to the License section")
require(".git-cliff.toml" in README and "RELEASING.md" in README and ".github/workflows/release.yml" in README, "README repository map must include the release configuration, guide, and workflow")
require("Normal CI must pass for the exact tagged commit" in README, "README must require successful CI for the exact tagged commit")
require("successful full NixOS system build must exist for that commit or an ancestor" in README, "README must describe the permitted ancestor full-system build")
require(
    "BLK_DEV_RUST_NULL = lib.kernel.no;" in CONFIG
    and "CPUFREQ_DT_RUST = lib.kernel.no;" in CONFIG,
    "the CachyOS RT-Bore-LTO workaround must keep both unused Rust modules out of the failing module-BTF path",
)
cachyos_locked = FLAKE_LOCK.get("nodes", {}).get("cachyos-kernel", {}).get("locked", {})
cachyos_revision = cachyos_locked.get("rev")
require(
    isinstance(cachyos_revision, str) and re.fullmatch(r"[0-9a-f]{40}", cachyos_revision) is not None,
    "flake.lock must contain a full resolved CachyOS kernel revision",
)
historical_kernel_revision = "755712deee259ef7efbfe9154038a270c3d75a87"
kernel_limitations = README.split("## Known limitations", 1)[1].split("\n### ", 1)[0]
require(
    f"`{cachyos_revision}`" in kernel_limitations
    and "Build #18" in kernel_limitations
    and "ancestor source commit" in kernel_limitations
    and "exact v1.4.7 build" in kernel_limitations
    and "exact kernel SHA booted for that test was not recorded" in kernel_limitations,
    "README must tie the active kernel note to flake.lock and distinguish the ancestor build from unrecorded target-host kernel identity",
)
historical_kernel_section = README.split(
    "### Target-system validation update — 2026-11-03 (historical)", 1
)[1].split("\n## Repository map", 1)[0]
require(
    cachyos_revision != historical_kernel_revision
    and f"`{historical_kernel_revision}`" in historical_kernel_section
    and "historical physical kernel test" in historical_kernel_section
    and "must not be attributed to the newer kernel revision" in historical_kernel_section,
    "README must keep the 3 November physical test tied to its historical SHA, not the current flake.lock revision",
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
    "0c035b2cec37192444a8d587520a4a1d8b64ae88" in STATE_INDEX and "removed both from `boot.kernelParams`" in STATE_INDEX,
    "current-state index must identify the historical IOMMU-parameter removal",
)
require(
    "fbd105c869a856ca561a31692215aa17363a274a" in STATE_INDEX and "replaced that old block" in STATE_INDEX
    and "verify both devices with `lsusb`" in STATE_INDEX,
    "current-state index must trace the historical USB block replacement",
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
workflow_defined_step_count = len(re.findall(r"(?m)^      - (?:name|uses|run):", CHECK_WORKFLOW))
workflow_step_note = f"all {workflow_defined_step_count} workflow-defined steps"
require(
    workflow_defined_step_count == 28
    and workflow_step_note in CHANGELOG
    and workflow_step_note in STATE_INDEX
    and workflow_step_note in REPAIR
    and "runner-generated `Set up job` entry" in CHANGELOG
    and "runner-generated `Set up job` entry" in STATE_INDEX
    and "runner-generated `Set up job` entry" in REPAIR,
    "CI documentation must match the YAML-defined step count and distinguish GitHub's generated setup entry",
)
require(
    "`nixos-unstable`" in INSTALLATION
    and "`nixos/flake.lock`" in INSTALLATION
    and '`system.stateVersion = "26.05"`' in INSTALLATION
    and "does not pin the installed packages to the 26.05 channel" in INSTALLATION,
    "installation guide must distinguish the Live ISO release, flake package channel, and stateVersion",
)
require(
    "CREATE_MEDIA_PARTITION=yes" in INSTALLATION
    and "CREATE_MEDIA_PARTITION=no" in INSTALLATION
    and 'sudo sgdisk -n 4:0:0 -t 4:8300 -c 4:MEDIA "$DISK_REAL"' in INSTALLATION
    and 'sudo mkfs.ext4 -L media "${PART_PREFIX}4"' in INSTALLATION
    and 'fileSystems."/mnt/media".device' in INSTALLATION
    and "MEDIA_UUID" in INSTALLATION
    and "Expected exactly %s partitions" in INSTALLATION
    and "ext4 `/mnt/media`" in README
    and "Use a disk with at least 810 GiB of total capacity" in README
    and "when enabled, the media partition uses the remaining space" in README
    and "Use at least 810 GiB when creating the media partition" not in README
    and 'sudo blkid -s UUID -o value' in README
    and "fileSystems." in README
    and "/mnt/media" in README
    and "MEDIA_UUID=" in INSTALLER
    and "findmnt /mnt/media" in INSTALLER
    and 'fileSystems."/mnt/media"' in CONFIG,
    "installation, README, and migration helper must document the optional fourth ext4 media partition and its machine-specific UUID mapping",
)
require("DEGISIKLIK_GECMISI.md" in RELEASING and "DEGISIKLIK_GECMISI.md" in RELEASE_WORKFLOW and "CONTRIBUTING.md" in RELEASING and "CHANGELOG.md" in RELEASING and "docs/REPAIR-AND-VALIDATION-REPORT.md" in RELEASING and "docs/OPTISCALER.md" in RELEASING and "docs/OPTISCALER.md" in RELEASE_WORKFLOW and "INSTALLATION.md" in RELEASING and "INSTALLATION.md" in RELEASE_WORKFLOW and ".github/workflows/check.yml" in RELEASING and "scripts/test-documentation-integrity.py" in RELEASING, "RELEASING allowlist documentation must match release.yml")
require("grep -E '^v(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$' |" in RELEASE_WORKFLOW, "release workflow must use a closed stable-semver regex when finding previous tags")
require("stable `vMAJOR.MINOR.PATCH` form" in RELEASING and "numeric components must not contain" in RELEASING, "release guide must document the strict stable tag format")
require(
    "previous-tag-to-HEAD" in RELEASING
    and "first release-note" in RELEASING
    and "already carries another stable version tag" in RELEASING,
    "release guide must explain version range, heading validation, and duplicate-commit tag protection",
)
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
    "format('{0}..{1} --tag {2} --strip header', steps.previous.outputs.tag, github.sha, steps.release.outputs.tag)" in RELEASE_WORKFLOW
    and "github.event_name == 'push' && '--current --strip header'" in RELEASE_WORKFLOW,
    "tag pushes must use git-cliff --current while manual releases use the explicit previous-tag..HEAD range and requested version",
)
require(
    "manual dispatch from `main` uses the explicit previous-tag-to-`HEAD` range" in STATE_INDEX
    and "`--latest` is not used for the current manual-release path" in STATE_INDEX,
    "status index must describe the current explicit git-cliff manual-release range",
)
require(
    'sudo cp -a -- "$src" "$BACKUP_DIR/$backup_name"' in INSTALLER,
    "installer backups must read root-owned deployment targets through sudo",
)
require(
    'python3 "$REPO/scripts/check-home-snapper-layout.py" "$TARGET_HW"' in README
    and '"$REPO_DIR/scripts/check-home-snapper-layout.py" "$hardware_config" --allow-missing-snapshots' in INSTALLER
    and "existing child `@home/.snapshots` subvolume" in README
    and "--allow-missing-snapshots" in INSTALLER,
    "manual migration must require the existing child subvolume while installer mode permits only a missing child for its later transaction create step",
)
require(
    "check-home-snapper-layout.py" in INSTALLATION and "check-home-snapper-layout.py" in README,
    "README and INSTALLATION must direct manual checks through the shared Home Snapper validator",
)
require(
    all(item in INSTALLER for item in (
        "trap 'exit 130' INT",
        "trap 'exit 143' TERM",
        "trap 'exit 129' HUP",
        "trap 'rollback_deployment \"$?\"' EXIT",
    )),
    "installer must convert INT/TERM/HUP to non-zero exits before EXIT rollback",
)
require(
    'git tag --points-at "$GITHUB_SHA"' in RELEASE_WORKFLOW
    and "already has stable release tag(s)" in RELEASE_WORKFLOW,
    "manual releases must refuse a commit that already has another stable version tag",
)
require(
    r'rf"^## {re.escape(release_tag)} - \d{{4}}-\d{{2}}-\d{{2}}$"' in RELEASE_WORKFLOW
    and "Release notes heading does not match" in RELEASE_WORKFLOW,
    "release workflow must preserve literal date quantifiers inside its raw f-string",
)
LATEST_RELEASES_URL = "https://github.com/kUmutUK/nixos-hyprland-vfio/releases/latest"
require(
    f"[GitHub Releases]({LATEST_RELEASES_URL})" in README
    and f"[GitHub Releases]({LATEST_RELEASES_URL})" in RELEASING,
    "README and release guide must use the stable GitHub latest-release URL instead of a copied version number",
)
require(
    "does not require a follow-up documentation" in RELEASING
    and "manual-dispatch input" in RELEASING,
    "release guide must preserve manual version selection while documenting the dynamic latest-release link",
)
require("Verified full-system build baseline" in REPAIR,
        "repair report must identify the last completed full-system build baseline")
require(
    "all 28 workflow-defined steps" in CHANGELOG
    and "all 28 workflow-defined steps" in STATE_INDEX
    and "all 28 workflow-defined steps" in REPAIR
    and "runner-generated `Set up job` entry" in CHANGELOG
    and "runner-generated `Set up job` entry" in STATE_INDEX
    and "runner-generated `Set up job` entry" in REPAIR,
    "CI documentation must state the 28 YAML-defined steps and distinguish GitHub's generated setup entry",
)
nav_section = REPAIR.split("## MAKO Renderer integration", 1)[0]
require(
    "Last completed full-system build baseline" in nav_section
    and "Game graphics profile guidance" in nav_section
    and "CS2 frame-generation profile" in nav_section
    and "Source-tree audit hardening" in nav_section,
    "repair report navigation must include the build baseline and established historical sections",
)
require(
    'read -rp "Enter a non-empty monitor output name (e.g. DP-1): " input_mon' in INSTALLER
    and 'monitorOutput      = "DP-1"' in INSTALLATION,
    "installer and installation guide must use the same illustrative DP-1 monitor-output example",
)
repair_baseline_match = re.search(
    r"(?m)^\*\*Verified full-system build baseline:\*\* GitHub `main` at `([0-9a-f]{40})`",
    REPAIR,
)
index_baseline_match = re.search(
    r"(?m)^- \*\*Last completed full-system build baseline \(2026-11-09\):\*\* GitHub `main` at `([0-9a-f]{40})`",
    STATE_INDEX,
)
reviewed_snapshot_match = re.search(
    r"(?m)^\*\*Reviewed source snapshot:\*\* GitHub `main` at `([0-9a-f]{40})`",
    REPAIR,
)
index_reviewed_snapshot_match = re.search(
    r"(?m)^- Reviewed source snapshot \(2026-11-09\): GitHub `main` at `([0-9a-f]{40})`",
    STATE_INDEX,
)
ci_run_match = re.search(
    r"(?m)^- \*\*Normal CI for the reviewed snapshot:\*\* \[run #(\d+)\]\(https://github\.com/kUmutUK/nixos-hyprland-vfio/actions/runs/(\d+)\) completed successfully for the exact reviewed snapshot `([0-9a-f]{40})`",
    REPAIR,
)
build_run_match = re.search(
    r"manual \[run #(\d+)\]\(https://github\.com/kUmutUK/nixos-hyprland-vfio/actions/runs/(\d+)\) completed successfully for the \*\*same exact commit\*\* `([0-9a-f]{40})`",
    REPAIR,
)
require(repair_baseline_match is not None, "repair report must contain the full SHA of the last successful full-system build")
require(index_baseline_match is not None, "current-state index must contain the full SHA of the last successful full-system build")
require(reviewed_snapshot_match is not None, "repair report must identify the separately reviewed source snapshot")
require(index_reviewed_snapshot_match is not None, "current-state index must identify the separately reviewed source snapshot")
require(ci_run_match is not None, "repair report must link normal CI for the reviewed source snapshot")
require(build_run_match is not None, "repair report must link the last successful full-system build")
if repair_baseline_match and index_baseline_match:
    build_sha = repair_baseline_match.group(1)
    require(index_baseline_match.group(1) == build_sha,
            "status index and repair report must identify the same full-system baseline")
    require(build_run_match is not None and build_run_match.group(3) == build_sha,
            "manual full-system build must match the documented baseline SHA")
if reviewed_snapshot_match and index_reviewed_snapshot_match and ci_run_match:
    reviewed_sha = reviewed_snapshot_match.group(1)
    require(index_reviewed_snapshot_match.group(1) == reviewed_sha,
            "status index and repair report must identify the same reviewed source snapshot")
    require(ci_run_match.group(3) == reviewed_sha,
            "normal CI must cover the exact reviewed source snapshot")
require("[#" + (ci_run_match.group(1) if ci_run_match else "") + "]" in STATE_INDEX,
        "status index must reference the same normal-CI run as the repair report")
require("run #" + (build_run_match.group(1) if build_run_match else "") in STATE_INDEX,
        "status index must reference the same full-system build as the repair report")
require(
    "2026-11-05 (previous reviewed snapshot; historical)" in REPAIR
    and "Previous reviewed snapshot (historical, 5 November 2026)" in STATE_INDEX
    and "CI #1239" in REPAIR and "CI #1239" in STATE_INDEX
    and "42032980751" in REPAIR and "42032980751" in STATE_INDEX
    and "7f923a2c7aa59721bc00728faccbc073e06c697a" in REPAIR
    and "7f923a2c7aa59721bc00728faccbc073e06c697a" in STATE_INDEX,
    "the previous CI #1239 / v1.4.4 snapshot must remain explicitly historical",
)
require(
    all(item in (README + CHANGELOG + STATE_INDEX + REPAIR) for item in (
        "v1.4.7", "release run #23", "c28250c34de4b4349023681305da99dee75aac9e",
        "407,251 bytes", "d33e36df8b8d6891c522fe2b8d27fa3d149da042c9284527d314c2eda89e9a05"
    ))
    and "Historical release-source validation snapshot — v1.4.7" in README
    and "Latest published release at this snapshot" in STATE_INDEX
    and "Latest published release at this snapshot" in REPAIR,
    "v1.4.7 run, commit, and ZIP metadata must remain recorded as a dated historical snapshot",
)
require(
    all(item in (README + CHANGELOG + STATE_INDEX + REPAIR + RELEASING) for item in (
        "v1.4.6", "release run #20", "a6dd4544319fafa7ec517e73b31ad29a1b4010b3"
    ))
    and all(item in (README + CHANGELOG + STATE_INDEX + REPAIR) for item in (
        "402,118 bytes", "05ffe97ee342a4b233f56bc7ae0e455f3b91a1c87df86c42e57e0441e9089e76"
    )),
    "previous v1.4.6 release metadata must remain available as historical information",
)
v152_heading = CHANGELOG.find("## [v1.5.2] - 2026-11-11")
v151_heading = CHANGELOG.find("## [v1.5.1] - 2026-11-11")
v150_heading = CHANGELOG.find("## [v1.5.0] - 2026-11-10")
v149_heading = CHANGELOG.find("## [v1.4.9] - 2026-11-10")
v148_heading = CHANGELOG.find("## [v1.4.8] - 2026-11-09")
v147_heading = CHANGELOG.find("## [v1.4.7] - 2026-11-09")
require(
    v152_heading >= 0 and v151_heading > v152_heading and v150_heading > v151_heading
    and v149_heading > v150_heading and v148_heading > v149_heading and v147_heading > v148_heading
    and "v1.4.6 is the current published release" not in CHANGELOG,
    "CHANGELOG must list v1.5.1, v1.5.0, v1.4.9, v1.4.8, and v1.4.7 newest-first without a stale current-release claim",
)
require(
    all(item in CHANGELOG for item in (
        "418bb687ec4f4d539e3ccc2d839baf242552c018",
        "Release ID `441604359`",
        "Release workflow run [#32]",
        "43012396764",
        "Normal Nix Flake Check [#1396]",
        "43012004213",
        "451,101 bytes",
        "11c0b38fc3de7c8f99a089018ad89131e175ca323c6652a19573f13f40b082c6",
    )) and "v1.5.2" in STATE_INDEX and "v1.5.2" in README,
    "v1.5.2 must be recorded as the latest release with its exact tag commit, exact-tag CI result, and canonical ZIP size",
)
require(
    "exact tag commit `a20962f9be065f17c7c2ec143473c47b7a75aae9`" in CHANGELOG
    and "Normal CI #1309" in CHANGELOG
    and "410,138-byte" in CHANGELOG and "ad231d7529721eae343385cca9073790e4e3be61" in CHANGELOG,
    "v1.4.9 must distinguish the published a20962f tag from the preceding ad231d7 archive/CI snapshot",
)
require(
    all(item in CHANGELOG + REPAIR for item in (
        "ec2482a7ada57917dac37309f58ef29b6e5f0240",
        "7ea632afcca2daa41a7c88638ce2257f8892968a",
        "ae175f4999b89a340fbc0cf48ae24a6e41b68ece",
        "100755",
        "100644",
    )) and all(item in CHANGELOG + REPAIR + README + STATE_INDEX for item in (
        "43011838520", "43012004213", "43022490748", "43022565265", "43033685955",
        "aebea08f6169190d4df0af5d7a1f20e5e76f18f3",
    )) and all(f"#{n}" in CHANGELOG for n in (1395,1396,1397,1398,1399)),
    "the latest five main-branch CI outcomes and executable-mode regression must remain documented",
)
require(
    "2 h 24 min 56 s" in CHANGELOG and "2 h 24 min 56 s" in STATE_INDEX
    and "2 h 24 min 51 s" not in CHANGELOG + STATE_INDEX,
    "Build #13 duration must match its recorded 09:24:26–11:49:22 UTC interval",
)
require(
    "manual dispatch from `main` uses `--latest`" not in CHANGELOG
    and "previous note claiming that manual dispatch from `main` used `--latest` was incorrect and is withdrawn" in CHANGELOG
    and "`--latest` is not used for the current manual-release path" in STATE_INDEX,
    "git-cliff documentation must not claim that the current manual release path uses --latest",
)
require(
    "this is also the exact target of the published v1.4.9 tag, not an unreleased snapshot" in REPAIR
    and "42-path list" in REPAIR
    and "the earlier statement that manual dispatch from `main` used `--latest` was incorrect and is withdrawn" in REPAIR
    and "f46b8ac8" in REPAIR and "fbd105c8" in REPAIR
    and "The full-system-build workflow exposes only `workflow_dispatch` and declares no inputs for an arbitrary commit SHA" in REPAIR,
    "the independent audit reconciliation must keep release provenance, allowlist count, USB chronology, git-cliff history, and Build #19 dispatch semantics aligned",
)
require(
    "f46b8ac8" in CHANGELOG and "fbd105c8" in CHANGELOG
    and "ed6ca666" in CHANGELOG and "0c035b2c" in CHANGELOG and "91c4d58e" in CHANGELOG
    and "history does not prove when they were re-enabled" not in CHANGELOG,
    "USB and IOMMU chronology must agree with the dated commit history in the archive preface",
)
require(
    "Step 8" in INSTALLATION and "A clean install creates and mounts it in Section 6." not in INSTALLATION,
    "the Home Snapper child subvolume must be referenced to the actual Step 8 mount stage",
)
require(
    "The checked-in CachyOS lock in this tree resolves" not in CHANGELOG
    and "Historical lock snapshot" in CHANGELOG
    and "9df32f70be3550911f178b3ba9ad784996a4e80c" in CHANGELOG,
    "the old CachyOS revision must be dated as historical and kept distinct from the current flake.lock revision",
)
require(
    "## Previous exact-HEAD build and v1.4.2 release verification — 2026-11-05 (historical)\n\n## Previous verification follow-up" not in STATE_INDEX,
    "the status index must not retain a bodyless historical section heading",
)
if (ROOT / ".git").exists():
    tracked_file_list = subprocess.run(
        ["git", "-C", str(ROOT), "ls-files", "--cached", "-z"],
        check=True,
        stdout=subprocess.PIPE,
    ).stdout
    tracked_source_file_count = sum(bool(path) for path in tracked_file_list.split(b"\0"))
else:
    # Canonical source ZIPs intentionally omit .git metadata. Their extracted
    # regular files are the complete tracked-source inventory.
    tracked_source_file_count = sum(
        1
        for path in ROOT.rglob("*")
        if path.is_file()
        and ".git" not in path.parts
        and "__pycache__" not in path.parts
        and path.suffix != ".pyc"
    )
repo_map_count = re.search(
    r"not a complete inventory of the (\d+) tracked files",
    README,
)
require(
    "## Repository map (selected entry points; non-exhaustive)" in README
    and repo_map_count is not None
    and int(repo_map_count.group(1)) == tracked_source_file_count,
    "README repository-map tracked-file count must match the complete source tree (checkout and canonical ZIP)",
)
require(
    all(item in (README + CHANGELOG + STATE_INDEX + REPAIR) for item in (
        "v1.5.0", "440771489", "run #27", "42879152113", "8818bd86dd55f8b456708902f16b01bf2052fbd8",
        "Normal CI #1351", "42873188122", "423,969 bytes",
        "f886f40b2e6f73ab96dad67ab24d87b0734f955c8b26c6696c8746f6e8894ad0",
        "74 tracked files", "9 executable",
        "target_host_validated=true", "Build #18", "c6f4b955475de2ea16bc2b34c59a95dad3a1ae78",
    )),
    "v1.5.0 release identity, source ZIP, CI, and ancestor-build attestation boundary must be recorded across current documentation",
)
require(
    all(item in (README + CHANGELOG + STATE_INDEX + REPAIR) for item in (
        "v1.5.1", "441417217", "run #31", "42988284472", "c77db6f76f48ffc2640a7b242964a7b9b984bc0d",
        "Normal CI #1380", "42987182911", "437,544 bytes",
        "7a37d0687ff8580aed0cb34eb4f4479cf2918fff0e65433e3e264e5b6787272f",
        "66 commits", "Build #19",
    )),
    "v1.5.1 release metadata and outstanding Build #19 must be recorded across current documentation",
)
require(
    "4cef0c5f02bb2a466070b6a2c9b5468fd59af7da" in README
    and "42993935944" in README
    and "4cef0c5f02bb2a466070b6a2c9b5468fd59af7da" in STATE_INDEX
    and "42993935944" in REPAIR,
    "current-main CI #1382 must be distinguished from the published v1.5.1 tag",
)
require(
    "MAC addresses, serial numbers, machine IDs, filesystem UUIDs, or PARTUUIDs must remain in a private local record" in REPAIR
    and "private local record" in README,
    "reference-host identity inventory must remain private and must not be committed to this repository",
)
require(
    "group 18" in REPAIR and "group 19" in REPAIR
    and "Different group numbers alone do not prove a security weakness" in REPAIR
    and "Linux VFIO documentation" in README,
    "the GPU/audio IOMMU split must be documented without overclaiming an isolation defect",
)
require(
    "restored and published on 10 November" in RELEASING
    and "440298465" in RELEASING
    and "has no associated GitHub Release" not in RELEASING,
    "RELEASING must not claim the restored v1.4.3 GitHub Release is still absent",
)
require(
    all(item in CHANGELOG for item in (
        "Release run [#25]", "42807672922", "exact tag commit `a20962f9be065f17c7c2ec143473c47b7a75aae9`",
        "410,138-byte", "f28f91955d05679b7ff64cb33fbd193a86f87527f856b9801f0e7a197c1f5e61",
        "published 411,239-byte asset", "56c3d8dfde3eb0b224803ccefa1b624b831a15eca02aaf62d5c4fd4907ff8a3e",
        "Normal CI #1309", "42807151011", "preceding commit `ad231d7529721eae343385cca9073790e4e3be61`",
    )),
    "CHANGELOG must preserve exact v1.4.9 release, CI, source commit, and archive provenance",
)
require(
    all(item in CHANGELOG for item in (
        "release run [#24]", "42699056863", "31acc15e5f590d67ab9d9ee477c7813e0766fe82",
        "410,656 bytes", "4db66f4c856da157b8fc6995aaea7b86d40397868455976b21cb76566b1cadab",
        "Normal CI [#1306]", "42698412118",
    )),
    "CHANGELOG must preserve exact v1.4.8 release, CI, source commit, and archive provenance",
)
require(
    "Changes from the v1.4.8 tag are limited to documentation, CI workflow, and regression-test paths" in CHANGELOG
    and "v1.4.9 is not a new full-system build" in CHANGELOG
    and "At the time of this 5 November historical section, v1.4.5 was the then-current published release; v1.4.6 was published on 6 November" in CHANGELOG,
    "CHANGELOG must distinguish the v1.4.9 documentation-only release boundary and date the v1.4.6 status historically",
)
require(
    all(item in (README + CHANGELOG + STATE_INDEX + REPAIR) for item in (
        "run #18", "42597469118", "c6f4b955475de2ea16bc2b34c59a95dad3a1ae78",
        "BLK_DEV_RUST_NULL", "CPUFREQ_DT_RUST"
    )),
    "successful Build #18 and both Rust/BTF workaround symbols must be recorded",
)
require(
    "#1299" in README and "#1299" in CHANGELOG and "#1299" in STATE_INDEX and "#1299" in REPAIR
    and "42684408581" in README and "42684408581" in REPAIR,
    "normal CI #1299 must be consistently recorded for the exact v1.4.7 release snapshot",
)
require(
    "#1285" in README and "#1285" in CHANGELOG and "#1285" in STATE_INDEX and "#1285" in REPAIR
    and "42625179836" in README and "42625179836" in REPAIR,
    "normal CI #1285 must remain identified as the historical pre-release reviewed snapshot",
)
require(
    "cm_auto_hdr = 0" in HOME_NIX
    and "cm_auto_hdr = 0" in README
    and "cm_auto_hdr = 0" in CHANGELOG
    and "cm_auto_hdr = 0" in STATE_INDEX
    and "cm_auto_hdr = 0" in REPAIR
    and "did not separately measure HDR activation" in REPAIR,
    "the Home Manager automatic-HDR runtime setting and its hardware-validation boundary must be documented",
)
require(
    "manual full-system build #18 completed successfully" in README
    and "has not yet been confirmed by a successful full-system build" not in README,
    "README must mark the two-symbol Rust/BTF workaround as validated by full-system build #18",
)
require(
    "NixOS was installed from scratch" in README and "Windows 10 VFIO VM" in README
    and "Fresh-install and VM validation — 2026-11-09" in CHANGELOG
    and "Target-host validation (owner-reported, 9 November 2026)" in REPAIR
    and "clean NixOS installation from scratch" in STATE_INDEX
    and "Windows 10 VFIO VM" in INSTALLATION
    and "installed from scratch without issues" in CONTRIBUTING,
    "documentation must record owner-reported fresh-install and Windows VFIO VM validation",
)
require(
    "23 commits" in REPAIR and "23 commits" in CHANGELOG and "23 commits" in STATE_INDEX
    and "23 commits" in README and "23 commits" in INSTALLATION
    and "No claim is made that the full-system build workflow ran on the v1.4.7 commit" in REPAIR
    and "does not mean a new full-system build ran" in INSTALLATION,
    "build-to-release boundary must distinguish Build #18's exact ancestor SHA from the attested release snapshot",
)
require(
    "Target-system validation update — 2026-11-03" in README
    and "Target-machine hardware validation — 2026-11-03" in CHANGELOG
    and "Target-host hardware validation (2026-11-03)" in STATE_INDEX
    and "Target-system validation update — 3 November 2026" in INSTALLATION
    and "755712deee259ef7efbfe9154038a270c3d75a87" in INSTALLATION,
    "the 3 November target-host test must remain as dated historical information",
)
require(
    "latest target-machine update dated 2026-11-09" in CONTRIBUTING
    and "3 November 2026" in CONTRIBUTING,
    "contributor guide must distinguish latest and historical target-host validation",
)
require(
    "13403280716" in REPAIR and "376,179 bytes" in REPAIR
    and "sha256:d892c0ee1a7227c9e4f593c04ce19fe0e3f69b35b1ae7a2562ed8e0804c3309d" in REPAIR,
    "repair report must retain the historical canonical artifact from baseline CI #1233",
)
require(
    "13416329673" in REPAIR and "379,511 bytes" in REPAIR
    and "sha256:f9fdf7c3be15b69d032f4965e6765f841fd04f54e9096d2536091f5c01e267ed" in REPAIR,
    "repair report must retain the canonical artifact details for historical CI #1239",
)
require(
    "v1.4.4" in REPAIR and "run #15" in REPAIR and "v1.4.4" in STATE_INDEX and "run #15" in STATE_INDEX
    and "42035815458" in REPAIR and "42035815458" in STATE_INDEX,
    "the previous v1.4.4 release must remain recorded as a historical snapshot",
)
require(
    "v1.4.3 GitHub Release restored/published" in REPAIR
    and "440298465" in REPAIR
    and "2026-11-10 at 11:52:57 UTC" in REPAIR
    and "7f923a2c7aa59721bc00728faccbc073e06c697a" in REPAIR
    and "The older v1.4.4 release description still carries its incorrect v1.4.3 heading" in REPAIR,
    "repair report must distinguish the republished v1.4.3 Release from the historical v1.4.4 heading anomaly",
)
require(
    "manual Build #18" in REPAIR and "full-system build baseline" in REPAIR
    and "c6f4b955475de2ea16bc2b34c59a95dad3a1ae78" in REPAIR
    and "42597469118" in REPAIR,
    "repair report must identify Build #18 as the last completed full-system build baseline",
)
require(
    "Build #18" in STATE_INDEX and "42597469118" in STATE_INDEX
    and "c6f4b955475de2ea16bc2b34c59a95dad3a1ae78" in STATE_INDEX,
    "current-state index must match the last completed full-system build baseline",
)
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
    ".github/workflows/kernel-build.yml",
    ".github/workflows/release.yml",
    "CHANGELOG.md",
    "CONTRIBUTING.md",
    "DISCLAIMER.md",
    "DEGISIKLIK_GECMISI.md",
    "README.md",
    "INSTALLATION.md",
    "RELEASING.md",
    "docs/REPAIR-AND-VALIDATION-REPORT.md",
    "docs/UUID-AND-MACHINE-IDENTITY.md",
    "docs/OPTISCALER.md",
    "docs/OPTISCALER-MANAGER.md",
    "docs/MAKO.md",
    "docs/archive/DEGISIKLIK_GECMISI.md",
    "docs/archive/README.md",
    "docs/archive/HISTORICAL-AUDITS.md",
    "scripts/check-home-snapper-layout.py",
    "scripts/test-home-snapper-layout.py",
    "scripts/check-vm-iso-paths.py",
    "scripts/test-vm-iso-paths.py",
    "scripts/test-vm-xml.py",
    "scripts/test-vm-xml-structure.py",
    "scripts/extract-embedded-scripts.py",
    "scripts/test-extract-embedded-scripts.py",
    "scripts/prepare-vm-diagnostic.py",
    "scripts/test-vm-diagnostic.py",
    "scripts/test-vm-xml-paths.py",
    "scripts/test-installer-rollback.sh",
    "docs/archive/README.md",
    "scripts/optiscaler_manager.py",
    "scripts/test-mako-renderer.py",
    "scripts/test-optiscaler-manager.py",
    "scripts/sync-vm-xml.py",
    "scripts/test-vm-xml-sync.py",
    "scripts/test-manual-vm-bootstrap.sh",
    "scripts/test-installer-invariants.sh",
    "scripts/test-vfio-hook-driver-state.sh",
    "scripts/test-documentation-integrity.py",
    "scripts/test-release-workflow-python.py",
    "scripts/test-lsfg-vk-v2.py",
}
for path in verification_metadata_paths:
    require(path in RELEASE_WORKFLOW, f"release workflow must keep {path!r} in the full-build ancestor allowlist")
require("fetch-depth: 0" in CHECK_WORKFLOW, "normal CI must fetch full Git history for the verified-baseline ancestry check")
require(
    'archive_test_dir="$RUNNER_TEMP/source-archive-test"' in CHECK_WORKFLOW
    and 'unzip -q "$RUNNER_TEMP/nixos-hyprland-vfio-source.zip" -d "$archive_test_dir"' in CHECK_WORKFLOW
    and 'python3 "$archive_test_dir/nixos-hyprland-vfio/scripts/test-documentation-integrity.py"' in CHECK_WORKFLOW,
    "normal CI must run static documentation checks from the canonical source ZIP without Git metadata",
)
try:
    git_root_result = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
except OSError:
    git_root_result = None
git_checkout = (
    git_root_result is not None
    and git_root_result.returncode == 0
    and Path(git_root_result.stdout.strip()).resolve() == ROOT.resolve()
)
if git_checkout:
    current_head = os.environ.get("GITHUB_SHA")
    if not current_head:
        head_result = subprocess.run(
            ["git", "rev-parse", "--verify", "HEAD^{commit}"],
            cwd=ROOT,
            check=False,
            capture_output=True,
            text=True,
        )
        current_head = head_result.stdout.strip() if head_result.returncode == 0 else None
else:
    # Canonical git-archive ZIPs expand this file through .gitattributes.
    # They intentionally contain no .git directory or commit graph.
    try:
        current_head = (ROOT / "SOURCE_REVISION").read_text(encoding="ascii").strip()
    except (OSError, UnicodeError):
        current_head = None
require(
    current_head is not None
    and re.fullmatch(r"[0-9a-f]{40}", current_head or "") is not None,
    "documentation checks require either a Git checkout HEAD or a canonical source ZIP SOURCE_REVISION",
)
if git_checkout and current_head and repair_baseline_match:
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
            full_build_pending_paths = {"nixos/configuration.nix", "nixos/hooks/qemu", "install.sh", "nixos/home.nix", "nixos/flake.nix", "nixos/flake.lock", "nixos/hardware-configuration.nix", "nixos/mako-renderer.nix"}
            vm_xml_pending_paths = {"vm-xml/win10.xml"}
            unexpected = sorted(set(changed) - verification_metadata_paths - full_build_pending_paths - vm_xml_pending_paths)
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
            vm_xml_pending = sorted(set(changed) & vm_xml_pending_paths)
            if vm_xml_pending:
                require(
                    "`vm-xml/win10.xml`" in REPAIR
                    and "optional NixOS test disk" in REPAIR
                    and "libvirt/QEMU semantic validation" in REPAIR
                    and "real Windows and NixOS guest boot tests" in REPAIR
                    and "before this VM definition can enter the release allowlist" in REPAIR,
                    "the changed VM XML template must document its separate target-VM validation gate",
                )
                require(
                    "vm-xml/win10.xml" not in documented_release_paths
                    and "vm-xml/win10.xml" not in workflow_release_paths,
                    "the VM XML template must remain outside the release allowlist until target-VM validation is documented",
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
            if "nixos/configuration.nix" in pending:
                require(
                    "nixos/configuration.nix" in REPAIR
                    and "XCURSOR_THEME" in REPAIR
                    and "fresh full-system build is required before release" in REPAIR,
                    "configuration.nix runtime changes must document their full-system build gate",
                )
                require(
                    "nixos/configuration.nix" in RELEASING and "nixos/configuration.nix" not in RELEASE_WORKFLOW,
                    "configuration.nix must remain outside the ancestor-build release allowlist",
                )
            if "nixos/flake.nix" in pending:
                require(
                    "nixos/flake.nix" in REPAIR
                    and "fresh full-system build is required before release" in REPAIR,
                    "flake output changes must be documented as requiring a fresh full-system build",
                )
                require(
                    "nixos/flake.nix" in RELEASING and "nixos/flake.nix" not in RELEASE_WORKFLOW,
                    "nixos/flake.nix must remain outside the ancestor-build release allowlist",
                )
            if "nixos/flake.lock" in pending:
                require(
                    "nixos/flake.lock" in REPAIR
                    and "fresh full-system build is required before release" in REPAIR,
                    "flake-lock input updates must be documented as requiring a fresh full-system build",
                )
                require(
                    "nixos/flake.lock" in RELEASING and "nixos/flake.lock" not in RELEASE_WORKFLOW,
                    "nixos/flake.lock must remain outside the release ancestor-build allowlist until a new full-system build passes",
                )
            if "nixos/hardware-configuration.nix" in pending:
                require(
                    "nixos/hardware-configuration.nix" in REPAIR
                    and "lsblk -f" in REPAIR
                    and "sudo blkid" in REPAIR
                    and "findmnt" in REPAIR,
                    "host hardware-configuration updates must document storage-ID verification and the full-system build gate",
                )
                require(
                    "nixos/hardware-configuration.nix" in RELEASING
                    and "nixos/hardware-configuration.nix" not in RELEASE_WORKFLOW,
                    "nixos/hardware-configuration.nix must remain outside the release ancestor-build allowlist until a new full-system build passes",
                )
            if "nixos/mako-renderer.nix" in pending:
                require(
                    "nixos/mako-renderer.nix" in REPAIR
                    and "fresh full-system build is required before release" in REPAIR,
                    "the MAKO package source must be documented as requiring a fresh full-system build",
                )
                require(
                    "nixos/mako-renderer.nix" in RELEASING
                    and "nixos/mako-renderer.nix" not in RELEASE_WORKFLOW,
                    "the MAKO Nix derivation must remain outside the ancestor-build release allowlist",
                )


elif not git_checkout:
    print(
        "SKIP: Git ancestry/diff checks require .git history; "
        "static documentation checks ran using SOURCE_REVISION."
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
require("### Fifth audit follow-up — 2026-10-30" in CHANGELOG, "CHANGELOG must number the inferred fifth audit follow-up")
require("### Tenth audit follow-up — 2026-10-30" in CHANGELOG, "CHANGELOG must record the tenth audit follow-up")
require(
    all(item in STATE_INDEX for item in (
        "Fifth audit follow-up",
        "Sixth and seventh audit follow-ups",
        "Eighth, ninth, and tenth audit follow-ups",
        "Eleventh audit and release-workflow repair / twelfth audit update",
        "Supplied comprehensive audit cross-check — 2026-11-03",
    )),
    "root index must preserve traceability for the fifth through twelfth audits and the unnumbered comprehensive cross-check",
)
vm_xml_heading = "### VM XML and exact-HEAD audit reconciliation — 2026-11-04"
pypr_heading = "### Pyprland, PCI and cursor audit remediation — 2026-11-04"
require(
    CHANGELOG.find(vm_xml_heading) >= 0
    and CHANGELOG.find(pypr_heading) > CHANGELOG.find(vm_xml_heading),
    "CHANGELOG audit follow-ups must have unique descriptive names and a stable newest-first order",
)
require(
    STATE_INDEX.find(vm_xml_heading) >= 0
    and STATE_INDEX.find(pypr_heading) > STATE_INDEX.find(vm_xml_heading),
    "current-state index audit follow-ups must match CHANGELOG order",
)
require(
    "Ninth-audit remediation — 2026-11-04" not in CHANGELOG
    and "Tenth-audit reconciliation — 2026-11-04" not in CHANGELOG
    and "Ninth supplied audit cross-check — 2026-11-04" not in REPAIR
    and "Tenth supplied audit cross-check and exact-HEAD verification — 2026-11-04" not in REPAIR,
    "4 November audit records must not reuse the 30 October ninth/tenth audit labels",
)
require(
    "run ID 41603404803" in REPAIR
    and "run #41603404803" not in REPAIR
    and "run ID 41603404803" in STATE_INDEX
    and "run #41603404803" not in STATE_INDEX,
    "the 41603404803 value must be identified as a workflow run ID, not a run number",
)
cs2_start = CHANGELOG.find("### CS2 frame-generation profile — 2026-11-04")
mako_start = CHANGELOG.find("### MAKO Renderer integration — 2026-11-04", cs2_start)
cs2_entry = CHANGELOG[cs2_start:mako_start] if cs2_start >= 0 and mako_start > cs2_start else ""
require(
    "new full-system build gate" in cs2_entry and "Build #10" in cs2_entry and "before release" in cs2_entry,
    "CS2's home.nix change must explicitly reopen the full-system build gate",
)
require("$Format:%H# Changelog" not in CHANGELOG and "placeholder. Its embedded" not in CHANGELOG, "CHANGELOG must not contain the malformed heading/source-revision splice")
require("6b0111ca7cfb442d84bdbc22c516efbde2e90c6ea5a1f88bf9076317d99b4b11" in CHANGELOG and "587,335-byte ZIP" in CHANGELOG, "CHANGELOG must identify the most recently inspected supplied ZIP")
require("583,569 bytes" in REPAIR and "98d5b073a12488f604dfc9f434f3f741d52defce055d30f22db44102ed1be25d" in REPAIR and "65b0028cd76352daea9e5a01e4d7d9afb954b10b" in REPAIR, "repair report must record the independently measured current ZIP identity")
require("283,401 bytes" in REPAIR and "7abee4ca2a29e02cc3eea810c308f029603070c427a4758b3ceb399574b10a47" in REPAIR and "nine executable files" in REPAIR, "repair report must distinguish the verified canonical reproduction from the uploaded ZIP")
require("45 entries (29 files and 16 directories)" in REPAIR and "create_system=0" in REPAIR and "external_attr=0x00000000" in REPAIR, "repair report must record the uploaded ZIP metadata and embedded Git subtree")
require(REPAIR.count("## Supplied ZIP provenance and canonical packaging — 2026-10-30") == 1, "repair report must contain exactly one supplied-ZIP provenance section")
require("| ZIP described in the supplied seventh audit" in REPAIR and "Git export-substitution placeholder" in REPAIR, "seventh ZIP provenance row must include the complete archive identity record")
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
vm_disks = vm.findall("./devices/disk[@device='disk']")
vm_disk_targets = {
    disk.find("target").get("dev"): disk
    for disk in vm_disks
    if disk.find("target") is not None
}
nixos_guest_disk = vm_disk_targets.get("vdb")
vm_cdroms = vm.findall("./devices/disk[@device='cdrom']")
vm_cdrom_targets = {
    disk.find("target").get("dev"): disk
    for disk in vm_cdroms
    if disk.find("target") is not None
}
nixos_guest_tray = vm_cdrom_targets.get("sdd")
require(len(vm_disks) == 2 and vm_disk_targets.get("vda") is not None and nixos_guest_disk is not None, "VM XML must preserve the Windows vda disk and add a separate NixOS vdb disk")
require(nixos_guest_disk is not None and nixos_guest_disk.find("source") is not None and nixos_guest_disk.find("source").get("startupPolicy") == "optional", "the NixOS qcow2 disk must be optional so the Windows VM can start before it is created")
require(len(vm_cdroms) == 3 and nixos_guest_tray is not None and nixos_guest_tray.find("source") is None, "VM XML must retain the Windows/VirtIO CD-ROMs and a source-free NixOS sdd tray")
require("Install NixOS on a separate guest disk" in README and "/dev/vdb" in README and "/dev/vda" in README, "README must document the separate NixOS disk and protect the existing Windows disk during installation")
require(memory is not None and memory.get("unit") == "KiB" and (memory.text or "").strip() == "16777216", "VM XML memory no longer matches the documented 16 GiB")
require(vcpu is not None and (vcpu.text or "").strip() == "6", "VM XML vCPU count no longer matches the documented 6 vCPUs")
require(sound is not None and sound.get("model") == "ich9", "VM XML sound model no longer matches the README")
require('`audio type="none"`' in README and "has no host audio backend" in README, "README must explain that the ICH9 sound device has no host audio backend")
require("passed-through GPU HDMI/DP audio function" in README, "README must identify the passed-through GPU audio function as the guest audio path")
audio = vm.find("./devices/audio")
require(audio is not None and audio.get("type") == "none", "VM XML audio backend changed; update the README and review the intended guest audio path")
require("nix build .#lsfg-vk-v2" in README and "nix build .#lsfg-vk` command" not in README, "README must use the current LSFG-VK v2 flake output")
require(
    'with tempfile.TemporaryDirectory(prefix="vm-xml-sync-mock-") as mock_root:' in VM_XML_SYNC_TEST
    and 'template.parent / "mock-bin"' not in VM_XML_SYNC_TEST,
    "VM XML sync test mocks must be isolated in an automatically cleaned temporary directory",
)
require(
    'repo_mock_bin = ROOT / "vm-xml" / "mock-bin"' in VM_XML_SYNC_TEST
    and "run_sync left a repository-local mock directory behind" in VM_XML_SYNC_TEST,
    "VM XML sync regression must detect repository-local test artifacts",
)
require(
    'git -C .. status --porcelain --untracked-files=all' in CHECK_WORKFLOW
    and "source checkout clean" in CHECK_WORKFLOW,
    "normal CI must reject untracked or modified files left by validation",
)
require("packages.${system} = {" in FLAKE and "lsfg-vk-v2 = lsfgVkV2Package;" in FLAKE and "packages.${system}.lsfg-vk =" not in FLAKE, "README package command must match the declared grouped flake output")
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
input_buses = {(node.get("type"), node.get("bus")) for node in vm.findall("./devices/input")}
require({("mouse", "ps2"), ("keyboard", "ps2")}.issubset(input_buses), "VM XML must retain its separate emulated PS/2 mouse and keyboard inputs")
require("emulated PS/2 keyboard and mouse" in README and "emulated PS/2 keyboard and mouse" in INSTALLATION, "README and INSTALLATION must distinguish emulated PS/2 inputs from USB passthrough")
require("/run/libvirt/nix-emulators/qemu-system-x86_64" in README and "/run/libvirt/nix-ovmf/" in README and "NixOS's [libvirtd module]" in README, "README must document the NixOS QEMU and OVMF runtime paths")

require("## [Unreleased]" in CHANGELOG, "CHANGELOG must use the undated [Unreleased] heading")
require(
    not re.search(r"(?m)^#{1,6}\s+\d+(?:\.\d+){2,}\b", README),
    "README must not use an orphaned dotted-number heading without its parent section hierarchy",
)
require(
    "Dated third-level headings under `[Unreleased]` are editorial event labels" in CHANGELOG
    and "the top-level `[Unreleased]` bucket itself remains undated" in CHANGELOG,
    "CHANGELOG must distinguish dated editorial subheadings from dated release sections",
)
home_snapper_section = (
    CHANGELOG.partition("### Home Snapper preflight parsing — 2026-11-11")[2]
    .partition("\n### ")[0]
)
require(
    "separate optional NixOS VirtIO disk" not in home_snapper_section
    and "immutable v1.5.0 source-archive snapshot" not in home_snapper_section
    and "Replace brittle VM XML diagnostic text matching" not in home_snapper_section
    and "### Dual-guest VM disk layout — 2026-11-10" in CHANGELOG
    and "### v1.5.0 source archive and v1.4.9 asset provenance — 2026-11-10" in CHANGELOG
    and "### VM XML diagnostics and README bootstrap regression — 2026-11-10" in CHANGELOG,
    "Unreleased changelog workstreams must have separate dated headings rather than appearing under the unrelated Home Snapper heading",
)
require("update_qemu_hook_pci()" in INSTALLER and "if ! update_qemu_hook_pci" in INSTALLER, "installer must use the checked QEMU hook PCI updater and fail closed on error")
require(not re.search(r"(?m)^## (?:Unreleased|Previous unreleased changes)\s*[—-]\s*\d{4}-\d{2}-\d{2}", CHANGELOG), "CHANGELOG still gives an Unreleased heading a date")
require(
    "## Follow-up fixes — documented 2026-10-23 (includes earlier changes)" in CHANGELOG
    and "not a claim that every listed change first occurred on 23 October" in CHANGELOG,
    "23 October must be identified as the consolidation date, not the date of every historical change",
)
require("## Follow-up fixes — 2026-10-23" not in CHANGELOG, "CHANGELOG must not retain the ambiguous 23 October section heading")
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
ci_shellcheck = re.search(r"(?m)^\s+shellcheck -S warning (?P<files>[^\n]+)$", CHECK_WORKFLOW)
require(
    readme_bash_loop is not None and contrib_bash_loop is not None and ci_shellcheck is not None,
    "README, CONTRIBUTING, and CI must expose their complete Bash/ShellCheck script lists",
)
if readme_bash_loop is not None and contrib_bash_loop is not None and ci_shellcheck is not None:
    readme_bash_files = {line.strip().removesuffix("\\").strip() for line in readme_bash_loop.group("body").splitlines() if line.strip()}
    contributing_bash_files = set(contrib_bash_loop.group("body").split())
    ci_shellcheck_files = set(ci_shellcheck.group("files").split())
    require(readme_bash_files == contributing_bash_files, "README and CONTRIBUTING Bash syntax-check file lists have drifted")
    require(contributing_bash_files == ci_shellcheck_files, "CONTRIBUTING Bash syntax and CI ShellCheck file lists have drifted")

contributing_embedded_count = re.search(r"Expected (\d+) embedded Bash scripts", CONTRIBUTING)
ci_embedded_count = re.search(r'(?m)^\s+if \[ "\$n" -ne (\d+) \]; then$', CHECK_WORKFLOW)
require(
    contributing_embedded_count is not None
    and ci_embedded_count is not None
    and contributing_embedded_count.group(1) == ci_embedded_count.group(1) == "7",
    "CONTRIBUTING and CI must agree on the seven embedded Bash scripts",
)

require(
    "Full-system build run-number reconciliation" in REPAIR
    and "No run #14 record was present in the retrieved Actions history" in REPAIR
    and "Run #15 and #16 both succeeded on the same exact source commit" in REPAIR,
    "repair report must reconcile full-system build run numbers with the retrieved workflow history",
)
require(
    "379,511 bytes for the outer GitHub Actions ZIP wrapper" in REPAIR
    and "388,000-byte canonical inner source ZIP" in REPAIR
    and "7621fcdccfe327e9e59f453947b9f7903cd0f477b73cde8f4aa5ee513061e0ff" in REPAIR,
    "v1.4.4 artifact documentation must distinguish the outer artifact from the checksum-verified inner source ZIP",
)
require(
    "Build #11 ran on 4 November 2026 UTC" in REPAIR
    and "v1.4.2 was released on 5 November 2026" in REPAIR,
    "Build #11 run date must be distinguished from the next-day v1.4.2 release date",
)
require("Current configuration notes — 2026-11-04" in STATE_INDEX, "current-state index date is stale")
require("2026-10-28 entry" in STATE_INDEX and "2026-10-27 entry" not in STATE_INDEX, "root index must point to the 2026-10-28 CHANGELOG section")
require("copy all six required Nix/flake files" in README and "copy all five required Nix/flake files" not in README and "four flake files" not in README, "README must describe the six-file migration accurately")
require("approximately lines 8–16" in INSTALLATION, "INSTALLATION must point to the actual Home Manager customization block")
require(
    f"text = {chr(0xF023)};" in HOME_NIX
    and "N I X O S   /   K I N G   G R E Y" not in HOME_NIX
    and "ENTER PASSWORD TO UNLOCK" not in HOME_NIX
    and "text =   $USER" not in HOME_NIX
    and "path = screenshot" in HOME_NIX
    and "blur_passes = 3" in HOME_NIX
    and "blur_size = 7" in HOME_NIX
    and "brightness = 0.72" in HOME_NIX
    and "size = 480, 340" not in HOME_NIX
    and "position = 0, 72" in HOME_NIX
    and "valign = bottom" in HOME_NIX
    and re.search(r'(?m)^\s*text\s*=\s*;', HOME_NIX) is None,
    "Fullscreen Hyprlock must use a blurred screenshot, omit the center card and place the password field at the bottom",
)
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
require(
    "four Nix source files required at the time" in CHANGELOG
    and "fifth required source file" in CHANGELOG
    and "sixth" in CHANGELOG
    and "current preflight and regression coverage require all six" in CHANGELOG
    and "current preflight and regression coverage require all five" not in CHANGELOG,
    "CHANGELOG must distinguish the historical four/five-file preflight from the current six-file source tree",
)

require("ilk snapshot: 2026-10-19" in ARCHIVE and "önsöz son güncelleme: 2026-11-04" in ARCHIVE, "archive note must distinguish its snapshot date from the preface update date")
require("Bu 19 Ekim snapshot'ındaki XML yazma açıklaması güncel değildir" in ARCHIVE, "archive preface must mark the old installer XML-writing statement as superseded")
require("Aşağıdaki `[1.3.8]` ICH9 kaldırma kaydı" in ARCHIVE and "6e8d6cfe" in ARCHIVE and "46bf9015" in ARCHIVE, "archive preface must trace the ICH9 removal and restoration")
require("not byte-for-byte identical to the original changelog" in ARCHIVE_INDEX and "historical Turkish release entries" in ARCHIVE_INDEX, "archive index must distinguish preserved release entries from the added preface")
require("geçersiz kılındı" in ARCHIVE and "Bu ayar güncel değildir" in ARCHIVE, "archive note must mark old Reflex and SSH policies as superseded")
require("ile etkinleştirilmiştir. Uyumsuz" not in ARCHIVE, "archive must not present the old Reflex setting as current")
require(not re.search(r"parola girişi yalnız.*kullanıcısına izin verir", ARCHIVE), "archive must not present the old SSH password policy as current")

require("Supplied ZIP provenance and canonical packaging — 2026-10-30" in REPAIR, "repair report must identify the supplied ZIP measurements as noncanonical provenance")
require("565,429 bytes" in REPAIR and "89fab35d7ecd18bb2b39bb74cbf7b799f8d76bc4c9d59970e7e94060f82dc374" in REPAIR and "b413e6df50f64ab16d1694d9b19dae97a078f56c" in REPAIR, "repair report must record the third supplied ZIP without conflating it with the earlier archive")
require("Y-1 reassessment" in REPAIR and "post-restoration" in REPAIR and "nine-file" in REPAIR, "repair report must qualify the executable-mode chronology rather than call it a proven contradiction")
require("IOMMU history is traced:" in STATE_INDEX, "root history index must point to the correct historical section")
require(
    all(sha in STATE_INDEX for sha in (
        "ed6ca666cb3c34ea13abca0de874ff74a3eba686",
        "0c035b2cec37192444a8d587520a4a1d8b64ae88",
        "91c4d58e8ece033af76e628b8bdf80c857fb9d9b",
    ))
    and "`iommu=pt` is present in the tracked configuration by" in STATE_INDEX
    and "The 9 October `ed6ca666` change adds only `amd_iommu=on`" in STATE_INDEX
    and "removes both IOMMU parameters together with six other kernel parameters" in STATE_INDEX,
    "current-state index must distinguish the pre-existing iommu=pt option from the later amd_iommu=on addition and the broader removal",
)
require(
    all(sha in STATE_INDEX for sha in (
        "6e8d6cfed6d160c6bbd40939d22e742b1842f2a8",
        "46bf9015721515b123628a7c67cf43980c425e77",
    ))
    and "followed by a later restoration" in STATE_INDEX,
    "current-state index must trace the ICH9 removal and restoration commits",
)
require(
    all(sha in STATE_INDEX for sha in (
        "f46b8ac865366165111e6b939a65ba5a9670ddbb",
        "fbd105c869a856ca561a31692215aa17363a274a",
    ))
    and "replaced that old block" in STATE_INDEX,
    "current-state index must trace the old USB hostdev disablement and new active IDs",
)
require(
    all(sha in ARCHIVE for sha in ("ed6ca666", "0c035b2c", "91c4d58e", "6e8d6cfe", "46bf9015", "f46b8ac8", "fbd105c8")),
    "Turkish historical preface must reconcile IOMMU, ICH9, and USB commit chronology",
)
require("historical note under release `[1.3.6]` about `amd_iommu=on`" not in STATE_INDEX, "root history index retains the wrong amd_iommu section reference")
require("Aşağıdaki `[1.3.5]` kaydındaki IOMMU değişimi Git geçmişiyle eşleştirildi" in ARCHIVE and "Aşağıdaki `[1.3.6]`" not in ARCHIVE, "archive preface must point to the section that actually records amd_iommu=on")
require("### Earlier unreleased work (2026-10-28)" not in CHANGELOG, "CHANGELOG still has an empty same-level group heading")
require("### Eighth audit follow-up — 2026-10-30" in CHANGELOG, "CHANGELOG must record the eighth audit follow-up")
require("### Ninth audit follow-up — 2026-10-30" in CHANGELOG, "CHANGELOG must record the ninth audit follow-up")
require("Historical pre-v2 design note (superseded 2026-10-29)" in CHANGELOG and "That statement no longer describes the current configuration" in CHANGELOG, "CHANGELOG must clearly supersede the old LSFG-VK v1 decision")
require("byte-for-byte unchanged copy" in CHANGELOG and "preserved unchanged in" not in CHANGELOG, "CHANGELOG must describe the archive preface accurately")
require("approximately lines 8–16" in INSTALLATION and "approximately lines 9–15" not in INSTALLATION and "approximately lines 4–12" not in INSTALLATION, "INSTALLATION must point to the current home.nix let-block line range")
wallpaper = re.search(r'(?m)^\s*wallpaperVideo\s*=\s*"\$\{config\.home\.homeDirectory\}/Downloads/([^"]+)"\s*;', HOME_NIX)
require(wallpaper is not None and f"~/Downloads/{wallpaper.group(1)}" in INSTALLATION, "INSTALLATION wallpaper default must match the exact home.nix filename")
require("installer backups are not automatically pruned" in CHANGELOG, "CHANGELOG must describe current backup retention rather than the historical five-backup policy")
require("verified current kernel defaults" in CHANGELOG and "0c035b2c" in CHANGELOG and "91c4d58e" in CHANGELOG, "CHANGELOG must distinguish current kernel parameters and record the historical IOMMU transition")
require("amdgpu.ppfeaturemask" in CHANGELOG and "amdgpu.featuremask" not in CHANGELOG, "CHANGELOG must use the documented amdgpu.ppfeaturemask parameter name")
require("older `[1.2.0]` archive entry" in CHANGELOG and "`2a7a:8a47` is absent" in CHANGELOG and "f46b8ac8" in CHANGELOG and "fbd105c8" in CHANGELOG, "CHANGELOG must state current USB passthrough IDs and trace their history")
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
require(
    'name = "scratchterm-float"' in HOME_NIX
    and 'match = { class = "^(pypr-term)$" }' in HOME_NIX
    and 'command = "kitty --class pypr-term"' in HOME_NIX
    and 'class = "pypr-term"' in HOME_NIX,
    "Pypr terminal floating rule must match the configured scratchpad window class",
)
require(
    'XCURSOR_THEME = "Plus-Cursor";' in CONFIG
    and 'XCURSOR_THEME = "Plus-Cursor";' in HOME_NIX
    and 'hl.exec_cmd("hyprctl setcursor Plus-Cursor 20")' in HOME_NIX,
    "system, Home Manager, and Hyprland startup cursor themes must agree",
)
plus_cursor_start = HOME_NIX.find('  plusCursorTheme = pkgs.runCommand "plus-cursor-theme"')
plus_cursor_end = HOME_NIX.find("\n\n  pywal16Fixed", plus_cursor_start)
plus_cursor_definition = (
    HOME_NIX[plus_cursor_start:plus_cursor_end]
    if plus_cursor_start >= 0 and plus_cursor_end > plus_cursor_start
    else ""
)
require(
    'for cursor in "$src"/cursors/*;' in plus_cursor_definition
    and 'ln -sfn "$src/cursors/plus" "$theme/cursors/$(basename "$cursor")"' in plus_cursor_definition
    and "Every cursor shape resolves to the plus glyph" in plus_cursor_definition
    and "Inherits=" not in plus_cursor_definition
    and "for alias in left_ptr default arrow top_left_arrow pointer hand hand1 hand2 text xterm wait watch progress busy help crosshair;" in plus_cursor_definition
    and 'name = "Plus-Cursor";' in HOME_NIX
    and "package = plusCursorTheme;" in HOME_NIX
    and "gtk.enable = true;" in HOME_NIX
    and "x11.enable = true;" in HOME_NIX,
    "every cursor state must resolve to the plus glyph with no inherited theme or alternative cursor package",
)
require(
    "### Pyprland, PCI and cursor audit remediation — 2026-11-04" in CHANGELOG
    and "### Pyprland, PCI and cursor audit remediation — 2026-11-04" in STATE_INDEX
    and "pypr-term" in STATE_INDEX
    and "fresh full-system build is required before release" in REPAIR,
    "ninth-audit remediation and its build boundary must be recorded in current-state documents",
)
gamemode_renice_match = re.search(r"(?m)^\s*renice\s*=\s*(-?\d+);", CONFIG)
gamemode_comment_start = CONFIG.find("# Three components can change CPU scheduling/priority")
gamemode_comment_end = CONFIG.find("networking.hostName", gamemode_comment_start)
gamemode_comment_raw = (
    CONFIG[gamemode_comment_start:gamemode_comment_end]
    if gamemode_comment_start >= 0 and gamemode_comment_end > gamemode_comment_start
    else ""
)
# Join wrapped comment lines before checking the semantic description; source formatting
# should not make the regression depend on where a comment happens to wrap.
gamemode_comment = " ".join(
    re.sub(r"^\s*#\s?", "", line).strip()
    for line in gamemode_comment_raw.splitlines()
)
if gamemode_renice_match:
    gamemode_renice = int(gamemode_renice_match.group(1))
    applied_nice = -gamemode_renice
    nice_direction = (
        "lowering CPU scheduling priority" if applied_nice > 0
        else "raising CPU scheduling priority" if applied_nice < 0
        else "leaving CPU scheduling priority unchanged"
    )
    expected_nice = f"nice value ({applied_nice:+d})"
else:
    nice_direction = expected_nice = ""
require(
    gamemode_renice_match is not None
    and expected_nice in gamemode_comment
    and nice_direction in gamemode_comment,
    "GameMode comment must match the configured renice value and its CPU-priority direction",
)

package_start = CONFIG.find("environment.systemPackages = with pkgs; [")
package_end = CONFIG.find("\n  ];", package_start)
require(package_start >= 0 and package_end > package_start, "system package list must remain discoverable for the Steam ownership check")
if package_start >= 0 and package_end > package_start:
    require("\n    steam\n" not in CONFIG[package_start:package_end], "Steam must not be redundantly listed in environment.systemPackages")
    require("\n    bibata-cursors\n" not in CONFIG[package_start:package_end], "the original Bibata theme must not be separately exposed as a system cursor choice")
require("programs.steam.enable = true;" in CONFIG, "Steam must remain enabled through programs.steam.enable")

home_packages_match = re.search(
    r"(?ms)^  home\.packages = with pkgs; \[(.*?)^  \];",
    HOME_NIX,
)
require(
    home_packages_match is not None
    and re.search(r"(?m)^\s*eza\s*$", home_packages_match.group(1)) is None
    and re.search(r"(?m)^    eza = \{\s*\n      enable = true;", HOME_NIX) is not None,
    "eza must be owned by programs.eza.enable and must not be repeated in home.packages",
)
require(
    "fzf, git, and Kitty intentionally remain available in the system profile too" in HOME_NIX,
    "the system-profile fzf/git/Kitty entries must remain explicitly intentional",
)
require(
    "Hyprland sürüm kaydı upstream Nixpkgs kaynaklarıyla düzeltildi" in ARCHIVE
    and "7a0f122f5090cf4c2ade2a13a0e229d4e19ba71f" in ARCHIVE
    and "pkgs/by-name/hy/hyprland/package.nix" in ARCHIVE
    and "pkgs/by-name/hy/hyprlock/package.nix" in ARCHIVE
    and "0.56.2" in ARCHIVE
    and "0.9.6" in ARCHIVE
    and "tek başına çalışma zamanı ABI uyumluluğunu kanıtlamaz" in ARCHIVE,
    "the Turkish archive must source-link the corrected Hyprland/hyprlock versions and retain the ABI verification boundary",
)
require(
    "Fourteenth supplied audit cross-check — 2026-11-04" in REPAIR
    and "770,684-byte" in REPAIR
    and "not independently measured" in REPAIR,
    "the fourteenth audit reconciliation must preserve the supplied-ZIP verification boundary",
)
require(
    "historical; superseded by #10 on 2026-11-04" in REPAIR
    and "Latest full-system build — complete" not in REPAIR,
    "the 3 November build #9 section must not describe itself as the latest build after #10",
)
require(
    "records for audits 1–4 are not retained" in CHANGELOG
    and "intentionally unnumbered" in CHANGELOG,
    "CHANGELOG must explain the retained audit-numbering gap and unnumbered 3 November cross-check",
)

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
manual_attestation_input = RELEASE_WORKFLOW.partition("      target_host_validated:")[2].partition("\npermissions:")[0]
release_guard = RELEASE_WORKFLOW.partition("- name: Require successful CI and a current-enough full-system build")[2].partition("- name: Find previous version tag")[0]
require(
    "target_host_validated:" in RELEASE_WORKFLOW
    and "type: boolean" in manual_attestation_input
    and "default: false" in manual_attestation_input
    and "TARGET_HOST_VALIDATED: ${{ inputs.target_host_validated }}" in RELEASE_WORKFLOW
    and "GITHUB_REF" in release_guard
    and '"refs/heads/main"' in release_guard
    and 'TARGET_HOST_VALIDATED" == "true"' in release_guard
    and "manual target-host validation attestation" in release_guard
    and release_guard.index("--workflow check.yml") < release_guard.index('if [[ -z "$build_sha" ]]')
    and release_guard.index('if [[ -z "$build_sha" ]]') < release_guard.index("manual_host_attestation=0")
    and "target_host_validated" in RELEASING
    and "Tag-triggered releases cannot" in RELEASING,
    "manual target-host attestation must be explicit, main-only, and must not bypass exact CI or the successful ancestor build baseline",
)
require(
    "docs/UUID-AND-MACHINE-IDENTITY.md" in RELEASING
    and "docs/UUID-AND-MACHINE-IDENTITY.md" in RELEASE_WORKFLOW
    and "docs/UUID-AND-MACHINE-IDENTITY.md" in verification_metadata_paths,
    "the UUID identity guide must be an explicit single-path entry in both ancestor-build allowlists and their integrity set",
)
require(
    "- name: Documentation integrity and MAKO integration regression tests" in CHECK_WORKFLOW
    and "python3 scripts/test-documentation-integrity.py" in CHECK_WORKFLOW
    and "python3 scripts/test-mako-renderer.py" in CHECK_WORKFLOW,
    "the documentation test step name must disclose the MAKO regression suite it runs",
)
require(
    "- name: Build the pinned LSFG-VK v2 and MAKO packages" in CHECK_WORKFLOW
    and ".#lsfg-vk-v2" in CHECK_WORKFLOW
    and ".#mako-renderer" in CHECK_WORKFLOW,
    "the package build step name must disclose both LSFG-VK v2 and MAKO builds",
)
require("## Audit finding fixes — 2026-11-03" in REPAIR, "repair report must record the new audit findings")
for feature_title, hardware_check in (
    ("Apple keyboard function-row mapping", "Fn-media behavior"),
    ("ALC897 mixer-state persistence", "input routing"),
    ("Razer DeathAdder scroll-wheel bounce filter", "device hotplug"),
):
    feature_match = re.search(
        rf"(?ms)^- \*\*{re.escape(feature_title)}.*?(?=^- \*\*|\Z)",
        REPAIR,
    )
    feature_note = feature_match.group(0) if feature_match else ""
    require(
        feature_match is not None
        and "Build #18" in feature_note
        and "CI #1299" in feature_note
        and "ancestor baseline" in feature_note
        and "release run #23" in feature_note
        and hardware_check in feature_note
        and "fresh manual full-system build are required before release" not in feature_note,
        f"{feature_title} must distinguish completed ancestor build/exact-release CI from still-pending target-host hardware verification",
    )
require(
    "## Chronological navigation (newest first)" in REPAIR
    and "The detailed sections remain grouped by subject and source snapshot" in REPAIR,
    "repair report must provide chronological navigation while preserving its declared subject-based grouping",
)
require(
    "## Current supplied archive report reconciliation — 2026-11-04" in REPAIR
    and "e0880015" in REPAIR
    and "760,112-byte" in REPAIR
    and "54-entry" in REPAIR
    and "not independently verified" in REPAIR,
    "latest supplied ZIP identity conflict and unresolved .git-count outlier must remain explicitly unverified",
)
require("run ID 41603404803" in REPAIR and "run #41603404803" not in REPAIR and "3105ea2c90a17584e11a9776d0767f1de5d59221" in REPAIR and "Previous normal-CI reference (superseded)" in REPAIR and "current normal-CI verification for the reviewed snapshot is run #1120" in REPAIR, "repair report must distinguish the superseded parent CI run ID from the reviewed-snapshot workflow run number")
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
require("docs/MAKO.md" in RELEASING and "scripts/test-mako-renderer.py" in RELEASING and "docs/MAKO.md" in RELEASE_WORKFLOW and "scripts/test-mako-renderer.py" in RELEASE_WORKFLOW, "release policy must allowlist MAKO documentation/tests while keeping the Nix package source build-gated")
require("scripts/test-vfio-hook-driver-state.sh" in RELEASING and "scripts/test-vfio-hook-driver-state.sh" in RELEASE_WORKFLOW, "release ancestor allowlist must include the hook test script but not the system-affecting hook itself")

version_input_block = (
    RELEASE_WORKFLOW.partition("      version:")[2].partition("      target_host_validated:")[0]
)
require(
    bool(version_input_block)
    and 'description: "New, unused stable version tag (vMAJOR.MINOR.PATCH)"' in version_input_block
    and "required: true" in version_input_block
    and "default:" not in version_input_block
    and 'refs/tags/$release_tag' in RELEASE_WORKFLOW
    and 'Tag $release_tag already exists.' in RELEASE_WORKFLOW,
    "manual release must request an explicit, unused version and reject tags that already exist",
)
require(
    "new, unused" in RELEASING
    and "preselected default" in RELEASING
    and 'VERSION="vMAJOR.MINOR.PATCH"' in RELEASING,
    "release guide must direct maintainers to choose a new unused version rather than a stale published tag",
)

require(
    all(item in RELEASING and item in RELEASE_WORKFLOW for item in (
        "scripts/prepare-vm-diagnostic.py",
        "scripts/test-vm-diagnostic.py",
        "scripts/test-vm-xml-paths.py",
        "scripts/test-installer-rollback.sh",
    )),
    "standalone VM diagnostic and offline regression paths must match in the release guide and workflow allowlist",
)
require(
    "v1.4.6 release run #20 gate log" in CHANGELOG
    and "full-system build passed at a6dd4544319fafa7ec517e73b31ad29a1b4010b3" in REPAIR,
    "v1.4.6 release-gate evidence must remain distinguished from the unsupported missing-evidence claim",
)

host_continuity_note = (
    "The available records do not establish whether the 9 November clean-install/Windows VM lifecycle test and the 11 November NixOS-only first-start test were performed on the same physical host. The 11 November inventory records only the state observed during that test; it does not establish when or why the Windows domain and disk became unavailable. No host reinstall, disk removal, or machine change is inferred."
)
require(
    all(host_continuity_note in document for document in (README, REPAIR, STATE_INDEX, CHANGELOG)),
    "README, repair report, status index, and changelog must preserve the unresolved 9–11 November host-continuity boundary without inferring a machine change",
)

audio_rule_marker = 'wireplumber.extraConfig."51-vg27aq1a-no-suspend" = {'
audio_rule = CONFIG.partition(audio_rule_marker)[2].partition('extraConfig.pipewire.')[0]
require(
    bool(audio_rule)
    and '"monitor.alsa.rules"' in audio_rule
    and "alsa_output.pci-0000_0b_00.1.hdmi-stereo-extra4" in audio_rule
    and '"session.suspend-timeout-seconds" = 0;' in audio_rule
    and "~alsa_output.*" not in audio_rule,
    "WirePlumber idle-suspend workaround must target only the measured VG27AQ1A DP sink and set its suspend timeout to zero",
)
require(
    "VG27AQ1A DisplayPort audio resume" in README
    and "session.suspend-timeout-seconds = 0" in README
    and "activation of this exact rule and its persistence after reboot remain unverified" in README
    and "TARGET_HOST_VALIDATED=true" in README
    and "Release #32's job log records `TARGET_HOST_VALIDATED=true`" in CHANGELOG
    and "rule-specific sink test or post-reboot persistence check" in CHANGELOG
    and "owner-reported VG27AQ1A DisplayPort audio idle-resume fix" in REPAIR
    and "rule-specific checks remain open" in REPAIR
    and "temporary user-level WirePlumber rule" in STATE_INDEX,
    "the VG27AQ1A note must distinguish the general Release #32 attestation from rule-specific activation/persistence evidence",
)
require(
    "3c33b8b613c8c1da71263ea998607c11f046f22c" in README
    and "43008843993" in README
    and "3c33b8b613c8c1da71263ea998607c11f046f22c" in STATE_INDEX
    and "43008843993" in STATE_INDEX
    and "3c33b8b613c8c1da71263ea998607c11f046f22c" in REPAIR
    and "43008843993" in REPAIR,
    "the current main HEAD and passing Normal CI #1393 must be recorded consistently",
)
require(
    all(
        run_id in REPAIR
        for run_id in (
            "43002384121", "43002963707", "43005017515", "43005111853",
            "43005218908", "43005306029", "43008833713", "43008838190",
            "43008843993", "43011231703",
        )
    )
    and "DEGISIKLIK_GECMISI is not defined" in REPAIR
    and "also failed #1394" in REPAIR
    and "79 commits behind the pre-reconciliation `main` snapshot" in REPAIR,
    "the current-main CI failure/correction sequence and 79-commit Build #18 boundary must remain documented",
)

require(
    CHANGELOG.index("### Independent audit cross-check and preflight fixes — 2026-11-11")
    < CHANGELOG.index("## Historical releases"),
    "the current 11 November independent-audit/preflight entry must remain in [Unreleased], before Historical releases",
)
require(
    "run #20's job log" in README
    and "no manifest asset" in README
    and "397,725-byte reproduction was not independently rerun" in README
    and "Release #20's job log records" in CHANGELOG
    and "unresolved asset/workflow provenance mismatch" in REPAIR
    and "nixos-hyprland-vfio-source.zip" in REPAIR
    and "nixos-hyprland-vfio.zip" in REPAIR,
    "v1.4.6 documentation must distinguish the published Release API asset from the workflow's logged canonical output",
)
require(
    "Release #32's job log" in README
    and "TARGET_HOST_VALIDATED: true" in REPAIR
    and "five post-Build #18 paths outside the 42-path allowlist" in REPAIR
    and "does not create Build #19" in REPAIR,
    "v1.5.2 release documentation must record the confirmed manual target-host attestation and preserve the Build #19 boundary",
)
require(
    "   The UUID identity guide above" in RELEASING
    and "    The UUID identity guide above" not in RELEASING,
    "RELEASING step-4 UUID explanation must align with the three-space list continuation",
)

if (ROOT / ".git").exists():
    def historical_kernel_params(revision: str) -> str | None:
        result = subprocess.run(
            ["git", "show", f"{revision}:nixos/configuration.nix"],
            cwd=ROOT, text=True, capture_output=True, check=False,
        )
        if result.returncode != 0:
            return None
        match = re.search(
            r"(?ms)^\\s*boot\\.kernelParams\\s*=\\s*\\[(.*?)^\\s*\\];",
            result.stdout,
        )
        return match.group(1) if match else None

    ed_parent = historical_kernel_params("ed6ca666^")
    ed_added = historical_kernel_params("ed6ca666")
    removal_parent = historical_kernel_params("0c035b2c^")
    removal_commit = historical_kernel_params("0c035b2c")
    removed_kernel_options = (
        "transparent_hugepage=madvise", "iommu=pt", "amd_iommu=on",
        "usbcore.autosuspend=-1", "video=efifb:off",
        "amdgpu.ppfeaturemask=0xfffd7fff", "kvm.ignore_msrs=1", "pcie_aspm=off",
    )
    require(
        ed_parent is not None and ed_added is not None
        and '"iommu=pt"' in ed_parent and '"amd_iommu=on"' not in ed_parent
        and '"iommu=pt"' in ed_added and '"amd_iommu=on"' in ed_added,
        "Git history must prove that ed6ca666 added amd_iommu=on while iommu=pt already existed in its parent",
    )
    require(
        removal_parent is not None and removal_commit is not None
        and all(f'"{option}"' in removal_parent for option in removed_kernel_options)
        and all(f'"{option}"' not in removal_commit for option in removed_kernel_options),
        "Git history must prove that 0c035b2c removed both IOMMU flags and the six other recorded kernel parameters",
    )

if errors:
    for error in errors:
        print(f"FAIL: {error}", file=sys.stderr)
    raise SystemExit(1)

print("OK: audit integrity, README/flake output, VM device/audio requirements, changelog supersession, and ZIP provenance checks passed.")
