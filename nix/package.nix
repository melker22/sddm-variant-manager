{
  stdenv,
  lib,
  cmake,
  ninja,
  pkg-config,
  qt6,
  kdePackages,
  ffmpeg,
  gsettings-desktop-schemas,
  gtk3,
  glib,
}:

stdenv.mkDerivation {
  pname = "sddm-variant-manager";
  version = "2.2.0";

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
        "design"
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
    # Freedesktop icons used by Kirigami.Icon (list-add, view-refresh, …).
    # Explicit so Hyprland/non-Plasma sessions still resolve UI icons when the
    # active GTK icon theme is missing or incomplete.
    kdePackages.breeze-icons
    gsettings-desktop-schemas
    gtk3
    glib
  ];

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
  ];

  # ffmpeg for video thumbnails; GSettings schemas so GTK file dialogs do not SIGABRT.
  # Schemas live under share/gsettings-schemas/<pkg>/glib-2.0/schemas on Nix.
  # breeze-icons on XDG_DATA_DIRS so QIcon fallback theme "breeze" is always found.
  qtWrapperArgs = [
    "--prefix PATH : ${lib.makeBinPath [ ffmpeg ]}"
    "--prefix XDG_DATA_DIRS : ${gsettings-desktop-schemas}/share"
    "--prefix XDG_DATA_DIRS : ${gtk3}/share"
    "--prefix XDG_DATA_DIRS : ${kdePackages.breeze-icons}/share"
    "--prefix GSETTINGS_SCHEMA_DIR : ${gsettings-desktop-schemas}/share/gsettings-schemas/${gsettings-desktop-schemas.name}/glib-2.0/schemas"
    "--prefix GSETTINGS_SCHEMA_DIR : ${gtk3}/share/gsettings-schemas/${gtk3.name}/glib-2.0/schemas"
  ];

  meta = with lib; {
    description = "Browse, preview, apply, and install SDDM login themes (including multi-variant collections)";
    homepage = "https://github.com/melker22/sddm-variant-manager";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
    mainProgram = "sddm-variant-manager";
  };
}
