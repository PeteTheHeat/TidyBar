#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ICONSET="$PWD/build/AppIcon.iconset"
mkdir -p "$ICONSET"
for SIZE in 16 32 128 256 512; do
  /usr/bin/sips -z "$SIZE" "$SIZE" Resources/AppIcon.png --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
  DOUBLE=$((SIZE * 2))
  /usr/bin/sips -z "$DOUBLE" "$DOUBLE" Resources/AppIcon.png --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
/usr/bin/iconutil -c icns "$ICONSET" -o build/AppIcon.icns
