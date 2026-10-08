import CoreGraphics
import Testing
@testable import MacTilerCore

struct FrameAnimationTests {
    private let from = CGRect(x: 100, y: 100, width: 800, height: 600)
    private let to = CGRect(x: 0, y: 37, width: 756, height: 945)

    @Test func endpoints() {
        let animation = FrameAnimation(from: from, to: to, duration: 0.2)
        #expect(animation.frame(at: 0) == from)
        #expect(animation.frame(at: 0.2) == to)
        #expect(animation.frame(at: 5) == to)
        #expect(animation.isFinished(at: 0.2))
        #expect(!animation.isFinished(at: 0.1))
    }

    @Test func framesAreWholePointsAndMonotonic() {
        let animation = FrameAnimation(from: from, to: to, duration: 0.2)
        var lastHeight = from.height
        for step in 0...24 {
            let frame = animation.frame(at: Double(step) / 120)
            #expect(frame.minX == frame.minX.rounded())
            #expect(frame.width == frame.width.rounded())
            #expect(frame.height >= lastHeight)
            lastHeight = frame.height
        }
    }

    @Test func zeroDurationJumps() {
        #expect(FrameAnimation(from: from, to: to, duration: 0).frame(at: 0) == to)
    }

    @Test func easing() {
        #expect(FrameAnimation.easeOutCubic(0) == 0)
        #expect(FrameAnimation.easeOutCubic(1) == 1)
        #expect(FrameAnimation.easeOutCubic(0.5) > 0.5) // ease-out front-loads
        #expect(FrameAnimation.easeOutCubic(2) == 1)
    }

    @Test func growingMovesFirst() {
        // Growing on both axes: move to the new origin before resizing,
        // otherwise macOS clips the new size at the old origin.
        let plan = FrameWritePlan(current: CGRect(x: 500, y: 300, width: 400, height: 300),
                                  next: CGRect(x: 0, y: 37, width: 1512, height: 945))
        #expect(plan.prePosition == CGPoint(x: 0, y: 37))
        #expect(plan.size == CGSize(width: 1512, height: 945))
    }

    @Test func shrinkingResizesFirst() {
        let plan = FrameWritePlan(current: CGRect(x: 0, y: 37, width: 1512, height: 945),
                                  next: CGRect(x: 756, y: 37, width: 756, height: 945))
        #expect(plan.prePosition == nil)
        #expect(plan.size == CGSize(width: 756, height: 945))
    }

    @Test func mixedAxes() {
        // Wider but shorter: move x first (growing), keep y until after the resize (shrinking)
        let plan = FrameWritePlan(current: CGRect(x: 500, y: 37, width: 400, height: 945),
                                  next: CGRect(x: 0, y: 500, width: 1000, height: 400))
        #expect(plan.prePosition == CGPoint(x: 0, y: 37))
    }

    @Test func pureMove() {
        let plan = FrameWritePlan(current: from, next: from.offsetBy(dx: 10, dy: 0))
        #expect(plan.prePosition == nil)
        #expect(plan.size == nil)
    }
}
