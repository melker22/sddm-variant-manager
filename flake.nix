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
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              cmake
              ninja
              gcc
              gdb
              pkg-config
              git
              ffmpeg

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
              export QML2_IMPORT_PATH="${qmlPath}''${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
              export QML_IMPORT_PATH="${qmlPath}''${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
              export QT_PLUGIN_PATH="${pluginPath}''${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
            '';
          };
        }
      );
    };
}
