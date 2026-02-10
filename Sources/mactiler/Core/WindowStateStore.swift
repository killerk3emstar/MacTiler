import AppKit

final class WindowStateStore {
    static let shared = WindowStateStore()

    private var states: [CGWindowID: WindowState] = [:]
    private let lock = NSLock()

    private init() {
        setupCleanupTimer()
    }

    func state(for windowId: CGWindowID) -> WindowState {
        lock.lock()
        defer { lock.unlock() }

        if let existing = states[windowId] {
            return existing
        }

        let newState = WindowState(windowId: windowId)
        states[windowId] = newState
        return newState
    }

    func updateState(_ state: WindowState) {
        lock.lock()
        defer { lock.unlock() }
        states[state.windowId] = state
    }

    func saveOriginalFrame(_ frame: CGRect, for windowId: CGWindowID) {
        lock.lock()
        defer { lock.unlock() }

        if var state = states[windowId] {
            if state.originalFrame == nil {
                state.originalFrame = frame
                states[windowId] = state
            }
        } else {
            var newState = WindowState(windowId: windowId)
            newState.originalFrame = frame
            states[windowId] = newState
        }
    }

    func setSnapPosition(_ position: SnapPosition, for windowId: CGWindowID) {
        lock.lock()
        defer { lock.unlock() }

        if var state = states[windowId] {
            state.snapPosition = position
            states[windowId] = state
        } else {
            var newState = WindowState(windowId: windowId)
            newState.snapPosition = position
            states[windowId] = newState
        }
    }

    func setSnappedFrame(_ frame: CGRect, for windowId: CGWindowID) {
        lock.lock()
        defer { lock.unlock() }

        if var state = states[windowId] {
            state.snappedFrame = frame
            states[windowId] = state
        }
    }

    func resetToFloating(for windowId: CGWindowID) {
        lock.lock()
        defer { lock.unlock() }

        if var state = states[windowId] {
            state.snapPosition = .floating
            state.originalFrame = nil
            state.snappedFrame = nil
            states[windowId] = state
        }
    }

    private func setupCleanupTimer() {
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.cleanupStaleStates()
        }
    }

    private func cleanupStaleStates() {
        lock.lock()
        defer { lock.unlock() }

        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        let activeWindowIds = Set(windowList.compactMap { $0[kCGWindowNumber as String] as? CGWindowID })

        states = states.filter { activeWindowIds.contains($0.key) }
    }
}
