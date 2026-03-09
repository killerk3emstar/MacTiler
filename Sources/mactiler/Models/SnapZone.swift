import AppKit
import CoreGraphics

enum SnapZone {
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

        case .topHalf:
            return CGRect(x: x, y: topY, width: width, height: (height - gap) / 2)

        case .bottomHalf:
            return CGRect(x: x, y: topY + (height + gap) / 2, width: width, height: (height - gap) / 2)

        case .tiled(let side, let widthFrac, let vertical):
            let tileWidth = (width - gap) * widthFrac.value
            let tileX: CGFloat
            if side == .left {
                tileX = x
            } else {
                tileX = x + (width - gap) * (1 - widthFrac.value) + gap
            }

            let tileHeight: CGFloat
            let tileY: CGFloat
            switch vertical {
            case .full:
                tileHeight = height
                tileY = topY
            case .top:
                tileHeight = (height - gap) / 2
                tileY = topY
            case .bottom:
                tileHeight = (height - gap) / 2
                tileY = topY + (height + gap) / 2
            }

            return CGRect(x: tileX, y: tileY, width: tileWidth, height: tileHeight)
        }
    }
}
