{
  lib,
  stdenv,
  pkg-config,
  qt6,
  makeWrapper,
  kitty,
  nix,
  sudo,
  systemd,
}:

stdenv.mkDerivation {
  pname = "nixos-kernel-manager";
  version = "1.0.0";

  src = ./kernel-manager.cpp;
  dontUnpack = true;

  nativeBuildInputs = [
    pkg-config
    qt6.wrapQtAppsHook
    makeWrapper
  ];
  buildInputs = [ qt6.qtbase ];

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
    wrapProgram "$out/bin/nixos-kernel-manager" \
      --prefix PATH : "${lib.makeBinPath [ kitty nix sudo systemd ]}"
  '';

  meta = {
    description = "Native Qt 6 desktop application for declarative NixOS kernel management";
    homepage = "https://github.com/kUmutUK/nixos-hyprland-vfio";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "nixos-kernel-manager";
  };
}
