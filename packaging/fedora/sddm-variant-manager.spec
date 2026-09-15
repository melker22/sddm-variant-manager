Name:           sddm-variant-manager
Version:        2.4.0
Release:        1%{?dist}
Summary:        Browse, preview, apply, install, and remove SDDM login theme variants
License:        GPL-3.0-or-later
URL:            https://github.com/melker22/sddm-variant-manager
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  cmake
BuildRequires:  extra-cmake-modules
BuildRequires:  ninja-build
BuildRequires:  gcc-c++
BuildRequires:  pkgconfig
BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtdeclarative-devel
BuildRequires:  qt6-qtmultimedia-devel
BuildRequires:  qt6-qtsvg-devel
BuildRequires:  qt6-qtwayland-devel
BuildRequires:  kf6-kirigami-devel
BuildRequires:  kf6-kcoreaddons-devel
BuildRequires:  kf6-ki18n-devel
BuildRequires:  kf6-karchive-devel

Requires:       qt6-qtbase
Requires:       qt6-qtdeclarative
Requires:       qt6-qtmultimedia
Requires:       qt6-qtsvg
Requires:       kf6-kirigami
Requires:       kf6-kcoreaddons
Requires:       kf6-ki18n
Requires:       kf6-karchive
Requires:       breeze-icon-theme
Requires:       sddm
Requires:       polkit
Recommends:     qt6-qtwayland
Recommends:     ffmpeg
Recommends:     git
Recommends:     qt6-qt5compat

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
* Tue Sep 15 2026 Melker Halberd Pereira Alves <melker168@gmail.com> - 2.4.0-1
- Initial Fedora package.
