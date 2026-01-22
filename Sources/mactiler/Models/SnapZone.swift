import AppKit
import CoreGraphics

struct SnapZone {
    let position: SnapPosition
    let frame: CGRect

    /// Calculate window frame for a snap position
    /// Important: NSScreen uses Cocoa coordinates (Y=0 at bottom)
    /// but AXUIElement uses screen coordinates (Y=0 at top)
    /// We need to convert between them.
    static func calculateFrame(for position: SnapPosition, on screen: NSScreen) -> CGRect {
        let visibleFrame = screen.visibleFrame
        let screenHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height

        let width = visibleFrame.width
        let height = visibleFrame.height
        let x = visibleFrame.origin.x

        // Convert Cocoa Y (bottom=0) to Screen Y (top=0)
        // topY = where the visible area starts from the top (e.g., below menu bar)
        let topY = screenHeight - visibleFrame.origin.y - visibleFrame.height

        switch position {
        case .floating:
            return .zero

        case .maximized:
            return CGRect(x: x, y: topY, width: width, height: height)

        case .leftHalf:
            return CGRect(x: x, y: topY, width: width / 2, height: height)

        case .rightHalf:
            return CGRect(x: x + width / 2, y: topY, width: width / 2, height: height)

        case .topHalf:
            return CGRect(x: x, y: topY, width: width, height: height / 2)

        case .bottomHalf:
            return CGRect(x: x, y: topY + height / 2, width: width, height: height / 2)

        case .topLeftQuarter:
            return CGRect(x: x, y: topY, width: width / 2, height: height / 2)

        case .topRightQuarter:
            return CGRect(x: x + width / 2, y: topY, width: width / 2, height: height / 2)

        case .bottomLeftQuarter:
            return CGRect(x: x, y: topY + height / 2, width: width / 2, height: height / 2)

        case .bottomRightQuarter:
            return CGRect(x: x + width / 2, y: topY + height / 2, width: width / 2, height: height / 2)
        }
    }
}
