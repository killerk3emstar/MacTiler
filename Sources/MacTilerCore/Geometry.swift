import CoreGraphics

/// All rects in this file are in Accessibility coordinates: origin at the
/// top-left of the primary screen, Y growing downward. AppKit (NSScreen) uses
/// bottom-left origin with Y growing upward; convert with `Geometry.toAX`.
public enum Geometry {
    // MARK: - Coordinate conversion

    /// Converts a Cocoa rect (NSScreen.frame / visibleFrame) to AX coordinates.
    /// `primaryHeight` is the height of `NSScreen.screens[0].frame`.
    public static func toAX(_ cocoaRect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: cocoaRect.minX,
               y: primaryHeight - cocoaRect.maxY,
               width: cocoaRect.width,
               height: cocoaRect.height)
    }

    // MARK: - Snap layout

    /// Target frame for a snap position inside a screen's visible area.
    /// Returns nil for `.floating`, which has no fixed frame.
    public static func frame(for position: SnapPosition, in visible: CGRect, gap: CGFloat) -> CGRect? {
        let area = visible.insetBy(dx: gap, dy: gap)
        let halfHeight = (area.height - gap) / 2
        let lowerY = area.minY + halfHeight + gap

        let rect: CGRect
        switch position {
        case .floating:
            return nil

        case .maximized:
            rect = area

        case .topHalf:
            rect = CGRect(x: area.minX, y: area.minY, width: area.width, height: halfHeight)

        case .bottomHalf:
            rect = CGRect(x: area.minX, y: lowerY, width: area.width, height: halfHeight)

        case .tiled(let side, let fraction, let vertical):
            let usable = area.width - gap
            let width = usable * fraction.value
            let x = side == .left ? area.minX : area.maxX - width

            switch vertical {
            case .full:
                rect = CGRect(x: x, y: area.minY, width: width, height: area.height)
            case .top:
                rect = CGRect(x: x, y: area.minY, width: width, height: halfHeight)
            case .bottom:
                rect = CGRect(x: x, y: lowerY, width: width, height: halfHeight)
            }
        }
        return roundedEdges(rect)
    }

    /// Width that width fractions are taken of: the visible area minus the
    /// outer gaps and the gap between two side-by-side tiles.
    public static func tileableWidth(in visible: CGRect, gap: CGFloat) -> CGFloat {
        visible.width - 3 * gap
    }

    /// Rounds each edge to a whole point independently, so neighbouring tiles
    /// share an exact edge and apps get integer sizes (avoids 1px drift noise).
    public static func roundedEdges(_ rect: CGRect) -> CGRect {
        let minX = rect.minX.rounded(), minY = rect.minY.rounded()
        let maxX = rect.maxX.rounded(), maxY = rect.maxY.rounded()
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// A frame of `size` centered in `bounds`, shrunk first if it does not fit.
    public static func centered(_ size: CGSize, in bounds: CGRect) -> CGRect {
        let fitted = CGSize(width: min(size.width, bounds.width),
                            height: min(size.height, bounds.height))
        return roundedEdges(CGRect(x: bounds.midX - fitted.width / 2,
                                   y: bounds.midY - fitted.height / 2,
                                   width: fitted.width,
                                   height: fitted.height))
    }

    // MARK: - Size constraints

    /// Where to put a window whose app refused the requested size (e.g. a
    /// minimum width): keep the anchored edges of `target` in place.
    public static func anchoredOrigin(for target: CGRect, actualSize: CGSize, anchor: AnchorEdges) -> CGPoint {
        var origin = target.origin
        if anchor.contains(.right) {
            origin.x = target.maxX - actualSize.width
        }
        if anchor.contains(.bottom) {
            origin.y = target.maxY - actualSize.height
        }
        return origin
    }

    /// True if `current` differs from `reference` by more than `tolerance` on any edge.
    public static func hasDrifted(_ current: CGRect, from reference: CGRect, tolerance: CGFloat = 8) -> Bool {
        abs(current.minX - reference.minX) > tolerance
            || abs(current.minY - reference.minY) > tolerance
            || abs(current.width - reference.width) > tolerance
            || abs(current.height - reference.height) > tolerance
    }

    // MARK: - Screens

    /// Index of the screen a window belongs to: the one with the largest
    /// overlap, or the nearest one if the window is entirely off-screen.
    public static func bestScreenIndex(for window: CGRect, screens: [CGRect]) -> Int? {
        guard !screens.isEmpty else { return nil }

        let areas = screens.map { screen -> CGFloat in
            let overlap = screen.intersection(window)
            return overlap.isNull ? 0 : overlap.width * overlap.height
        }
        if let best = areas.indices.max(by: { areas[$0] < areas[$1] }), areas[best] > 0 {
            return best
        }

        let center = CGPoint(x: window.midX, y: window.midY)
        return screens.indices.min { distanceSquared(center, screens[$0]) < distanceSquared(center, screens[$1]) }
    }

    /// Index of the nearest screen in `direction` that overlaps `current` on the other axis.
    public static func adjacentScreenIndex(to current: CGRect, in screens: [CGRect], direction: SnapDirection) -> Int? {
        func overlapsVertically(_ r: CGRect) -> Bool { r.minY < current.maxY && current.minY < r.maxY }
        func overlapsHorizontally(_ r: CGRect) -> Bool { r.minX < current.maxX && current.minX < r.maxX }

        let candidates = screens.indices.filter { screens[$0] != current }
        switch direction {
        case .right:
            return candidates
                .filter { screens[$0].minX >= current.maxX && overlapsVertically(screens[$0]) }
                .min { screens[$0].minX < screens[$1].minX }
        case .left:
            return candidates
                .filter { screens[$0].maxX <= current.minX && overlapsVertically(screens[$0]) }
                .max { screens[$0].maxX < screens[$1].maxX }
        case .up:
            return candidates
                .filter { screens[$0].maxY <= current.minY && overlapsHorizontally(screens[$0]) }
                .max { screens[$0].maxY < screens[$1].maxY }
        case .down:
            return candidates
                .filter { screens[$0].minY >= current.maxY && overlapsHorizontally(screens[$0]) }
                .min { screens[$0].minY < screens[$1].minY }
        }
    }

    private static func distanceSquared(_ point: CGPoint, _ rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return dx * dx + dy * dy
    }
}
