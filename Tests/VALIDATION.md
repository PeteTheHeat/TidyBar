# Verification on the target Mac

Verified 2026-10-08 on macOS 27.0.1, build 26A434, Apple Silicon. Installed application: `/Applications/TidyBar.app`.

## Release packaging verification: 1.0.0

On 2026-10-09, the final ZIP was extracted and its app installed in Applications. All 11 live checks below passed again using that packaged binary. The user's original category choices were restored. The DMG mounted successfully, contained the app, Applications shortcut, installation guide, license, and notices, and its app passed deep strict signature verification. The ZIP's executable matched the build output. Both archives and the installation guide passed their SHA-256 manifest checks. The binary is arm64; the release is ad-hoc signed, without Developer ID signing or Apple notarization. The download Gatekeeper approval flow was documented from Apple's instructions, not exercised with a fresh quarantine on this Mac.

Light, dark, and permissions screenshots were visually reviewed. They render the settings view with sample items and static equivalents of interactive scroll/drop controls. They contain no captured personal menu bar configuration.

## Live native checks: 11 passed

The app launched three actual native menu bar fixture applications. Assertions below came from fresh Accessibility snapshots of MenuBarAgent, including each item's on-screen frame, rather than from the configuration or completion callback alone.

- All three fixture icons appeared before hiding.
- Always Show remained visible when collapsed.
- Show on Demand disappeared when collapsed.
- Always Hidden disappeared when collapsed.
- The native assertion completed without an error.
- Actual Wi-Fi and Bluetooth icons disappeared in their assigned categories.
- Show on Demand returned on reveal.
- Always Show remained visible on reveal.
- Always Hidden remained absent on reveal.
- Wi-Fi returned on reveal while Bluetooth remained hidden.
- Pausing restored all three fixture icons.

The harness restored the original categories and terminated the fixture apps. Diagnostic frames are in `/tmp/tidybar-live-test.txt` for this run.

## Native settings checks

- Accessibility was requested through macOS and approved by the user. The installed app retained permission across rebuilds and installation.
- The live inventory identified third-party apps and supported Apple system items.
- Assigning a third-party item through the category picker changed the actual menu bar.
- Clicking TidyBar's real menu bar icon revealed on-demand items.
- AppKit drag-and-drop moved that item into Always Hidden; the drag log confirmed source, target, accepted identifier, and successful native drop operation.
- Always Hidden survived quitting and relaunching the app.
- The category picker restored the item's original category afterward. Auto-hide was restored to enabled. No fixture assignments remain.
- All three category trays fit in the settings window. Permission status distinguishes Granted from native backend Available.
- The Carbon event handler and global hotkey both registered successfully (`OSStatus 0`). Option–Command–B toggled visibility in the app through native event handling. Physical keyboard input from another application was not tested; CUA's app-targeted keyboard delivery did not exercise that route.
- Ad-hoc signing and the complete installed bundle passed `codesign --verify --deep --strict`.
- Policy checks passed for collapsed and revealed categories, always-hidden isolation, new apps, preserving the control icon, and settings serialization.

## Limits

The backend uses macOS 27's private MenuBarClientCore API. It can change in future OS updates. Third-party icons are managed by app bundle, so an app's multiple icons share one category. Unsupported Apple extras are excluded from assignable tiles; native hiding suppresses some extras, including Now Playing and Fast User Switching. Screen Recording was left ungranted, so optional image captures were not verified; app-icon previews and all core controls were tested without it.
