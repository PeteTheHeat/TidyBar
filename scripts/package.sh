#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build.sh
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)
NAME="TidyBar-$VERSION-arm64"
STAGE="$PWD/build/package"
DIST="$PWD/build/release"
mkdir -p "$STAGE" "$DIST"
/usr/bin/ditto build/TidyBar.app "$STAGE/TidyBar.app"
ln -sfn /Applications "$STAGE/Applications"
cp docs/INSTALL.txt "$STAGE/Read Me.txt"
cp LICENSE "$STAGE/LICENSE.txt"
cp THIRD_PARTY_NOTICES.md "$STAGE/Third Party Notices.md"
/usr/bin/codesign --verify --deep --strict "$STAGE/TidyBar.app"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$STAGE/TidyBar.app" "$DIST/$NAME.zip"
/usr/bin/hdiutil create -volname "TidyBar $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DIST/$NAME.dmg"
cp docs/INSTALL.txt "$DIST/INSTALL.txt"
(cd "$DIST" && /usr/bin/shasum -a 256 "$NAME.dmg" "$NAME.zip" INSTALL.txt > SHA256SUMS.txt)
echo "Release assets: $DIST"
