import AppKit
import ApplicationServices
import MacTilerCore

@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ windowId: inout CGWindowID) -> AXError

/// A top-level window of another app, driven through the Accessibility API.
///
/// Every AX call is a synchronous IPC round trip into the target app. Each
/// element gets a short messaging timeout so a busy app (Messages doing
/// layout, a beachballing Electron app) cannot freeze MacTiler for the default
/// ~6 seconds.
@MainActor
final class AXWindow {
    /// Timeout for normal one-off calls.
    static let defaultTimeout: Float = 0.25
    /// Timeout during animation: a frame that takes longer is skipped anyway.
    static let animationTimeout: Float = 0.05

    let element: AXUIElement
    let pid: pid_t
    let id: CGWindowID

    init?(_ element: AXUIElement) {
        var pid: pid_t = 0
        var id: CGWindowID = 0
        guard AXUIElementGetPid(element, &pid) == .success,
              _AXUIElementGetWindow(element, &id) == .success else { return nil }
        self.element = element
        self.pid = pid
        self.id = id
        setMessagingTimeout(Self.defaultTimeout)
    }

    // MARK: - Finding windows

    /// The window the user is working in.
    ///
    /// Prefers a standard window. AXFocusedWindow can be a floating panel or
    /// picker (Messages' emoji picker, inspector panels), which should never
    /// be tiled, so in that case the app's main window is used instead.
    static func focused() -> AXWindow? {
        guard let app = focusedApplication() else { return nil }

        let focused = app.element(for: kAXFocusedWindowAttribute).flatMap(AXWindow.init)
        if let focused, focused.isStandard { return focused }

        let main = app.element(for: kAXMainWindowAttribute).flatMap(AXWindow.init)
        if let main, main.isStandard { return main }

        if let focused, focused.role == kAXWindowRole, !focused.isPanel { return focused }
        return nil
    }

    /// The most recently minimized window of the frontmost app, using
    /// window-server order (front to back) to decide which is most recent.
    static func lastMinimizedOfFrontmostApp() -> AXWindow? {
        guard let app = focusedApplication(),
              let elements: [AXUIElement] = app.value(for: kAXWindowsAttribute) else { return nil }

        let minimized = elements.compactMap(AXWindow.init).filter(\.isMinimized)
        guard !minimized.isEmpty else { return nil }

        let byId = Dictionary(minimized.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let order = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        for info in order {
            if let number = info[kCGWindowNumber as String] as? CGWindowID, let window = byId[number] {
                return window
            }
        }
        return minimized.first
    }

    private static func focusedApplication() -> AXUIElement? {
        // The system-wide element tracks focus changes immediately, while
        // NSWorkspace.frontmostApplication can lag right after Cmd-Tab.
        let systemWide = AXUIElementCreateSystemWide()
        if let app = systemWide.element(for: kAXFocusedApplicationAttribute) {
            AXUIElementSetMessagingTimeout(app, defaultTimeout)
            return app
        }
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return nil }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, defaultTimeout)
        return app
    }

    // MARK: - Attributes

    var frame: CGRect? {
        guard let position, let size else { return nil }
        return CGRect(origin: position, size: size)
    }

    var position: CGPoint? {
        guard let value = element.axValue(for: kAXPositionAttribute) else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(value, .cgPoint, &point) ? point : nil
    }

    var size: CGSize? {
        guard let value = element.axValue(for: kAXSizeAttribute) else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(value, .cgSize, &size) ? size : nil
    }

    var role: String? { element.value(for: kAXRoleAttribute) }
    var subrole: String? { element.value(for: kAXSubroleAttribute) }
    var isFullScreen: Bool { element.value(for: "AXFullScreen") ?? false }
    var isMinimized: Bool { element.value(for: kAXMinimizedAttribute) ?? false }

    private var isStandard: Bool {
        role == kAXWindowRole && subrole == kAXStandardWindowSubrole
    }

    private var isPanel: Bool {
        let panels: Set<String> = [kAXFloatingWindowSubrole, kAXSystemFloatingWindowSubrole, kAXSystemDialogSubrole]
        return subrole.map(panels.contains) ?? false
    }

    // MARK: - Writing

    @discardableResult
    func setPosition(_ point: CGPoint) -> Bool {
        var point = point
        guard let value = AXValueCreate(.cgPoint, &point) else { return false }
        return AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value) == .success
    }

    @discardableResult
    func setSize(_ size: CGSize) -> Bool {
        var size = size
        guard let value = AXValueCreate(.cgSize, &size) else { return false }
        return AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value) == .success
    }

    /// One step from `current` toward `next` in the right write order (see
    /// `FrameWritePlan`). Returns where the window actually ended up, honoring
    /// any size the app refused by keeping the `anchor` edges in place.
    @discardableResult
    func apply(_ next: CGRect, from current: CGRect, anchor: AnchorEdges) -> CGRect {
        let plan = FrameWritePlan(current: current, next: next)
        let positionBeforeResize = plan.prePosition ?? current.origin
        if let pre = plan.prePosition { setPosition(pre) }

        var actualSize = current.size
        if let target = plan.size {
            setSize(target)
            actualSize = size ?? target
        }

        let origin = actualSize == next.size
            ? next.origin
            : Geometry.anchoredOrigin(for: next, actualSize: actualSize, anchor: anchor)
        if origin != positionBeforeResize { setPosition(origin) }
        return CGRect(origin: origin, size: actualSize)
    }

    /// Puts the window exactly at `target` without animation.
    ///
    /// Runs one `apply` step, then retries the size once: when a window moves
    /// to a different display its first resize can be clipped by the old one.
    @discardableResult
    func settle(at target: CGRect, anchor: AnchorEdges) -> CGRect? {
        guard let current = frame else { return nil }
        var result = apply(target, from: current, anchor: anchor)
        if result.size != target.size {
            result = apply(target, from: result, anchor: anchor)
        }
        return result
    }

    func raise() {
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)
    }

    func minimize() {
        AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
    }

    func unminimize() {
        AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
    }

    func setMessagingTimeout(_ seconds: Float) {
        AXUIElementSetMessagingTimeout(element, seconds)
    }

    // MARK: - AXEnhancedUserInterface

    /// Some apps (Chrome, Electron, and any app while an assistive
    /// tool like VoiceOver is running) set AXEnhancedUserInterface on
    /// themselves. While it is on they animate or delay every AX frame change,
    /// which turns our animation into a stutter. Turn it off for the duration
    /// of a move and put it back afterwards. Returns whether it was on.
    func disableEnhancedUserInterface() -> Bool {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, Self.defaultTimeout)
        let wasOn: Bool = app.value(for: Self.enhancedUIAttribute) ?? false
        if wasOn {
            AXUIElementSetAttributeValue(app, Self.enhancedUIAttribute as CFString, kCFBooleanFalse)
        }
        return wasOn
    }

    func restoreEnhancedUserInterface(wasOn: Bool) {
        guard wasOn else { return }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, Self.defaultTimeout)
        AXUIElementSetAttributeValue(app, Self.enhancedUIAttribute as CFString, kCFBooleanTrue)
    }

    private static let enhancedUIAttribute = "AXEnhancedUserInterface"
}

// MARK: - AXUIElement helpers

extension AXUIElement {
    func value<T>(for attribute: String) -> T? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, attribute as CFString, &ref) == .success else { return nil }
        return ref as? T
    }

    func element(for attribute: String) -> AXUIElement? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, attribute as CFString, &ref) == .success,
              let ref, CFGetTypeID(ref) == AXUIElementGetTypeID() else { return nil }
        return (ref as! AXUIElement)
    }

    func axValue(for attribute: String) -> AXValue? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, attribute as CFString, &ref) == .success,
              let ref, CFGetTypeID(ref) == AXValueGetTypeID() else { return nil }
        return (ref as! AXValue)
    }
}
