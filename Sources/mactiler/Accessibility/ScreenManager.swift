import AppKit

final class ScreenManager {
    static let shared = ScreenManager()

    private init() {}

    var screens: [NSScreen] {
        NSScreen.screens
    }

    var mainScreen: NSScreen? {
        NSScreen.main
    }

    func screen(containing point: CGPoint) -> NSScreen? {
        let flippedPoint = CGPoint(x: point.x, y: primaryScreenHeight - point.y)
        return screens.first { $0.frame.contains(flippedPoint) }
    }

    func screen(for window: AccessibilityElement) -> NSScreen? {
        guard let frame = window.frame else { return mainScreen }
        let center = CGPoint(x: frame.midX, y: frame.midY)
        return screen(containing: center) ?? mainScreen
    }

    var primaryScreenHeight: CGFloat {
        screens.first?.frame.height ?? 0
    }

    func convertToScreenCoordinates(_ rect: CGRect, on screen: NSScreen) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: primaryScreenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    func convertFromScreenCoordinates(_ rect: CGRect, on screen: NSScreen) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: primaryScreenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    /// Find the adjacent screen in the given direction based on screen geometry.
    /// Uses Cocoa coordinates (Y=0 at bottom).
    func adjacentScreen(to currentScreen: NSScreen, direction: SnapDirection) -> NSScreen? {
        let current = currentScreen.frame
        let candidates = screens.filter { $0 != currentScreen }

        switch direction {
        case .right:
            // Screens whose left edge >= current right edge, with vertical overlap
            return candidates
                .filter { $0.frame.minX >= current.maxX && hasVerticalOverlap(current, $0.frame) }
                .min { $0.frame.minX < $1.frame.minX }

        case .left:
            // Screens whose right edge <= current left edge, with vertical overlap
            return candidates
                .filter { $0.frame.maxX <= current.minX && hasVerticalOverlap(current, $0.frame) }
                .min { $0.frame.maxX > $1.frame.maxX }

        case .up:
            // Screens whose bottom edge >= current top edge, with horizontal overlap
            // In Cocoa coords, "up" means higher Y values
            return candidates
                .filter { $0.frame.minY >= current.maxY && hasHorizontalOverlap(current, $0.frame) }
                .min { $0.frame.minY < $1.frame.minY }

        case .down:
            // Screens whose top edge <= current bottom edge, with horizontal overlap
            return candidates
                .filter { $0.frame.maxY <= current.minY && hasHorizontalOverlap(current, $0.frame) }
                .min { $0.frame.maxY > $1.frame.maxY }
        }
    }

    private func hasVerticalOverlap(_ a: CGRect, _ b: CGRect) -> Bool {
        a.minY < b.maxY && b.minY < a.maxY
    }

    private func hasHorizontalOverlap(_ a: CGRect, _ b: CGRect) -> Bool {
        a.minX < b.maxX && b.minX < a.maxX
    }
}
