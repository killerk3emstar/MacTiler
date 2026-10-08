import AppKit
import MacTilerCore

/// What we remember about a snapped window. Floating windows have no entry.
struct WindowState {
    var position: SnapPosition
    /// Frame before the first snap; `Restore` goes back here.
    var originalFrame: CGRect
    /// Where the window should be right now. Starts as the target frame and is
    /// replaced by the real frame once the app has settled.
    var expectedFrame: CGRect
}

@MainActor
final class WindowManager {
    static let shared = WindowManager()

    private var states: [CGWindowID: WindowState] = [:]
    private let mover = WindowMover.shared
    private let observer = WindowObserver.shared
    private let settings = Settings.shared

    func start() {
        observer.onUserDragged = { [weak self] window in self?.userDragged(window) }
        observer.onClosed = { [weak self] id in
            self?.states[id] = nil
            self?.mover.windowClosed(id)
        }
        observer.start()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { WindowMover.shared.finishCurrent() }
        }
    }

    // MARK: - Actions

    func handleDirection(_ direction: SnapDirection) {
        Log.info("Direction: \(direction)")

        if direction == .up, settings.minimizeEnabled, AXWindow.focused() == nil,
           let minimized = AXWindow.lastMinimizedOfFrontmostApp() {
            Log.info("No focused window, unminimizing \(minimized.id)")
            // No raise here: raising during the Dock's restore animation makes the window flash
            minimized.unminimize()
            return
        }

        withFocusedWindow { window, position in
            perform(position.transition(direction: direction, enabledFractions: settings.enabledWidthFractions,
                                        minimumFraction: minimumWidthFraction(of: window)),
                    on: window)
        }
    }

    func maximize() {
        withFocusedWindow { window, position in perform(position.maximizeAction, on: window) }
    }

    func restore() {
        withFocusedWindow { window, position in perform(position.restoreAction, on: window) }
    }

    func center() {
        withFocusedWindow { window, _ in
            guard let frame = window.frame, let screen = Screen.containing(frame) else { return }
            forget(window.id)
            mover.move(window, to: Geometry.centered(frame.size, in: screen.visibleFrame),
                       animated: settings.animationsEnabled)
        }
    }

    func moveToMonitor(_ direction: SnapDirection) {
        Log.info("Move to monitor: \(direction)")

        withFocusedWindow { window, position in
            guard let frame = window.frame,
                  let current = Screen.containing(frame),
                  let target = current.adjacent(direction) else {
                Log.info("No screen in direction \(direction)")
                return
            }

            // Moves across displays are never animated (see WindowMover).
            if position != .floating, var state = states[window.id],
               let targetFrame = Geometry.frame(for: position, in: target.visibleFrame, gap: settings.windowGap) {
                // Rebase the original frame so Restore stays on the new screen
                state.originalFrame = Geometry.centered(state.originalFrame.size, in: target.visibleFrame)
                state.expectedFrame = targetFrame
                states[window.id] = state
                move(window, to: targetFrame, anchor: position.anchor, animated: false)
            } else {
                mover.move(window, to: Geometry.centered(frame.size, in: target.visibleFrame), animated: false)
            }
        }
    }

    // MARK: - Internals

    /// Shared preamble: permission, a usable focused window, finish any
    /// running animation, and drop stale state if the window was changed
    /// behind our back.
    private func withFocusedWindow(_ body: (AXWindow, SnapPosition) -> Void) {
        guard AccessibilityPermissions.isGranted else {
            Log.error("No accessibility permission")
            AccessibilityPermissions.requestPermissions()
            return
        }
        guard let window = AXWindow.focused() else {
            Log.info("No focused window")
            return
        }
        guard !window.isFullScreen, !window.isMinimized else {
            Log.info("Window \(window.id) is fullscreen or minimized, ignoring")
            return
        }

        mover.finishCurrent()
        dropStateIfDrifted(window)
        body(window, states[window.id]?.position ?? .floating)
    }

    /// If a snapped window is no longer where we put it (the app or another
    /// tool moved it), treat it as floating. No resize here: only real user
    /// drags restore the original size, see `userDragged`.
    private func dropStateIfDrifted(_ window: AXWindow) {
        guard let state = states[window.id], !mover.isBusy(window.id),
              let frame = window.frame,
              Geometry.hasDrifted(frame, from: state.expectedFrame) else { return }
        Log.info("Window \(window.id) moved since last snap, now floating")
        forget(window.id)
    }

    /// The window's known minimum width as a fraction of its screen's tile
    /// area, so width cycling can skip sizes the window cannot take.
    private func minimumWidthFraction(of window: AXWindow) -> CGFloat {
        let minWidth = mover.sizeLimits(of: window.id).minimum.width
        guard minWidth > 0, let frame = window.frame, let screen = Screen.containing(frame) else { return 0 }
        let tileable = Geometry.tileableWidth(in: screen.visibleFrame, gap: settings.windowGap)
        return tileable > 0 ? minWidth / tileable : 0
    }

    private func perform(_ action: SnapAction, on window: AXWindow) {
        Log.info("Action: \(action)")
        switch action {
        case .snapTo(let position): snap(window, to: position)
        case .restore: restoreOriginal(window)
        case .minimize: minimize(window)
        case .noOp: break
        }
    }

    private func snap(_ window: AXWindow, to position: SnapPosition) {
        guard let frame = window.frame,
              let screen = Screen.containing(frame),
              let target = Geometry.frame(for: position, in: screen.visibleFrame, gap: settings.windowGap) else {
            Log.error("Could not compute target for window \(window.id)")
            return
        }

        // State changes now, not when the animation ends, so a fast second
        // keypress already sees the new position.
        let original = states[window.id]?.originalFrame ?? frame
        states[window.id] = WindowState(position: position, originalFrame: original, expectedFrame: target)
        observer.watch(window)

        move(window, to: target, anchor: position.anchor, animated: settings.animationsEnabled)
    }

    private func move(_ window: AXWindow, to target: CGRect, anchor: AnchorEdges, animated: Bool) {
        let id = window.id
        mover.move(window, to: target, anchor: anchor, animated: animated) { [weak self] settled in
            self?.states[id]?.expectedFrame = settled
        }
    }

    private func restoreOriginal(_ window: AXWindow) {
        guard let state = states[window.id] else { return }
        forget(window.id)
        mover.move(window, to: state.originalFrame, animated: settings.animationsEnabled)
    }

    private func minimize(_ window: AXWindow) {
        guard settings.minimizeEnabled else { return }
        forget(window.id)
        window.minimize()
    }

    /// The user dragged a snapped window away: it is floating now. Optionally
    /// give it back its pre-snap size where the user dropped it, like Windows.
    /// A drag that resized the window is left alone: the user chose that size.
    private func userDragged(_ window: AXWindow) {
        guard let state = states[window.id] else { return }
        forget(window.id)

        guard settings.restoreSizeOnUntile, let frame = window.frame else { return }
        let wasResized = abs(frame.width - state.expectedFrame.width) > 1
            || abs(frame.height - state.expectedFrame.height) > 1
        guard !wasResized, frame.size != state.originalFrame.size else { return }

        // Keep the point under the cursor at the same relative spot in the title bar
        let size = state.originalFrame.size
        let cursorX = NSEvent.mouseLocation.x
        let ratio = frame.width > 0 ? (cursorX - frame.minX) / frame.width : 0.5
        let x = cursorX - ratio * size.width

        Log.info("Window \(window.id) dragged out of snap, restoring size")
        mover.move(window, to: CGRect(x: x.rounded(), y: frame.minY, width: size.width, height: size.height),
                   animated: false)
    }

    private func forget(_ id: CGWindowID) {
        states[id] = nil
        observer.unwatch(id)
    }
}
