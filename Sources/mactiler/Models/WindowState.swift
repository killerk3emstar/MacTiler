import CoreGraphics

struct WindowState {
    let windowId: CGWindowID
    var snapPosition: SnapPosition
    var originalFrame: CGRect?
    var snappedFrame: CGRect?

    init(windowId: CGWindowID, snapPosition: SnapPosition = .floating, originalFrame: CGRect? = nil) {
        self.windowId = windowId
        self.snapPosition = snapPosition
        self.originalFrame = originalFrame
        self.snappedFrame = nil
    }

    var isSnapped: Bool {
        snapPosition != .floating
    }
}
