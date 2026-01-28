import AppKit

final class WindowManager {
    static let shared = WindowManager()

    private let stateMachine = WindowStateMachine.shared
    private let stateStore = WindowStateStore.shared
    private let screenManager = ScreenManager.shared

    private var lastMinimizedWindow: (element: AccessibilityElement, windowId: CGWindowID)?

    private init() {}

    func handleDirection(_ direction: SnapDirection) {
        Logger.action("Direction: \(direction)")

        guard AccessibilityPermissions.isGranted else {
            Logger.error("No accessibility permission")
            AccessibilityPermissions.requestPermissions()
            return
        }

        // Arrow up: unminimize a minimized window
        if direction == .up, Settings.shared.minimizeEnabled {
            // Check if the frontmost app has a minimized window
            if let minimizedWindow = AccessibilityElement.frontmostMinimizedWindow {
                let title = minimizedWindow.title ?? "Unknown"
                Logger.log("Unminimizing window: \"\(title)\"")
                minimizedWindow.unminimize()
                minimizedWindow.bringToFront()
                lastMinimizedWindow = nil
                Logger.success("Unminimized to floating")
                return
            }

            // Fallback: unminimize window we minimized via MacTiler
            // (frontmost app may have changed since minimize)
            if let minimized = lastMinimizedWindow {
                Logger.log("Unminimizing previously minimized window (id: \(minimized.windowId))")
                minimized.element.unminimize()
                minimized.element.bringToFront()
                lastMinimizedWindow = nil
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

        guard let screen = screenManager.screen(for: window) else { return }

        let visibleFrame = screen.visibleFrame
        let centeredX = visibleFrame.origin.x + (visibleFrame.width - currentFrame.width) / 2
        let centeredY = visibleFrame.origin.y + (visibleFrame.height - currentFrame.height) / 2

        let centeredFrame = CGRect(
            x: centeredX,
            y: centeredY,
            width: currentFrame.width,
            height: currentFrame.height
        )

        window.setFrame(centeredFrame)
        stateStore.resetToFloating(for: windowId)
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

        // Save original frame before first snap
        if let currentFrame = window.frame {
            let state = stateStore.state(for: windowId)
            if state.originalFrame == nil {
                Logger.log("Saving original frame: \(currentFrame)")
            }
            stateStore.saveOriginalFrame(currentFrame, for: windowId)
        }

        // Calculate target frame
        let targetFrame = SnapZone.calculateFrame(for: position, on: screen)
        Logger.log("Target frame: \(targetFrame)")

        // Apply the frame
        window.setFrame(targetFrame)

        // Update state
        stateStore.setSnapPosition(position, for: windowId)
        Logger.success("Snapped to \(position)")
    }

    private func restoreWindow(_ window: AccessibilityElement, windowId: CGWindowID) {
        let state = stateStore.state(for: windowId)

        if let originalFrame = state.originalFrame {
            Logger.log("Restoring to original frame: \(originalFrame)")
            window.setFrame(originalFrame)
            Logger.success("Restored")
        } else {
            Logger.error("No original frame to restore!")
        }

        stateStore.resetToFloating(for: windowId)
    }

    private func minimizeWindow(_ window: AccessibilityElement, windowId: CGWindowID) {
        guard Settings.shared.minimizeEnabled else {
            Logger.log("Minimize disabled in settings, ignoring")
            return
        }
        Logger.log("Minimizing window")
        lastMinimizedWindow = (element: window, windowId: windowId)
        window.minimize()
        stateStore.resetToFloating(for: windowId)
        Logger.success("Minimized")
    }
}
