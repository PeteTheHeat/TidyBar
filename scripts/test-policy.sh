#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Pure visibility rules can be tested on older macOS SDKs too.
mkdir -p build/modules
/usr/bin/xcrun swiftc -swift-version 5 -module-cache-path "$PWD/build/modules" Sources/Policy.swift Tests/PolicyTests.swift -o build/policy-tests
build/policy-tests
