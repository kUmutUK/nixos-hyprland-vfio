#!/usr/bin/env bash
# Regression checks for installer, libvirt ownership/password setup, and English system UI.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$ROOT/install.sh"
README="$ROOT/README.md"
CONTRIBUTING="$ROOT/CONTRIBUTING.md"
ENGLISH_GUIDE="$ROOT/INSTALLATION.md"
CONFIG="$ROOT/nixos/configuration.nix"
FLAKE="$ROOT/nixos/flake.nix"
HOME_CONFIG="$ROOT/nixos/home.nix"
HOOK="$ROOT/nixos/hooks/qemu"

check_fail2ban_loopback_only() {
  python3 - "$1" <<'PY'
import re
import sys
from pathlib import Path

configuration = Path(sys.argv[1]).read_text(encoding="utf-8")
match = re.search(r"ignoreIP\s*=\s*\[(.*?)\]\s*;", configuration, re.DOTALL)
addresses = re.findall(r'"([^"]+)"', match.group(1)) if match else []
if len(addresses) != 2 or set(addresses) != {"127.0.0.0/8", "::1"}:
    raise SystemExit(1)
PY
}

bash -n "$INSTALLER"
bash -n "$ROOT/scripts/pci-address.sh"

# Exercise the exact shared PCI validator used by install.sh.
source "$ROOT/scripts/pci-address.sh"
for address in 0000:0b:00.0 0000:0B:00.0 0000:0B:00.7 0000:0b:1f.7 0000:0B:1F.0; do
  if ! valid_pci_address "$address"; then
    echo "FAIL: valid PCI address was rejected: $address" >&2
    exit 1
  fi
done
for address in 0000:0b:00.8 0000:0b:00.f 0000:0b:00 0000:0b:00.g 0000:0b:20.0 0000:0b:ff.0; do
  if valid_pci_address "$address"; then
    echo "FAIL: invalid PCI address was accepted: $address" >&2
    exit 1
  fi
done
if [[ "$(normalize_pci_address 0000:0B:00.0)" != "0000:0b:00.0" ]]; then
  echo "FAIL: PCI address normalization did not lowercase the address." >&2
  exit 1
fi

# Exercise the early Home Snapper filesystem preflight without touching the host.
home_preflight_test_dir="$(mktemp -d)"
trap 'rm -rf "${state_test_dir:-}" "$home_preflight_test_dir"' EXIT
awk '/^require_btrfs_home\(\) \{/ { capture=1 } capture { print } capture && /^}/ { exit }' "$INSTALLER" \
  > "$home_preflight_test_dir/require-btrfs-home.sh"
if ! grep -q '^require_btrfs_home() {' "$home_preflight_test_dir/require-btrfs-home.sh"; then
  echo "FAIL: could not locate require_btrfs_home() for its regression test." >&2
  exit 1
fi
cat > "$home_preflight_test_dir/harness.sh" <<'BASH'
set -euo pipefail
error() { printf '%s\n' "$*" >&2; return 1; }
findmnt() { printf '%s\n' "$TEST_HOME_FSTYPE"; }
source "$1"
require_btrfs_home
BASH
if ! TEST_HOME_FSTYPE=btrfs bash "$home_preflight_test_dir/harness.sh" "$home_preflight_test_dir/require-btrfs-home.sh"; then
  echo "FAIL: Btrfs /home was rejected by the installer preflight." >&2
  exit 1
fi
for filesystem in ext4 xfs unknown; do
  if TEST_HOME_FSTYPE="$filesystem" bash "$home_preflight_test_dir/harness.sh" "$home_preflight_test_dir/require-btrfs-home.sh" >/dev/null 2>&1; then
    echo "FAIL: non-Btrfs /home was accepted by the installer preflight ($filesystem)." >&2
    exit 1
  fi
done
home_preflight_call_line="$(grep -n '^require_btrfs_home$' "$INSTALLER" | cut -d: -f1)"
first_mutation_line="$(grep -n '^mkdir -m 700' "$INSTALLER" | head -n 1 | cut -d: -f1)"
if [[ -z "$home_preflight_call_line" || -z "$first_mutation_line" ]] \
  || (( home_preflight_call_line >= first_mutation_line )); then
  echo "FAIL: Home Snapper filesystem preflight must run before deployment/backup mutations." >&2
  exit 1
fi

# Exercise the real apply_state_version() helper without running the installer.
# The installer is interactive and performs system changes at top level, so only
# extract this pure helper and provide harmless stubs for sudo/log/error.
state_test_dir="$(mktemp -d)"

# Exercise the actual installer source preflight against temporary repository trees.
preflight_dir="$state_test_dir/source-preflight"
mkdir -p "$preflight_dir/repo/nixos"
preflight_function="$preflight_dir/validate-source.sh"
awk '/^validate_nixos_source_files\(\) \{/ { capture=1 } capture { print } capture && /^}/ { exit }' "$INSTALLER" \
  > "$preflight_function"
if ! grep -q '^validate_nixos_source_files() {' "$preflight_function"; then
  echo "FAIL: could not locate validate_nixos_source_files() for its regression test." >&2
  exit 1
fi
if ! grep -Fq 'REQUIRED_NIXOS_SOURCE_FILES=(configuration.nix home.nix flake.nix flake.lock)' "$INSTALLER"; then
  echo "FAIL: installer source preflight must declare all four required Nix source files." >&2
  exit 1
fi
cat > "$preflight_dir/harness.sh" <<'BASH'
set -euo pipefail
REPO_DIR="$1"
REQUIRED_NIXOS_SOURCE_FILES=(configuration.nix home.nix flake.nix flake.lock)
error() { printf '%s\\n' "$*" >&2; return 1; }
source "$2"
validate_nixos_source_files
BASH
for file in configuration.nix home.nix flake.nix flake.lock; do
  printf 'valid %s\\n' "$file" > "$preflight_dir/repo/nixos/$file"
done
if ! bash "$preflight_dir/harness.sh" "$preflight_dir/repo" "$preflight_function"; then
  echo "FAIL: complete non-empty Nix source set was rejected." >&2
  exit 1
fi

# Every required source must fail closed when missing or empty.
for file in configuration.nix home.nix flake.nix flake.lock; do
  source_file="$preflight_dir/repo/nixos/$file"
  mv "$source_file" "$source_file.saved"
  if bash "$preflight_dir/harness.sh" "$preflight_dir/repo" "$preflight_function" >/dev/null 2>&1; then
    echo "FAIL: missing required source was accepted: $file" >&2
    exit 1
  fi
  mv "$source_file.saved" "$source_file"
  cp "$source_file" "$source_file.saved"
  : > "$source_file"
  if bash "$preflight_dir/harness.sh" "$preflight_dir/repo" "$preflight_function" >/dev/null 2>&1; then
    echo "FAIL: empty required source was accepted: $file" >&2
    exit 1
  fi
  mv "$source_file.saved" "$source_file"
done

# The initial preflight must run before the risk acknowledgement and before backup creation.
preflight_call_line="$(grep -n "^validate_nixos_source_files$" "$INSTALLER" | head -n 1 | cut -d: -f1)"
acknowledgement_line="$(grep -n "Do you accept using this high-risk automated migration helper" "$INSTALLER" | cut -d: -f1)"
backup_line="$(grep -n '^mkdir -m 700' "$INSTALLER" | cut -d: -f1)"
if [[ -z "$preflight_call_line" || -z "$acknowledgement_line" || -z "$backup_line" ]] \
  || (( preflight_call_line >= acknowledgement_line || preflight_call_line >= backup_line )); then
  echo "FAIL: source preflight must precede user acknowledgement and backup/deployment work." >&2
  exit 1
fi
if grep -Fq 'Skipping missing file:' "$INSTALLER"; then
  echo "FAIL: required Nix source files must not be silently skipped during installation." >&2
  exit 1
fi


# Keep the development shell self-contained and documentation aligned with the shipped files.
if ! grep -Fq 'python3' "$FLAKE"; then
  echo "FAIL: the Nix development shell must include Python for repository tests." >&2
  exit 1
fi
if ! grep -Fq 'packages.${system}.lsfg-vk' "$FLAKE"; then
  echo "FAIL: the selected LSFG-VK package must be exposed for an explicit build check." >&2
  exit 1
fi
if ! grep -Fq 'LSFG-VK schema decision' "$README" \
  || ! grep -Fq 'v1 `[[game]]`/`exe` profile format' "$README" \
  || ! grep -Fq 'python3 scripts/test-lsfg-v1-config.py' "$ROOT/.github/workflows/check.yml" \
  || ! grep -Fq 'Build the selected LSFG-VK v1 package' "$ROOT/.github/workflows/check.yml"; then
  echo "FAIL: the documented LSFG-VK v1 schema decision must match the CI test/build contract." >&2
  exit 1
fi
if ! grep -Fq 'nixfmt --check' "$README" \
  || ! grep -Fq '├── .gitignore' "$README" \
  || ! grep -Fq '├── DISCLAIMER.md' "$README" \
  || ! grep -Fq 'Lossless Scaling' "$README" \
  || ! grep -Fq 'Lossless Scaling' "$ENGLISH_GUIDE" \
  || ! grep -Fq 'nixfmt --check' "$CONTRIBUTING" \
  || ! grep -Fq 'shellcheck -S warning install.sh scripts/pci-address.sh nixos/hooks/qemu' "$README" \
  || ! grep -Fq 'shellcheck -S warning install.sh scripts/pci-address.sh nixos/hooks/qemu' "$CONTRIBUTING" \
  || ! grep -Fq 'pci-address.sh' "$README" \
  || ! grep -Fq 'statix check .' "$README" \
  || ! grep -Fq 'deadnix .' "$README" \
  || ! grep -Fq 'statix check .' "$CONTRIBUTING" \
  || ! grep -Fq 'deadnix .' "$CONTRIBUTING" \
  || ! grep -Fq 'scripts/pci-address.sh' "$ROOT/.github/workflows/check.yml" \
  || ! grep -Fq 'statix check .' "$ROOT/.github/workflows/check.yml" \
  || ! grep -Fq 'deadnix .' "$ROOT/.github/workflows/check.yml"; then
  echo "FAIL: manual validation docs must match CI for formatting, PCI helper ShellCheck, Statix, and Deadnix." >&2
  exit 1
fi

if [[ "$(grep -c '^awk .*apply_state_version' "$0")" -ne 1 ]]; then
  echo "FAIL: installer invariant test helper block must appear exactly once." >&2
  exit 1
fi

awk '/^apply_state_version\(\) \{/ { capture=1 } capture { print } capture && /^}/ { exit }' "$INSTALLER" \
  > "$state_test_dir/apply-state-version.sh"
if ! grep -q '^apply_state_version() {' "$state_test_dir/apply-state-version.sh"; then
  echo "FAIL: could not locate apply_state_version() for its regression test." >&2
  exit 1
fi
cat > "$state_test_dir/state-version-harness.sh" <<'BASH'
sudo() { "$@"; }
error() { printf 'FAIL: %s\n' "$*" >&2; exit 90; }
log() { :; }
BACKUP_DIR="${TMPDIR:-/tmp}/state-version-test-backup"
source "$1"
apply_state_version "$2" "$3" "$4"
BASH
cat > "$state_test_dir/configuration.nix" <<'NIX'
system.stateVersion = "26.05";
NIX
# A blank value (the clean-install path) must leave the template default intact.
bash "$state_test_dir/state-version-harness.sh" \
  "$state_test_dir/apply-state-version.sh" \
  "$state_test_dir/configuration.nix" system.stateVersion ""
if ! grep -Fxq 'system.stateVersion = "26.05";' "$state_test_dir/configuration.nix"; then
  echo "FAIL: empty stateVersion must leave the repository template unchanged." >&2
  exit 1
fi
# A detected existing value must be written and then verified by the helper.
bash "$state_test_dir/state-version-harness.sh" \
  "$state_test_dir/apply-state-version.sh" \
  "$state_test_dir/configuration.nix" system.stateVersion 24.11
if ! grep -Fxq 'system.stateVersion = "24.11";' "$state_test_dir/configuration.nix"; then
  echo "FAIL: existing system.stateVersion was not applied to the copied template." >&2
  exit 1
fi
cat > "$state_test_dir/home.nix" <<'NIX'
home.stateVersion = "26.05";
NIX
bash "$state_test_dir/state-version-harness.sh" \
  "$state_test_dir/apply-state-version.sh" \
  "$state_test_dir/home.nix" home.stateVersion ""
if ! grep -Fxq 'home.stateVersion = "26.05";' "$state_test_dir/home.nix"; then
  echo "FAIL: empty home.stateVersion must leave the repository template unchanged." >&2
  exit 1
fi
bash "$state_test_dir/state-version-harness.sh" \
  "$state_test_dir/apply-state-version.sh" \
  "$state_test_dir/home.nix" home.stateVersion 24.11
if ! grep -Fxq 'home.stateVersion = "24.11";' "$state_test_dir/home.nix"; then
  echo "FAIL: existing home.stateVersion was not applied to the copied template." >&2
  exit 1
fi

# Test the installer’s source-selection logic separately from the destructive top-level flow.
state_source_helpers="$state_test_dir/read-state-version-functions.sh"
awk '/^extract_state_version\(\) \{/ { capture=1 } capture { print } capture && /^}/ { exit }' "$INSTALLER" > "$state_source_helpers"
awk '/^read_state_version\(\) \{/ { capture=1 } capture { print } capture && /^}/ { exit }' "$INSTALLER" >> "$state_source_helpers"
if ! grep -q '^extract_state_version() {' "$state_source_helpers" \
  || ! grep -q '^read_state_version() {' "$state_source_helpers"; then
  echo "FAIL: could not extract stateVersion source-selection helpers." >&2
  exit 1
fi
cat > "$state_test_dir/read-state-version-harness.sh" <<'BASH'
set -euo pipefail
warn() { printf 'WARN: %s\n' "$*" >&2; }
error() { printf 'ERROR: %s\n' "$*" >&2; exit 90; }
source "$1"
read_state_version "$2" "${@:3}"
printf '%s|%s\n' "$STATE_VERSION_VALUE" "$STATE_VERSION_SOURCE"
BASH
state_candidate_a="$state_test_dir/state-candidate-a.nix"
state_candidate_b="$state_test_dir/state-candidate-b.nix"
printf 'system.stateVersion = "24.11";\n' > "$state_candidate_a"
printf 'system.stateVersion = "24.11";\n' > "$state_candidate_b"
state_output="$(bash "$state_test_dir/read-state-version-harness.sh" "$state_source_helpers" system.stateVersion "$state_candidate_a" "$state_candidate_b")"
if [[ "$state_output" != "24.11|$state_candidate_a" ]]; then
  echo "FAIL: identical stateVersion candidates should preserve the established candidate priority." >&2
  exit 1
fi

# Conflicting existing files must prompt for explicit confirmation, not silently
# choose the first candidate, because either file may be an older snapshot.
printf 'home.stateVersion = "26.05";\n' > "$state_candidate_a"
printf 'home.stateVersion = "24.11";\n' > "$state_candidate_b"
printf '25.11\n' | bash "$state_test_dir/read-state-version-harness.sh" "$state_source_helpers" home.stateVersion "$state_candidate_a" "$state_candidate_b" \
  > "$state_test_dir/conflicting-state-output" 2> "$state_test_dir/conflicting-state-warning"
if ! grep -Fxq '25.11|user input after ambiguous/conflicting sources' "$state_test_dir/conflicting-state-output" \
  || ! grep -Fq 'Cannot safely infer home.stateVersion' "$state_test_dir/conflicting-state-warning"; then
  echo "FAIL: conflicting stateVersion candidates must require explicit user selection." >&2
  exit 1
fi

# A setting that exists but is duplicated or not a simple literal is ambiguous;
# the helper must not ignore it and silently use a different file's value.
printf 'system.stateVersion = "24.11";\nsystem.stateVersion = "26.05";\n' > "$state_candidate_a"
printf 'system.stateVersion = "24.11";\n' > "$state_candidate_b"
printf '25.05\n' | bash "$state_test_dir/read-state-version-harness.sh" "$state_source_helpers" system.stateVersion "$state_candidate_a" "$state_candidate_b" \
  > "$state_test_dir/ambiguous-state-output" 2> "$state_test_dir/ambiguous-state-warning"
if ! grep -Fxq '25.05|user input after ambiguous/conflicting sources' "$state_test_dir/ambiguous-state-output" \
  || ! grep -Fq 'ambiguous or non-literal' "$state_test_dir/ambiguous-state-warning"; then
  echo "FAIL: an ambiguous stateVersion assignment must require explicit user selection." >&2
  exit 1
fi

# A valid literal plus a second non-literal assignment must also be ambiguous.
printf 'system.stateVersion = "24.11";\nsystem.stateVersion = lib.mkDefault selectedVersion;\n' > "$state_candidate_a"
printf 'system.stateVersion = "24.11";\n' > "$state_candidate_b"
printf '25.07\n' | bash "$state_test_dir/read-state-version-harness.sh" "$state_source_helpers" system.stateVersion "$state_candidate_a" "$state_candidate_b" \
  > "$state_test_dir/mixed-state-output" 2> "$state_test_dir/mixed-state-warning"
if ! grep -Fxq '25.07|user input after ambiguous/conflicting sources' "$state_test_dir/mixed-state-output" \
  || ! grep -Fq 'ambiguous or non-literal' "$state_test_dir/mixed-state-warning"; then
  echo "FAIL: mixed literal/non-literal stateVersion assignments must require explicit user selection." >&2
  exit 1
fi

# An unreadable/invalid-UTF-8 candidate must not be treated as absent and
# silently replaced by the next file's value.
printf '\377' > "$state_candidate_a"
printf 'system.stateVersion = "24.11";\n' > "$state_candidate_b"
printf '25.09\n' | bash "$state_test_dir/read-state-version-harness.sh" "$state_source_helpers" system.stateVersion "$state_candidate_a" "$state_candidate_b" \
  > "$state_test_dir/unreadable-state-output" 2> "$state_test_dir/unreadable-state-warning"
if ! grep -Fxq '25.09|user input after ambiguous/conflicting sources' "$state_test_dir/unreadable-state-output" \
  || ! grep -Fq 'ambiguous or non-literal' "$state_test_dir/unreadable-state-warning"; then
  echo "FAIL: an unreadable stateVersion source must require explicit user selection." >&2
  exit 1
fi

# A genuinely new install, with no source files, keeps the repository default.
state_output="$(bash "$state_test_dir/read-state-version-harness.sh" "$state_source_helpers" system.stateVersion "$state_test_dir/missing-a" "$state_test_dir/missing-b")"
if [[ "$state_output" != "|repository default (new install)" ]]; then
  echo "FAIL: stateVersion defaults should be preserved only when no existing candidate exists." >&2
  exit 1
fi

# Guard against the former SC2154 typo: the warning must reference the declared
# gpu_iommu_dir variable, not an undeclared iommu_dir variable.
if grep -Eq '\$\{iommu_dir\}|\$iommu_dir([^[:alnum:]_]|$)' "$INSTALLER"; then
  echo "FAIL: undeclared iommu_dir variable reference remains in installer." >&2
  exit 1
fi
if ! grep -Fq 'if [ -z "$gpu_grp" ]; then' "$INSTALLER" || ! grep -Fq 'Could not resolve the GPU IOMMU group at ${gpu_iommu_dir}' "$INSTALLER"; then
  echo "FAIL: installer must abort when the GPU IOMMU group cannot be resolved." >&2
  exit 1
fi
if ! grep -Fq 'if [ -z "$audio_grp" ]; then' "$INSTALLER" || ! grep -Fq 'Could not resolve the GPU audio-function IOMMU group at ${audio_iommu_dir}' "$INSTALLER"; then
  echo "FAIL: installer must abort when the GPU audio-function IOMMU group cannot be resolved." >&2
  exit 1
fi
if grep -Fq 'Ensure IOMMU is enabled in firmware; skipping this check.' "$INSTALLER"; then
  echo "FAIL: installer must not skip the required IOMMU validation and continue." >&2
  exit 1
fi
if ! grep -Fq 'readlink -e -- "$link"' "$INSTALLER"; then
  echo "FAIL: IOMMU group resolution must require an existing canonical sysfs target." >&2
  exit 1
fi
if ! grep -Fq 'Installer failed after deployment began; restoring the prior NixOS/VFIO/XML files.' "$INSTALLER" \
  || ! grep -Fq "trap 'rollback_deployment \"\$?\"' EXIT" "$INSTALLER" \
  || ! grep -Fq '"$PATCHED_XML"; do' "$INSTALLER"; then
  echo "FAIL: installer must back up the deployed VM XML and roll back partial NixOS/VFIO/XML updates." >&2
  exit 1
fi
if ! grep -Fq 'Installer stopped before changing system configuration because the detected hardware is unsupported.' "$INSTALLER"; then
  echo "FAIL: installer must stop on unsupported CPU/GPU hardware rather than proceed with AMD-only settings." >&2
  exit 1
fi
if ! grep -Fq 'Documented target: AMD Radeon RX 6700 XT (Navi 22).' "$INSTALLER" \
  || ! grep -Fq "I ACCEPT THE RISKS" "$INSTALLER" \
  || ! grep -Fq "GPU compatibility was not acknowledged; no system files were changed." "$INSTALLER"; then
  echo "FAIL: installer must require explicit risk and target-GPU compatibility acknowledgements." >&2
  exit 1
fi
if ! grep -Fq 'RECOMMENDED APPROACH: Follow the manual migration steps in README.md first.' "$INSTALLER"; then
  echo "FAIL: installer must tell users that manual migration is the recommended default." >&2
  exit 1
fi
if grep -Fq 'rm -rf -- "$old_backup"' "$INSTALLER" || grep -Fq 'Keep the five newest installer backups' "$INSTALLER"; then
  echo "FAIL: installer must not delete old recovery backups automatically." >&2
  exit 1
fi
if ! grep -Fq 'The active libvirt hook is generated by NixOS and is not refreshed until a successful nixos-rebuild switch.' "$INSTALLER" \
  || ! grep -Fq 'The written VM XML is not applied with virsh define automatically' "$INSTALLER"; then
  echo "FAIL: installer must distinguish the hook source from the active hook and the written XML from a defined VM." >&2
  exit 1
fi
if [ "$(grep -Fc 'scripts/check-vm-iso-paths.py' "$INSTALLER")" -lt 2 ] \
  || ! grep -Fq 'Before defining the VM, validate the ISO/source paths in the synchronized XML:' "$INSTALLER" \
  || ! grep -Fq 'Only define the VM after the ISO/source preflight above passes and the guest is shut down.' "$INSTALLER"; then
  echo "FAIL: both installer VM-definition instructions must direct users through ISO/source preflight first." >&2
  exit 1
fi
if ! grep -Fq 'mkdir -m 700 -- "$BACKUP_DIR"' "$INSTALLER" \
  || ! grep -Fq 'Backup path already exists; refusing to reuse it:' "$INSTALLER"; then
  echo "FAIL: installer backups must be private and must not reuse an existing timestamp path." >&2
  exit 1
fi
if ! grep -Fq 'Preserve an existing valid hash; create one only if the file is missing or empty.' "$INSTALLER"; then
  echo "FAIL: installer checklist must preserve existing valid password hashes." >&2
  exit 1
fi
if ! grep -Fq 'if [ ! -s /etc/nixos/hashedPassword ]; then' "$INSTALLER"; then
  echo "FAIL: installer password instructions must only create the hash when missing or empty." >&2
  exit 1
fi
if ! grep -Fq '[[ "$group_num" =~ ^[0-9]+$ ]]' "$INSTALLER"; then
  echo "FAIL: IOMMU group IDs must be validated as numeric before use." >&2
  exit 1
fi
if grep -Eq 'basename "\$\(readlink -f .*iommu_group' "$INSTALLER"; then
  echo "FAIL: the old unsafe duplicate IOMMU group resolver remains." >&2
  exit 1
fi

# Test the SSH password-file preflight without touching /etc/nixos.
password_test_dir="$(mktemp -d)"
trap 'rm -rf -- "${state_test_dir:-}" "${monitor_test_dir:-}" "${password_test_dir:-}"' EXIT
awk '/^check_ssh_password_file\(\) \{/ { capture=1 } capture { print } capture && /^}/ { exit }' "$INSTALLER" > "$password_test_dir/check-password.sh"
if ! grep -q '^check_ssh_password_file() {' "$password_test_dir/check-password.sh"; then
  echo "FAIL: could not locate check_ssh_password_file() for its regression test." >&2
  exit 1
fi
cat > "$password_test_dir/harness.sh" <<'BASH'
warn() { :; }
log() { :; }
stat() { printf '%s\n' "${FAKE_STAT:-root:root:600}"; }
source "$1"
check_ssh_password_file "$2"
BASH
: > "$password_test_dir/empty"
if FAKE_STAT='root:root:600' bash "$password_test_dir/harness.sh" "$password_test_dir/check-password.sh" "$password_test_dir/missing"; then
  echo "FAIL: a missing SSH password file was accepted." >&2
  exit 1
fi
if FAKE_STAT='root:root:600' bash "$password_test_dir/harness.sh" "$password_test_dir/check-password.sh" "$password_test_dir/empty"; then
  echo "FAIL: an empty SSH password file was accepted." >&2
  exit 1
fi
printf 'test-hash\n' > "$password_test_dir/valid"
if FAKE_STAT='root:root:600' bash "$password_test_dir/harness.sh" "$password_test_dir/check-password.sh" "$password_test_dir/valid"; then :; else
  echo "FAIL: a non-empty root:root/0600 SSH password file was rejected." >&2
  exit 1
fi
if FAKE_STAT='localhost:users:644' bash "$password_test_dir/harness.sh" "$password_test_dir/check-password.sh" "$password_test_dir/valid"; then
  echo "FAIL: an insecure SSH password file was accepted." >&2
  exit 1
fi

assignment_line="$(awk '/^PATCHED_XML="\/var\/lib\/libvirt\/win10\.xml"$/ { print NR; exit }' "$INSTALLER")"
first_use_line="$(awk '/\$PATCHED_XML/ { print NR; exit }' "$INSTALLER")"
if [[ -z "$assignment_line" || -z "$first_use_line" || "$assignment_line" -ge "$first_use_line" ]]; then
  echo "FAIL: PATCHED_XML must be assigned before its first use." >&2
  exit 1
fi

# Exercise the actual path-boundary helper with a temporary deployment tree.
# Both the exact /etc/nixos-equivalent root and descendants must be rejected;
# a checkout outside the deployment tree must remain allowed.
repo_guard_dir="$(mktemp -d)"
trap 'rm -rf -- "${state_test_dir:-}" "${monitor_test_dir:-}" "${password_test_dir:-}" "${repo_guard_dir:-}"' EXIT
mkdir -p "$repo_guard_dir/nixos/repo/nixos" "$repo_guard_dir/outside/repo"
awk '/^ensure_repo_outside_deployment_target\(\) \{/ { capture=1 } capture { print } capture && /^}/ { exit }' "$INSTALLER" > "$repo_guard_dir/guard.sh"
if ! grep -q '^ensure_repo_outside_deployment_target() {' "$repo_guard_dir/guard.sh"; then
  echo "FAIL: could not locate the repository deployment-path guard." >&2
  exit 1
fi
cat > "$repo_guard_dir/harness.sh" <<'BASH'
error() { printf '%s\n' "$*" >&2; exit 1; }
source "$1"
ensure_repo_outside_deployment_target "$2" "$3"
BASH
nixos_target="$(cd "$repo_guard_dir/nixos" && pwd -P)"
nixos_root="$nixos_target"
nixos_nested="$(cd "$repo_guard_dir/nixos/repo" && pwd -P)"
outside_repo="$(cd "$repo_guard_dir/outside/repo" && pwd -P)"
if bash "$repo_guard_dir/harness.sh" "$repo_guard_dir/guard.sh" "$nixos_root" "$nixos_target" 2>/dev/null; then
  echo "FAIL: installer accepted a repository rooted at /etc/nixos." >&2
  exit 1
fi
if bash "$repo_guard_dir/harness.sh" "$repo_guard_dir/guard.sh" "$nixos_nested" "$nixos_target" 2>/dev/null; then
  echo "FAIL: installer accepted a repository nested beneath /etc/nixos." >&2
  exit 1
fi
if ! bash "$repo_guard_dir/harness.sh" "$repo_guard_dir/guard.sh" "$outside_repo" "$nixos_target"; then
  echo "FAIL: installer rejected a repository outside /etc/nixos." >&2
  exit 1
fi
if ! grep -Fq 'input_mon="$(trim_whitespace "$input_mon")"' "$INSTALLER"; then
  echo "FAIL: monitor input must be trimmed before it is accepted or used as a default." >&2
  exit 1
fi
if grep -Fq 'input_mon:-$monitor_output' "$INSTALLER"; then
  echo "FAIL: raw monitor input must not override the validated monitor default." >&2
  exit 1
fi

monitor_test_dir="$(mktemp -d)"
trap 'rm -rf -- "${state_test_dir:-}" "${monitor_test_dir:-}" "${password_test_dir:-}" "${repo_guard_dir:-}"' EXIT
awk '/^trim_whitespace\(\) \{/ { capture=1 } capture { print } capture && /^}/ { exit }' "$INSTALLER" > "$monitor_test_dir/trim.sh"
cat >> "$monitor_test_dir/trim.sh" <<'BASH'
set -e
whitespace_only="$(printf ' \t  ')"
[[ "$(trim_whitespace "$whitespace_only")" == "" ]]
[[ "$(trim_whitespace '  DP-3  ')" == "DP-3" ]]
BASH
if ! bash "$monitor_test_dir/trim.sh"; then
  echo "FAIL: monitor input trimming did not handle blank/padded input." >&2
  exit 1
fi

if ! grep -Fq 'scripts/sync-vm-xml.py' "$INSTALLER"; then
  echo "FAIL: installer must call the tested VM XML synchronization helper." >&2
  exit 1
fi
if ! grep -Fq 'REGISTERED_DOMAINS="$(sudo virsh list --all --name)"' "$INSTALLER" \
  || ! grep -Fq 'VM_XML_SYNCED=1' "$INSTALLER" \
  || ! grep -Fq 'No registered win10 domain or deployed VM XML exists.' "$INSTALLER" \
  || ! grep -Fq 'if [ "$VM_XML_SYNCED" -eq 1 ]; then' "$INSTALLER"; then
  echo "FAIL: migration must defer fresh VM XML creation when neither a registered domain nor deployed XML exists." >&2
  exit 1
fi
if ! grep -Fq 'git clone https://github.com/kUmutUK/nixos-hyprland-vfio.git "$REPO"' "$README" \
  || ! grep -Fq 'git clone https://github.com/kUmutUK/nixos-hyprland-vfio.git "$REPO"' "$ENGLISH_GUIDE" \
  || ! grep -Fq 'REPO="$HOME/nixos-hyprland-vfio"' "$README" \
  || ! grep -Fq 'REPO="$HOME/nixos-hyprland-vfio"' "$ENGLISH_GUIDE"; then
  echo "FAIL: clean-install VM preparation must create/use a persistent checkout after the Live ISO reboot." >&2
  exit 1
fi
for guide in "$README" "$ROOT/INSTALLATION.md"; do
  if ! grep -Fq 'SOURCE_REVISION="$(git -C /tmp/repo rev-parse --verify HEAD)"' "$guide" \
    || ! grep -Fq 'SOURCE_REVISION_FILE=/etc/nixos/.source-revision' "$guide" \
    || ! grep -Fq 'git -C "$REPO" checkout --detach "$SOURCE_REVISION"' "$guide" \
    || ! grep -Fq 'git -C "$REPO" status --porcelain --untracked-files=all' "$guide"; then
    echo "FAIL: clean-install VM setup must pin and verify the post-reboot checkout to the original commit." >&2
    exit 1
  fi
done

python3 - "$README" "$ROOT/INSTALLATION.md" <<'PY'
from pathlib import Path
import sys

for name in sys.argv[1:]:
    text = Path(name).read_text(encoding="utf-8")
    if name.endswith("README.md"):
        anchor = "After the first system activation and reboot, prepare the VM disk and define the domain."
    else:
        anchor = "# Run these commands after the first reboot, not from the live ISO."
    begin = text.index(anchor)
    fence = chr(96) * 3 + "bash\n"
    # In README the anchor is prose before the code block. In INSTALLATION.md
    # the anchor is a comment inside the block, so its opening fence is before it.
    if name.endswith("README.md"):
        start = text.index(fence, begin) + len(fence)
    else:
        start = text.rindex(fence, 0, begin) + len(fence)
    end = text.index("\n" + chr(96) * 3, start)
    block = text[start:end]
    required = (
        'BOOTSTRAP_XML="$STAGING_XML_DIR/win10.xml"',
        '"$REPO/vm-xml/win10.xml" "$BOOTSTRAP_XML" --domain win10',
        'scripts/check-vm-iso-paths.py" "$BOOTSTRAP_XML"',
        'qemu-img create -f qcow2 "$STAGED_DISK_PATH" 120G',
        'mv --no-clobber --no-target-directory -- "$STAGED_DISK_PATH" "$DISK_PATH"',
        'mv --no-clobber --no-target-directory -- "$BOOTSTRAP_XML" "$VM_XML"',
    )
    positions = [block.find(item) for item in required]
    if any(position < 0 for position in positions):
        raise SystemExit(f"FAIL: {name} is missing a staged new-VM bootstrap invariant.")
    if not positions[1] < positions[2] < positions[3] < positions[4] < positions[5]:
        raise SystemExit(f"FAIL: {name} must validate XML/ISOs and prepare the disk before publishing new-VM files.")
print("OK: both manual VM-preparation guides pin source revisions and stage XML/disk before publication.")
PY

if [ ! -s "$ROOT/scripts/test-extract-embedded-scripts.py" ] \
  || ! grep -Fq 'python3 scripts/test-extract-embedded-scripts.py' "$ROOT/.github/workflows/check.yml" \
  || ! grep -Fq 'python3 scripts/test-extract-embedded-scripts.py' "$ROOT/CONTRIBUTING.md"; then
  echo "FAIL: embedded-script extraction boundary regressions must be tested in CI and contributor validation." >&2
  exit 1
fi
if ! grep -Fq 'registered_domain_xml(domain)' "$ROOT/scripts/sync-vm-xml.py" \
  || ! grep -Fq '"dumpxml", "--inactive", domain' "$ROOT/scripts/sync-vm-xml.py" \
  || ! grep -Fq '"$PATCHED_XML" --domain win10' "$INSTALLER" \
  || ! grep -Fq '"$REPO/vm-xml/win10.xml" "$BOOTSTRAP_XML" --domain win10' "$README" \
  || ! grep -Fq '"$REPO/vm-xml/win10.xml" "$BOOTSTRAP_XML" --domain win10' "$ROOT/INSTALLATION.md" \
  || ! grep -Fq 'REGISTERED_DOMAINS="$(sudo virsh list --all --name)"' "$README" \
  || ! grep -Fq 'REGISTERED_DOMAINS="$(sudo virsh list --all --name)"' "$ROOT/INSTALLATION.md" \
  || ! grep -Fq 'grep -Fxq win10' "$README" \
  || ! grep -Fq 'grep -Fxq win10' "$ROOT/INSTALLATION.md"; then
  echo "FAIL: installer/manual VM preparation must prefer a validated registered libvirt XML and fail closed on query errors." >&2
  exit 1
fi
if ! grep -Fq 'only its two PCI hostdev source addresses were synchronized' "$ROOT/scripts/sync-vm-xml.py"; then
  echo "FAIL: VM XML helper must explicitly report its preservation behavior." >&2
  exit 1
fi
if ! grep -Fq 'preserving' "$ROOT/scripts/sync-vm-xml.py" || ! grep -Fq 'synchronize_pci_addresses' "$ROOT/scripts/sync-vm-xml.py"; then
  echo "FAIL: VM XML helper must preserve existing XML and validate PCI synchronization." >&2
  exit 1
fi

python3 - "$README" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
helper_call = 'sudo python3 "$REPO/scripts/sync-vm-xml.py"'
unsafe_copy = 'sudo cp ./vm-xml/win10.xml /var/lib/libvirt/win10.xml'
if helper_call not in text or 'generates a fresh UUID and MAC' not in text or unsafe_copy in text:
    raise SystemExit("FAIL: README must use the VM XML helper to synchronize PCI addresses and generate fresh identity for a new VM.")
if text.index('Path B — Manual migration of an existing NixOS installation (recommended)') > text.index('Path C — Optional `install.sh` migration helper (advanced users only; not the default recommendation)'):
    raise SystemExit("FAIL: README must put manual migration before the optional installer script.")
if 'use the manual installation steps first' not in text:
    raise SystemExit("FAIL: README must recommend manual installation before install.sh.")
if 'retains prior installer backups without automatically deleting them' not in text:
    raise SystemExit("FAIL: README must disclose that old recovery backups are retained.")
if "Before rebuilding, make sure `/etc/nixos/hashedPassword` exists" not in text:
    raise SystemExit("FAIL: README must document hashedPassword as a prerequisite for migration rebuilds.")
if 'sudo test -s /etc/nixos/hashedPassword' not in text or 'sudo chmod 600 /etc/nixos/hashedPassword' not in text:
    raise SystemExit("FAIL: README must check hashedPassword with sufficient privilege and restrict its permissions.")
if "sudo stat -c '%U:%G:%a' /etc/nixos/hashedPassword" not in text or 'root:root:600' not in text:
    raise SystemExit("FAIL: README must validate hashedPassword owner, group, and mode.")

install_guide = Path(sys.argv[1]).parent / "INSTALLATION.md"
guide_text = install_guide.read_text(encoding="utf-8")
if 'sudo python3 "$REPO/scripts/sync-vm-xml.py"' not in guide_text or '/etc/nixos/vm-xml/win10.xml' in guide_text:
    raise SystemExit("FAIL: INSTALLATION.md must use the checked-out XML helper instead of assuming the repository is inside /etc/nixos.")
install_command = guide_text.index("sudo nixos-install --flake /mnt/etc/nixos/nixos#nixos")
root_pass_command = guide_text.index("sudo nixos-enter --root /mnt -c 'passwd root'")
if root_pass_command < install_command:
    raise SystemExit("FAIL: INSTALLATION.md must place root password setup after successful nixos-install.")

config = Path(sys.argv[1]).parent / "nixos" / "configuration.nix"
config_text = config.read_text(encoding="utf-8")
service_start = config_text.index('systemd.services.libvirtd-qemu-ownership = {')
service_end = config_text.index('\n  };', service_start) + len('\n  };')
service_text = config_text[service_start:service_end]
if 'requires = [ "libvirtd-config.service" ];' not in service_text or 'after = [ "libvirtd-config.service" ];' not in service_text:
    raise SystemExit("FAIL: qemu ownership service must run after and require libvirtd-config.service.")
if '/var/lib/libvirt/qemu/nvram' not in service_text:
    raise SystemExit("FAIL: qemu ownership service must prepare the VM NVRAM directory.")
if 'fix_qemu_data_tree /var/lib/libvirt/qemu\n' in service_text or 'for d in /var/lib/libvirt/images /var/lib/libvirt/qemu ' in service_text:
    raise SystemExit("FAIL: ownership service must not chown the qemu config/network directory broadly.")
PY

if grep -q 'tr_TR\.UTF-8' "$CONFIG" "$HOME_CONFIG"; then
  echo "FAIL: a Turkish locale override remains in the active system or desktop configuration." >&2
  exit 1
fi

if ! grep -Fq 'boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-rt-bore-lto;' "$FLAKE"; then
  echo "FAIL: the flake must select the intended CachyOS RT-Bore-LTO kernel package." >&2
  exit 1
fi
# A blank monitorOutput intentionally disables live wallpaper, so the missing-file
# notification must be gated by the monitor argument rather than shown at every login.
# Commands are stored as ordinary Nix double-quoted strings so their Lua/shell
# arguments can be serialized safely. Literal shell quotes are escaped in the source.
if ! grep -Fq 'if [ -n \"$2\" ] && [ ! -e \"$1\" ]; then notify-send -t 15000 -u critical \"mpvpaper\" \"Live wallpaper file not found: $1' "$HOME_CONFIG" \
  || ! grep -Fq '${lib.escapeShellArg wallpaperVideo} ${lib.escapeShellArg monitorOutput}' "$HOME_CONFIG"; then
  echo "FAIL: missing-wallpaper notification must only run when live wallpaper is enabled." >&2
  exit 1
fi
if ! grep -Fq 'LOW_LATENCY_LAYER = "1";' "$CONFIG" || ! grep -Fq 'LOW_LATENCY_LAYER_REFLEX = "1";' "$CONFIG"; then
  echo "FAIL: the low-latency Vulkan layer and Reflex interface must be enabled system-wide." >&2
  exit 1
fi
if grep -Eq '^[[:space:]]*DISABLE_LOW_LATENCY_LAYER[[:space:]]*=' "$CONFIG" "$HOME_CONFIG"; then
  echo "FAIL: the global layer configuration must not disable the Vulkan latency layer." >&2
  exit 1
fi
if ! grep -Fq 'DISABLE_LOW_LATENCY_LAYER=1 %command%' "$README"; then
  echo "FAIL: README must document the per-game opt-out for incompatible Vulkan apps." >&2
  exit 1
fi
if ! grep -Fq 'fps_max 0' "$README" || ! grep -Fq 'fps_max 0' "$ROOT/INSTALLATION.md"; then
  echo "FAIL: both guides must document the upstream CS2/Source 2 frame-pacing workaround." >&2
  exit 1
fi
if [ ! -s "$ENGLISH_GUIDE" ] \
  || ! grep -Fq '[`INSTALLATION.md`](INSTALLATION.md)' "$README" \
  || ! grep -Fq 'sudo nixos-install --flake /mnt/etc/nixos/nixos#nixos' "$ENGLISH_GUIDE" \
  || ! grep -Fq "Type exactly 'WIPE \$DISK_REAL': " "$ENGLISH_GUIDE"; then
  echo "FAIL: the English installation guide must be linked and include the validated install steps." >&2
  exit 1
fi
if ! grep -Fq 'cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/master";' "$FLAKE"; then
  echo "FAIL: the CachyOS input must follow the upstream master branch, not a hard-coded tag." >&2
  exit 1
fi
# The generic lock-integrity check below validates the current master ref and hashes.
# Avoid tying this regression suite to one dated upstream kernel commit.
if ! grep -Fq 'nup = "sudo nix flake update --flake /etc/nixos/nixos cachyos-kernel";' "$HOME_CONFIG"; then
  echo "FAIL: nup must update only the CachyOS input against the absolute system flake path." >&2
  exit 1
fi
if grep -Fq -- '--accept-flake-config' "$HOME_CONFIG"; then
  echo "FAIL: nup must not silently auto-accept untrusted flake cache settings." >&2
  exit 1
fi
if grep -Fq 'RFC1918 home/LAN ranges are exempt' "$CONFIG"; then
  echo "FAIL: stale Fail2ban comments still claim private LAN ranges are exempt." >&2
  exit 1
fi
if ! check_fail2ban_loopback_only "$CONFIG"; then
  echo "FAIL: Fail2ban must exempt only loopback addresses, not private LAN addresses." >&2
  exit 1
fi
if ! grep -Fq 'check_ssh_password_file "$NIXOS_DIR/hashedPassword"' "$INSTALLER" || ! grep -Fq 'root:root:600' "$INSTALLER"; then
  echo "FAIL: installer preflight must check the SSH password hash file and its secure metadata." >&2
  exit 1
fi
if ! grep -Fq 'nix flake update --flake /etc/nixos/nixos cachyos-kernel' "$README" \
  || ! grep -Fq 'nix flake update --flake /etc/nixos/nixos cachyos-kernel' "$ROOT/INSTALLATION.md"; then
  echo "FAIL: both install guides must document how to update the CachyOS kernel input." >&2
  exit 1
fi
if grep -Fq 'nixos-install --flake /mnt/etc/nixos/nixos#nixos --accept-flake-config' \
    "$README" "$ROOT/INSTALLATION.md" "$ROOT/DEGISIKLIK_GECMISI.md" "$ROOT/docs/REPAIR-AND-VALIDATION-REPORT.md" \
  || grep -Fq 'nix flake update cachyos-kernel --accept-flake-config' \
    "$README" "$ROOT/INSTALLATION.md" "$ROOT/DEGISIKLIK_GECMISI.md" "$ROOT/docs/REPAIR-AND-VALIDATION-REPORT.md"; then
  echo "FAIL: active install/update guidance must not silently bypass flake cache-trust prompts." >&2
  exit 1
fi
if ! grep -Fq 'services.openssh = {' "$CONFIG" || ! grep -Fq 'PasswordAuthentication = false;' "$CONFIG" || ! grep -Fq 'KbdInteractiveAuthentication = false;' "$CONFIG" || ! grep -Fq 'PubkeyAuthentication = true;' "$CONFIG" || ! grep -Fq 'AllowUsers = [ "localhost" ];' "$CONFIG" || ! grep -Fq 'PermitRootLogin = "no";' "$CONFIG"; then
  echo "FAIL: SSH must require public-key authentication for localhost and disallow root login." >&2
  exit 1
fi
if ! grep -Fq 'allowedTCPPorts = [ 22 ];' "$CONFIG"; then
  echo "FAIL: the firewall must allow the configured SSH port." >&2
  exit 1
fi
if grep -Eq '^[[:space:]]*loginctl[[:space:]]+terminate-user' "$HOOK" || ! grep -Fq 'loginctl terminate-seat seat0' "$HOOK"; then
  echo "FAIL: VFIO handoff must preserve remote SSH sessions and terminate only seat0." >&2
  exit 1
fi
if ! grep -Fq 'Target-system validation update — 2026-10-23' "$README" || ! grep -Fq 'RT-Bore-LTO ThinLTO kernel compiled successfully' "$README"; then
  echo "FAIL: README must record the latest owner-reported RT-Bore-LTO target-system validation." >&2
  exit 1
fi
if ! grep -Fq 'On 2026-10-16' "$README" || grep -Fq 'The current RT-Bore-LTO variant has not yet been built or tested' "$README"; then
  echo "FAIL: README must keep the 2026-10-16 BORE-LTO result explicitly historical." >&2
  exit 1
fi
if ! grep -Fq 'In a later update dated 2026-10-23' "$CONTRIBUTING" || ! grep -Fq 'RT-Bore-LTO ThinLTO' "$CONTRIBUTING"; then
  echo "FAIL: CONTRIBUTING.md must describe the latest owner-reported RT-Bore-LTO validation." >&2
  exit 1
fi
if ! grep -Fq 'Target-system validation update — 23 October 2026' "$ENGLISH_GUIDE" || grep -Fq 'current RT-Bore-LTO kernel has not yet been validated' "$ENGLISH_GUIDE"; then
  echo "FAIL: INSTALLATION.md must distinguish the historical result from the latest RT-Bore-LTO validation." >&2
  exit 1
fi
if ! grep -Fq 'Monitor output name (for Hyprland monitor rule and mpvpaper wallpaper)' "$INSTALLER"; then
  echo "FAIL: the monitor prompt must explain that the setting affects both the Hyprland rule and mpvpaper." >&2
  exit 1
fi
if ! grep -Fq 'not published in the upstream CachyOS binary cache' "$README"; then
  echo "FAIL: README must disclose that RT-Bore-LTO requires a local build." >&2
  exit 1
fi

if grep -Rqi waypaper "$CONFIG" "$HOME_CONFIG" "$ROOT/install.sh" "$ROOT/.github" "$README"; then
  echo "FAIL: Waypaper remains in active configuration, installer, CI, or current README." >&2
  exit 1
fi

if grep -Fq '`lspci -nn`' "$INSTALLER"; then
  echo "FAIL: installer error text must not execute lspci using command substitution." >&2
  exit 1
fi

python3 - "$CONFIG" "$HOME_CONFIG" "$INSTALLER" "$ROOT/nixos/hooks/qemu" "$ROOT/vm-xml/win10.xml" <<'PY'
from pathlib import Path
import sys

# These are runtime/UI strings that accidentally regressed to Turkish in earlier revisions.
forbidden = (
    "Bağlı Değil", "Bağlantı yok", "Çeviri:", "Otomatik Çeviri", "Durduruldu",
    "bulunamadı", "Kullanılan:", "Toplam:", "Boş:", "CPU kullanımı:", "Güç Menüsü",
    "Şifre...", "altyazı|", "seçenekler|", "yaninda renderD", "KLAVYE/FARE GİRİŞİ",
    "GPU PCI adresi:", "GPU Audio PCI adresi:", "tee 644 acar", "Ollama API henüz hazır", "Renk",
)
for name in sys.argv[1:]:
    text = Path(name).read_text(encoding="utf-8")
    found = [word for word in forbidden if word in text]
    if found:
        raise SystemExit(f"FAIL: Turkish UI/comment strings remain in {name}: {', '.join(found)}")
PY

python3 - "$FLAKE" "$ROOT/nixos/flake.lock" <<'PY'
import json
import re
import sys
from pathlib import Path
flake_text = Path(sys.argv[1]).read_text(encoding="utf-8")
lock = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
node = lock["nodes"]["cachyos-kernel"]
locked = node["locked"]
if node["original"].get("ref") != "master":
    raise SystemExit("FAIL: the CachyOS lock must follow the upstream master branch.")
if locked["rev"] == "b1332396df6e880d7e3b6b451c6a74132ce8cf66":
    raise SystemExit("FAIL: the known stale 7.2.8 CachyOS lock revision has returned.")
if not re.fullmatch(r"[0-9a-f]{40}", locked.get("rev", "")) or not locked.get("narHash"):
    raise SystemExit("FAIL: CachyOS lock revision/hash must be complete.")
child = lock["nodes"][node["inputs"]["nixpkgs"]]["locked"]
if not re.fullmatch(r"[0-9a-f]{40}", child.get("rev", "")) or not child.get("narHash"):
    raise SystemExit("FAIL: the CachyOS nested nixpkgs lock revision/hash must be complete.")
if "linuxPackages-cachyos-rt-bore-lto" not in flake_text:
    raise SystemExit("FAIL: flake must select the RT-Bore-LTO package.")
PY

# Verify that the configured upstream CachyOS branch, flake lock, and current
# operator-facing instructions agree. Historical changelog entries are excluded.
python3 - "$FLAKE" "$ROOT/nixos/flake.lock" "$README" "$ROOT/INSTALLATION.md" "$ROOT/CHANGELOG.md" "$ROOT/DEGISIKLIK_GECMISI.md" "$ROOT/docs/REPAIR-AND-VALIDATION-REPORT.md" <<'PY_KERNEL_REF'
import json
import re
import sys
from pathlib import Path

flake_path, lock_path, readme_path, setup_path, changelog_path, tr_history_path, report_path = sys.argv[1:]
flake = Path(flake_path).read_text(encoding="utf-8")
lock = json.loads(Path(lock_path).read_text(encoding="utf-8"))
match = re.search(r'cachyos-kernel\.url\s*=\s*"github:xddxdd/nix-cachyos-kernel/([^"/]+)"', flake)
if not match:
    raise SystemExit("FAIL: could not determine CachyOS branch from nixos/flake.nix.")
branch = match.group(1)
locked_ref = lock["nodes"]["cachyos-kernel"]["original"].get("ref")
if locked_ref != branch:
    raise SystemExit(f"FAIL: flake branch {branch!r} and flake.lock original.ref {locked_ref!r} disagree.")

readme = Path(readme_path).read_text(encoding="utf-8")
if f"selected through the upstream `{branch}` flake input" not in readme:
    raise SystemExit("FAIL: README's active kernel summary does not match the CachyOS flake branch.")
if f"The flake follows the upstream `{branch}` branch" not in readme:
    raise SystemExit("FAIL: README's installation guidance does not match the CachyOS flake branch.")

setup = Path(setup_path).read_text(encoding="utf-8")
if f"CachyOS upstream `{branch}` input" not in setup:
    raise SystemExit("FAIL: INSTALLATION.md's kernel update instructions do not match the CachyOS flake branch.")

changelog = Path(changelog_path).read_text(encoding="utf-8")
unreleased = changelog.split("## Follow-up status", 1)[0]
if f"upstream `{branch}` branch" not in unreleased:
    raise SystemExit("FAIL: the current CHANGELOG section does not describe the configured CachyOS branch.")
if f"CachyOS `{branch}` input" not in unreleased:
    raise SystemExit("FAIL: the current CHANGELOG validation notes do not match the configured CachyOS branch.")

tr_history = Path(tr_history_path).read_text(encoding="utf-8")
if f"CachyOS upstream `{branch}` input" not in tr_history:
    raise SystemExit("FAIL: DEGISIKLIK_GECMISI.md's English current-state summary does not match the CachyOS flake branch.")

report = Path(report_path).read_text(encoding="utf-8")
if f"from the upstream `{branch}` input" not in report.split("## Corrections applied", 1)[0]:
    raise SystemExit("FAIL: the active status in docs/REPAIR-AND-VALIDATION-REPORT.md does not match the CachyOS flake branch.")

config = Path(Path(flake_path).parent / "configuration.nix").read_text(encoding="utf-8")
if 'networking.hostName = "nixos";' not in config:
    raise SystemExit("FAIL: the configured host name changed; update the host-name guidance if intentional.")
if 'The included configuration sets `networking.hostName = "nixos"`' not in readme or '`nixos/configuration.nix` sets the default hostname to `nixos`' not in setup:
    raise SystemExit("FAIL: host-name guidance in README/KURULUM is missing or stale.")
print(f"OK: CachyOS branch {branch!r}, lock, active docs, and host-name guidance are consistent.")
PY_KERNEL_REF

echo "OK: installer, VM/VFIO, English locale/UI, updateable RT-Bore-LTO selection, global Reflex, SSH access, and SSH-preserving VFIO handoff invariants passed."


# The migration installer must fail closed on NixOS live media before any mutations.
if ! grep -Fq 'findmnt -rn -M /iso -t iso9660' "$INSTALLER" \
  || ! grep -Fq 'findmnt -rn -M /nix/.ro-store -t squashfs' "$INSTALLER"; then
  echo "FAIL: installer must detect the NixOS live ISO and its read-only store in preflight." >&2
  exit 1
fi
live_test_dir="$(mktemp -d)"
trap 'rm -rf -- "${state_test_dir:-}" "${monitor_test_dir:-}" "${password_test_dir:-}" "${repo_guard_dir:-}" "${live_test_dir:-}" "${migration_test_dir:-}"' EXIT
awk '$0 == "is_nixos_live_installer() {" { capture=1 } capture { print } capture && /^}/ { exit }' "$INSTALLER" > "$live_test_dir/live-check.sh"
cat > "$live_test_dir/findmnt" <<'SH'
#!/usr/bin/env sh
case "$*" in
  *"/iso"*"iso9660"*) [ "${TEST_ISO_MOUNTED:-0}" = 1 ]; exit $? ;;
  *"/nix/.ro-store"*"squashfs"*) [ "${TEST_RO_STORE_MOUNTED:-0}" = 1 ]; exit $? ;;
esac
exit 1
SH
chmod +x "$live_test_dir/findmnt"
cat >> "$live_test_dir/live-check.sh" <<'SH'
PATH="$TEST_FINDMNT_DIR:/usr/bin:/bin"
export PATH
export TEST_ISO_MOUNTED TEST_RO_STORE_MOUNTED
TEST_ISO_MOUNTED=1 TEST_RO_STORE_MOUNTED=0
if ! is_nixos_live_installer; then echo 'FAIL: ISO mount was not detected.' >&2; exit 1; fi
TEST_ISO_MOUNTED=0 TEST_RO_STORE_MOUNTED=1
if ! is_nixos_live_installer; then echo 'FAIL: read-only live store was not detected.' >&2; exit 1; fi
TEST_ISO_MOUNTED=0 TEST_RO_STORE_MOUNTED=0
if is_nixos_live_installer; then echo 'FAIL: normal installed system was falsely identified as live media.' >&2; exit 1; fi
SH
TEST_FINDMNT_DIR="$live_test_dir" PATH="$live_test_dir:/usr/bin:/bin" bash "$live_test_dir/live-check.sh"

wallpaper_test_dir="$(mktemp -d)"
awk '$0 == "expand_home_prefix() {" { capture=1 } capture { print } capture && /^}/ { exit }' "$INSTALLER" > "$wallpaper_test_dir/path-helper.sh"
cat >> "$wallpaper_test_dir/path-helper.sh" <<'SH'
error() { printf '%s\n' "$*" >&2; exit 1; }
HOME=/home/test-user
export HOME
[ "$(expand_home_prefix '~/Downloads/wallpaper.mp4')" = '/home/test-user/Downloads/wallpaper.mp4' ]
[ "$(expand_home_prefix '~')" = '/home/test-user' ]
[ "$(expand_home_prefix '/mnt/media/wallpaper.mp4')" = '/mnt/media/wallpaper.mp4' ]
SH
bash "$wallpaper_test_dir/path-helper.sh"
rm -rf -- "$wallpaper_test_dir"

if ! grep -Fq 'DISK_REAL=$(readlink -f -- "$DISK")' "$ROOT/INSTALLATION.md" \
  || ! grep -Fq 'holders_dir="/sys/class/block/${device##*/}/holders"' "$ROOT/INSTALLATION.md" \
  || ! grep -Fq 'WIPE $DISK_REAL' "$ROOT/INSTALLATION.md" \
  || ! grep -Fq 'FORMAT LUKS ${PART_PREFIX}3' "$ROOT/INSTALLATION.md" \
  || ! grep -Fq 'assert_partition_on_target "${PART_PREFIX}3"' "$ROOT/INSTALLATION.md"; then
  echo "FAIL: disk guide must validate the canonical target, reject active holders, validate partition ancestry, and require explicit confirmations." >&2
  exit 1
fi
if ! grep -Fq 'SNAPSHOT_SUBVOL_CREATED=1' "$INSTALLER" \
  || ! grep -Fq 'btrfs subvolume delete "$SNAPSHOT_SUBVOL"' "$INSTALLER"; then
  echo "FAIL: installer rollback must track and safely clean up a newly-created empty snapshot subvolume." >&2
  exit 1
fi

# Regression-test the exact hardware-configuration migration snippet in README.
# Substitute temporary paths so no host /etc/nixos files can be read or changed.
migration_test_dir="$(mktemp -d)"
hardware_source="$migration_test_dir/source/hardware-configuration.nix"
hardware_target="$migration_test_dir/target/hardware-configuration.nix"
mkdir -p "$(dirname "$hardware_source")" "$(dirname "$hardware_target")"
awk '$0 == "if [ ! -f /etc/nixos/nixos/hardware-configuration.nix ]; then" { capture=1 } capture { print } capture && $0 == "fi" { exit }' "$README" \
  | sed -e "s|/etc/nixos/nixos/hardware-configuration.nix|$hardware_target|g" \
        -e "s|/etc/nixos/hardware-configuration.nix|$hardware_source|g" \
  > "$migration_test_dir/readme-snippet.sh"
if ! grep -Fq 'test -f '"$hardware_source" "$migration_test_dir/readme-snippet.sh" \
  || ! grep -Fq 'install -m 0644 '"$hardware_source" "$migration_test_dir/readme-snippet.sh"; then
  echo "FAIL: README migration snippet must verify and copy the machine-generated source file." >&2
  exit 1
fi
{
  printf 'sudo() { "$@"; }\n'
  cat "$migration_test_dir/readme-snippet.sh"
} > "$migration_test_dir/run-snippet.sh"
printf 'machine-specific hardware config\n' > "$hardware_source"
if ! bash "$migration_test_dir/run-snippet.sh"; then
  echo "FAIL: README migration should copy the generated source when the target is missing." >&2
  exit 1
fi
if ! cmp -s "$hardware_source" "$hardware_target"; then
  echo "FAIL: README migration did not copy the machine-generated hardware configuration." >&2
  exit 1
fi
# An existing target must remain untouched and must not require the source file.
rm -f "$hardware_source"
printf 'keep-existing-target\n' > "$hardware_target"
if ! bash "$migration_test_dir/run-snippet.sh" || ! grep -Fxq 'keep-existing-target' "$hardware_target"; then
  echo "FAIL: README migration must preserve an existing hardware configuration." >&2
  exit 1
fi
# Missing source and target must fail closed without creating a target.
rm -f "$hardware_target"
if bash "$migration_test_dir/run-snippet.sh" >/dev/null 2>&1; then
  echo "FAIL: README migration must stop when the machine-generated source is missing." >&2
  exit 1
fi
if [ -e "$hardware_target" ]; then
  echo "FAIL: README migration created a target despite a missing machine-generated source." >&2
  exit 1
fi
echo "OK: README hardware-configuration migration checks source, preserves existing target, and fails closed."
