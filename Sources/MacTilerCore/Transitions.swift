import CoreGraphics

extension SnapPosition {
    /// The heart of MacTiler: what a direction key does from this state.
    /// See the transition table in the README.
    ///
    /// `minimumFraction` is the window's minimum width as a fraction of the
    /// tile area on its screen, if known. Widths below it all look the same
    /// (the window stays at its minimum), so width cycling skips steps that
    /// would not visibly change anything.
    public func transition(direction: SnapDirection, enabledFractions: [WidthFraction],
                           minimumFraction: CGFloat = 0) -> SnapAction {
        switch (self, direction) {
        // floating
        case (.floating, .up):    return .snapTo(.maximized)
        case (.floating, .down):  return .minimize
        case (.floating, .left):  return .snapTo(.leftHalf())
        case (.floating, .right): return .snapTo(.rightHalf())

        // maximized
        case (.maximized, .up):    return .snapTo(.topHalf)
        case (.maximized, .down):  return .restore
        case (.maximized, .left):  return .snapTo(.leftHalf())
        case (.maximized, .right): return .snapTo(.rightHalf())

        // topHalf
        case (.topHalf, .up):    return .snapTo(.maximized)
        case (.topHalf, .down):  return .restore
        case (.topHalf, .left):  return .snapTo(.leftHalf(.top))
        case (.topHalf, .right): return .snapTo(.rightHalf(.top))

        // bottomHalf
        case (.bottomHalf, .up):    return .snapTo(.topHalf)
        case (.bottomHalf, .down):  return .restore
        case (.bottomHalf, .left):  return .snapTo(.leftHalf(.bottom))
        case (.bottomHalf, .right): return .snapTo(.rightHalf(.bottom))

        // tiled
        case (.tiled(let side, let width, let vertical), let dir):
            return tiledTransition(side: side, width: width, vertical: vertical, direction: dir,
                                   enabledFractions: enabledFractions, minimumFraction: minimumFraction)
        }
    }

    public var maximizeAction: SnapAction {
        self == .maximized ? .noOp : .snapTo(.maximized)
    }

    public var restoreAction: SnapAction {
        self == .floating ? .noOp : .restore
    }

    private func tiledTransition(side: SnapSide, width: WidthFraction, vertical: VerticalSlice,
                                 direction: SnapDirection, enabledFractions: [WidthFraction],
                                 minimumFraction: CGFloat) -> SnapAction {
        let isSame = (side == .left && direction == .left) || (side == .right && direction == .right)
        let isOpposite = (side == .left && direction == .right) || (side == .right && direction == .left)
        let otherSide: SnapSide = side == .left ? .right : .left

        // Quarters (top/bottom): no fraction cycling
        if vertical != .full {
            if isSame {
                return .snapTo(.tiled(side: side, width: .half, vertical: .full))
            }
            if isOpposite {
                return .snapTo(.tiled(side: otherSide, width: .half, vertical: vertical))
            }
        }

        // Full height: fraction cycling / restore
        if isSame {
            guard let nextWidth = Self.nextFraction(after: width, in: enabledFractions,
                                                    minimumFraction: minimumFraction) else {
                return .noOp
            }
            return .snapTo(.tiled(side: side, width: nextWidth, vertical: .full))
        }

        if isOpposite { return .restore }

        // up/down changes the vertical slice (quarters are always half width)
        switch (direction, vertical) {
        case (.up, .full):     return .snapTo(.tiled(side: side, width: .half, vertical: .top))
        case (.up, .top):      return .snapTo(.maximized)
        case (.up, .bottom):   return .snapTo(.tiled(side: side, width: .half, vertical: .full))
        case (.down, .full):   return .snapTo(.tiled(side: side, width: .half, vertical: .bottom))
        case (.down, .top):    return .snapTo(.tiled(side: side, width: .half, vertical: .full))
        case (.down, .bottom): return .restore
        default:               return .noOp
        }
    }

    static func nextFraction(after current: WidthFraction, in enabled: [WidthFraction],
                             minimumFraction: CGFloat = 0) -> WidthFraction? {
        guard enabled.count > 1 else { return nil }

        // Order to try: the enabled widths after the current one, wrapping around.
        // If the current width is no longer enabled, start at the next larger one.
        let startIndex: Int
        if let idx = enabled.firstIndex(of: current) {
            startIndex = idx + 1
        } else {
            startIndex = enabled.firstIndex(where: { $0 > current }) ?? 0
        }
        let candidates = (0..<enabled.count).map { enabled[(startIndex + $0) % enabled.count] }

        // Skip widths that end up the same size as the current one because
        // the window cannot get narrower than its minimum.
        func effective(_ fraction: WidthFraction) -> CGFloat { max(fraction.value, minimumFraction) }
        let currentWidth = effective(current)
        return candidates.first { $0 != current && abs(effective($0) - currentWidth) > 0.005 }
    }
}
