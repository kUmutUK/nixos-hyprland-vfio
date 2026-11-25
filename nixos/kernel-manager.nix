{
  lib,
  stdenv,
  pkg-config,
  qt6,
  makeWrapper,
  writeShellScriptBin,
  bash,
  coreutils,
  findutils,
  gawk,
  git,
  gnugrep,
  gnused,
  kitty,
  nix,
  systemd,
  util-linux,
}:

let
  polkitHelper = writeShellScriptBin "nixos-kernel-manager-polkit-helper" ''
    set -uo pipefail
    export SYSTEMD_PAGER=cat
    export SYSTEMD_COLORS=0
    export LC_ALL=C
    export PATH="${
      lib.makeBinPath [
        bash
        coreutils
        findutils
        gawk
        git
        gnugrep
        gnused
        nix
        systemd
        util-linux
      ]
    }:/run/current-system/sw/bin:/run/current-system/sw/sbin"

    if [ "$#" -ne 1 ] || [ "$1" != "session" ]; then
      echo "Usage: nixos-kernel-manager-polkit-helper session" >&2
      exit 2
    fi

    allowed_flake="/etc/nixos/nixos"
    if [ ! -f "$allowed_flake/flake.nix" ] || [ ! -f "$allowed_flake/flake.lock" ]; then
      echo "Both flake.nix and flake.lock must exist in $allowed_flake." >&2
      exit 2
    fi

    printf '%s\n' "__KM_SESSION_READY__"
    while IFS= read -r action; do
      case "$action" in
        inspect-system)
          printf '%s\n' "__KM_ACTION_BEGIN__:inspect-system"
          result=0

          printf '%s\n' "__KM_BOOT_BEGIN__"
          if boot_entries="$(bootctl list --no-pager 2>&1)"; then
            printf '%s\n' "$boot_entries"
          else
            command_status=$?
            printf '%s\n' "$boot_entries"
            result="$command_status"
          fi
          printf '%s\n' "__KM_BOOT_END__"

          printf '%s\n' "__KM_GENERATIONS_BEGIN__"
          if generations="$(nix-env --profile /nix/var/nix/profiles/system --list-generations 2>&1)"; then
            printf '%s\n' "$generations"
          else
            command_status=$?
            printf '%s\n' "$generations"
            result="$command_status"
          fi
          printf '%s\n' "__KM_GENERATIONS_END__"
          printf '%s\n' "__KM_ACTION_END__:inspect-system:$result"
          ;;
        update-cachyos)
          printf '%s\n' "__KM_ACTION_BEGIN__:update-cachyos"
          if nix flake update --flake "$allowed_flake" cachyos-kernel 2>&1; then
            result=0
          else
            result=$?
          fi
          printf '%s\n' "__KM_ACTION_END__:update-cachyos:$result"
          ;;
        rebuild-switch)
          printf '%s\n' "__KM_ACTION_BEGIN__:rebuild-switch"
          if [ ! -x /run/current-system/sw/bin/nixos-rebuild ]; then
            echo "nixos-rebuild was not found in the active NixOS system profile." >&2
            result=127
          elif /run/current-system/sw/bin/nixos-rebuild switch --flake "$allowed_flake#nixos" 2>&1; then
            result=0
          else
            result=$?
          fi
          printf '%s\n' "__KM_ACTION_END__:rebuild-switch:$result"
          ;;
        exit)
          printf '%s\n' "__KM_SESSION_CLOSED__"
          break
          ;;
        *)
          printf '%s\n' "__KM_ACTION_BEGIN__:invalid"
          echo "Unsupported privileged Kernel Manager request." >&2
          printf '%s\n' "__KM_ACTION_END__:invalid:2"
          ;;
      esac
    done
  '';
in
stdenv.mkDerivation {
  pname = "nixos-kernel-manager";
  version = "1.2.0";

  src = ./kernel-manager.cpp;
  dontUnpack = true;

  nativeBuildInputs = [
    pkg-config
    qt6.wrapQtAppsHook
    makeWrapper
  ];
  buildInputs = [
    qt6.qtbase
    qt6.qtwayland
  ];

  dontWrapQtApps = true;

  buildPhase = ''
    runHook preBuild
    $CXX -std=c++20 -O2 -fPIC "$src" -o nixos-kernel-manager \
      $(pkg-config --cflags --libs Qt6Widgets)
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 nixos-kernel-manager "$out/bin/nixos-kernel-manager"
    install -Dm444 /dev/stdin "$out/share/icons/hicolor/scalable/apps/nixos-kernel-manager.svg" <<'SVG'
    <svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
      <rect x="7" y="7" width="114" height="114" rx="27" fill="#1a202b" stroke="#465064" stroke-width="4"/>
      <rect x="22" y="22" width="84" height="84" rx="18" fill="#252d3a"/>
      <path d="M64 31v11m0 44v11M31 64h11m44 0h11M41 41l8 8m30 30 8 8m0-46-8 8m-30 30-8 8"
            stroke="#eab2c2" stroke-width="7" stroke-linecap="round"/>
      <circle cx="64" cy="64" r="22" fill="#eab2c2"/>
      <circle cx="64" cy="64" r="9" fill="#20232c"/>
      <path d="M64 50v28M50 64h28" stroke="#20232c" stroke-width="5" stroke-linecap="round"/>
    </svg>
    SVG
    runHook postInstall
  '';

  postFixup = ''
    wrapQtApp "$out/bin/nixos-kernel-manager" \
      --prefix PATH : "${
        lib.makeBinPath [
          bash
          kitty
          nix
          systemd
        ]
      }" \
      --set KERNEL_MANAGER_POLKIT_HELPER "${polkitHelper}/bin/nixos-kernel-manager-polkit-helper"
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    test -x "$out/bin/nixos-kernel-manager"
    test -s "$out/share/icons/hicolor/scalable/apps/nixos-kernel-manager.svg"
  '';

  meta = {
    description = "Native Qt 6 desktop application for declarative NixOS kernel management";
    homepage = "https://github.com/kUmutUK/nixos-hyprland-vfio";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "nixos-kernel-manager";
  };
}
