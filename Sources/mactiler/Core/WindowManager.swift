import AppKit

final class WindowManager {
    static let shared = WindowManager()

    private let stateMachine = WindowStateMachine.shared
    private let stateStore = WindowStateStore.shared
    private let screenManager = ScreenManager.shared

    private var dragMonitor: Any?

    private init() {}

    func setupDragDetection() {
        dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            self?.checkForDragDrift()
        }
    }

    private func checkForDragDrift() {
        WindowAnimator.shared.cancel()

        guard Settings.shared.restoreSizeOnUntile else { return }

        guard let window = AccessibilityElement.focusedWindow,
              let windowId = window.windowId,
              !window.isFullScreen,
              !window.isMinimized else { return }

        let state = stateStore.state(for: windowId)
        guard state.isSnapped,
              let snappedFrame = state.snappedFrame,
              let currentFrame = window.frame,
              hasDrifted(currentFrame, from: snappedFrame) else { return }

        if let originalFrame = state.originalFrame {
            let restoredFrame = CGRect(
                x: currentFrame.origin.x,
                y: currentFrame.origin.y,
                width: originalFrame.width,
                height: originalFrame.height
            )
            window.setFrame(restoredFrame)
            Logger.log("Drag detected: restored original size")
        }
        stateStore.resetToFloating(for: windowId)
    }

    func handleDirection(_ direction: SnapDirection) {
        Logger.action("Direction: \(direction)")

        guard AccessibilityPermissions.isGranted else {
            Logger.error("No accessibility permission")
            AccessibilityPermissions.requestPermissions()
            return
        }

        // Arrow up: unminimize a minimized window of the frontmost app
        if direction == .up, Settings.shared.minimizeEnabled {
            if let minimizedWindow = AccessibilityElement.frontmostMinimizedWindow {
                let title = minimizedWindow.title ?? "Unknown"
                Logger.log("Unminimizing window: \"\(title)\"")
                minimizedWindow.unminimize()
                minimizedWindow.bringToFront()
                Logger.success("Unminimized to floating")
                return
            }
        }

        guard let window = AccessibilityElement.focusedWindow else {
            Logger.error("No focused window")
            return
        }

        guard let windowId = window.windowId else {
            Logger.error("Could not get window ID")
            return
        }

        guard !window.isFullScreen else {
            Logger.log("Window is fullscreen, ignoring")
            return
        }

        guard !window.isMinimized else {
            Logger.log("Window is minimized, ignoring")
            return
        }

        let windowTitle = window.title ?? "Unknown"
        Logger.log("Window: \"\(windowTitle)\" (id: \(windowId))")

        WindowAnimator.shared.finalizePendingAnimation()
        validateWindowState(window: window, windowId: windowId)

        let currentState = stateStore.state(for: windowId)
        Logger.log("Current state: \(currentState.snapPosition)")

        let action = stateMachine.determineAction(currentState: currentState, direction: direction)
        Logger.log("Action: \(action)")

        executeAction(action, on: window, windowId: windowId)
    }

    func maximize() {
        guard AccessibilityPermissions.isGranted else {
            AccessibilityPermissions.requestPermissions()
            return
        }

        guard let window = AccessibilityElement.focusedWindow,
              let windowId = window.windowId,
              !window.isFullScreen,
              !window.isMinimized else {
            return
        }

        WindowAnimator.shared.finalizePendingAnimation()
        validateWindowState(window: window, windowId: windowId)

        let currentState = stateStore.state(for: windowId)
        let action = stateMachine.actionForMaximize(currentState: currentState)

        executeAction(action, on: window, windowId: windowId)
    }

    func restore() {
        guard AccessibilityPermissions.isGranted else {
            AccessibilityPermissions.requestPermissions()
            return
        }

        guard let window = AccessibilityElement.focusedWindow,
              let windowId = window.windowId,
              !window.isFullScreen,
              !window.isMinimized else {
            return
        }

        WindowAnimator.shared.finalizePendingAnimation()
        validateWindowState(window: window, windowId: windowId)

        let currentState = stateStore.state(for: windowId)
        let action = stateMachine.actionForRestore(currentState: currentState)

        executeAction(action, on: window, windowId: windowId)
    }

    func center() {
        guard AccessibilityPermissions.isGranted else {
            AccessibilityPermissions.requestPermissions()
            return
        }

        guard let window = AccessibilityElement.focusedWindow,
              let windowId = window.windowId,
              !window.isFullScreen,
              !window.isMinimized,
              let currentFrame = window.frame else {
            return
        }

        WindowAnimator.shared.finalizePendingAnimation()
        validateWindowState(window: window, windowId: windowId)

        guard let screen = screenManager.screen(for: window) else { return }

        let centeredFrame = centeredFrame(for: currentFrame.size, on: screen)

        if Settings.shared.animationsEnabled {
            WindowAnimator.shared.animate(window: window, from: currentFrame, to: centeredFrame) { [self] _ in
                stateStore.resetToFloating(for: windowId)
            }
        } else {
            window.setFrame(centeredFrame)
            stateStore.resetToFloating(for: windowId)
        }
    }

    func moveToMonitor(_ direction: SnapDirection) {
        Logger.action("Move to monitor: \(direction)")

        guard AccessibilityPermissions.isGranted else {
            Logger.error("No accessibility permission")
            AccessibilityPermissions.requestPermissions()
            return
        }

        guard let window = AccessibilityElement.focusedWindow else {
            Logger.error("No focused window")
            return
        }

        guard let windowId = window.windowId else {
            Logger.error("Could not get window ID")
            return
        }

        guard !window.isFullScreen, !window.isMinimized else {
            Logger.log("Window is fullscreen or minimized, ignoring")
            return
        }

        guard let currentScreen = screenManager.screen(for: window) else {
            Logger.error("Could not determine current screen")
            return
        }

        guard let targetScreen = screenManager.adjacentScreen(to: currentScreen, direction: direction) else {
            Logger.log("No adjacent screen in direction \(direction)")
            return
        }

        validateWindowState(window: window, windowId: windowId)

        let currentState = stateStore.state(for: windowId)
        let windowTitle = window.title ?? "Unknown"
        Logger.log("Moving \"\(windowTitle)\" to adjacent monitor (\(direction)), state: \(currentState.snapPosition)")

        if currentState.snapPosition != .floating {
            // Snapped: recalculate same position on target screen
            let position = currentState.snapPosition
            let targetFrame = SnapZone.calculateFrame(for: position, on: targetScreen)
            window.setFrame(targetFrame)

            applyAnchorCorrection(window: window, targetFrame: targetFrame, position: position)

            if let achievedFrame = window.frame {
                stateStore.setSnappedFrame(achievedFrame, for: windowId)
            }

            // Rebase originalFrame onto target screen so restore doesn't jump back
            if let origFrame = currentState.originalFrame {
                var updatedState = stateStore.state(for: windowId)
                updatedState.originalFrame = centeredFrame(for: origFrame.size, on: targetScreen)
                stateStore.updateState(updatedState)
            }

            Logger.success("Moved to adjacent monitor, kept \(currentState.snapPosition)")
        } else {
            // Floating: center on target screen
            guard let currentFrame = window.frame else { return }
            window.setFrame(centeredFrame(for: currentFrame.size, on: targetScreen))
            Logger.success("Moved to adjacent monitor, centered")
        }
    }

    /// Re-anchor window position if it couldn't shrink to target size.
    /// For right-aligned positions, keeps right edge fixed; for bottom-aligned, keeps bottom edge fixed.
    private func applyAnchorCorrection(window: AccessibilityElement, targetFrame: CGRect, position: SnapPosition) {
        guard let actualFrame = window.frame else { return }

        var adjustedOrigin = targetFrame.origin
        var needsAdjust = false

        if position.isRightAligned && actualFrame.width > targetFrame.width {
            adjustedOrigin.x = targetFrame.origin.x + targetFrame.width - actualFrame.width
            needsAdjust = true
        }

        if position.isBottomAligned && actualFrame.height > targetFrame.height {
            adjustedOrigin.y = targetFrame.origin.y + targetFrame.height - actualFrame.height
            needsAdjust = true
        }

        if needsAdjust {
            Logger.log("Window couldn't achieve target size, re-anchoring position")
            window.position = adjustedOrigin
        }
    }

    private func validateWindowState(window: AccessibilityElement, windowId: CGWindowID) {
        let state = stateStore.state(for: windowId)
        guard state.isSnapped,
              let snappedFrame = state.snappedFrame,
              let currentFrame = window.frame,
              hasDrifted(currentFrame, from: snappedFrame) else { return }

        Logger.log("Window manually moved/resized, resetting to floating")

        if Settings.shared.restoreSizeOnUntile, let originalFrame = state.originalFrame {
            let restoredFrame = CGRect(
                x: currentFrame.origin.x,
                y: currentFrame.origin.y,
                width: originalFrame.width,
                height: originalFrame.height
            )
            window.setFrame(restoredFrame)
            Logger.log("Restored original size: \(originalFrame.width)x\(originalFrame.height)")
        }

        stateStore.resetToFloating(for: windowId)
    }

    /// Calculate a centered frame for a given size on a screen (in AX coordinates).
    private func centeredFrame(for size: CGSize, on screen: NSScreen) -> CGRect {
        let visibleFrame = screen.visibleFrame
        let screenHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
        let topY = screenHeight - visibleFrame.origin.y - visibleFrame.height

        return CGRect(
            x: visibleFrame.origin.x + (visibleFrame.width - size.width) / 2,
            y: topY + (visibleFrame.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    private func hasDrifted(_ current: CGRect, from snapped: CGRect) -> Bool {
        let tolerance: CGFloat = 5
        return abs(current.origin.x - snapped.origin.x) > tolerance
            || abs(current.origin.y - snapped.origin.y) > tolerance
            || abs(current.width - snapped.width) > tolerance
            || abs(current.height - snapped.height) > tolerance
    }

    private func executeAction(_ action: SnapAction, on window: AccessibilityElement, windowId: CGWindowID) {
        switch action {
        case .snapTo(let position):
            snapWindow(window, windowId: windowId, to: position)

        case .restore:
            restoreWindow(window, windowId: windowId)

        case .minimize:
            minimizeWindow(window, windowId: windowId)

        case .noOp:
            break
        }
    }

    private func snapWindow(_ window: AccessibilityElement, windowId: CGWindowID, to position: SnapPosition) {
        guard let screen = screenManager.screen(for: window) else {
            Logger.error("Could not determine screen for window")
            return
        }

        guard let currentFrame = window.frame else {
            Logger.error("Could not read window frame")
            return
        }

        // Save original frame before first snap
        let state = stateStore.state(for: windowId)
        if state.originalFrame == nil {
            Logger.log("Saving original frame: \(currentFrame)")
        }
        stateStore.saveOriginalFrame(currentFrame, for: windowId)

        // Calculate target frame
        let targetFrame = SnapZone.calculateFrame(for: position, on: screen)
        Logger.log("Target frame: \(targetFrame)")

        if Settings.shared.animationsEnabled {
            WindowAnimator.shared.animate(window: window, from: currentFrame, to: targetFrame,
                                          anchorPosition: position) { [self] achievedFrame in
                // Store achieved frame for drift detection
                if let achieved = achievedFrame {
                    stateStore.setSnappedFrame(achieved, for: windowId)
                } else if let fallback = window.frame {
                    stateStore.setSnappedFrame(fallback, for: windowId)
                }
                stateStore.setSnapPosition(position, for: windowId)
                Logger.success("Snapped to \(position)")
            }
        } else {
            window.setFrame(targetFrame)
            applyAnchorCorrection(window: window, targetFrame: targetFrame, position: position)

            if let achievedFrame = window.frame {
                stateStore.setSnappedFrame(achievedFrame, for: windowId)
            }
            stateStore.setSnapPosition(position, for: windowId)
            Logger.success("Snapped to \(position)")
        }
    }

    private func restoreWindow(_ window: AccessibilityElement, windowId: CGWindowID) {
        let state = stateStore.state(for: windowId)

        if let originalFrame = state.originalFrame {
            Logger.log("Restoring to original frame: \(originalFrame)")

            if Settings.shared.animationsEnabled {
                guard let currentFrame = window.frame else {
                    window.setFrame(originalFrame)
                    stateStore.resetToFloating(for: windowId)
                    Logger.success("Restored")
                    return
                }
                WindowAnimator.shared.animate(window: window, from: currentFrame, to: originalFrame) { [self] _ in
                    stateStore.resetToFloating(for: windowId)
                    Logger.success("Restored")
                }
            } else {
                window.setFrame(originalFrame)
                stateStore.resetToFloating(for: windowId)
                Logger.success("Restored")
            }
        } else {
            Logger.error("No original frame to restore!")
            stateStore.resetToFloating(for: windowId)
        }
    }

    private func minimizeWindow(_ window: AccessibilityElement, windowId: CGWindowID) {
        guard Settings.shared.minimizeEnabled else {
            Logger.log("Minimize disabled in settings, ignoring")
            return
        }
        Logger.log("Minimizing window")
        window.minimize()
        stateStore.resetToFloating(for: windowId)
        Logger.success("Minimized")
    }
}
