#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
VERSION="$(sed -n 's/^sddm-variant-manager (\([^)]*\)).*/\1/p' "$HERE/debian/changelog" | head -1 | cut -d- -f1)"
ROOT="$(cd "$HERE/../.." && pwd)"
if [[ -z "${TARBALL:-}" ]]; then
  TARBALL="$ROOT/packaging/out/sddm-variant-manager-${VERSION}.tar.gz"
fi
OUT="${OUT:-$ROOT/../out/debian}"

if ! command -v dpkg-buildpackage >/dev/null; then
  echo "dpkg-buildpackage not found. Install dpkg-dev, or run via packaging/docker/build-all.sh" >&2
  exit 1
fi

if [[ ! -f "$TARBALL" ]]; then
  "$ROOT/packaging/docker/make-source-tarball.sh" "$TARBALL"
fi

WORKDIR="$(mktemp -d)"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

tar -xzf "$TARBALL" -C "$WORKDIR"
SRC="$WORKDIR/sddm-variant-manager-${VERSION}"
cp -a "$HERE/debian" "$SRC/debian"
chmod +x "$SRC/debian/rules"

(cd "$SRC" && dpkg-buildpackage -us -uc -b)

mkdir -p "$OUT"
find "$WORKDIR" -maxdepth 1 -type f \( -name '*.deb' -o -name '*.ddeb' -o -name '*.changes' -o -name '*.buildinfo' \) \
  -exec cp -v {} "$OUT/" \;
echo "Packages in $OUT"
ls -1 "$OUT"/*.deb
