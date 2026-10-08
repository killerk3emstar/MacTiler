# How MacTiler moves windows

This document explains how a third-party app moves and resizes *other apps'* windows on macOS, why that is harder than it looks, and what MacTiler does about it. If you just want to use MacTiler, the [README](../README.md) is enough.

- [The only tool: the Accessibility API](#the-only-tool-the-accessibility-api)
- [Two coordinate systems](#two-coordinate-systems)
- [Finding the window to act on](#finding-the-window-to-act-on)
- [Writing a frame](#writing-a-frame)
- [Animation](#animation)
- [Settling and learning size limits](#settling-and-learning-size-limits)
- [State, drags and drift](#state-drags-and-drift)
- [Multiple displays](#multiple-displays)
- [Approaches that don't work](#approaches-that-dont-work)

## The only tool: the Accessibility API

macOS has no public API to move another app's window. The only supported way is the **Accessibility API** (AX), the same one VoiceOver uses. Every window is an `AXUIElement`, and you move it by setting its `AXPosition` and `AXSize` attributes.

Three properties of AX shape everything else:

1. **Every call is a synchronous round trip into the other app.** Setting a window's size sends a message to that app, waits for it to handle it on its main thread, and waits for the reply. If the app is busy, you wait.
2. **Position and size are separate writes.** There is no "set frame" call. A move plus resize is at least two messages, and the app sees them one at a time.
3. **The app decides.** You ask for a size; the app can refuse (minimum sizes), round it (Terminal snaps to character cells), or apply it later (Catalyst and SwiftUI apps, like Messages, often settle a few frames late).

AX also has no public way to map an `AXUIElement` to a `CGWindowID`. MacTiler uses the private `_AXUIElementGetWindow` symbol for that, like every other macOS window manager. Window IDs are what per-window state is keyed by.

## Two coordinate systems

AppKit (`NSScreen`) puts the origin at the **bottom-left** of the primary display with Y growing up. AX puts it at the **top-left** of the primary display with Y growing down. Every screen rect has to be converted before it can be used as a window frame:

```
ax.y = primaryScreenHeight - (cocoa.y + cocoa.height)
```

The same formula converts back, since the flip is its own inverse. It lives in one place, `Geometry.toAX`, and everything in `MacTilerCore` works in AX coordinates. `Screen` wraps each `NSScreen` with its frames already converted.

## Finding the window to act on

`AXWindow.focused()` asks the system-wide AX element for the focused application. That is updated immediately on Cmd-Tab, while `NSWorkspace.frontmostApplication` can lag. Then it picks a window:

1. The app's focused window, if it's a standard window (`AXWindow` role, `AXStandardWindow` subrole).
2. Otherwise the app's main window, if it's standard.
3. Otherwise the focused window, unless it's a floating panel or system dialog.

This matters because the focused window is often a panel: an inspector, a color picker, Messages' emoji picker. Tiling those is never what you want.

Full-screen and minimized windows are ignored.

## Writing a frame

`AXWindow.apply(_:from:anchor:)` performs one step from the current frame to the next. Several problems are handled here.

### Busy apps: messaging timeouts

The default AX timeout is about 6 seconds. A busy app could freeze MacTiler for that long on a single call, and with it the hotkeys and the animation. MacTiler sets:

| Scope | Timeout |
|---|---|
| Global cap (system-wide element) | 1 s |
| Normal calls on a window or app | 0.25 s |
| During an animation | 0.05 s, a frame that takes longer is skipped anyway |

### Apps that animate AX writes: `AXEnhancedUserInterface`

Assistive tools such as VoiceOver, and other utilities, set `AXEnhancedUserInterface` on apps to get a richer accessibility tree from them. Chrome and Electron apps in particular react to it. While it is on, the app animates or delays every AX frame change, so a MacTiler animation turns into a pile of overlapping app animations and the window lags behind.

MacTiler turns it off on the app before writing and restores it right after, for every move, animated or not. AeroSpace, yabai and Rectangle do the same.

### Write order: grow vs shrink

Because position and size are separate writes, the order matters:

- **Growing at the old position** can push the window past the screen edge. macOS clips it, and the window ends up smaller than asked.
- **Shrinking after moving** briefly shows the window at its old size in the new place.

So the order is decided **per axis** (`FrameWritePlan` in `MacTilerCore`):

```
axis grows   ->  move first, then resize
axis shrinks ->  resize first, then move
```

A window that gets wider but shorter moves its X before the resize and its Y after.

### Apps that refuse a size: anchoring

After the resize, MacTiler reads back the size the app actually accepted. If it differs, the window is positioned to keep its **anchored edges** in place (`Geometry.anchoredOrigin`). A right-side tile is anchored right, a bottom tile is anchored bottom. A Messages window that can't get as narrow as a right quarter stays flush with the right screen edge and extends left, instead of spilling off screen.

### Retrying across displays

When a window moves to another display, its first resize can be clipped by the display it is leaving. `AXWindow.settle` runs one more `apply` if the size didn't take. This replaces the classic `size -> position -> size` trick with something that only does the extra write when needed.

## Animation

Animations take 0.2 s with an ease-out curve. They run on the target screen's **display link** (`NSScreen.displayLink`), so they tick at the display's refresh rate, up to 120 Hz on ProMotion. Progress comes from elapsed time, not a frame counter, so a slow frame is skipped instead of stretching the animation.

There are two kinds of animation, because moving and resizing cost very different amounts.

### Moving is cheap

Changing only a window's position doesn't make the app lay anything out. Even heavy apps handle it at display rate. When the size doesn't change (half to half, quarter to quarter, center), MacTiler animates the **real window**, writing an interpolated position every frame.

### Resizing is expensive

Every size change makes the app relayout its whole window. Apps optimize for the user dragging a window corner (AppKit's "live resize" mode), but an AX resize doesn't trigger that mode, so each write is a full, unoptimized relayout. A heavy app like Messages, Discord or Slack can't do 120 of those per second. Resizing the real window every frame is what made animations stutter in earlier versions, and other tilers have the same problem.

### The overlay ("glass")

So for size changes MacTiler animates something it owns instead: a borderless window drawn above everything, styled as frosted glass by default (`ResizeOverlay`). Moving and resizing your own window is cheap, so the overlay stays smooth no matter how slow the app underneath is.

The real window still takes part, but only in cheap ways:

```
Shrinking (e.g. rightHalf -> right quarter)
  t = 0      resize the window to its target size, once
  0 -> 0.2s  overlay shrinks from the old frame to the new one;
             the window rides along, pinned to the overlay's anchored corner
  end        overlay fades out

Growing (e.g. small floating window -> leftHalf)
  0 -> 0.2s  overlay grows from the old frame to the new one;
             the window keeps its old size and rides along, pinned to the
             overlay's anchored corner
  end        resize the window to its target size, once; overlay fades out
```

Riding along is a position write per frame, which is cheap. If even that is too slow for an app (two frames over 50 ms in a row), the window stops following and the overlay finishes alone.

The overlay draws nothing from the window underneath. It is just a shape. That's why it needs no screen recording permission.

Styles: Frosted (`NSVisualEffectView`, default), Liquid Glass and Clear Glass (`NSGlassEffectView`, macOS 26+, falling back to Frosted on older systems), Accent and Outline. The blur radius of the system materials is fixed; there is no public API to change it, so the only extra knob is opacity.

The **Live** resize animation is still available in Preferences. It writes the full frame to the real window every frame, and gives up and jumps to the end if the app is too slow (two frames over 50 ms in a row).

### When animation is skipped

- Animations are off in Preferences.
- The move crosses displays. A window straddling two displays mid-move gets clipped and jumps.
- Low Power Mode is on.
- A new hotkey, a mouse click or a display change arrives mid-animation: the current animation jumps straight to its end before anything else happens.

## Settling and learning size limits

After the final write, MacTiler waits **150 ms** before reading the window's real frame. Catalyst and SwiftUI apps often apply a size a few frames after accepting it, so an immediate read would be stale. That settled frame becomes the window's expected frame (see below).

Comparing the size it asked for with the size it got tells MacTiler the window's **size limits**, which AX doesn't expose:

- **Got bigger than asked** -> that's the window's minimum on that axis.
- **Got smaller than asked** -> that's its maximum.
- **Got a size outside a learned limit** -> the limit was stale (the app changed it, or macOS clipped the window to a small display), so it's dropped.

Limits are kept in memory per window and forgotten when the window closes. They're used in two places:

1. **Width cycling.** The minimum width in points is converted to a fraction of the current screen's tile area at the moment you press the key, so the same window behaves correctly on a laptop and on an ultrawide. Widths below the minimum all look the same, so cycling skips any step that wouldn't change the width (`SnapPosition.nextFraction`). Discord on a laptop with ¼, ½ and ¾ enabled cycles between its minimum and ¾.
2. **The overlay.** When shrinking, the window is resized before the overlay starts, so its real size is known and the overlay ends exactly there. When growing, a known maximum stops the overlay short. If an unknown maximum is hit, the overlay snaps onto the real frame before fading, and the maximum is remembered.

Limits are deliberately **not saved to disk**. A saved limit would have to be per app rather than per window, and windows of one app have different minimums. Worse, if an update lowered an app's minimum, cycling would keep skipping a size that now works and never find out. Relearning costs one ordinary keypress per window per session.

## State, drags and drift

`WindowManager` keeps state only for **snapped** windows: the snap position, the frame before the first snap (for Restore), and the expected frame. A window without an entry is floating.

State changes when the action happens, not when its animation ends, so a fast second keypress already sees the new position.

### Drags

A window the user drags out of its tile should become floating. MacTiler registers an `AXObserver` for move and resize notifications on each snapped window. A notification that arrives **while a mouse button is held** and **not during MacTiler's own move** is a user drag. On mouse-up, the window becomes floating. If "Restore original size when dragged out of a tile" is on, it gets its pre-snap size back, positioned so the point under the cursor stays at the same relative spot in the title bar. A drag that resized the window is left alone, since the user picked that size.

The same observer reports when a window closes or its app quits, which clears its state.

### Drift

An app can also move its own window, or another tool can. Those changes are not drags and are ignored when they happen. Instead, on the next hotkey, MacTiler compares the window's current frame to the expected frame. If any edge is off by more than 8 points, the window is treated as floating and the hotkey acts from the floating row of the table. Nothing is resized in that case.

## Multiple displays

- The screen a window is on is the one showing the **largest part** of it, not the one containing its center, which is wrong for windows hanging over an edge.
- `Ctrl+Cmd+Option+Arrow` finds the nearest display in that direction that overlaps on the other axis.
- A snapped window keeps its snap position on the new display. Its saved original frame is moved to the new display too, so Restore doesn't jump back.
- A floating window is centered on the new display and shrunk if it doesn't fit.

## Approaches that don't work

These came up while designing the engine. They are documented here so nobody has to rediscover why they were rejected.

| Approach | Why not |
|---|---|
| **Resize the real window every frame** | Each write is a full relayout in the app. Heavy apps stutter. Still available as the Live option. |
| **Resize once at the start, then slide** | The window visibly jumps to its new size before moving. This was the original MacTiler animation. |
| **Animate a screenshot of the window** (yabai-style) | Needs Screen Recording permission. Also, without SIP you can't hide the real window, so it would show under the screenshot anyway. |
| **Transform or warp other apps' windows** (`SLSSetWindowTransform`, `CGSSetWindowWarp`) | Only the Dock's connection may do this to other apps' windows. yabai gets there by injecting code into the Dock, which requires partially disabling SIP and breaks with macOS updates. |
| **macOS 15+ "Move & Resize" menu items via AX** | Native Apple animation, but only fixed halves, quarters and fill, so fractional widths are impossible. The app must be frontmost and have a standard Window menu, and the menu identifiers are private. |
| **Probe a window's minimum size** by asking for 1×1 | The window visibly flashes. Learning from refused sizes costs nothing. |
| **Persist learned size limits** | See [Settling and learning size limits](#settling-and-learning-size-limits). |
