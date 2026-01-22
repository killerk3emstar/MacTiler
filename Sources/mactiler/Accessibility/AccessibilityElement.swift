import AppKit
import ApplicationServices

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ windowId: inout CGWindowID) -> AXError

final class AccessibilityElement {
    let element: AXUIElement

    init(_ element: AXUIElement) {
        self.element = element
    }

    static var focusedWindow: AccessibilityElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        var focusedWindow: AnyObject?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)

        guard result == .success, let windowElement = focusedWindow else { return nil }
        return AccessibilityElement(windowElement as! AXUIElement)
    }

    var windowId: CGWindowID? {
        var windowId: CGWindowID = 0
        let result = _AXUIElementGetWindow(element, &windowId)
        return result == .success ? windowId : nil
    }

    var frame: CGRect? {
        get {
            guard let position = position, let size = size else { return nil }
            return CGRect(origin: position, size: size)
        }
        set {
            guard let newFrame = newValue else { return }
            position = newFrame.origin
            size = newFrame.size
        }
    }

    var position: CGPoint? {
        get {
            var positionRef: AnyObject?
            let result = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef)
            guard result == .success, let positionValue = positionRef else { return nil }

            var point = CGPoint.zero
            AXValueGetValue(positionValue as! AXValue, .cgPoint, &point)
            return point
        }
        set {
            guard var newPosition = newValue else { return }
            guard let axValue = AXValueCreate(.cgPoint, &newPosition) else { return }
            AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, axValue)
        }
    }

    var size: CGSize? {
        get {
            var sizeRef: AnyObject?
            let result = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef)
            guard result == .success, let sizeValue = sizeRef else { return nil }

            var size = CGSize.zero
            AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
            return size
        }
        set {
            guard var newSize = newValue else { return }
            guard let axValue = AXValueCreate(.cgSize, &newSize) else { return }
            AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, axValue)
        }
    }

    var isFullScreen: Bool {
        var fullScreenRef: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, "AXFullScreen" as CFString, &fullScreenRef)
        guard result == .success, let isFullScreen = fullScreenRef as? Bool else { return false }
        return isFullScreen
    }

    var isMinimized: Bool {
        var minimizedRef: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXMinimizedAttribute as CFString, &minimizedRef)
        guard result == .success, let isMinimized = minimizedRef as? Bool else { return false }
        return isMinimized
    }

    var title: String? {
        var titleRef: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
        guard result == .success, let title = titleRef as? String else { return nil }
        return title
    }

    func setFrame(_ frame: CGRect, animationDuration: TimeInterval = 0) {
        size = frame.size
        position = frame.origin
        size = frame.size
    }

    func bringToFront() {
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)
    }

    func minimize() {
        AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, true as CFBoolean)
    }
}
