# Architecture

How the code is organized and how a keypress turns into a moved window. For *why* the window engine works the way it does, see [How it works](how-it-works.md).

## Layout

The package has two targets. Everything that can be pure is in `MacTilerCore`, which doesn't import AppKit, so it can be unit-tested without a window server.

```
Sources/
├── MacTilerCore/              pure logic, no AppKit
│   ├── SnapPosition.swift     snap states, width fractions, anchors, actions
│   ├── Transitions.swift      the transition table and width cycling
│   ├── Geometry.swift         coordinate flip, tile frames, anchoring,
│   │                          drift check, screen picking
│   └── FrameAnimation.swift   easing, interpolation, grow/shrink write order
│
└── mactiler/                  the app
    ├── App/                   main, AppDelegate, Info.plist
    ├── Accessibility/
    │   ├── AXWindow.swift     one window of another app, via AX
    │   ├── Screens.swift      NSScreen with frames in AX coordinates
    │   └── AccessibilityPermissions.swift
    ├── Core/
    │   ├── WindowManager.swift   actions, per-window state, drift
    │   ├── WindowMover.swift     animation, overlay, settling, size limits
    │   ├── WindowObserver.swift  AXObserver: drags, closed windows
    │   └── Log.swift
    ├── Models/Settings.swift     preferences, single source of truth
    ├── Shortcuts/ShortcutAction.swift   every action, hotkeys and menu
    └── UI/
        ├── StatusBarController.swift    menu bar icon and menu
        ├── ResizeOverlay.swift          the glass overlay window
        └── Preferences/                 SwiftUI views, window controller

Tests/MacTilerCoreTests/       transition table, geometry, animation math
```

## Keypress flow

```
KeyboardShortcuts (Carbon hotkey, key down)
  └─ ShortcutAction.perform()
       └─ WindowManager.handleDirection(.right)
            ├─ AXWindow.focused()                  which window
            ├─ WindowMover.finishCurrent()         end any running animation
            ├─ dropStateIfDrifted()                moved behind our back?
            ├─ SnapPosition.transition(...)        what to do (MacTilerCore)
            │     uses the learned minimum width to skip dead widths
            ├─ Geometry.frame(for:in:gap:)         where to put it (MacTilerCore)
            ├─ state updated, WindowObserver.watch()
            └─ WindowMover.move(...)
                 ├─ live or glass animation on the display link
                 ├─ AXWindow.apply / settle        the actual AX writes
                 └─ 150 ms later: read real frame, learn size limits,
                    report it back as the expected frame
```

The menu bar menu calls the same `ShortcutAction.perform()`, so the menu and the hotkeys can't behave differently.

## Responsibilities

| Type | Owns | Doesn't know about |
|---|---|---|
| `SnapPosition` + transitions | What a direction means from a given state | Screens, windows, AX |
| `Geometry` | All rectangle math, in AX coordinates | NSScreen, Settings |
| `AXWindow` | Talking to one window: reads, writes, timeouts, `AXEnhancedUserInterface` | State, animation |
| `WindowMover` | Getting a window to a frame: animation, overlay, settling, size limits | Snap positions, the transition table |
| `WindowObserver` | Noticing user drags and closed windows | What to do about them |
| `WindowManager` | Per-window state and turning actions into moves | How moves are animated |
| `Settings` | Every preference, persisted to `UserDefaults` | Who reads it |
| `ShortcutAction` | The list of user actions, their titles and hotkeys | How actions are carried out |

## Threading

Everything runs on the main thread. The app target is in Swift 6 language mode and every type that touches AppKit or AX is `@MainActor`. Callbacks that arrive from C or from AppKit (AX observer, event monitors, display link, notifications) are on the main run loop and enter the main actor with `MainActor.assumeIsolated`.

AX calls are synchronous, so a slow app could block the main thread. That is bounded by the messaging timeouts described in [How it works](how-it-works.md#busy-apps-messaging-timeouts) rather than by moving AX work to background threads. AeroSpace uses one thread per app instead. That would be the next step if a timeout ever turns out not to be enough.

## Settings and shortcuts

`Settings` is an `@Observable` class and the only place preferences live. Each property writes to `UserDefaults` in `didSet`, and the Preferences views bind to it directly. Launch at login is not stored: it is read from `SMAppService` so it can't disagree with System Settings.

Shortcuts are defined by `Settings` (modifier groups plus the configurable keys) and pushed into KeyboardShortcuts by `ShortcutAction.syncWithSettings()`. KeyboardShortcuts keeps its own copy in `UserDefaults` only because it needs one to register hotkeys. Hotkeys are paused while the menu bar menu is open, otherwise they'd be buffered and fire when it closes.

## Activation policy

MacTiler runs as an accessory app (`LSUIElement`): no Dock icon and no main menu. When Preferences opens, it switches to a regular app with a main menu, a Dock icon and a Cmd-Tab entry, and switches back when Preferences closes. An accessory app that becomes active has no menu to show, which left the menu bar empty.

Launching MacTiler while it runs opens Preferences (`applicationShouldHandleReopen`). That's the way back in when the menu bar icon is hidden.

## Tests

```bash
swift test
```

`MacTilerCore` is covered by Swift Testing suites:

- **TransitionTests**: the README transition table, row by row; width cycling; skipping widths below a window's minimum.
- **GeometryTests**: coordinate conversion, tile frames with and without gaps, shared tile edges, centering, anchoring, drift, picking screens.
- **FrameAnimationTests**: interpolation, easing, and the grow/shrink write order.

The app target has no automated tests. Anything that talks to AX needs real windows from real apps and is tested by hand; see [Development](development.md#testing-by-hand).
