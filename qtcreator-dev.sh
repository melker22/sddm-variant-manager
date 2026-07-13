#!/usr/bin/env bash
# Launch Qt Creator inside this project's nix-shell so CMake finds Qt6 + Kirigami.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
exec nix-shell --run "qtcreator '${ROOT}/CMakeLists.txt' $*"
