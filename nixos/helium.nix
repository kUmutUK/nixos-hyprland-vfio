{
  appimageTools,
  fetchurl,
  lib,
  makeWrapper,
}:

# Package the official Helium Linux AppImage without importing a third-party
# packaging flake into this MIT-licensed repository. The asset is hash-pinned.
appimageTools.wrapType2 (finalAttrs: {
  pname = "helium";
  version = "0.22.4.1";

  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${finalAttrs.version}/helium-${finalAttrs.version}-x86_64.AppImage";
    hash = "sha256-aJs8ayXmGSRpXDYOfhi4vgHlXBJ+nHQaCGMr9xibAYg=";
  };

  nativeBuildInputs = [ makeWrapper ];

  # Preserve the upstream launcher and browser sandbox. Only request Ozone
  # auto-detection when the native NixOS Wayland session is active.
  extraInstallCommands = ''
    install -Dm444 ${finalAttrs.contents}/helium.desktop "$out/share/applications/helium.desktop"
    install -Dm444 ${finalAttrs.contents}/helium.png "$out/share/icons/hicolor/256x256/apps/helium.png"
    wrapProgram "$out/bin/helium" \
      --add-flags "''${NIXOS_OZONE_WL:+''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto}}"
  '';

  meta = {
    description = "Privacy-focused Chromium-based web browser";
    homepage = "https://helium.computer/";
    license = lib.licenses.gpl3Only;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "helium";
  };
})
