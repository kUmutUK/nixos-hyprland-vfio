#!/usr/bin/env bash
# Capture benchmark context and optionally summarize an existing MangoHud CSV.
set -euo pipefail

LABEL="${1:-}"
CSV="${2:-}"
if [[ ! "$LABEL" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]]; then
  echo "Usage: scripts/benchmark-capture.sh <label> [mangohud.csv]" >&2
  exit 2
fi

ROOT="${BENCHMARK_ROOT:-$HOME/Documents/benchmarks}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$ROOT/$STAMP-$LABEL"
mkdir -p "$OUT"
META="$OUT/system.txt"

{
  printf 'label=%s\n' "$LABEL"
  printf 'timestamp=%s\n' "$(date --iso-8601=seconds)"
  printf 'kernel=%s\n' "$(uname -r)"
  printf 'architecture=%s\n' "$(uname -m)"
  printf 'nixos_generation=%s\n' "$(readlink -f /nix/var/nix/profiles/system 2>/dev/null || echo unavailable)"
  printf 'online_cpus=%s\n' "$(getconf _NPROCESSORS_ONLN 2>/dev/null || nproc)"
  printf 'cpu_model=%s\n' "$(awk -F: '/model name/ {sub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo)"
  printf 'memory=%s\n' "$(awk '/MemTotal:/ {printf \"%.1f GiB\", $2/1048576}' /proc/meminfo)"
  printf 'power_profile=%s\n' "$(powerprofilesctl get 2>/dev/null || echo unavailable)"
  printf 'scx_scheduler=%s\n' "$(scxctl get 2>/dev/null | tr '\n' ' ' || echo unavailable)"
  printf 'gamemode=%s\n' "$(gamemoded -s 2>/dev/null | tr '\n' ' ' || echo unavailable)"
  if [[ -r /sys/block/nvme0n1/queue/scheduler ]]; then
    printf 'nvme_scheduler=%s\n' "$(cat /sys/block/nvme0n1/queue/scheduler)"
  else
    printf 'nvme_scheduler=unavailable\n'
  fi
  for sensor in /sys/class/drm/card[0-9]*/device/gpu_busy_percent; do
    [[ -r "$sensor" ]] || continue
    printf 'gpu_busy_percent=%s\n' "$(cat "$sensor")"
    break
  done
  for sensor in /sys/class/drm/card[0-9]*/device/mem_info_vram_used; do
    [[ -r "$sensor" ]] || continue
    printf 'gpu_vram_used_bytes=%s\n' "$(cat "$sensor")"
    break
  done
  for sensor in /sys/class/drm/card[0-9]*/device/hwmon/hwmon*/temp1_input; do
    [[ -r "$sensor" ]] || continue
    printf 'gpu_edge_millicelsius=%s\n' "$(cat "$sensor")"
    break
  done
  for sensor in /sys/class/drm/card[0-9]*/device/hwmon/hwmon*/temp2_input; do
    [[ -r "$sensor" ]] || continue
    printf 'gpu_junction_millicelsius=%s\n' "$(cat "$sensor")"
    break
  done
  for sensor in /sys/class/drm/card[0-9]*/device/hwmon/hwmon*/power1_average; do
    [[ -r "$sensor" ]] || continue
    printf 'gpu_power_microwatts=%s\n' "$(cat "$sensor")"
    break
  done
  for sensor in /sys/class/drm/card[0-9]*/device/hwmon/hwmon*/fan1_input; do
    [[ -r "$sensor" ]] || continue
    printf 'gpu_fan_rpm=%s\n' "$(cat "$sensor")"
    break
  done
} > "$META"

if [[ -n "$CSV" ]]; then
  [[ -f "$CSV" ]] || { echo "MangoHud CSV not found: $CSV" >&2; exit 1; }
  cp -- "$CSV" "$OUT/mangohud.csv"
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  python3 "$SCRIPT_DIR/benchmark-report.py" "$OUT/mangohud.csv" > "$OUT/summary.txt"
fi

printf 'Benchmark captured: %s\nMetadata: %s\n' "$OUT" "$META"
