import Foundation

enum SnapDirection {
    case up
    case down
    case left
    case right
}

extension SnapPosition {
    func transition(direction: SnapDirection, enabledFractions: [WidthFraction]) -> SnapAction {
        switch (self, direction) {
        // floating
        case (.floating, .up):    return .snapTo(.maximized)
        case (.floating, .down):  return .minimize
        case (.floating, .left):  return .snapTo(.tiled(side: .left, width: .half, vertical: .full))
        case (.floating, .right): return .snapTo(.tiled(side: .right, width: .half, vertical: .full))

        // maximized
        case (.maximized, .up):    return .snapTo(.topHalf)
        case (.maximized, .down):  return .restore
        case (.maximized, .left):  return .snapTo(.tiled(side: .left, width: .half, vertical: .full))
        case (.maximized, .right): return .snapTo(.tiled(side: .right, width: .half, vertical: .full))

        // topHalf
        case (.topHalf, .up):    return .snapTo(.maximized)
        case (.topHalf, .down):  return .restore
        case (.topHalf, .left):  return .snapTo(.tiled(side: .left, width: .half, vertical: .top))
        case (.topHalf, .right): return .snapTo(.tiled(side: .right, width: .half, vertical: .top))

        // bottomHalf
        case (.bottomHalf, .up):    return .snapTo(.topHalf)
        case (.bottomHalf, .down):  return .restore
        case (.bottomHalf, .left):  return .snapTo(.tiled(side: .left, width: .half, vertical: .bottom))
        case (.bottomHalf, .right): return .snapTo(.tiled(side: .right, width: .half, vertical: .bottom))

        // tiled
        case (.tiled(let side, let width, let vertical), let dir):
            return tiledTransition(side: side, width: width, vertical: vertical,
                                   direction: dir, enabledFractions: enabledFractions)
        }
    }

    private func tiledTransition(side: SnapSide, width: WidthFraction, vertical: VerticalSlice,
                                 direction: SnapDirection, enabledFractions: [WidthFraction]) -> SnapAction {
        let isSame = (side == .left && direction == .left) || (side == .right && direction == .right)
        let isOpposite = (side == .left && direction == .right) || (side == .right && direction == .left)
        let otherSide: SnapSide = side == .left ? .right : .left

        // Quarters (top/bottom) — no fraction cycling
        if vertical != .full {
            if isSame {
                return .snapTo(.tiled(side: side, width: .half, vertical: .full))
            }
            if isOpposite {
                return .snapTo(.tiled(side: otherSide, width: .half, vertical: vertical))
            }
        }

        // Full-height — fraction cycling / restore
        if isSame {
            guard let nextWidth = nextFraction(after: width, in: enabledFractions) else {
                return .noOp
            }
            return .snapTo(.tiled(side: side, width: nextWidth, vertical: .full))
        }

        if isOpposite { return .restore }

        // up/down — change vertical slice (quarters always half-width)
        switch (direction, vertical) {
        case (.up, .full):   return .snapTo(.tiled(side: side, width: .half, vertical: .top))
        case (.up, .top):    return .snapTo(.maximized)
        case (.up, .bottom): return .snapTo(.tiled(side: side, width: .half, vertical: .full))
        case (.down, .full):   return .snapTo(.tiled(side: side, width: .half, vertical: .bottom))
        case (.down, .top):    return .snapTo(.tiled(side: side, width: .half, vertical: .full))
        case (.down, .bottom): return .restore
        default: return .noOp
        }
    }

    private func nextFraction(after current: WidthFraction, in enabled: [WidthFraction]) -> WidthFraction? {
        guard enabled.count > 1 else { return nil }
        if let idx = enabled.firstIndex(of: current) {
            return enabled[(idx + 1) % enabled.count]
        }
        // Current fraction not in enabled list — find nearest larger, or wrap to first
        return enabled.first(where: { $0 > current }) ?? enabled.first
    }
}
