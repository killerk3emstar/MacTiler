import AppKit
import MacTilerCore

/// An NSScreen with its frames already converted to AX coordinates.
@MainActor
struct Screen {
    let nsScreen: NSScreen
    let frame: CGRect
    let visibleFrame: CGRect

    static var all: [Screen] {
        let screens = NSScreen.screens
        // screens[0] is the primary (menu bar) screen; AX coordinates start at its top-left.
        let primaryHeight = screens.first?.frame.height ?? 0
        return screens.map {
            Screen(nsScreen: $0,
                   frame: Geometry.toAX($0.frame, primaryHeight: primaryHeight),
                   visibleFrame: Geometry.toAX($0.visibleFrame, primaryHeight: primaryHeight))
        }
    }

    /// The screen showing most of `windowFrame`.
    static func containing(_ windowFrame: CGRect) -> Screen? {
        let screens = all
        return Geometry.bestScreenIndex(for: windowFrame, screens: screens.map(\.frame)).map { screens[$0] }
    }

    func adjacent(_ direction: SnapDirection) -> Screen? {
        let screens = Screen.all
        return Geometry.adjacentScreenIndex(to: frame, in: screens.map(\.frame), direction: direction).map { screens[$0] }
    }
}
