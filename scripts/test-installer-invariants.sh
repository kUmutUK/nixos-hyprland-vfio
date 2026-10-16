#!/usr/bin/env bash
# Regression checks for the installer XML destination and English system UI.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$ROOT/install.sh"
README="$ROOT/README.md"
CONFIG="$ROOT/nixos/configuration.nix"
HOME_CONFIG="$ROOT/nixos/home.nix"

bash -n "$INSTALLER"

assignment_line="$(awk '/^PATCHED_XML="\/var\/lib\/libvirt\/win10\.xml"$/ { print NR; exit }' "$INSTALLER")"
first_use_line="$(awk '/\$PATCHED_XML/ { print NR; exit }' "$INSTALLER")"
if [[ -z "$assignment_line" || -z "$first_use_line" || "$assignment_line" -ge "$first_use_line" ]]; then
  echo "FAIL: PATCHED_XML must be assigned before its first use." >&2
  exit 1
fi

python3 - "$README" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
guard = 'if [ ! -f /var/lib/libvirt/win10.xml ]; then'
copy = 'sudo cp /etc/nixos/vm-xml/win10.xml /var/lib/libvirt/win10.xml'
if guard not in text or copy not in text or text.index(guard) > text.index(copy):
    raise SystemExit("FAIL: README must only copy the source VM XML when no deployed XML exists.")
PY

if grep -q 'tr_TR\.UTF-8' "$CONFIG" "$HOME_CONFIG"; then
  echo "FAIL: a Turkish locale override remains in the active system or desktop configuration." >&2
  exit 1
fi

python3 - "$CONFIG" "$HOME_CONFIG" "$INSTALLER" "$ROOT/nixos/hooks/qemu" "$ROOT/vm-xml/win10.xml" "$README" "$ROOT/KURULUM.md" <<'PY'
from pathlib import Path
import sys

# The suspend/remove/rescan workaround is potentially disruptive and must stay opt-in.
config = Path(sys.argv[1]).read_text(encoding="utf-8")
hook = Path(sys.argv[4]).read_text(encoding="utf-8")
readme = Path(sys.argv[6]).read_text(encoding="utf-8")
kurulum = Path(sys.argv[7]).read_text(encoding="utf-8")
if "export VFIO_ALLOW_SUSPEND_RECOVERY=\"" not in config or "${VFIO_ALLOW_SUSPEND_RECOVERY:-0}" not in config:
    raise SystemExit("FAIL: Nix-generated VFIO hook must default suspend recovery to 0.")
if '"${VFIO_ALLOW_SUSPEND_RECOVERY:-0}" != "1"' not in hook:
    raise SystemExit("FAIL: VFIO suspend recovery must require an explicit opt-in.")
if "disabled by default" not in readme or "VFIO_ALLOW_SUSPEND_RECOVERY=1" not in readme:
    raise SystemExit("FAIL: README must document opt-in-only suspend recovery.")
if "varsayılan olarak **kapalıdır**" not in kurulum or 'VFIO_ALLOW_SUSPEND_RECOVERY = "1"' not in kurulum:
    raise SystemExit("FAIL: KURULUM.md must explain the recovery default and explicit opt-in setting.")

# These are runtime/UI strings that accidentally regressed to Turkish in earlier revisions.
forbidden = (
    "Bağlı Değil", "Bağlantı yok", "Çeviri:", "Otomatik Çeviri", "Durduruldu",
    "bulunamadı", "Kullanılan:", "Toplam:", "Boş:", "CPU kullanımı:", "Güç Menüsü",
    "Şifre...", "altyazı|", "seçenekler|", "yaninda renderD", "KLAVYE/FARE GİRİŞİ",
    "GPU PCI adresi:", "GPU Audio PCI adresi:", "tee 644 acar", "Ollama API henüz hazır",
)
for name in sys.argv[1:6]:
    text = Path(name).read_text(encoding="utf-8")
    found = [word for word in forbidden if word in text]
    if found:
        raise SystemExit(f"FAIL: Turkish UI/comment strings remain in {name}: {', '.join(found)}")
PY

echo "OK: installer XML destination, README XML preservation, English locale, and runtime UI invariants passed."
