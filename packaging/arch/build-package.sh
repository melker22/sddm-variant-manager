#!/usr/bin/bash
# SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$(dirname "$0")"

if ! command -v makepkg >/dev/null; then
  echo "makepkg not found. Install base-devel: pamac install base-devel --no-confirm"
  exit 1
fi

echo "Creating source tarball from $ROOT ..."
rm -f "sddm-variant-manager-1.0.0.tar.gz"
tar --exclude='.git' \
    --exclude='build' \
    --exclude='.qtcreator' \
    --exclude='packaging/arch/*.tar.gz' \
    --exclude='packaging/arch/pkg' \
    --exclude='packaging/arch/src' \
    --exclude='packaging/arch/*.pkg.tar.zst' \
    -czf "sddm-variant-manager-1.0.0.tar.gz" \
    --transform 's,^,sddm-variant-manager-1.0.0/,' \
    -C "$ROOT" .

echo "Updating sha256sum in PKGBUILD ..."
SUM=$(sha256sum "sddm-variant-manager-1.0.0.tar.gz" | awk '{print $1}')
sed -i "s/^sha256sums=('.*')/sha256sums=('${SUM}')/" PKGBUILD

makepkg --syncdeps --cleanbuild --noconfirm "$@"

echo
echo "Package built in: $(pwd)"
ls -1 ./*.pkg.tar.zst 2>/dev/null || true
echo
echo "Install with:"
echo "  sudo pacman -U ./sddm-variant-manager-*.pkg.tar.zst"
echo "  # or: pamac install ./sddm-variant-manager-*.pkg.tar.zst --no-confirm"
