import Foundation

enum SnapPosition: String, Codable, CaseIterable {
    case floating
    case maximized
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case topLeftQuarter
    case topRightQuarter
    case bottomLeftQuarter
    case bottomRightQuarter
    case leftStrip
    case rightStrip

    /// Whether this position is anchored to the right edge of the screen.
    /// Used to re-adjust windows that can't shrink to the target width.
    var isRightAligned: Bool {
        switch self {
        case .rightHalf, .rightStrip, .topRightQuarter, .bottomRightQuarter:
            return true
        default:
            return false
        }
    }

    /// Whether this position is anchored to the bottom edge of the screen.
    /// Used to re-adjust windows that can't shrink to the target height.
    var isBottomAligned: Bool {
        switch self {
        case .bottomHalf, .bottomLeftQuarter, .bottomRightQuarter:
            return true
        default:
            return false
        }
    }
}
