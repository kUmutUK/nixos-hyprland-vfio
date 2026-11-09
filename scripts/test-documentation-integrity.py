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
SOURCE_REVISION_PLACEHOLDER = "$" + "Format:%H" + "$"
errors = []


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


readme_top = "\n".join(README.splitlines()[:8])
require("docs/REPAIR-AND-VALIDATION-REPORT.md" in readme_top and "docs/AUDIT-2026-10-28-VM-XML-VFIO.md" not in readme_top, "README must point to the current repair report, not the older audit")
require("2026-11-04 source-tree cross-checks" in readme_top, "README must identify the current 2026-11-04 source-tree cross-check")
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
    and 'fileSystems."/mnt/media"' in CONFIG,
    "installation and README must document the optional fourth ext4 media partition and its machine-specific UUID mapping",
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
    'git tag --points-at "$GITHUB_SHA"' in RELEASE_WORKFLOW
    and "already has stable release tag(s)" in RELEASE_WORKFLOW,
    "manual releases must refuse a commit that already has another stable version tag",
)
require(
    r'rf"^## {re.escape(release_tag)} - \d{{4}}-\d{{2}}-\d{{2}}$"' in RELEASE_WORKFLOW
    and "Release notes heading does not match" in RELEASE_WORKFLOW,
    "release workflow must preserve literal date quantifiers inside its raw f-string",
)
release_heading_pattern = re.compile(rf"^## {re.escape('v1.4.5')} - \d{{4}}-\d{{2}}-\d{{2}}$")
require(
    release_heading_pattern.fullmatch("## v1.4.5 - 2026-11-05") is not None
    and release_heading_pattern.fullmatch("## v1.4.4 - 2026-11-05") is None
    and release_heading_pattern.fullmatch("## v1.4.5 - 2026-11-5") is None,
    "release-note heading regex must accept only the exact requested version and an ISO date",
)
require(
    "Last completed full-system build baseline — 2026-11-07" in REPAIR,
    "repair report must label the last completed full-system build baseline and avoid a duplicated heading",
)
audit_gate_line = "**Latest published release snapshot (5 November 2026):** GitHub `main` at `994b05c888fbb52295d93e8ef74e41bac66c5e65` at publication time; **normal CI:** run #1242 passed all 28 workflow-defined steps on this exact release commit; **full-system build:** manual [#13](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/42002113160) passed on ancestor build baseline `1dbb7d5407f5b478cee14da5d52dc0c1822d4e8b` (2 h 24 min 51 s); **published release:** [v1.4.5](https://github.com/kUmutUK/nixos-hyprland-vfio/releases/tag/v1.4.5) was published by release run #17 from this exact snapshot. The latest subsequent full-system build is manual run #16 on ancestor `a6dd4544319fafa7ec517e73b31ad29a1b4010b3`; changes after that build include kernel configuration, flake inputs/lock, and host hardware-configuration updates, so a new full-system build and successful normal CI on the exact candidate commit are required before a later release. The 3 November target-hardware validation remains owner-reported; libvirt saved-state/managed-save restore remains unverified."
require(
    audit_gate_line in REPAIR and audit_gate_line in STATE_INDEX and audit_gate_line in README,
    "the repair report, root status index, and README must show the same explicit reviewed-HEAD/full-build gate",
)
pre_reconciliation_main_line = "**Pre-reconciliation main verification (5 November 2026):** GitHub `main` at `4eb6a106d825890a929fe57054a1660da524a458`; normal CI [#1244](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/42076151633) passed all 28 workflow-defined steps on this exact commit and uploaded `nixos-hyprland-vfio-source` (artifact ID `13438456860`, 383,949 bytes; outer artifact digest `sha256:f04a477945bc2b47d7f8c7394a8f178895ed950bba2f245fae9b7aecdf553d97`). The preceding documentation-only commit `d35155ce6b9fb089934ee2f15f4208279dc5e2da` had CI #1243 fail at the documentation-integrity gate; commit `4eb6a10` restored the missing historical assertions and CI #1244 passed. This is the last completed validation before this documentation/test reconciliation; this follow-up requires its own exact-commit normal CI before a later release."
require(
    pre_reconciliation_main_line in README
    and pre_reconciliation_main_line in CHANGELOG
    and pre_reconciliation_main_line in STATE_INDEX
    and pre_reconciliation_main_line in REPAIR,
    "README, changelog, root index, and repair report must agree on the latest completed pre-reconciliation main CI and artifact",
)
require(
    "**Previous reviewed artifact (historical):** Normal CI #1239" in README
    and "13416329673" in README
    and "not the artifact for the pre-reconciliation main verification above" in README,
    "README must label CI #1239's v1.4.4 artifact as historical rather than current",
)
require(
    "[v1.4.5](https://github.com/kUmutUK/nixos-hyprland-vfio/releases/tag/v1.4.5)" in RELEASING
    and "published by release run #17 on 5 November 2026" in RELEASING,
    "release guide must identify v1.4.5 as the current published release while retaining the v1.4.3 tag anomaly as history",
)
require(
    "Thirteenth supplied audit cross-check — 2026-11-04" in REPAIR
    and "46 commits ahead" in REPAIR
    and "765,259-byte" in REPAIR
    and "SOURCE_REVISION export-subst" in REPAIR
    and "54-entry" not in REPAIR.split("## Thirteenth supplied audit cross-check", 1)[1].split("\n## ", 1)[0],
    "the thirteenth audit reconciliation must distinguish confirmed Git facts from unverified ZIP measurements",
)
nav_section = REPAIR.split("## MAKO Renderer integration", 1)[0]
require(
    "Last completed full-system build baseline" in nav_section
    and "Game graphics profile guidance" in nav_section
    and "CS2 frame-generation profile" in nav_section
    and "Source-tree audit hardening" in nav_section,
    "the repair report navigation must include the build baseline and related 4 November changelog updates",
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
    r"(?m)^- \*\*Last completed full-system build baseline \(2026-11-07\):\*\* GitHub `main` at `([0-9a-f]{40})`",
    STATE_INDEX,
)
reviewed_snapshot_match = re.search(
    r"(?m)^\*\*Reviewed source snapshot:\*\* GitHub `main` at `([0-9a-f]{40})`",
    REPAIR,
)
index_reviewed_snapshot_match = re.search(
    r"(?m)^- Reviewed source snapshot \(2026-11-07\): GitHub `main` at `([0-9a-f]{40})`",
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
require(
    "Previous reviewed snapshot (historical, 5 November 2026)" in REPAIR
    and "Previous reviewed snapshot (historical, 5 November 2026)" in STATE_INDEX
    and "run #1239" in REPAIR and "run #1239" in STATE_INDEX
    and "42032980751" in REPAIR and "42032980751" in STATE_INDEX
    and "7f923a2c7aa59721bc00728faccbc073e06c697a" in REPAIR
    and "7f923a2c7aa59721bc00728faccbc073e06c697a" in STATE_INDEX,
    "previous CI #1239 / v1.4.4 snapshot must remain clearly historical",
)
require(
    "994b05c888fbb52295d93e8ef74e41bac66c5e65" in README
    and "994b05c888fbb52295d93e8ef74e41bac66c5e65" in CHANGELOG
    and "994b05c888fbb52295d93e8ef74e41bac66c5e65" in STATE_INDEX
    and "994b05c888fbb52295d93e8ef74e41bac66c5e65" in REPAIR
    and "run #1242" in README and "run #1242" in CHANGELOG
    and "run #1242" in STATE_INDEX and "run #1242" in REPAIR
    and "release run #17" in README and "release run #17" in CHANGELOG
    and "v1.4.5" in STATE_INDEX and "v1.4.5" in REPAIR
    and "392,212 bytes" in README and "392,212 bytes" in CHANGELOG
    and "392,212 bytes" in STATE_INDEX and "392,212 bytes" in REPAIR
    and "f97fb12bdfbaaff4d32e7ab57bbc9251fababcd126a8ef7644947844924de9e0" in README
    and "f97fb12bdfbaaff4d32e7ab57bbc9251fababcd126a8ef7644947844924de9e0" in REPAIR,
    "the v1.4.5 release snapshot and its CI/build metadata must agree across documentation",
)
require(
    "run #13" in REPAIR and "run #13" in STATE_INDEX
    and "42002113160" in REPAIR and "42002113160" in STATE_INDEX
    and "2 h 24 min 51 s" in REPAIR and "2 h 24 min 51 s" in STATE_INDEX,
    "current full-system build #13, exact run ID, and duration must be recorded in both current-state documents",
)
require(
    "2026-11-03 update below" in README
    and "Target-system validation update — 2026-11-03" in README
    and "755712deee259ef7efbfe9154038a270c3d75a87" in README,
    "README must identify the latest 3 November target-host rebuild/kernel/VM validation",
)
require(
    "Target-machine hardware validation — 2026-11-03" in CHANGELOG
    and "755712deee259ef7efbfe9154038a270c3d75a87" in CHANGELOG
    and "Target-host hardware validation — 2026-11-03" in REPAIR
    and "Target-host hardware validation (2026-11-03)" in STATE_INDEX,
    "the changelog, repair report, and current-state index must preserve the dated owner-reported hardware validation",
)
require(
    "latest target-machine update dated 2026-11-03" in CONTRIBUTING
    and "Target-system validation update — 3 November 2026" in INSTALLATION
    and "755712deee259ef7efbfe9154038a270c3d75a87" in CONTRIBUTING
    and "755712deee259ef7efbfe9154038a270c3d75a87" in INSTALLATION,
    "contributor and installation guides must identify the latest 3 November target-host validation",
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
    "v1.4.3" in REPAIR and "no GitHub Release" in REPAIR and "incorrect" in REPAIR,
    "repair report must distinguish the legacy v1.4.3 tag and v1.4.4 heading anomaly",
)
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
    ".github/workflows/kernel-build.yml",
    ".github/workflows/release.yml",
    "CHANGELOG.md",
    "CONTRIBUTING.md",
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
    "scripts/optiscaler_manager.py",
    "scripts/test-mako-renderer.py",
    "scripts/test-optiscaler-manager.py",
    "scripts/sync-vm-xml.py",
    "scripts/test-vm-xml-sync.py",
    "scripts/test-manual-vm-bootstrap.sh",
    "scripts/test-installer-invariants.sh",
    "scripts/test-vfio-hook-driver-state.sh",
    "scripts/test-documentation-integrity.py",
    "scripts/test-lsfg-vk-v2.py",
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
            full_build_pending_paths = {"nixos/configuration.nix", "nixos/hooks/qemu", "install.sh", "nixos/home.nix", "nixos/flake.nix", "nixos/flake.lock", "nixos/hardware-configuration.nix", "nixos/mako-renderer.nix"}
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
    "Dated third-level headings under `[Unreleased]` are editorial event labels" in CHANGELOG
    and "the top-level `[Unreleased]` bucket itself remains undated" in CHANGELOG,
    "CHANGELOG must distinguish dated editorial subheadings from dated release sections",
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
require(readme_bash_loop is not None and contrib_bash_loop is not None, "README and CONTRIBUTING must both expose a full Bash syntax-check loop")
if readme_bash_loop is not None and contrib_bash_loop is not None:
    readme_bash_files = {line.strip().removesuffix("\\").strip() for line in readme_bash_loop.group("body").splitlines() if line.strip()}
    contributing_bash_files = set(contrib_bash_loop.group("body").split())
    require(readme_bash_files == contributing_bash_files, "README and CONTRIBUTING Bash syntax-check file lists have drifted")
require("Current configuration notes — 2026-11-04" in STATE_INDEX, "current-state index date is stale")
require("2026-10-28 entry" in STATE_INDEX and "2026-10-27 entry" not in STATE_INDEX, "root index must point to the 2026-10-28 CHANGELOG section")
require("copy all six required Nix/flake files" in README and "copy all five required Nix/flake files" not in README and "four flake files" not in README, "README must describe the six-file migration accurately")
require("approximately lines 8–16" in INSTALLATION, "INSTALLATION must point to the actual Home Manager customization block")
require(
    "text = ;" in HOME_NIX
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
    and "removed both from `boot.kernelParams`" in STATE_INDEX,
    "current-state index must identify the IOMMU parameter addition, removal, and clarification commits",
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
release_allowlist_match = re.search(
    r"(?s)\*\*Exact release allowlist \(literal paths only\):\*\*\s*(.*?)\n\n",
    RELEASING,
)
workflow_allowlist_match = re.search(
    r"(?m)^\s*(\S[^\n]*?\.github/workflows/release\.yml)\)\s*$",
    RELEASE_WORKFLOW,
)
if release_allowlist_match and workflow_allowlist_match:
    documented_release_paths = set(re.findall(r"`([^`]+)`", release_allowlist_match.group(1)))
    workflow_release_paths = set(workflow_allowlist_match.group(1).strip().split("|"))
else:
    documented_release_paths = set()
    workflow_release_paths = set()
require(
    documented_release_paths == workflow_release_paths and len(workflow_release_paths) == 27,
    "RELEASING.md and release.yml must contain the same exhaustive 27-path literal allowlist",
)
require(
    "no wildcard rules or blanket exemptions" in RELEASING
    and "changed path matches the exact literal allowlist documented in RELEASING.md" in RELEASE_WORKFLOW,
    "release policy must state that documentation/CI labels do not grant blanket path exemptions",
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
    RELEASE_WORKFLOW.partition("      version:")[2].partition("permissions:")[0]
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

if errors:
    for error in errors:
        print(f"FAIL: {error}", file=sys.stderr)
    raise SystemExit(1)

print("OK: audit integrity, README/flake output, VM device/audio requirements, changelog supersession, and ZIP provenance checks passed.")
