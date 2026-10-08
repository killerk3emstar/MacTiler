# MacTiler

A native macOS window tiling app inspired by Windows 11's Snap Assist.

Unlike most macOS tilers (Rectangle, Magnet) which only cycle through fixed sizes, MacTiler uses a **real state machine** - the same hotkey produces different results depending on the window's current state. From a half, pressing the same edge again cycles its width through *the fractions you've enabled* (¼, ⅓, ½, ⅔, ¾); pressing the perpendicular direction transitions to a quarter; pressing the opposite edge restores. It feels like Windows 11 with knobs.

> [!WARNING]
> **Beta.** Developed and tested on an M4 MacBook on macOS 26 and 27. It builds for macOS 14+ on Apple Silicon and Intel, but older systems and Intel Macs are untested. Multi-monitor is lightly tested. Feel free to file issues / PRs.

## Demo

> [!NOTE]
> This video shows an older version, before the new animation engine. A new one is coming.

https://github.com/user-attachments/assets/b1570a6d-f290-4372-a1f7-2dabf3f5b749


## Why this exists

macOS beats Windows on almost every axis - except tiling. The popular third-party options (Rectangle, Magnet, Loop) all share the same mental model: each shortcut cycles through *widths* (½ → ⅔ → ⅓) or snaps to one fixed target. None of them think in terms of *transitions between window states*, and none of them are deeply customizable in the Windows 11 sense.

Concrete pain point that pushed me to build this: I wanted a chat app permanently docked as a narrow ¼-width sidebar on the right edge - full screen height - with my main window filling the rest. In MacTiler I enable `¼` and `¾` in the width cycle (`½` is always included), snap right (`Cmd+Option+→`) to land on `rightHalf`, then keep pressing `→` until the width cycles down to ¼. That configurable sidebar workflow plus a real state machine is what I couldn't get from the existing tools.

I also just like fidgeting with windows when I'm thinking - cycling one through the four corners on hotkeys (top-right → top-left → bottom-left → bottom-right) is genuinely satisfying.

## Features

- **Stateful tiling** - halves, quarters (top/bottom × left/right), maximize, top/bottom half, and floating, navigated via a direction-aware transition table
- **Configurable width cycling** - pick any subset of ¼ / ⅓ / ½ / ⅔ / ¾. Widths a window can't take (apps with a minimum width, like Discord or System Settings) are skipped, so cycling never lands on a step that looks the same
- **Smooth animations with any app** - moves animate the real window at your display's refresh rate. Resizes use an animated overlay while the window is resized once, so heavy apps like Messages don't stutter. See [how it works](docs/how-it-works.md)
- **Per-window state** - every window keeps its own original frame; `Restore` returns it exactly where it was before the first snap
- **Drag to untile** - dragging a snapped window out of its tile makes it floating again and, optionally, gives it back its original size under the cursor
- **Multi-monitor** - move windows across displays with `Ctrl+Cmd+Option+Arrow`; the original frame is rebased onto the new screen
- **Configurable gap** between tiled windows (0-20 px)
- **Menu bar app** - no Dock icon. The menu bar icon can be hidden too; launch MacTiler again to open Preferences
- **Launch at login** via `SMAppService`

## Compared to Rectangle, Magnet, and Loop

|                                            | MacTiler         | Rectangle      | Magnet         | Loop            |
|--------------------------------------------|------------------|----------------|----------------|-----------------|
| Direction-based state machine              | ✅               | ❌             | ❌             | ❌              |
| Drag out of a tile resets state            | ✅               | ❌             | ❌             | ❌              |
| Width cycling on repeated press            | ✅ **user-configurable subset of ¼/⅓/½/⅔/¾** | ✅ (fixed) | ❌ | ✅ (fixed)      |
| Skips widths the window can't take         | ✅               | ❌             | ❌             | ❌              |
| Free                                       | ✅               | ✅             | ❌ paid         | ✅              |
| Open source                                | ✅ (GPL-3.0)      | ✅ (MIT)        | ❌             | ✅ (GPL-3.0)    |
| Keyboard shortcuts                         | ✅               | ✅             | ✅             | ✅              |
| Halves, quarters, thirds                   | ✅               | ✅             | ✅             | ✅              |
| Drag-to-snap                               | ❌               | ✅             | ✅             | ✅              |

The first three solve "where should this window go?" with **width cycling** (Rectangle, Loop - same key cycles ½ → ⅔ → ⅓ along the same edge) or **direct positioning** (Magnet - every shortcut hits one fixed target). MacTiler combines width cycling with a **direction-aware state machine**: pressing the same edge cycles through *the widths you've enabled*, while pressing a *perpendicular* direction transitions to a related state. From `leftHalf`, `←` cycles widths; `↑` produces a top-left quarter; `↓` a bottom-left quarter; `→` restores. Multi-step moves feel like a sequence of intentions rather than memorized cycles.

The trade-off: no drag-to-snap. If you live by dragging windows to the screen edge, Rectangle / Magnet / Loop will serve you better. MacTiler is the keyboard-first option for people who already think in terms of state.

## Install

There are no prebuilt releases yet, so build it yourself. You need macOS 14+ and Xcode (or the Xcode command line tools).

```bash
git clone https://github.com/killerk3emstar/MacTiler.git
cd MacTiler
./build-app.sh
cp -R MacTiler.app ~/Applications/
open ~/Applications/MacTiler.app
```

On first launch macOS asks for **Accessibility permission** (System Settings → Privacy & Security → Accessibility). MacTiler needs it to move other apps' windows. It needs nothing else: no screen recording, no SIP changes.

> [!NOTE]
> Without a signing identity the app is ad-hoc signed, and macOS forgets the Accessibility permission on every rebuild. See [docs/development.md](docs/development.md#signing) for how to keep it.

## Default shortcuts

| Action | Shortcut |
|---|---|
| Snap left / right / up / down | `Cmd+Option+←/→/↑/↓` |
| Maximize | `Cmd+Option+Return` |
| Restore | `Cmd+Option+Delete` |
| Center | `Cmd+Option+C` |
| Move to adjacent monitor | `Ctrl+Cmd+Option+Arrow` |

Modifiers and the Maximize / Restore / Center keys are configurable in Preferences.

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

- `cycle width ↻` cycles through the fractions you've enabled in Preferences (`½` is always included). The `leftHalf` / `rightHalf` rows describe **any** full-height tile on that side; a ¼-width sidebar transitions the same way, it just cycles to a different next width.
- If a window has a minimum width, widths below it would all look the same, so cycling skips them. MacTiler learns the minimum the first time the app refuses a size.
- `RESTORE` jumps back to the frame the window had before its first snap.
- `MINIMIZE` (and `↑` with no focused window to unminimize) can be turned off in Preferences.

This table is also a unit test (`Tests/MacTilerCoreTests/TransitionTests.swift`), so it can't silently drift from the code.

## Preferences

Open with `Cmd+,` from the menu bar menu, or by launching MacTiler again while it runs.

| Setting | What it does |
|---|---|
| Launch at login | Registers MacTiler as a login item. Reflects System Settings → General → Login Items. |
| Show menu bar icon | Hide the icon entirely. You can also Cmd-drag it out of the menu bar. Launch MacTiler again to get back to Preferences. |
| Enable minimize/unminimize | Whether `↓` from floating minimizes, and `↑` with no window unminimizes. |
| Restore original size when dragged out of a tile | After dragging a snapped window away, give it back its pre-snap size under the cursor. Drags that resize the window are left alone. |
| Animate window transitions | Master switch for animations. |
| Resize animation | **Glass** animates an overlay while the window is resized once (smooth with any app). **Live** resizes the real window every frame (smooth only with light apps). |
| Overlay style / opacity | Look of the glass overlay: Frosted (default), Liquid Glass, Clear Glass (both macOS 26+), Accent, Outline. **Preview** plays it over the Preferences window. |
| Tiling sizes | Which widths to cycle through. |
| Window gap | Space around and between tiles. |
| Shortcuts tab | Modifiers for tiling and for moving between monitors, and the keys for Maximize / Restore / Center. |

## Documentation

- [How it works](docs/how-it-works.md) - moving other apps' windows: the Accessibility API, animation, the overlay, size limits, drag detection, and the approaches that don't work
- [Architecture](docs/architecture.md) - code layout, keypress flow, threading, tests
- [Development](docs/development.md) - building, testing, signing, logging, debugging

## Known limitations

- **Unminimize with several minimized windows of one app** picks by window-server order, which Apple doesn't guarantee. Single-window case works fine.
- **No drag-to-snap** (dragging a window to a screen edge) and no snap zone preview while dragging.
- **Some Electron apps** may ignore Accessibility resize calls.
- **Size limits are learned per window per session.** The first time a window hits its minimum width, that press is a normal visible step; after that, cycling skips dead widths.
- **Moves between displays are not animated**, on purpose: macOS clips windows that straddle displays mid-move.

## Acknowledgements

- The macOS window-manager community at large - [Yabai](https://github.com/koekeishiya/yabai), [Amethyst](https://github.com/ianyh/Amethyst), [AeroSpace](https://github.com/nikitabobko/AeroSpace), [Hammerspoon](https://github.com/Hammerspoon/hammerspoon), [Rectangle](https://github.com/rxhanson/Rectangle), [Loop](https://github.com/MrKai77/Loop), and others. The `_AXUIElementGetWindow` private symbol, the `AXEnhancedUserInterface` workaround and the grow/shrink write ordering are well-known across these projects, and any modern macOS WM stands on their collective documentation, source, and decade of accumulated bug reports.
- [`KeyboardShortcuts`](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre Sorhus for global hotkey registration.

## License

GPL-3.0 - see [LICENSE](LICENSE).
