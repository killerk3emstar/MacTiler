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
        let gap = Settings.shared.windowGap

        let visibleFrame = screen.visibleFrame
        let screenHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height

        // Apply outer gap to the visible frame
        let width = visibleFrame.width - (gap * 2)
        let height = visibleFrame.height - (gap * 2)
        let x = visibleFrame.origin.x + gap

        // Convert Cocoa Y (bottom=0) to Screen Y (top=0)
        let topY = screenHeight - visibleFrame.origin.y - visibleFrame.height + gap

        switch position {
        case .floating:
            return .zero

        case .maximized:
            return CGRect(x: x, y: topY, width: width, height: height)

        case .leftHalf:
            return CGRect(x: x, y: topY, width: (width - gap) / 2, height: height)

        case .rightHalf:
            return CGRect(x: x + (width + gap) / 2, y: topY, width: (width - gap) / 2, height: height)

        case .topHalf:
            return CGRect(x: x, y: topY, width: width, height: (height - gap) / 2)

        case .bottomHalf:
            return CGRect(x: x, y: topY + (height + gap) / 2, width: width, height: (height - gap) / 2)

        case .topLeftQuarter:
            return CGRect(x: x, y: topY, width: (width - gap) / 2, height: (height - gap) / 2)

        case .topRightQuarter:
            return CGRect(x: x + (width + gap) / 2, y: topY, width: (width - gap) / 2, height: (height - gap) / 2)

        case .bottomLeftQuarter:
            return CGRect(x: x, y: topY + (height + gap) / 2, width: (width - gap) / 2, height: (height - gap) / 2)

        case .bottomRightQuarter:
            return CGRect(x: x + (width + gap) / 2, y: topY + (height + gap) / 2, width: (width - gap) / 2, height: (height - gap) / 2)
        }
    }
}
