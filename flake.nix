{
  description = "SDDM Variant Manager — browse, preview, apply, and install SDDM themes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          sddm-variant-manager = pkgs.callPackage ./nix/package.nix { };
        in
        {
          default = sddm-variant-manager;
          sddm-variant-manager = sddm-variant-manager;
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/sddm-variant-manager";
        };
      });

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
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
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              cmake
              ninja
              gcc
              gdb
              pkg-config
              ffmpeg
              git

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

              # Native GTK file dialogs need schemas or GLib aborts the process.
              gsettings-desktop-schemas
              gtk3
              glib
            ];

            shellHook = ''
              export QML2_IMPORT_PATH="${qmlPath}''${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
              export QML_IMPORT_PATH="${qmlPath}''${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
              export QT_PLUGIN_PATH="${pluginPath}''${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"

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
          };
        }
      );
    };
}
