import AppKit

final class WindowAnimator {
    static let shared = WindowAnimator()

    private var animationTimer: Timer?
    private var pendingWindow: AccessibilityElement?
    private var pendingOriginalTarget: CGRect?
    private var pendingCompletion: ((_ achievedFrame: CGRect?) -> Void)?

    private init() {}

    /// Animate a window to a target frame using "Resize at Start, Slide Into Place":
    /// set target size once with 1px nudge trick, then animate position only.
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

        // Double-resize trick with 1px nudge: triggers app re-layout without
        // jumping to target position (which would cause visible flash)
        window.size = target.size
        window.position = CGPoint(x: start.origin.x, y: start.origin.y + 1)
        window.size = target.size
        window.position = start.origin

        guard var achievedSize = window.size else {
            window.setFrame(target)
            completion?(window.frame)
            return
        }

        // If resize was severely clamped (>50px off), the window can't achieve
        // target size at start position. Fall back to setFrame at target position.
        // This causes a brief flash but is necessary for maximize/strip→corner.
        let widthShort = target.size.width - achievedSize.width
        let heightShort = target.size.height - achievedSize.height
        if widthShort > 50 || heightShort > 50 {
            window.setFrame(target)
            if let retrySize = window.size {
                achievedSize = retrySize
            }
            window.position = start.origin
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

        pendingWindow = window
        pendingOriginalTarget = correctedTarget
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
                window.position = finalOrigin
                let finalFrame = window.frame
                let comp = self?.pendingCompletion
                self?.clearPending()
                comp?(finalFrame)
            }
        }
    }

    /// Immediately finish the in-progress animation: jump to target and run completion.
    /// Call this before starting a new action so the state is up-to-date.
    func finalizePendingAnimation() {
        guard animationTimer != nil else { return }
        animationTimer?.invalidate()
        animationTimer = nil

        // Jump to final state: set frame to original target, let setFrame handle sizing
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
