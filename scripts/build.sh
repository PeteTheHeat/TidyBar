#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/toolchain.sh
APP="$PWD/build/TidyBar.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Helpers" build/modules
"$CLANG" -fobjc-arc -fmodules -fmodules-cache-path="$PWD/build/modules" -isysroot "$SDK" -mmacosx-version-min=27.0 -c Sources/Native/MBAssessmentShim.m -o build/MBAssessmentShim.o
"$SWIFTC" -swift-version 5 -O -sdk "$SDK" -target arm64-apple-macosx27.0 -module-cache-path "$PWD/build/modules" -import-objc-header Sources/Native/include/MBAssessmentShim.h Sources/*.swift Sources/UI/*.swift build/MBAssessmentShim.o -framework AppKit -framework SwiftUI -framework ApplicationServices -framework Carbon -o "$APP/Contents/MacOS/TidyBar"
cp Resources/Info.plist "$APP/Contents/Info.plist"
./scripts/icon.sh
cp Resources/AppIcon.png "$APP/Contents/Resources/AppIcon.png"
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp LICENSE "$APP/Contents/Resources/LICENSE"
cp THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/THIRD_PARTY_NOTICES.md"
"$SWIFTC" -swift-version 5 -O -sdk "$SDK" -target arm64-apple-macosx27.0 -module-cache-path "$PWD/build/modules" Tests/Fixture.swift -o build/Fixture
for NAME in Shown Hidden Never; do
  FIXTURE="$APP/Contents/Helpers/$NAME.app"
  mkdir -p "$FIXTURE/Contents/MacOS"
  cp build/Fixture "$FIXTURE/Contents/MacOS/Fixture"
  LOWER=$(echo "$NAME" | tr '[:upper:]' '[:lower:]')
  cat > "$FIXTURE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleExecutable</key><string>Fixture</string><key>CFBundleIdentifier</key><string>com.peterargany.TidyBar.fixture.$LOWER</string><key>CFBundleName</key><string>$NAME</string><key>CFBundlePackageType</key><string>APPL</string><key>LSUIElement</key><true/><key>LSMinimumSystemVersion</key><string>27.0</string></dict></plist>
EOF
  /usr/bin/codesign --force --sign - "$FIXTURE"
done
/usr/bin/codesign --force --sign - --identifier com.peterargany.TidyBar -r '=designated => identifier "com.peterargany.TidyBar"' "$APP"
/usr/bin/codesign --verify --deep --strict "$APP"
"$APP/Contents/MacOS/TidyBar" --self-test
echo "Built $APP"
