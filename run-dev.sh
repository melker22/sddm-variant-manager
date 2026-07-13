#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
BIN="$ROOT/build/Desktop_Nix_Qt6-Debug/sddm-variant-manager"
if [[ ! -x "$BIN" ]]; then
  BIN="$ROOT/build/sddm-variant-manager"
fi
exec nix-shell --run "exec \"$BIN\" $*"
