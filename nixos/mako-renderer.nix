{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  qt6,
  alsa-lib,
  dbus,
  fontconfig,
  freetype,
  glib,
  libdrm,
  libglvnd,
  libxkbcommon,
  vulkan-loader,
  wayland,
  xorg,
  zlib,
}:

stdenvNoCC.mkDerivation {
  pname = "mako-renderer";
  version = "4.6.0";

  src = fetchurl {
    url = "https://github.com/eugeniosegala/MAKO/releases/download/render-v4.6.0/MAKO-Renderer-v4.6.0-linux.tar.xz";
    hash = "sha256-ZiJEFOLZT3ywGSJnNbO20mub5xA8UzQlBSL3JgITvlY=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    (lib.getLib stdenv.cc.cc)
    alsa-lib
    dbus
    fontconfig
    freetype
    glib
    libdrm
    libglvnd
    libxkbcommon
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtwayland
    vulkan-loader
    wayland
    xorg.libX11
    xorg.libXext
    xorg.libXrender
    xorg.libXi
    xorg.libxcb
    zlib
  ];

  # The renderer libraries are loaded inside Steam/Proton's game runtime.
  # Patch host-side executables only; preserve both Vulkan-layer payloads.
  dontAutoPatchelf = true;
  dontStrip = true;
  runtimeDependencies = [ vulkan-loader ];

  sourceRoot = ".";

  unpackPhase = ''
    runHook preUnpack
    tar -xJf "$src"
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -a . "$out/"
    runHook postInstall
  '';

  postInstall = ''
    # Home Manager owns this copy; do not expose a competing mutable
    # installer that writes to ~/.local.
    rm -f \
      "$out/Install MAKO Renderer" \
      "$out/README.txt" \
      "$out/MAKO-Renderer-install-manifest.txt" \
      "$out/bin/mako-installer" \
      "$out/share/applications/io.github.eugeniosegala.mako.uninstaller.desktop"
  '';

  postFixup = ''
    # Search the package's own shared libraries for host-side CLI dependencies,
    # but never recursively patch the Vulkan layers used by game processes.
    addAutoPatchelfSearchPath "$out/lib"
    addAutoPatchelfSearchPath "$out/lib32"
    autoPatchelf --no-recurse "$out/bin"
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    test -x "$out/bin/mako-launch"
    test -x "$out/bin/mako-ui"
    test -x "$out/bin/mako-cli"
    test -s "$out/lib/libmako-render.so"
    test -s "$out/lib/libmako-render-scaling.so"
    test -s "$out/lib32/libmako-render.so"
    test -s "$out/lib32/libmako-render-scaling.so"
    test -s "$out/share/mako-render/vulkan/implicit_layer.d/VkLayer_MAKO_render.json"
    test -s "$out/share/mako-render/vulkan/spatial_scaling.d/VkLayer_MAKO_spatial_scaling.json"
    test ! -e "$out/bin/mako-installer"
    test ! -e "$out/share/applications/io.github.eugeniosegala.mako.uninstaller.desktop"
  '';

  meta = with lib; {
    description = "Vulkan frame generation, spatial scaling, and shader renderer for Linux games";
    homepage = "https://github.com/eugeniosegala/MAKO";
    license = licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "mako-ui";
  };
}
