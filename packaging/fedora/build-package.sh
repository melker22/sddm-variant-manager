#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
VERSION="$(sed -n 's/^Version:[[:space:]]*//p' "$HERE/sddm-variant-manager.spec" | head -1)"
if [[ -z "${TARBALL:-}" ]]; then
  ROOT="$(cd "$HERE/../.." && pwd)"
  TARBALL="$ROOT/packaging/out/sddm-variant-manager-${VERSION}.tar.gz"
fi
OUT="${OUT:-${ROOT:-$HERE}/../out/fedora}"

if ! command -v rpmbuild >/dev/null; then
  echo "rpmbuild not found. Install rpm-build on Fedora, or run via packaging/docker/build-all.sh" >&2
  exit 1
fi

if [[ ! -f "$TARBALL" ]]; then
  "$ROOT/packaging/docker/make-source-tarball.sh" "$TARBALL"
fi

WORKDIR="$(mktemp -d)"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

mkdir -p "$WORKDIR"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
cp "$TARBALL" "$WORKDIR/SOURCES/"
cp "$HERE/sddm-variant-manager.spec" "$WORKDIR/SPECS/"

rpmbuild -ba "$WORKDIR/SPECS/sddm-variant-manager.spec" \
  --define "_topdir $WORKDIR"

mkdir -p "$OUT"
find "$WORKDIR/RPMS" "$WORKDIR/SRPMS" -type f \( -name '*.rpm' \) -exec cp -v {} "$OUT/" \;
echo "Packages in $OUT"
ls -1 "$OUT"/*.rpm
