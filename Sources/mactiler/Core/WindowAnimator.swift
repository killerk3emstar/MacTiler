import AppKit

final class WindowAnimator {
    static let shared = WindowAnimator()

    private var animationTimer: Timer?
    private var pendingWindow: AccessibilityElement?
    private var pendingOriginalTarget: CGRect?
    private var pendingCompletion: ((_ achievedFrame: CGRect?) -> Void)?

    private init() {}

    /// Animate a window to a target frame using "Resize at Start, Slide Into Place":
    /// set target size once with nudge trick, then animate position only.
    func animate(window: AccessibilityElement, from start: CGRect, to target: CGRect,
                 anchorPosition: SnapPosition? = nil, duration: TimeInterval = 0.15,
                 completion: ((_ achievedFrame: CGRect?) -> Void)? = nil) {
        finalizePendingAnimation()

        // Phase 1: First resize attempt at start position (may be clamped by screen edge)
        window.size = target.size
        let firstAchieved = window.size ?? target.size
        let isClamped = (target.size.width - firstAchieved.width) > 5
            || (target.size.height - firstAchieved.height) > 5

        // Phase 2: Nudge + second resize
        // The nudge position depends on the situation:
        // - Clamped (e.g. maximize from offset): nudge toward target.x so full width fits
        // - Right/bottom aligned (e.g. rightHalf→rightStrip): preserve trailing edge
        // - Normal: stay at start (1px Y nudge only)
        var nudgePos: CGPoint
        if isClamped {
            nudgePos = CGPoint(x: min(start.origin.x, target.origin.x),
                               y: min(start.origin.y, target.origin.y))
        } else if let anchor = anchorPosition, (anchor.isRightAligned || anchor.isBottomAligned) {
            var x = start.origin.x, y = start.origin.y
            if anchor.isRightAligned { x = start.origin.x + start.width - firstAchieved.width }
            if anchor.isBottomAligned { y = start.origin.y + start.height - firstAchieved.height }
            nudgePos = CGPoint(x: x, y: y)
        } else {
            nudgePos = start.origin
        }

        window.position = CGPoint(x: nudgePos.x, y: nudgePos.y + 1)
        window.size = target.size

        guard let achievedSize = window.size else {
            window.setFrame(target)
            completion?(window.frame)
            return
        }

        // Phase 3: Compute animation start (trailing-edge-preserved for right/bottom)
        var animStart = start.origin
        if let anchor = anchorPosition {
            if anchor.isRightAligned {
                animStart.x = start.origin.x + start.width - achievedSize.width
            }
            if anchor.isBottomAligned {
                animStart.y = start.origin.y + start.height - achievedSize.height
            }
        }
        window.position = animStart

        // Compute anchor-corrected final origin (for min-width windows)
        var finalOrigin = target.origin
        if let anchor = anchorPosition {
            if anchor.isRightAligned && achievedSize.width > target.width {
                finalOrigin.x = target.origin.x + target.width - achievedSize.width
            }
            if anchor.isBottomAligned && achievedSize.height > target.height {
                finalOrigin.y = target.origin.y + target.height - achievedSize.height
            }
        }

        // Phase 4: Position-only animation
        pendingWindow = window
        pendingOriginalTarget = CGRect(origin: target.origin, size: target.size)
        pendingCompletion = completion

        let totalSteps = 8
        var step = 0

        animationTimer = Timer.scheduledTimer(withTimeInterval: duration / Double(totalSteps), repeats: true) {
            [weak self] timer in
            step += 1
            let t = Double(step) / Double(totalSteps)
            let e = 1 - pow(1 - t, 3) // ease-out cubic

            let x = animStart.x + (finalOrigin.x - animStart.x) * e
            let y = animStart.y + (finalOrigin.y - animStart.y) * e
            window.position = CGPoint(x: x, y: y)

            if step >= totalSteps {
                timer.invalidate()
                self?.animationTimer = nil
                window.position = finalOrigin
                let finalFrame = window.frame
                let comp = self?.pendingCompletion
                self?.clearPending()
                comp?(finalFrame)
            }
        }
    }

    /// Immediately finish the in-progress animation: jump to target and run completion.
    func finalizePendingAnimation() {
        guard animationTimer != nil else { return }
        animationTimer?.invalidate()
        animationTimer = nil

        if let window = pendingWindow, let target = pendingOriginalTarget {
            window.setFrame(target)
        }
        let completion = pendingCompletion
        let finalFrame = pendingWindow?.frame
        clearPending()
        completion?(finalFrame)
    }

    func cancel() {
        animationTimer?.invalidate()
        animationTimer = nil
        clearPending()
    }

    private func clearPending() {
        pendingWindow = nil
        pendingOriginalTarget = nil
        pendingCompletion = nil
    }
}
