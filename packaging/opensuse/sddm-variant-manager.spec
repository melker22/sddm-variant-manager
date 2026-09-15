Name:           sddm-variant-manager
Version:        2.4.0
Release:        1.0
Summary:        Browse, preview, apply, install, and remove SDDM login theme variants
License:        GPL-3.0-or-later
Group:          System/GUI/KDE
URL:            https://github.com/melker22/sddm-variant-manager
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  cmake
BuildRequires:  extra-cmake-modules
BuildRequires:  ninja
BuildRequires:  gcc-c++
BuildRequires:  pkg-config
BuildRequires:  qt6-base-devel
BuildRequires:  qt6-declarative-devel
BuildRequires:  qt6-multimedia-devel
BuildRequires:  qt6-svg-devel
BuildRequires:  qt6-wayland-devel
BuildRequires:  kf6-kirigami-devel
BuildRequires:  kf6-kcoreaddons-devel
BuildRequires:  kf6-ki18n-devel
BuildRequires:  kf6-karchive-devel

Requires:       libQt6Core6
Requires:       libQt6Gui6
Requires:       libQt6Qml6
Requires:       libQt6Quick6
Requires:       libQt6Multimedia6
Requires:       libQt6Svg6
Requires:       kf6-kirigami
Requires:       kf6-kcoreaddons
Requires:       kf6-ki18n
Requires:       kf6-karchive
Requires:       breeze6-icons
Requires:       sddm
Requires:       polkit
Recommends:     ffmpeg
Recommends:     git

%description
SDDM Variant Manager lists installed SDDM themes, supports multi-variant
collections, installs themes from archives or public GitHub repositories
without executing install.sh, and runs the real greeter in test mode.

%prep
%autosetup -n %{name}-%{version}

%build
cmake -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=%{_prefix}
cmake --build build

%install
DESTDIR=%{buildroot} cmake --install build

%files
%license LICENSE
%doc README.md
%{_bindir}/sddm-variant-manager
%{_datadir}/applications/org.github.melker.sddmvariantmanager.desktop
%{_datadir}/metainfo/org.github.melker.sddmvariantmanager.appdata.xml
%{_datadir}/icons/hicolor/*/apps/org.github.melker.sddmvariantmanager.*

%changelog
* Tue Sep 15 2026 Melker Halberd Pereira Alves <melker168@gmail.com> - 2.4.0-1.0
- Initial openSUSE package.
