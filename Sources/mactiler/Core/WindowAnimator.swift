import AppKit

final class WindowAnimator {
    static let shared = WindowAnimator()

    private var animationTimer: Timer?
    private var pendingWindow: AccessibilityElement?
    private var pendingTarget: CGRect?
    private var pendingCompletion: ((_ achievedFrame: CGRect?) -> Void)?

    private init() {}

    /// Animate a window to a target frame using "Size Once, Slide Into Place":
    /// set target size immediately (1 AX size call), then animate position only (8 position calls).
    ///
    /// - Parameters:
    ///   - window: The window to animate.
    ///   - start: The window's current frame (caller already has it).
    ///   - target: The desired target frame.
    ///   - anchorPosition: Snap position for anchor correction (right/bottom aligned).
    ///   - duration: Animation duration (default 0.15s).
    ///   - completion: Called with the final achieved frame (anchor-corrected) or nil on failure.
    func animate(window: AccessibilityElement, from start: CGRect, to target: CGRect,
                 anchorPosition: SnapPosition? = nil, duration: TimeInterval = 0.15,
                 completion: ((_ achievedFrame: CGRect?) -> Void)? = nil) {
        finalizePendingAnimation()

        // Frame 0: Set target size once — the only resize call
        window.size = target.size

        // Read achieved size (may differ due to min-width/min-height constraints)
        guard let achievedSize = window.size else {
            window.setFrame(target)
            completion?(window.frame)
            return
        }

        // Compute anchor-corrected final origin
        var finalOrigin = target.origin

        if let anchor = anchorPosition {
            if anchor.isRightAligned && achievedSize.width > target.width {
                let targetRightEdge = target.origin.x + target.width
                finalOrigin.x = targetRightEdge - achievedSize.width
            }

            if anchor.isBottomAligned && achievedSize.height > target.height {
                let targetBottomEdge = target.origin.y + target.height
                finalOrigin.y = targetBottomEdge - achievedSize.height
            }
        }

        let correctedTarget = CGRect(origin: finalOrigin, size: achievedSize)

        // Hold window at start position
        window.position = start.origin

        pendingWindow = window
        pendingTarget = correctedTarget
        pendingCompletion = completion

        let totalSteps = 8
        var step = 0

        animationTimer = Timer.scheduledTimer(withTimeInterval: duration / Double(totalSteps), repeats: true) {
            [weak self] timer in
            step += 1
            let t = Double(step) / Double(totalSteps)
            let e = 1 - pow(1 - t, 3) // ease-out cubic

            let x = start.origin.x + (finalOrigin.x - start.origin.x) * e
            let y = start.origin.y + (finalOrigin.y - start.origin.y) * e

            window.position = CGPoint(x: x, y: y)

            if step >= totalSteps {
                timer.invalidate()
                self?.animationTimer = nil
                // Exact final position
                window.position = finalOrigin
                let comp = self?.pendingCompletion
                let target = self?.pendingTarget
                self?.clearPending()
                comp?(target)
            }
        }
    }

    /// Immediately finish the in-progress animation: jump to target and run completion.
    /// Call this before starting a new action so the state is up-to-date.
    func finalizePendingAnimation() {
        guard animationTimer != nil else { return }
        animationTimer?.invalidate()
        animationTimer = nil

        if let window = pendingWindow, let target = pendingTarget {
            window.setFrame(target)
        }
        let completion = pendingCompletion
        let target = pendingTarget
        clearPending()
        completion?(target)
    }

    func cancel() {
        animationTimer?.invalidate()
        animationTimer = nil
        clearPending()
    }

    private func clearPending() {
        pendingWindow = nil
        pendingTarget = nil
        pendingCompletion = nil
    }
}
