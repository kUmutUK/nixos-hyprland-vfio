#!/usr/bin/env bash
# Regression checks for installer, libvirt ownership/password setup, and English system UI.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$ROOT/install.sh"
README="$ROOT/README.md"
CONFIG="$ROOT/nixos/configuration.nix"
FLAKE="$ROOT/nixos/flake.nix"
HOME_CONFIG="$ROOT/nixos/home.nix"
HOOK="$ROOT/nixos/hooks/qemu"

bash -n "$INSTALLER"

# Exercise the real apply_state_version() helper without running the installer.
# The installer is interactive and performs system changes at top level, so only
# extract this pure helper and provide harmless stubs for sudo/log/error.
state_test_dir="$(mktemp -d)"
trap 'rm -rf "$state_test_dir"' EXIT
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

# Guard against the former SC2154 typo: the warning must reference the declared
# gpu_iommu_dir variable, not an undeclared iommu_dir variable.
if grep -Eq '\$\{iommu_dir\}|\$iommu_dir([^[:alnum:]_]|$)' "$INSTALLER"; then
  echo "FAIL: undeclared iommu_dir variable reference remains in installer." >&2
  exit 1
fi
if ! grep -Fq 'Could not resolve GPU IOMMU group information (${gpu_iommu_dir})' "$INSTALLER"; then
  echo "FAIL: missing IOMMU warning must describe an unresolved path, not assume the link is absent." >&2
  exit 1
fi
if ! grep -Fq 'readlink -e -- "$link"' "$INSTALLER"; then
  echo "FAIL: IOMMU group resolution must require an existing canonical sysfs target." >&2
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
trap 'rm -rf "$state_test_dir" "$monitor_test_dir" "$password_test_dir"' EXIT
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

if ! grep -Fq 'Do not run the repository from /etc/nixos itself.' "$INSTALLER"; then
  echo "FAIL: installer must reject a checkout whose root overlaps /etc/nixos before making changes." >&2
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
trap 'rm -rf "$state_test_dir" "$monitor_test_dir"' EXIT
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

python3 - "$INSTALLER" <<'PY'
import ast
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
marker = 'sudo "$PYTHON3" - "$gpu_pci" "$gpu_audio" "$REPO_DIR/vm-xml/win10.xml" "$PATCHED_XML" <<\'PYEOF\''
try:
    start = text.index(marker)
except ValueError:
    raise SystemExit("FAIL: installer PCI XML synchronization heredoc is missing.")
body_start = text.index("\n", start) + 1
body_end = text.index("\nPYEOF", body_start)
embedded = text[body_start:body_end]
try:
    tree = ast.parse(embedded)
except SyntaxError as exc:
    raise SystemExit(f"FAIL: embedded installer Python is invalid: {exc}")

pattern_assignment = next((node for node in tree.body if isinstance(node, ast.Assign)
                            and any(isinstance(target, ast.Name) and target.id == "pattern"
                                    for target in node.targets)), None)
if pattern_assignment is None:
    raise SystemExit("FAIL: installer PCI hostdev address pattern is missing.")
namespace = {}
exec(compile(ast.Module(body=[pattern_assignment], type_ignores=[]), "installer-pattern", "exec"),
     {"re": re}, namespace)
pattern = namespace["pattern"]
sample_xml = "\n".join([
    '<domain><name>win10</name><uuid>11111111-2222-3333-4444-555555555555</uuid>',
    '<devices>',
    '<hostdev mode="subsystem" type="usb"><source><address bus="1" device="2"/></source></hostdev>',
    '<hostdev mode="subsystem" type="pci"><source><address domain="0x0000" bus="0x0b" slot="0x00" function="0x0"/></source></hostdev>',
    "<hostdev mode=\"subsystem\" type='pci'><source><address domain='0x0000' bus='0x0b' slot='0x00' function='0x1'/></source></hostdev>",
    '<interface type="network"><mac address="52:54:00:00:00:01"/></interface>',
    '</devices></domain>',
])
matches = list(pattern.finditer(sample_xml))
if len(matches) != 2 or any(re.search(r'type\s*=\s*["\']usb["\']', m.group(0)) for m in matches):
    raise SystemExit("FAIL: installer PCI synchronization must match PCI hostdevs only, never USB address sources.")
if "pci_hostdev_count != 2 or n != 2" not in embedded:
    raise SystemExit("FAIL: installer must fail closed unless exactly two actual PCI hostdevs have synchronizable source addresses.")
if "ET.fromstring(data)" not in embedded or "comment_spans" not in embedded:
    raise SystemExit("FAIL: XML validation must parse real XML nodes and ignore commented-out examples.")

# Execute the actual embedded updater against temporary fixtures. Failed cases must
# exit non-zero before a destination XML is created; the valid pair must be rewritten.
import subprocess
import tempfile

pci0 = '<hostdev mode="subsystem" type="pci"><source><address domain="0x0000" bus="0x0b" slot="0x00" function="0x0"/></source></hostdev>'
pci1 = "<hostdev mode='subsystem' type='pci'><source><address domain='0x0000' bus='0x0b' slot='0x00' function='0x1'/></source></hostdev>"
pci2 = '<hostdev mode="subsystem" type="pci"><source><address domain="0x0000" bus="0x0c" slot="0x00" function="0x0"/></source></hostdev>'
usb = '<hostdev mode="subsystem" type="usb"><source><address bus="1" device="2"/></source></hostdev>'
header = '<domain><name>win10</name><uuid>11111111-2222-3333-4444-555555555555</uuid><devices>'
footer = '<interface type="network"><mac address="52:54:00:00:00:01"/></interface></devices></domain>'
fixtures = {
    "valid-two": (header + usb + '<!-- ' + pci2 + ' -->' + pci0 + pci1 + footer, True),
    "none": (header + usb + footer, False),
    "one": (header + pci0 + footer, False),
    "three": (header + pci0 + pci1 + pci2 + footer, False),
    "unmatched-source": (header + pci0 + '<hostdev type="pci"><source><adapter name="missing-address"/></source></hostdev>' + footer, False),
    "malformed-xml": (header + pci0 + pci1 + footer + '<', False),
}
for name, (xml, should_pass) in fixtures.items():
    with tempfile.TemporaryDirectory(prefix="installer-xml-test-") as temp:
        src = Path(temp) / "source.xml"
        dst = Path(temp) / "deployed.xml"
        src.write_text(xml, encoding="utf-8")
        result = subprocess.run(
            [sys.executable, "-", "0000:0b:00.0", "0000:0b:00.1", str(src), str(dst)],
            input=embedded, text=True, capture_output=True,
        )
        passed = result.returncode == 0 and dst.is_file()
        if passed != should_pass:
            raise SystemExit(
                f"FAIL: XML updater fixture {name!r}: expected success={should_pass}, "
                f"exit={result.returncode}, output={result.stdout}{result.stderr}"
            )
        if not should_pass and dst.exists():
            raise SystemExit(f"FAIL: XML updater fixture {name!r} wrote a destination on failure.")
        if name == "valid-two":
            generated = dst.read_text(encoding="utf-8")
            if 'bus="0x0b" slot="0x00" function="0x0"' not in generated or 'function="0x1"' not in generated:
                raise SystemExit("FAIL: valid XML did not receive the selected GPU/audio addresses.")
            if ('<!-- ' + pci2 + ' -->') not in generated:
                raise SystemExit("FAIL: a commented-out PCI example was altered by XML synchronization.")
PY

python3 - "$README" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
guard = 'if [ ! -f /var/lib/libvirt/win10.xml ]; then'
copy = 'sudo cp ./vm-xml/win10.xml /var/lib/libvirt/win10.xml'
if guard not in text or copy not in text or text.index(guard) > text.index(copy):
    raise SystemExit("FAIL: README must only copy the repository VM XML when no deployed XML exists.")
if "Before rebuilding, make sure `/etc/nixos/hashedPassword` exists" not in text:
    raise SystemExit("FAIL: README must document hashedPassword as a prerequisite for migration rebuilds.")
if 'sudo test -s /etc/nixos/hashedPassword' not in text or 'sudo chmod 600 /etc/nixos/hashedPassword' not in text:
    raise SystemExit("FAIL: README must check hashedPassword with sufficient privilege and restrict its permissions.")
if "sudo stat -c '%U:%G:%a' /etc/nixos/hashedPassword" not in text or 'root:root:600' not in text:
    raise SystemExit("FAIL: README must validate hashedPassword owner, group, and mode.")

install_guide = Path(sys.argv[1]).parent / "KURULUM.md"
guide_text = install_guide.read_text(encoding="utf-8")
install_command = guide_text.index("sudo nixos-install --flake /mnt/etc/nixos/nixos#nixos")
root_pass_command = guide_text.index("sudo nixos-enter --root /mnt -c 'passwd root'")
if root_pass_command < install_command:
    raise SystemExit("FAIL: KURULUM.md must place root password setup after successful nixos-install.")

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
if ! grep -Fq 'cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";' "$FLAKE"; then
  echo "FAIL: the CachyOS input must follow the upstream release channel, not a hard-coded tag." >&2
  exit 1
fi
if ! grep -Fq 'nup = "sudo nix flake update --accept-flake-config --flake /etc/nixos/nixos cachyos-kernel";' "$HOME_CONFIG"; then
  echo "FAIL: nup must update only the CachyOS input against the absolute system flake path." >&2
  exit 1
fi
if grep -Fq 'RFC1918 home/LAN ranges are exempt' "$CONFIG"; then
  echo "FAIL: stale Fail2ban comments still claim private LAN ranges are exempt." >&2
  exit 1
fi
if ! grep -Fq 'ignoreIP = [ "127.0.0.0/8" "::1" ];' "$CONFIG"; then
  echo "FAIL: Fail2ban must exempt loopback only, not private LAN addresses." >&2
  exit 1
fi
if ! grep -Fq 'check_ssh_password_file "$NIXOS_DIR/hashedPassword"' "$INSTALLER" || ! grep -Fq 'root:root:600' "$INSTALLER"; then
  echo "FAIL: installer preflight must check the SSH password hash file and its secure metadata." >&2
  exit 1
fi
if ! grep -Fq 'nix flake update cachyos-kernel --accept-flake-config' "$README" || ! grep -Fq 'nix flake update cachyos-kernel --accept-flake-config' "$ROOT/KURULUM.md"; then
  echo "FAIL: both install guides must document how to update the CachyOS kernel input." >&2
  exit 1
fi
if ! grep -Fq 'services.openssh = {' "$CONFIG" || ! grep -Fq 'enable = true;' "$CONFIG" || ! grep -Fq 'PasswordAuthentication = true;' "$CONFIG" || ! grep -Fq 'AllowUsers = [ "localhost" ];' "$CONFIG" || ! grep -Fq 'PermitRootLogin = "no";' "$CONFIG"; then
  echo "FAIL: SSH must be usable for localhost without allowing root SSH login." >&2
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
if ! grep -Fq 'not yet been built or tested on the target system' "$README"; then
  echo "FAIL: README must clearly mark RT-Bore-LTO as unvalidated until target testing." >&2
  exit 1
fi
if ! grep -Fq 'not in the upstream binary cache' "$README"; then
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
if node["original"].get("ref") != "release":
    raise SystemExit("FAIL: the CachyOS lock must follow the upstream release branch.")
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

echo "OK: installer, VM/VFIO, English locale/UI, updateable RT-Bore-LTO selection, global Reflex, SSH access, and SSH-preserving VFIO handoff invariants passed."
