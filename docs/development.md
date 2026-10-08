# Development

## Requirements

- macOS 14 or later
- Xcode with a recent SDK (the app is built with the newest SDK installed; see [SDK version](#sdk-version))
- Swift 6 (comes with Xcode)

## Build and run

```bash
swift build                 # debug build of everything
swift test                  # unit tests for MacTilerCore
./build-app.sh              # release MacTiler.app (universal: arm64 + x86_64)
```

To install and restart the app after a build:

```bash
osascript -e 'quit app "MacTiler"'
rm -rf ~/Applications/MacTiler.app && cp -R MacTiler.app ~/Applications/
open ~/Applications/MacTiler.app
```

The app needs Accessibility permission (System Settings → Privacy & Security → Accessibility). If hotkeys do nothing after a rebuild, the permission was lost: remove MacTiler from that list, add it again, and relaunch. See [Signing](#signing) to avoid that.

## What build-app.sh does

1. Builds a universal release binary with SwiftPM.
2. Creates `MacTiler.app` with the binary and `Sources/mactiler/App/Info.plist`.
3. Stamps the real SDK version into the binary (see below).
4. Signs the bundle: with `CODESIGN_IDENTITY` if set, ad-hoc otherwise.

### SDK version

SwiftPM records the deployment target (14.0) as the SDK version in the binary. macOS keeps apps linked against an old SDK in the old design, so without a fix MacTiler would miss the macOS 26+ look (Liquid Glass, new window controls). The script rewrites the SDK version with `vtool` to the SDK actually used. The minimum system version stays 14.0, so this doesn't affect which systems can run the app.

Check it with:

```bash
otool -l MacTiler.app/Contents/MacOS/MacTiler | grep -A4 LC_BUILD_VERSION
```

### Signing

macOS ties the Accessibility permission to the app's code signature. An ad-hoc signature changes on every build, so the permission is lost every time. Sign with a real identity to keep it:

```bash
security find-identity -v -p codesigning
CODESIGN_IDENTITY="Apple Development: Your Name (TEAMID)" ./build-app.sh
```

A free Apple Development certificate from Xcode is enough for your own machine. Distributing builds to other people needs a Developer ID certificate and notarization, which the script doesn't do yet.

## Logging

MacTiler logs through `os.Logger` with the subsystem `com.mactiler.app`. Watch it live:

```bash
log stream --predicate 'subsystem == "com.mactiler.app"' --level info
```

Logs are public, so they never include window titles or other user content. Windows are identified by their numeric ID.

## Settings

Preferences are stored in `UserDefaults` under `com.mactiler.app`:

```bash
defaults read com.mactiler.app
defaults delete com.mactiler.app     # reset everything to defaults
```

Keys written by an older pre-release build (`fraction_quarter` and similar) are migrated on launch.

## Testing by hand

The window engine talks to real apps, so it needs manual testing. Apps worth checking, and why:

| App | Why |
|---|---|
| Messages | Catalyst app: large minimum size, applies sizes late, slow relayout |
| Discord, Slack | Electron: heavy relayout, reacts to `AXEnhancedUserInterface` |
| System Settings | Large minimum width |
| Terminal | Resizes in character-cell steps |
| Finder, Safari | Light, well-behaved baseline |

Things to try:

- Width cycling on both sides, including apps whose minimum width is above some enabled widths. After the first press that hits the minimum, no press should look like a no-op.
- Fast repeated hotkeys during an animation.
- Floating to half and back (Restore), from a small window in the middle of the screen.
- Dragging a snapped window out of its tile, with and without "Restore original size".
- Moving between displays, snapped and floating.
- Each overlay style, including on a macOS version below 26 if you have one (Liquid Glass falls back to Frosted).
- Preferences with the menu bar icon hidden: launch MacTiler again, check the window opens on the current Space and the menu bar shows MacTiler's menu.

## Code style

- Pure logic goes in `MacTilerCore` with tests. Anything that needs AppKit or AX goes in the app target.
- Keep rectangles in AX coordinates. Convert from `NSScreen` once, through `Screen` or `Geometry.toAX`.
- Comments explain why, especially for workarounds of app or macOS behavior.
- If you change the transition table, change the README table and `TransitionTests` together.
