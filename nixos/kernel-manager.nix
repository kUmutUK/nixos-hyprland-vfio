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
  polkit,
  systemd,
  util-linux,
}:

let
  polkitHelper = writeShellScriptBin "nixos-kernel-manager-polkit-helper" ''
    set -euo pipefail
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

    if [ "$#" -ne 2 ]; then
      echo "Usage: nixos-kernel-manager-polkit-helper <update-cachyos|rebuild-switch> <flake-path>" >&2
      exit 2
    fi
    action="$1"
    flake_ref="$2"
    case "$action" in
      update-cachyos)
        case "$flake_ref" in
          /*) ;;
          *) echo "The NixOS Flake path must be absolute." >&2; exit 2 ;;
        esac
        flake_dir="$flake_ref"
        if [ ! -f "$flake_dir/flake.nix" ] || [ ! -f "$flake_dir/flake.lock" ]; then
          echo "Both flake.nix and flake.lock must exist in $flake_dir." >&2
          exit 2
        fi
        exec nix flake update --flake "$flake_dir" cachyos-kernel
        ;;
      rebuild-switch)
        case "$flake_ref" in
          /*#nixos) ;;
          *) echo "Only an absolute Flake reference ending in #nixos is allowed." >&2; exit 2 ;;
        esac
        flake_dir="''${flake_ref%#nixos}"
        if [ ! -f "$flake_dir/flake.nix" ] || [ ! -f "$flake_dir/flake.lock" ]; then
          echo "Both flake.nix and flake.lock must exist in $flake_dir." >&2
          exit 2
        fi
        if [ ! -x /run/current-system/sw/bin/nixos-rebuild ]; then
          echo "nixos-rebuild was not found in the active NixOS system profile." >&2
          exit 127
        fi
        exec /run/current-system/sw/bin/nixos-rebuild switch --flake "$flake_ref"
        ;;
      *)
        echo "Unsupported privileged Kernel Manager action: $action" >&2
        exit 2
        ;;
    esac
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

  # Wrap manually so the Qt plugin path and action-tool PATH are both retained.
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
          polkit
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
