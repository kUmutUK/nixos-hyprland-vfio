# Read-only AMDGPU telemetry for a Waybar custom module.
# The optional root override exists only to make the sysfs reader testable.
set -euo pipefail
export LC_ALL=C

SYSFS_ROOT="\${WAYBAR_AMDGPU_SYSFS_ROOT:-/sys/class/drm}"

read_text() {
  local path="$1"
  local value

  [[ -r "$path" ]] || return 1
  IFS= read -r value < "$path" || return 1
  printf '%s' "$value"
}

read_uint() {
  local value

  value="$(read_text "$1")" || return 1
  [[ "$value" =~ ^[0-9]+$ ]] || return 1
  printf '%s' "$value"
}

format_millicelsius() {
  awk -v value="$1" 'BEGIN { printf "%.0f", value / 1000 }'
}

format_gib() {
  awk -v value="$1" 'BEGIN { printf "%.1f", value / 1073741824 }'
}

format_watts() {
  awk -v value="$1" 'BEGIN { printf "%.0f", value / 1000000 }'
}

gpu_device=""
for card_path in "$SYSFS_ROOT"/card[0-9]*; do
  [[ -d "$card_path" ]] || continue
  card_name="\${card_path##*/}"
  [[ "$card_name" =~ ^card[0-9]+$ ]] || continue

  device_path="$card_path/device"
  vendor="$(read_text "$device_path/vendor" 2>/dev/null || true)"
  case "$vendor" in
    0x1002|0X1002)
      gpu_device="$device_path"
      break
      ;;
  esac
done

if [[ -z "$gpu_device" ]]; then
  printf '{"text":"GPU —","tooltip":"AMD GPU telemetry unavailable (no AMD DRM card found or the GPU is bound to vfio-pci).","class":"unavailable"}\n'
  exit 0
fi

usage="$(read_uint "$gpu_device/gpu_busy_percent" 2>/dev/null || true)"
vram_used="$(read_uint "$gpu_device/mem_info_vram_used" 2>/dev/null || true)"
vram_total="$(read_uint "$gpu_device/mem_info_vram_total" 2>/dev/null || true)"
edge_raw=""
junction_raw=""
fan_rpm=""
power_raw=""
clock_mhz=""

hwmon_dir=""
for candidate in "$gpu_device"/hwmon/hwmon*; do
  [[ -d "$candidate" ]] || continue
  hwmon_dir="$candidate"
  break
done

if [[ -n "$hwmon_dir" ]]; then
  edge_raw="$(read_uint "$hwmon_dir/temp1_input" 2>/dev/null || true)"
  junction_raw="$(read_uint "$hwmon_dir/temp2_input" 2>/dev/null || true)"
  fan_rpm="$(read_uint "$hwmon_dir/fan1_input" 2>/dev/null || true)"
  power_raw="$(read_uint "$hwmon_dir/power1_average" 2>/dev/null || true)"
  if [[ -z "$power_raw" ]]; then
    power_raw="$(read_uint "$hwmon_dir/power1_input" 2>/dev/null || true)"
  fi
fi

if [[ -r "$gpu_device/pp_dpm_sclk" ]]; then
  clock_mhz="$(
    awk '/\*/ {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /[Mm][Hh][Zz]$/) {
          gsub(/[^0-9.]/, "", $i)
          print $i
          exit
        }
      }
    }' "$gpu_device/pp_dpm_sclk"
  )"
fi

usage_display="N/A"
if [[ "$usage" =~ ^[0-9]+$ ]] && (( usage <= 100 )); then
  usage_display="$usage"
fi

vram_display="unavailable"
if [[ "$vram_used" =~ ^[0-9]+$ && "$vram_total" =~ ^[0-9]+$ ]] && (( vram_total > 0 )); then
  vram_display="$(format_gib "$vram_used") / $(format_gib "$vram_total") GiB"
fi

edge_display="unavailable"
if [[ "$edge_raw" =~ ^[0-9]+$ ]]; then
  edge_display="$(format_millicelsius "$edge_raw")°C"
fi

junction_display="unavailable"
if [[ "$junction_raw" =~ ^[0-9]+$ ]]; then
  junction_display="$(format_millicelsius "$junction_raw")°C"
fi

power_display="unavailable"
if [[ "$power_raw" =~ ^[0-9]+$ ]]; then
  power_display="$(format_watts "$power_raw") W"
fi

fan_display="unavailable"
if [[ "$fan_rpm" =~ ^[0-9]+$ ]]; then
  fan_display="$fan_rpm RPM"
fi

clock_display="unavailable"
if [[ "$clock_mhz" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  clock_display="$clock_mhz MHz"
fi

text="GPU —"
if [[ "$usage_display" != "N/A" ]]; then
  text="GPU $usage_display%"
fi
if [[ "$vram_display" != "unavailable" ]]; then
  text="$text · VRAM \${vram_display% GiB}G"
fi
if [[ "$edge_raw" =~ ^[0-9]+$ ]]; then
  text="$text · $(format_millicelsius "$edge_raw")°"
fi

tooltip="AMD GPU (read-only)\\nUsage: $usage_display"
tooltip="$tooltip\\nVRAM: $vram_display"
tooltip="$tooltip\\nEdge: $edge_display"
tooltip="$tooltip\\nJunction: $junction_display"
tooltip="$tooltip\\nClock: $clock_display"
tooltip="$tooltip\\nPower: $power_display"
tooltip="$tooltip\\nFan: $fan_display"

printf '{"text":"%s","tooltip":"%s","class":"amd-gpu"}\n' "$text" "$tooltip"
