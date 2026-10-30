#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DESTINATION="$HOME/Applications/Multicopy.app"

"$ROOT/scripts/build.sh"

mkdir -p "$HOME/Applications"
pkill -x Multicopy 2>/dev/null || true
rm -rf "$DESTINATION"
ditto "$ROOT/build/Multicopy.app" "$DESTINATION"
xattr -cr "$DESTINATION"

codesign --force --sign - "$DESTINATION"
codesign --verify --strict "$DESTINATION"

open "$DESTINATION"
echo "Installed $DESTINATION"
