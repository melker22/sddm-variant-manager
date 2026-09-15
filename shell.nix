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
    kdePackages.layer-shell-qt
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
      kdePackages.layer-shell-qt
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
    kdePackages.layer-shell-qt

    # File dialogs via QT_QPA_PLATFORMTHEME=gtk3 need these or GLib aborts.
    gsettings-desktop-schemas
    gtk3
    glib
  ];

  shellHook = ''
    # Prefer nix-shell QML modules over incomplete system merges (e.g. Plasma).
    export QML2_IMPORT_PATH="${qmlPath}''${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
    export QML_IMPORT_PATH="${qmlPath}''${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
    export QT_PLUGIN_PATH="${pluginPath}''${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"

    # Prevent "No GSettings schemas are installed on the system" SIGABRT when
    # opening native GTK file/folder dialogs from the install sheet.
    # Nix stores compiled schemas under share/gsettings-schemas/<pkg>/glib-2.0/schemas.
    _schema_dirs=()
    for _root in \
      "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas" \
      "${pkgs.gtk3}/share/gsettings-schemas"
    do
      if [[ -d "$_root" ]]; then
        for _p in "$_root"/*/glib-2.0/schemas; do
          if [[ -d "$_p" ]]; then
            _schema_dirs+=("$_p")
          fi
        done
      fi
    done
    if ((''${#_schema_dirs[@]})); then
      _joined="$(IFS=:; echo "''${_schema_dirs[*]}")"
      export GSETTINGS_SCHEMA_DIR="''${_joined}''${GSETTINGS_SCHEMA_DIR:+:$GSETTINGS_SCHEMA_DIR}"
    fi
    export XDG_DATA_DIRS="${pkgs.gsettings-desktop-schemas}/share:${pkgs.gtk3}/share''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
  '';
}
