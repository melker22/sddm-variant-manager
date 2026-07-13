{
  stdenv,
  lib,
  cmake,
  ninja,
  pkg-config,
  qt6,
  kdePackages,
  git,
  ffmpeg,
}:

stdenv.mkDerivation {
  pname = "sddm-variant-manager";
  version = "2.0.2";

  src = lib.cleanSourceWith {
    src = ../.;
    filter =
      path: type:
      let
        base = baseNameOf path;
      in
      !(builtins.elem base [
        ".git"
        "build"
        "result"
        ".qtcreator"
        ".cursor"
      ]);
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtmultimedia
    qt6.qtsvg
    qt6.qtwayland
    kdePackages.kirigami
    kdePackages.kcoreaddons
    kdePackages.ki18n
    kdePackages.karchive
    kdePackages.extra-cmake-modules
    kdePackages.qqc2-desktop-style
  ];

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
  ];

  # Ensure git/ffmpeg are available for install-from-GitHub and video thumbnails.
  qtWrapperArgs = [
    "--prefix PATH : ${lib.makeBinPath [ git ffmpeg ]}"
  ];

  meta = with lib; {
    description = "Browse, preview, apply, and install SDDM login themes (including multi-variant collections)";
    homepage = "https://github.com/melker22/sddm-variant-manager";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
    mainProgram = "sddm-variant-manager";
  };
}
