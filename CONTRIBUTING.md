# Contributing

Small, focused changes are welcome. TidyBar keeps one clear job: choose which menu bar items are visible.

## Develop

Use an Apple Silicon Mac, macOS 27 or newer, and a macOS 27 SDK or newer. Install Apple's Command Line Tools or Xcode. There are no package dependencies. `DEVELOPER_DIR` can select a toolchain; otherwise the build prefers a complete macOS 27 Command Line Tools installation.

```sh
./scripts/build.sh
./scripts/install.sh
open /Applications/TidyBar.app
```

Quit the previous instance before installing. Run the installed copy in Applications, because macOS uses the registered application identity for native menu bar control. Grant Accessibility through System Settings. Never edit the permissions database.

## Verify

```sh
./scripts/test-policy.sh
/Applications/TidyBar.app/Contents/MacOS/TidyBar --probe
open /Applications/TidyBar.app --args --verify-live
cat /tmp/tidybar-live-test.txt
```

Quit TidyBar before starting the live test. It temporarily launches three bundled fixture apps, checks actual MenuBarAgent frames, exercises category visibility and pause, then restores the original in-memory state. Fixture rules are not saved. The fixture apps are only launched by this opt-in test.

Policy CI verifies the pure category rules. Full application and menu bar checks require a Mac with the supported OS and user-approved Accessibility. See [the validation record](Tests/VALIDATION.md) for what was actually tested and what remains unverified.

## Package and screenshots

```sh
./scripts/package.sh
build/TidyBar.app/Contents/MacOS/TidyBar --export-screenshots docs/images
```

The packaging script creates an ad-hoc signed DMG, ZIP, installation guide, and SHA-256 manifest in `build/release`. It does not notarize the app. Screenshots render the production settings view with sample data; they do not scan the Mac, activate hiding, or save assignments.

## Review

Describe the trigger, expected behavior, actual behavior, OS build, and checks performed. Changes to the private native adapter need live visibility checks, error handling, and restoration on failure. Preserve upstream attribution and the GPL-3.0 license. Do not commit private screen captures, local settings, or credentials.
