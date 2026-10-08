import CoreGraphics
import Foundation

/// Time-based interpolation between two window frames. Progress comes from
/// elapsed time, not a frame counter, so a slow frame is skipped instead of
/// stretching the whole animation.
public struct FrameAnimation: Sendable {
    public let from: CGRect
    public let to: CGRect
    public let duration: TimeInterval

    public init(from: CGRect, to: CGRect, duration: TimeInterval) {
        self.from = from
        self.to = to
        self.duration = duration
    }

    public func isFinished(at elapsed: TimeInterval) -> Bool {
        elapsed >= duration
    }

    /// Eased frame at `elapsed` seconds, rounded to whole points.
    public func frame(at elapsed: TimeInterval) -> CGRect {
        guard duration > 0, elapsed < duration else { return to }
        let t = CGFloat(Self.easeOutCubic(max(0, elapsed) / duration))
        let rect = CGRect(x: from.minX + (to.minX - from.minX) * t,
                          y: from.minY + (to.minY - from.minY) * t,
                          width: from.width + (to.width - from.width) * t,
                          height: from.height + (to.height - from.height) * t)
        return Geometry.roundedEdges(rect)
    }

    public static func easeOutCubic(_ t: Double) -> Double {
        let clamped = min(max(t, 0), 1)
        return 1 - pow(1 - clamped, 3)
    }
}

/// Order of AX writes for one step from `current` to `next`.
///
/// macOS clips a window that would grow past the screen edge at its current
/// origin, and a window that shrinks before moving shows a gap. So, per axis:
/// when growing, move first and resize after; when shrinking, resize first and
/// move after. `prePosition` is the origin to set before the resize (nil if
/// unchanged); the post-resize origin is computed from the size the app
/// actually accepted, see `Geometry.anchoredOrigin`.
public struct FrameWritePlan: Equatable, Sendable {
    public let prePosition: CGPoint?
    public let size: CGSize?

    public init(current: CGRect, next: CGRect) {
        let pre = CGPoint(x: next.width > current.width ? next.minX : current.minX,
                          y: next.height > current.height ? next.minY : current.minY)
        prePosition = pre == current.origin ? nil : pre
        size = next.size == current.size ? nil : next.size
    }
}
