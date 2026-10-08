import CoreGraphics

public enum SnapSide: String, Sendable, Hashable {
    case left, right
}

public enum WidthFraction: String, CaseIterable, Comparable, Sendable, Hashable {
    case quarter, third, half, twoThirds, threeQuarters

    public var value: CGFloat {
        switch self {
        case .quarter: return 0.25
        case .third: return 1.0 / 3.0
        case .half: return 0.5
        case .twoThirds: return 2.0 / 3.0
        case .threeQuarters: return 0.75
        }
    }

    public var displayName: String {
        switch self {
        case .quarter: return "1/4"
        case .third: return "1/3"
        case .half: return "1/2"
        case .twoThirds: return "2/3"
        case .threeQuarters: return "3/4"
        }
    }

    public static func < (lhs: WidthFraction, rhs: WidthFraction) -> Bool {
        lhs.value < rhs.value
    }
}

public enum VerticalSlice: String, Sendable, Hashable {
    case full, top, bottom
}

public enum SnapPosition: Hashable, Sendable, CustomStringConvertible {
    case floating
    case maximized
    case topHalf
    case bottomHalf
    case tiled(side: SnapSide, width: WidthFraction, vertical: VerticalSlice)

    public static func leftHalf(_ vertical: VerticalSlice = .full) -> SnapPosition {
        .tiled(side: .left, width: .half, vertical: vertical)
    }

    public static func rightHalf(_ vertical: VerticalSlice = .full) -> SnapPosition {
        .tiled(side: .right, width: .half, vertical: vertical)
    }

    /// Screen edges the window should stay glued to when the app refuses the
    /// requested size (minimum width, size steps). Used for anchor correction.
    public var anchor: AnchorEdges {
        var edges: AnchorEdges = []
        switch self {
        case .tiled(let side, _, let vertical):
            if side == .right { edges.insert(.right) }
            if vertical == .bottom { edges.insert(.bottom) }
        case .bottomHalf:
            edges.insert(.bottom)
        case .floating, .maximized, .topHalf:
            break
        }
        return edges
    }

    public var description: String {
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

public struct AnchorEdges: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let right = AnchorEdges(rawValue: 1 << 0)
    public static let bottom = AnchorEdges(rawValue: 1 << 1)
}

public enum SnapDirection: Sendable, Hashable {
    case up, down, left, right
}

public enum SnapAction: Equatable, Sendable {
    case snapTo(SnapPosition)
    case restore
    case minimize
    case noOp
}
