import AppKit
import ApplicationServices

/// Watches snapped windows for moves, resizes and closes.
///
/// A move or resize that happens while a mouse button is held, and that we
/// did not cause ourselves, is the user dragging the window. It is reported on
/// mouse-up through `onUserDragged`, once per drag. Changes without the mouse
/// (an app adjusting its own frame) are ignored here; the next hotkey compares
/// against the expected frame instead.
@MainActor
final class WindowObserver {
    static let shared = WindowObserver()

    var onUserDragged: (AXWindow) -> Void = { _ in }
    var onClosed: (CGWindowID) -> Void = { _ in }

    private var observers: [pid_t: AXObserver] = [:]
    private var watched: [CGWindowID: AXWindow] = [:]
    private var dragged: Set<CGWindowID> = []
    private var monitors: [Any] = []

    private static let notifications = [
        kAXMovedNotification,
        kAXResizedNotification,
        kAXUIElementDestroyedNotification,
    ]

    func start() {
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown, handler: { _ in
            MainActor.assumeIsolated { WindowMover.shared.finishCurrent() }
        }) {
            monitors.append(monitor)
        }
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.mouseUp() }
        }) {
            monitors.append(monitor)
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
            MainActor.assumeIsolated {
                if let pid { self?.appTerminated(pid) }
            }
        }
    }

    func watch(_ window: AXWindow) {
        guard watched[window.id] == nil, let observer = observer(for: window.pid) else { return }
        watched[window.id] = window
        for name in Self.notifications {
            AXObserverAddNotification(observer, window.element, name as CFString, nil)
        }
    }

    func unwatch(_ id: CGWindowID) {
        guard let window = watched.removeValue(forKey: id) else { return }
        dragged.remove(id)
        if let observer = observers[window.pid] {
            for name in Self.notifications {
                AXObserverRemoveNotification(observer, window.element, name as CFString)
            }
        }
    }

    // MARK: - Events

    fileprivate func handle(_ element: AXUIElement, notification: String) {
        // Destroyed elements can no longer report their window id, so match by element.
        guard let window = watched.values.first(where: { CFEqual($0.element, element) }) else { return }

        if notification == kAXUIElementDestroyedNotification {
            unwatch(window.id)
            onClosed(window.id)
            return
        }

        let mouseDown = NSEvent.pressedMouseButtons & 1 != 0
        if mouseDown && !WindowMover.shared.isBusy(window.id) {
            dragged.insert(window.id)
        }
    }

    private func mouseUp() {
        let ids = dragged
        dragged.removeAll()
        for id in ids {
            if let window = watched[id] { onUserDragged(window) }
        }
    }

    private func appTerminated(_ pid: pid_t) {
        for (id, window) in watched where window.pid == pid {
            watched[id] = nil
            dragged.remove(id)
            onClosed(id)
        }
        if let observer = observers.removeValue(forKey: pid) {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
    }

    private func observer(for pid: pid_t) -> AXObserver? {
        if let existing = observers[pid] { return existing }

        var observer: AXObserver?
        guard AXObserverCreate(pid, observerCallback, &observer) == .success, let observer else {
            Log.error("Could not create AX observer for pid \(pid)")
            return nil
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        observers[pid] = observer
        return observer
    }
}

private func observerCallback(_ observer: AXObserver, _ element: AXUIElement,
                              _ notification: CFString, _ refcon: UnsafeMutableRawPointer?) {
    // The observer's run loop source is on the main run loop, so this runs on main.
    let name = notification as String
    nonisolated(unsafe) let element = element
    MainActor.assumeIsolated {
        WindowObserver.shared.handle(element, notification: name)
    }
}
