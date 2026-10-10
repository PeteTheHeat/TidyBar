#!/bin/bash
# Prefer a complete macOS 27 Command Line Tools installation when no toolchain
# was requested. An explicit DEVELOPER_DIR always takes priority.
if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Library/Developer/CommandLineTools/SDKs/MacOSX27.0.sdk ]; then
  export DEVELOPER_DIR=/Library/Developer/CommandLineTools
fi
SDK=$(/usr/bin/xcrun --sdk macosx --show-sdk-path)
SDK_VERSION=$(/usr/bin/xcrun --sdk macosx --show-sdk-version)
if [ "${SDK_VERSION%%.*}" -lt 27 ]; then
  echo "TidyBar requires the macOS 27 SDK or newer. Found SDK $SDK_VERSION." >&2
  exit 1
fi
SWIFTC=$(/usr/bin/xcrun --find swiftc)
CLANG=$(/usr/bin/xcrun --find clang)
