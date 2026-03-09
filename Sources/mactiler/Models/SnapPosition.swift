import CoreGraphics

enum SnapSide: String, Codable, Equatable, Hashable {
    case left, right
}

enum WidthFraction: String, CaseIterable, Codable, Comparable, Hashable {
    case quarter, third, half, twoThirds, threeQuarters

    var value: CGFloat {
        switch self {
        case .quarter: return 0.25
        case .third: return 1.0 / 3.0
        case .half: return 0.5
        case .twoThirds: return 2.0 / 3.0
        case .threeQuarters: return 0.75
        }
    }

    var displayName: String {
        switch self {
        case .quarter: return "1/4"
        case .third: return "1/3"
        case .half: return "1/2"
        case .twoThirds: return "2/3"
        case .threeQuarters: return "3/4"
        }
    }

    static func < (lhs: WidthFraction, rhs: WidthFraction) -> Bool {
        lhs.value < rhs.value
    }
}

enum VerticalSlice: String, Codable, Equatable, Hashable {
    case full, top, bottom
}

enum SnapPosition: Equatable, Hashable, CustomStringConvertible {
    case floating
    case maximized
    case topHalf
    case bottomHalf
    case tiled(side: SnapSide, width: WidthFraction, vertical: VerticalSlice)

    var isRightAligned: Bool {
        if case .tiled(let side, _, _) = self { return side == .right }
        return false
    }

    var isBottomAligned: Bool {
        switch self {
        case .tiled(_, _, .bottom), .bottomHalf: return true
        default: return false
        }
    }

    var description: String {
        switch self {
        case .floating: return "floating"
        case .maximized: return "maximized"
        case .topHalf: return "topHalf"
        case .bottomHalf: return "bottomHalf"
        case .tiled(let side, let width, let vertical):
            if vertical == .full {
                return "\(side)\(width.displayName)"
            }
            return "\(side)\(width.displayName).\(vertical)"
        }
    }
}
