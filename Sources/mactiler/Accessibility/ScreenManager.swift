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
}
