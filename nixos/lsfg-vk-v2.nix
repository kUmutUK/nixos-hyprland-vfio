{
  lib,
  clangStdenv,
  fetchgit,
  cmake,
  pkg-config,
  makeWrapper,
  vulkan-headers,
  vulkan-loader,
  qt6,
}:

# LSFG-VK v2 moved away from the archived GitHub source. Build from the current
# upstream Git service at an immutable revision and verify it with the NAR hash.
# Upstream's CC BY-NC-ND 4.0 license forbids distributing modified source, so this
# expression changes the toolchain/build flags only and does not patch source files.
clangStdenv.mkDerivation rec {
  pname = "lsfg-vk";
  version = "2.0.0-unstable-2026-10-19";

  src = fetchgit {
    url = "https://git.lsfg-vk.dev/lsfg-vk.git";
    rev = "21fbd1bc4e94ebc076cc0a86f09e3107b83f0c96";
    hash = "sha256-YwCvbxdRhPz2daEIEMOciA/i4nhk/hY0Tj7l9t9oOWI=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    makeWrapper
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    vulkan-headers
    vulkan-loader
    qt6.qtbase
    qt6.qtdeclarative
  ];

  cmakeFlags = [
    "-DLSFGVK_BUILD_LAYER=ON"
    "-DLSFGVK_BUILD_UI=ON"
    "-DLSFGVK_BUILD_CLI=ON"
    "-DLSFGVK_MANAGED=ON"
    "-DLSFGVK_LAYER_LIBRARY_PATH=${placeholder "out"}/lib/liblsfg-vk-layer.so"
  ];

  # Keep the CLI free of Qt environment variables; wrap each binary with only its
  # actual runtime requirements.
  dontWrapQtApps = true;

  postFixup = ''
    wrapQtApp $out/bin/lsfg-vk-ui \
      --prefix LD_LIBRARY_PATH : "${vulkan-loader}/lib"

    wrapProgram $out/bin/lsfg-vk-cli \
      --prefix LD_LIBRARY_PATH : "${vulkan-loader}/lib"
  '';

  meta = with lib; {
    description = "Vulkan frame-generation layer using Lossless Scaling";
    homepage = "https://lsfg-vk.dev";
    license = licenses.cc-by-nc-nd-40;
    platforms = platforms.linux;
    mainProgram = "lsfg-vk-ui";
  };
}
