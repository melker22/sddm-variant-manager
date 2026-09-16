#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VERSION="$(sed -n 's/^project(sddm-variant-manager VERSION \([^ ]*\).*/\1/p' "$ROOT/CMakeLists.txt" | head -1)"
OUT="${1:-$ROOT/packaging/out/sddm-variant-manager-${VERSION}.tar.gz}"

mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"

tar --exclude='.git' \
    --exclude='build' \
    --exclude='build-debug' \
    --exclude='build-lightfix' \
    --exclude='result' \
    --exclude='.qt' \
    --exclude='.qtcreator' \
    --exclude='design' \
    --exclude='packaging/out' \
    --exclude='packaging/arch/pkg' \
    --exclude='packaging/arch/src' \
    --exclude='packaging/arch/*.tar.gz' \
    --exclude='packaging/arch/*.pkg.tar.zst' \
    --exclude='*.rpm' \
    --exclude='*.deb' \
    --exclude='*.pkg.tar.zst' \
    -czf "$OUT" \
    --transform "s,^,sddm-variant-manager-${VERSION}/," \
    -C "$ROOT" .

echo "$OUT"
