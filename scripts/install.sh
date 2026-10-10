#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build.sh
DEST="${1:-/Applications/TidyBar.app}"
if [ -e "$DEST/Contents/Info.plist" ]; then
  ID=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$DEST/Contents/Info.plist")
  if [ "$ID" != "com.peterargany.TidyBar" ]; then
    echo "Refusing to replace a different application at $DEST" >&2
    exit 1
  fi
fi
/usr/bin/ditto build/TidyBar.app "$DEST"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST"
/usr/bin/codesign --verify --deep --strict "$DEST"
echo "Installed $DEST"
