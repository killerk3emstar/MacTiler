# MacTiler

A native macOS window tiling app inspired by Windows 11's Snap Assist.

Unlike most macOS tilers (Rectangle, Magnet) which only cycle through fixed sizes, MacTiler uses a **real state machine** - the same hotkey produces different results depending on the window's current state. From a half, pressing the same edge again cycles its width through *the fractions you've enabled* (¼, ⅓, ½, ⅔, ¾); pressing the perpendicular direction transitions to a quarter; pressing the opposite edge restores. It feels like Windows 11 with knobs.

> [!WARNING]
> **Early beta.** Tested on one M4 MacBook on macOS 15 + 26 only - Intel and older macOS untested. Animations are still rough around the edges, multi-monitor is lightly tested, and a couple of known edge cases (see [Known limitations](#known-limitations-for-now)) are unfixed. Expect rough edges and feel free to file issues / PRs.

## Demo

https://github.com/user-attachments/assets/b1570a6d-f290-4372-a1f7-2dabf3f5b749


## Why this exists

macOS beats Windows on almost every axis - except tiling. The popular third-party options (Rectangle, Magnet, Loop) all share the same mental model: each shortcut cycles through *widths* (½ → ⅔ → ⅓) or snaps to one fixed target. None of them think in terms of *transitions between window states*, and none of them are deeply customizable in the Windows 11 sense.

Concrete pain point that pushed me to build this: I wanted a chat app permanently docked as a narrow ¼-width sidebar on the right edge - full screen height - with my main window filling the rest. In MacTiler I enable `¼` and `¾` in the width cycle (`½` is always included), snap right (`Cmd+Option+→`) to land on `rightHalf`, then keep pressing `→` until the width cycles down to ¼. If the chat app drifts itself out of place, drift detection clears the snap so the next hotkey starts clean. That configurable sidebar workflow plus a real state machine is what I couldn't get from the existing tools.

I also just like fidgeting with windows when I'm thinking - cycling one through the four corners on hotkeys (top-right → top-left → bottom-left → bottom-right) is genuinely satisfying.

## Features

- **Stateful tiling** - halves, quarters (top/bottom × left/right), maximize, top/bottom half, and floating, navigated via a direction-aware transition table
- **Per-window state** - every window keeps its own original frame; `Restore` returns it exactly where it was before the first snap
- **Drift detection** - manually moving a snapped window resets it to floating, so the next hotkey starts fresh
- **Multi-monitor** - move windows across displays with `Ctrl+Cmd+Option+Arrow`; the original frame is rebased onto the new screen
- ~~**Smooth animations**~~ **Animations** *(work-in-progress, see [Known limitations](#known-limitations-for-now))* - custom "resize at start, slide into place" with anchor correction for right/bottom-aligned targets; the algorithm is in place but transitions still look rough in some cases
- **Configurable gap** between tiled windows (0-20 px)
- **Launch at login** via `SMAppService`
- **Menu bar app** - no Dock icon, stays out of your way

## Compared to Rectangle, Magnet, and Loop

|                                            | MacTiler         | Rectangle      | Magnet         | Loop            |
|--------------------------------------------|------------------|----------------|----------------|-----------------|
| Direction-based state machine              | ✅               | ❌             | ❌             | ❌              |
| Drift detection (manual move resets state) | ✅               | ❌             | ❌             | ❌              |
| Width cycling on repeated press            | ✅ **user-configurable subset of ¼/⅓/½/⅔/¾** | ✅ (fixed) | ❌ | ✅ (fixed)      |
| Free                                       | ✅               | ✅             | ❌ paid         | ✅              |
| Open source                                | ✅ (GPL-3.0)      | ✅ (MIT)        | ❌             | ✅ (GPL-3.0)    |
| Keyboard shortcuts                         | ✅               | ✅             | ✅             | ✅              |
| Halves, quarters, thirds                   | ✅               | ✅             | ✅             | ✅              |
| Drag-to-snap                               | ❌               | ✅             | ✅             | ✅              |
| Visual preview                             | ❌               | Drag footprint | Edge overlay   | Radial menu     |

The first three solve "where should this window go?" with **width cycling** (Rectangle, Loop - same key cycles ½ → ⅔ → ⅓ along the same edge) or **direct positioning** (Magnet - every shortcut hits one fixed target). MacTiler combines width cycling with a **direction-aware state machine**: pressing the same edge cycles through *the widths you've enabled* (¼, ⅓, ½, ⅔, ¾ - pick any subset), while pressing a *perpendicular* direction transitions to a related state. From `leftHalf`, `←` cycles widths; `↑` produces a top-left quarter; `↓` a bottom-left quarter; `→` restores. Multi-step moves feel like a sequence of intentions rather than memorized cycles.

The trade-offs: no drag-to-snap and no preview overlay. If you live by dragging windows to the screen edge with visual feedback, Rectangle / Magnet / Loop will serve you better. MacTiler is the keyboard-first option for people who already think in terms of state.

## Default shortcuts

| Action | Shortcut |
|---|---|
| Snap left / right / up / down | `Cmd+Option+←/→/↑/↓` |
| Maximize | `Cmd+Option+Return` |
| Restore | `Cmd+Option+Delete` |
| Center | `Cmd+Option+C` |
| Move to adjacent monitor | `Ctrl+Cmd+Option+Arrow` |

All rebindable in Preferences (`Cmd+,`).

## State machine

The transition table - arrow = direction the window wants to "go":

```
┌──────────────────────┬──────────────┬──────────────┬──────────────────┬──────────────────┐
│ Current state        │     ↑        │     ↓        │       ←          │       →          │
├──────────────────────┼──────────────┼──────────────┼──────────────────┼──────────────────┤
│ floating             │ maximized    │ MINIMIZE     │ leftHalf         │ rightHalf        │
│ maximized            │ topHalf      │ RESTORE      │ leftHalf         │ rightHalf        │
│ topHalf              │ maximized    │ RESTORE      │ topLeftQ         │ topRightQ        │
│ bottomHalf           │ topHalf      │ RESTORE      │ botLeftQ         │ botRightQ        │
│ leftHalf             │ topLeftQ     │ botLeftQ     │ cycle width ↻    │ RESTORE          │
│ rightHalf            │ topRightQ    │ botRightQ    │ RESTORE          │ cycle width ↻    │
│ topLeftQuarter       │ maximized    │ leftHalf     │ leftHalf         │ topRightQ        │
│ topRightQuarter      │ maximized    │ rightHalf    │ topLeftQ         │ rightHalf        │
│ bottomLeftQuarter    │ leftHalf     │ RESTORE      │ leftHalf         │ botRightQ        │
│ bottomRightQuarter   │ rightHalf    │ RESTORE      │ botLeftQ         │ rightHalf        │
└──────────────────────┴──────────────┴──────────────┴──────────────────┴──────────────────┘
```

`cycle width ↻` cycles through the fractions you've enabled in Preferences (¼ / ⅓ / ½ / ⅔ / ¾ - `½` is always included). The `leftHalf` / `rightHalf` rows describe behavior for **any** full-height tile on that side; narrower full-height widths (e.g. a ¼-width sidebar) transition the same way, they just cycle to a different next width on same-side press. `RESTORE` always jumps back to the frame the window had before its first snap.

## Build

Requirements: macOS 13+, Swift 5.9+, Xcode command line tools.

```bash
swift build -c release
./build-app.sh                        # produces MacTiler.app
cp -r MacTiler.app ~/Applications/
open ~/Applications/MacTiler.app
```

On first launch, macOS will prompt for **Accessibility permission** (System Settings → Privacy & Security → Accessibility). The Accessibility API requires unsandboxed access to other processes - see "Technical notes" below.

## Architecture

```
Sources/mactiler/
├── App/              - AppDelegate, Info.plist (LSUIElement), main
├── Accessibility/    - AXUIElement wrapper, permission gate, multi-display
├── Core/             - WindowManager, WindowStateMachine, WindowStateStore,
│                       WindowAnimator, SnapPositionTransitions
├── Models/           - SnapPosition, SnapZone (frame math + gap),
│                       WindowState, Settings (UserDefaults)
├── Shortcuts/        - global hotkeys (KeyboardShortcuts by sindresorhus)
└── UI/               - StatusBarController, SwiftUI Preferences window
```

Keypress flow:

```
KeyboardShortcuts → ShortcutManager → WindowManager.handleDirection
  → AccessibilityElement.focusedWindow
  → validateWindowState (drift check vs last snappedFrame)
  → WindowStateStore.state(for: windowId)
  → WindowStateMachine.determineAction (transition table)
  → WindowAnimator.animate / AccessibilityElement.setFrame
  → WindowStateStore.setSnapPosition + setSnappedFrame
```

## Technical notes

**Two coordinate systems.** `NSScreen` uses Cocoa coordinates (Y=0 at the bottom); `AXUIElement` uses screen coordinates (Y=0 at the top). Setting a window's position via the Accessibility API requires converting:

```swift
let topY = NSScreen.screens.first!.frame.height
        - visibleFrame.origin.y - visibleFrame.height
```

Without this, vertical directions are inverted and windows don't sit flush against edges.

**Private API for window IDs.** `AXUIElement` has no public mapping to `CGWindowID`. MacTiler uses `_AXUIElementGetWindow` via `@_silgen_name` - the same private symbol that every macOS window manager relies on. Could break on a future macOS release.

**`size → position → size` trick.** Some apps (Terminal is the classic example) silently ignore a resize when the window is in the "wrong" position. Setting size twice - before and after the move - works around it.

**Animation nudge trick.** During the "slide into place" animation, a 1 px nudge (`size → position(nudge) → size → position(back)`) forces the app to re-layout without a visible flash. The nudge axis depends on the target: clamped windows nudge along X to reach full width; right/bottom-aligned targets preserve the trailing edge to avoid bounce.

**Z-order heuristic for unminimize.** Restoring a minimized window uses `CGWindowListCopyWindowInfo(.optionAll)` to read window-server z-order and pick the frontmost minimized window of the focused app. Apple doesn't guarantee that ordering, but it works in practice for the common single-window case.

**Drift detection.** After every snap, the achieved frame is stored alongside the target. On the next hotkey, MacTiler compares the window's current frame to the stored snapped frame (5 px tolerance); if they disagree, the user moved or resized the window manually, so the state is reset to `floating` and the next hotkey starts fresh from the floating row of the table. There's also a real-time path: a global `NSEvent` monitor for `.leftMouseUp` triggers the same drift check immediately on drag-release (active only when "Restore original size when untiled" is enabled in Preferences).

**No sandbox.** The Accessibility API needs to control other processes, which is impossible inside the App Sandbox. MacTiler ships as `LSUIElement=true` (menu bar, no Dock icon) but unsandboxed.

## Dependencies

- [`KeyboardShortcuts`](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre Sorhus - global hotkey registration. Without this, hotkeys mean dropping into Carbon Events.

## Acknowledgements

- The macOS window-manager community at large - [Yabai](https://github.com/koekeishiya/yabai), [Amethyst](https://github.com/ianyh/Amethyst), [Hammerspoon](https://github.com/Hammerspoon/hammerspoon), [Rectangle](https://github.com/rxhanson/Rectangle), and others. The `_AXUIElementGetWindow` private symbol and the `size → position → size` resize workaround are well-known across these projects, and any modern macOS WM stands on their collective documentation, source, and decade of accumulated bug reports.
- Apple's Accessibility API documentation, for everything else.

## Known limitations (for now)

- **Unminimize picks wrong window with multiple minimized windows of the same app.** The CGWindowList z-order heuristic returns the *first* minimized window rather than the most recent. Single-window case works fine.
- No visual overlay preview when snapping (Windows 11 shows zone hints).
- No drag-to-snap (dragging a window to a screen edge).
- Some Electron apps may ignore Accessibility resize calls.
- No behavioral presets (Windows 11 / Simple / Custom).
- Animations do not really work as expected.

## License

GPL-3.0 - see [LICENSE](LICENSE).
