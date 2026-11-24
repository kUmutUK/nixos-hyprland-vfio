#!/usr/bin/env bash
set -Eeuo pipefail

APP_TITLE="NixOS Kernel Manager"
FLAKE_DIR="${NIXOS_CONFIG_FLAKE:-/etc/nixos/nixos}"
FLAKE_FILE="$FLAKE_DIR/flake.nix"
LOCK_FILE="$FLAKE_DIR/flake.lock"

require_flake() {
  [[ -s "$FLAKE_FILE" && -s "$LOCK_FILE" ]] || {
    printf 'NixOS Flake not found at %s\n' "$FLAKE_DIR" >&2
    return 1
  }
}

kernel_profile() {
  if grep -Eq 'boot\.kernelPackages[[:space:]]*=[[:space:]]*rtBoreLtoV3KernelPackages;' "$FLAKE_FILE"; then
    printf 'CachyOS RT-Bore-LTO (x86-64-v3)'
  else
    printf 'Custom Flake kernel expression'
  fi
}

cachyos_revision() {
  jq -r '.nodes["cachyos-kernel"].locked.rev // "unknown"' "$LOCK_FILE" 2>/dev/null || printf 'unknown'
}

pause_terminal() {
  printf '\n'
  read -r -p 'Press Enter to close this window...' _ || true
}

show_overview() {
  require_flake || { pause_terminal; return 1; }
  printf '\033[1;36m%s\033[0m\n\n' "$APP_TITLE"
  printf 'Running kernel      : %s\n' "$(uname -r)"
  printf 'Configured profile  : %s\n' "$(kernel_profile)"
  printf 'CachyOS source rev   : %s\n' "$(cachyos_revision)"
  printf 'Flake directory      : %s\n' "$FLAKE_DIR"
  printf 'Current system       : %s\n' "$(readlink -f /run/current-system 2>/dev/null || printf unknown)"
  printf '\n\033[1;36mSystemd-boot entries\033[0m\n'
  SYSTEMD_PAGER=cat bootctl list --no-pager 2>&1 || true
  printf '\n\033[1;36mNixOS system generations\033[0m\n'
  nix-env --profile /nix/var/nix/profiles/system --list-generations 2>&1 || true
  printf '\nThe manager does not use pacman/AUR or edit boot entries directly.\n'
  printf 'Kernel selection remains declarative in nixos/flake.nix.\n'
  pause_terminal
}

show_boot_entries() {
  printf '\033[1;36mSystemd-boot entries\033[0m\n\n'
  SYSTEMD_PAGER=cat bootctl list --no-pager 2>&1 || true
  pause_terminal
}

show_kernel_config() {
  require_flake || { pause_terminal; return 1; }
  printf '\033[1;36mKernel declaration in nixos/flake.nix\033[0m\n\n'
  grep -n -B 10 -A 8 -E 'rtBoreLtoV3Kernel|boot\.kernelPackages' "$FLAKE_FILE" || true
  pause_terminal
}

confirm_action() {
  local prompt="$1" label="$2" answer
  answer="$(printf 'Cancel\n%s\n' "$label" | rofi -dmenu -i -no-custom \
    -p 'Confirm' -mesg "$prompt" -selected-row 0 || true)"
  [[ "$answer" == "$label" ]]
}

run_update() {
  require_flake || { pause_terminal; return 1; }
  local before after
  before="$(cachyos_revision)"
  printf 'CachyOS Flake input update\nBefore: %s\n\n' "$before"
  printf 'Only the cachyos-kernel lock entry is updated. No kernel is built or activated.\n\n'
  if sudo nix flake update --flake "$FLAKE_DIR" cachyos-kernel; then
    after="$(cachyos_revision)"
    printf '\nAfter: %s\n' "$after"
    printf 'Review flake.lock before deciding whether to build or switch.\n'
  else
    printf '\nUpdate failed; the running system was not switched.\n'
  fi
  pause_terminal
}

run_kernel_build() {
  require_flake || { pause_terminal; return 1; }
  printf 'Kernel-only build. This does not activate the kernel.\n'
  printf 'A cache miss may require a long local build.\n\n'
  if nix build --no-link --print-out-paths --show-trace --no-update-lock-file \
    "${FLAKE_DIR}#nixosConfigurations.nixos.config.boot.kernelPackages.kernel"; then
    printf '\nKernel build completed. The running kernel and boot entries were not changed.\n'
  else
    printf '\nKernel-only build failed; no system switch was attempted.\n'
  fi
  pause_terminal
}

run_rebuild() {
  require_flake || { pause_terminal; return 1; }
  printf 'Full NixOS rebuild and switch.\n'
  printf 'This builds and activates the current Flake. It does not update flake.lock.\n\n'
  if sudo nixos-rebuild switch --flake "${FLAKE_DIR}#nixos"; then
    printf '\nNixOS rebuild and switch completed.\n'
  else
    printf '\nRebuild/switch failed. Review the output before retrying.\n'
  fi
  pause_terminal
}

launch_terminal() {
  kitty --title "$1" -e "$0" --action "$2"
}

main_menu() {
  local choice summary
  while true; do
    summary="Running: $(uname -r) | Configured: $(kernel_profile) | CachyOS: $(cachyos_revision)"
    choice="$(printf '%s\n' \
      'Kernel and system overview' \
      'Systemd-boot entries' \
      'View kernel Flake declaration' \
      'Build selected kernel only (no activation)' \
      'Update CachyOS Flake input (lock only)' \
      'Rebuild and switch current Flake' \
      'Exit' | rofi -dmenu -i -no-custom -p "$APP_TITLE" \
        -mesg "$summary" -theme-str 'window { width: 56%; } listview { lines: 7; }' || true)"
    case "$choice" in
      'Kernel and system overview') launch_terminal 'Kernel overview' overview ;;
      'Systemd-boot entries') launch_terminal 'Boot entries' boot ;;
      'View kernel Flake declaration') launch_terminal 'Kernel declaration' config ;;
      'Build selected kernel only (no activation)')
        if confirm_action 'Build only the Flake-selected kernel. A cache miss can take a long time; no activation occurs.' 'Build kernel'; then
          launch_terminal 'Kernel-only build' build
        fi ;;
      'Update CachyOS Flake input (lock only)')
        if confirm_action 'Update only cachyos-kernel in flake.lock. This does not build or activate a kernel.' 'Update Flake input'; then
          launch_terminal 'CachyOS Flake update' update
        fi ;;
      'Rebuild and switch current Flake')
        if confirm_action 'Run sudo nixos-rebuild switch for the full current Flake. This activates the system.' 'Rebuild and switch'; then
          launch_terminal 'NixOS rebuild and switch' rebuild
        fi ;;
      'Exit'|'') return 0 ;;
    esac
  done
}

if [[ "${1:-}" == '--action' ]]; then
  case "${2:-}" in
    overview) show_overview ;;
    boot) show_boot_entries ;;
    config) show_kernel_config ;;
    update) run_update ;;
    build) run_kernel_build ;;
    rebuild) run_rebuild ;;
    *) printf 'Unknown kernel manager action.\n' >&2; exit 2 ;;
  esac
  exit 0
fi

command -v rofi >/dev/null 2>&1 || { printf 'Rofi is required.\n' >&2; exit 1; }
command -v kitty >/dev/null 2>&1 || { printf 'Kitty is required.\n' >&2; exit 1; }
[[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]] || { printf 'Launch this manager from a graphical session.\n' >&2; exit 1; }
main_menu
