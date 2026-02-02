import AppKit
import CoreGraphics

struct WindowState {
    let windowId: CGWindowID
    var snapPosition: SnapPosition
    var originalFrame: CGRect?
    var snappedFrame: CGRect?
    var currentScreen: NSScreen?

    init(windowId: CGWindowID, snapPosition: SnapPosition = .floating, originalFrame: CGRect? = nil) {
        self.windowId = windowId
        self.snapPosition = snapPosition
        self.originalFrame = originalFrame
        self.snappedFrame = nil
        self.currentScreen = nil
    }

    var isSnapped: Bool {
        snapPosition != .floating
    }
}
