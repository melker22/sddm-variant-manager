{ pkgs ? import <nixpkgs> { } }:

let
  qmlPackages = with pkgs; [
    kdePackages.kirigami.unwrapped
    qt6.qtdeclarative
    qt6.qtmultimedia
    qt6.qtbase
    qt6.qtsvg
    qt6.qtwayland
    kdePackages.qqc2-desktop-style
  ];

  qmlPath = pkgs.lib.makeSearchPath "lib/qt-6/qml" qmlPackages;
  pluginPath = pkgs.lib.makeSearchPath "lib/qt-6/plugins" (
    with pkgs;
    [
      qt6.qtbase
      qt6.qtdeclarative
      qt6.qtmultimedia
      qt6.qtsvg
      qt6.qtwayland
      kdePackages.qqc2-desktop-style
    ]
  );
in
pkgs.mkShell {
  packages = with pkgs; [
    cmake
    ninja
    gcc
    gdb
    pkg-config

    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtmultimedia
    qt6.qtsvg
    qt6.qttools
    qt6.qtwayland

    kdePackages.extra-cmake-modules
    kdePackages.kirigami
    kdePackages.kcoreaddons
    kdePackages.ki18n
    kdePackages.karchive
    kdePackages.qqc2-desktop-style
  ];

  shellHook = ''
    # Prefer nix-shell QML modules over incomplete system merges (e.g. Plasma).
    export QML2_IMPORT_PATH="${qmlPath}''${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
    export QML_IMPORT_PATH="${qmlPath}''${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
    export QT_PLUGIN_PATH="${pluginPath}''${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
  '';
}
