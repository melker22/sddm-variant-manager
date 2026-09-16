#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Melker Halberd Pereira Alves
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Build distro packages inside Docker from a NixOS (or any) host.
# Usage: packaging/docker/build-all.sh [arch|fedora|debian|opensuse|all]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/packaging/out"
VERSION="$(sed -n 's/^project(sddm-variant-manager VERSION \([^ ]*\).*/\1/p' "$ROOT/CMakeLists.txt" | head -1)"
TARGET="${1:-all}"

docker_bin() {
  if command -v docker >/dev/null && docker info >/dev/null 2>&1; then
    echo docker
    return
  fi
  if sudo -n docker info >/dev/null 2>&1; then
    echo "sudo docker"
    return
  fi
  if command -v docker >/dev/null; then
    echo "sudo docker"
    return
  fi
  echo "Docker is not available. Enable virtualisation.docker and rebuild NixOS." >&2
  exit 1
}

DOCKER="$(docker_bin)"
mkdir -p "$OUT"

TARBALL="$OUT/sddm-variant-manager-${VERSION}.tar.gz"
"$ROOT/packaging/docker/make-source-tarball.sh" "$TARBALL"

run_distro() {
  local name="$1"
  local dockerfile="$ROOT/packaging/docker/Dockerfile.$name"
  local image="sddm-variant-manager-$name"
  local dest="$OUT/$name"

  echo "=== Building image $image ==="
  $DOCKER build -t "$image" -f "$dockerfile" "$ROOT/packaging/docker"

  echo "=== Building $name package ==="
  mkdir -p "$dest"
  $DOCKER run --rm \
    --network=host \
    -v "$TARBALL:/src/sddm-variant-manager-${VERSION}.tar.gz:ro" \
    -v "$ROOT/packaging:/packaging:ro" \
    -v "$dest:/out" \
    -e "TARBALL=/src/sddm-variant-manager-${VERSION}.tar.gz" \
    -e "OUT=/out" \
    "$image" \
    bash -lc "
      set -euo pipefail
      case '$name' in
        arch)
          tar -xzf /src/sddm-variant-manager-${VERSION}.tar.gz -C /tmp
          SRC=/tmp/sddm-variant-manager-${VERSION}
          mkdir -p \$SRC/packaging/arch
          cp /packaging/arch/PKGBUILD /packaging/arch/build-package.sh \$SRC/packaging/arch/
          chown -R builder:builder /tmp/sddm-variant-manager-${VERSION}
          su - builder -c \"cd \$SRC/packaging/arch && bash ./build-package.sh\"
          cp -v \$SRC/packaging/arch/*.pkg.tar.zst /out/
          ;;
        fedora)
          bash /packaging/fedora/build-package.sh
          ;;
        debian)
          bash /packaging/debian/build-package.sh
          ;;
        opensuse)
          bash /packaging/opensuse/build-package.sh
          ;;
      esac
    "

  echo "=== $name artifacts ==="
  ls -lh "$dest"
}

case "$TARGET" in
  arch|fedora|debian|opensuse)
    run_distro "$TARGET"
    ;;
  all)
    for d in arch fedora debian opensuse; do
      run_distro "$d"
    done
    ;;
  *)
    echo "Usage: $0 [arch|fedora|debian|opensuse|all]" >&2
    exit 2
    ;;
esac

echo
echo "Done. Packages under $OUT"
find "$OUT" -type f \( -name '*.rpm' -o -name '*.deb' -o -name '*.pkg.tar.zst' \) -print
