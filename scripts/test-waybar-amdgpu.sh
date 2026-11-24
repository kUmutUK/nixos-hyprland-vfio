#!/usr/bin/env bash
# Regression tests for the read-only AMDGPU Waybar sysfs reader.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/waybar-amdgpu.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TMP_DIR"' EXIT

SYSFS="$TMP_DIR/sysfs"
DEVICE="$SYSFS/card0/device"
HWMON="$DEVICE/hwmon/hwmon0"
mkdir -p "$HWMON"

# A machine without an AMD DRM device must render an unavailable state, not fail.
no_gpu_output="$(WAYBAR_AMDGPU_SYSFS_ROOT="$SYSFS" bash "$SCRIPT")"
python3 -c '
import json, sys
item = json.loads(sys.argv[1])
assert item["text"] == "GPU —"
assert item["class"] == "unavailable"
assert "vfio-pci" in item["tooltip"]
' "$no_gpu_output"

# Build a representative RX 6700 XT sysfs fixture (12 GiB VRAM).
printf '0x1002\n' > "$DEVICE/vendor"
printf '0x73df\n' > "$DEVICE/device"
printf '64\n' > "$DEVICE/gpu_busy_percent"
printf '4294967296\n' > "$DEVICE/mem_info_vram_used"
printf '12884901888\n' > "$DEVICE/mem_info_vram_total"
printf '52000\n' > "$HWMON/temp1_input"
printf '78000\n' > "$HWMON/temp2_input"
printf '1250\n' > "$HWMON/fan1_input"
printf '145000000\n' > "$HWMON/power1_average"
printf '0: 500Mhz\n1: 2500Mhz *\n' > "$DEVICE/pp_dpm_sclk"

output="$(WAYBAR_AMDGPU_SYSFS_ROOT="$SYSFS" bash "$SCRIPT")"
python3 -c '
import json, sys
item = json.loads(sys.argv[1])
assert item["class"] == "amd-gpu"
assert "GPU 64%" in item["text"]
assert "VRAM 4.0 / 12.0G" in item["text"]
assert "52°" in item["text"]
for expected in ("Usage: 64", "Edge: 52°C", "Junction: 78°C",
                 "Clock: 2500 MHz", "Power: 145 W", "Fan: 1250 RPM"):
    assert expected in item["tooltip"], (expected, item["tooltip"])
' "$output"

# Missing optional hwmon counters must not break JSON output.
rm -f "$HWMON/temp2_input" "$HWMON/fan1_input" "$HWMON/power1_average" "$DEVICE/pp_dpm_sclk"
output="$(WAYBAR_AMDGPU_SYSFS_ROOT="$SYSFS" bash "$SCRIPT")"
python3 -c '
import json, sys
item = json.loads(sys.argv[1])
assert item["class"] == "amd-gpu"
assert "Junction: unavailable" in item["tooltip"]
assert "Power: unavailable" in item["tooltip"]
' "$output"

printf 'OK: AMDGPU Waybar telemetry unavailable, populated, and partial-sensor cases passed.\n'
