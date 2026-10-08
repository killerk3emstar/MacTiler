import AppKit
import MacTilerCore
import QuartzCore

/// Moves windows to target frames, animated or not, and reports where they
/// really ended up once the app has settled.
///
/// Animations tick on the target screen's display link (up to 120 Hz) with
/// time-based progress. Two modes:
/// - Live: the real window gets every interpolated frame, written in the order
///   described by `FrameWritePlan`. Used when the size does not change, since
///   moving a window is cheap for any app.
/// - Glass: used when the size changes. Every resize makes the app relayout,
///   which heavy apps cannot do at display rate, so resizing the real window
///   per frame stutters. Instead a `ResizeOverlay` takes the interpolated
///   frames and the real window keeps one size while riding along, pinned to
///   the overlay's anchored corner (moving is cheap). The window is resized
///   once: at the start when shrinking, at the end when growing.
@MainActor
final class WindowMover: NSObject {
    static let shared = WindowMover()

    static let duration: TimeInterval = 0.2
    /// An AX write slower than this is a dropped frame. Two in a row means the
    /// app cannot keep up: live mode jumps to the end, glass mode stops moving
    /// the window and lets the overlay finish alone.
    private static let slowStepThreshold: CFTimeInterval = 0.05
    /// Time to let an app finish its own layout before reading the final frame.
    /// Catalyst and SwiftUI apps (Messages) often apply sizes a few frames late.
    private static let settleDelay: Duration = .milliseconds(150)

    private enum Mode {
        case live
        /// `windowSize` is the size the window keeps while riding the overlay.
        case glass(windowSize: CGSize)
    }

    /// Size limits per window, learned whenever an app refuses a size we ask
    /// for. AX does not expose minimum or maximum sizes. Minimums let width
    /// cycling skip steps that would not change anything; maximums let the
    /// overlay stop where a growing window will (it is resized only at the end).
    struct SizeLimits {
        var minimum = CGSize.zero
        var maximum = CGSize(width: CGFloat.infinity, height: CGFloat.infinity)
    }
    private var limits: [CGWindowID: SizeLimits] = [:]

    func sizeLimits(of id: CGWindowID) -> SizeLimits {
        limits[id] ?? SizeLimits()
    }

    private struct Animation {
        let window: AXWindow
        let target: CGRect
        let anchor: AnchorEdges
        let curve: FrameAnimation
        let mode: Mode
        let startTime: CFTimeInterval
        let enhancedUIWasOn: Bool
        let generation: Int
        let completion: (CGRect) -> Void
        /// Last frame written to the real window.
        var current: CGRect
        var slowSteps = 0
        var windowFrozen = false
    }

    private var animation: Animation?
    private var displayLink: CADisplayLink?
    private let overlay = ResizeOverlay()
    /// Bumped per move. A pending settle check only reports if it is still the latest.
    private var generations: [CGWindowID: Int] = [:]
    /// Windows we are moving or waiting to settle. Move events for them are ours, not the user's.
    private var busy: Set<CGWindowID> = []

    /// Shows a sample overlay animation around `frame` (AX coordinates).
    func previewOverlay(around frame: CGRect) {
        overlay.preview(around: frame)
    }

    func windowClosed(_ id: CGWindowID) {
        limits[id] = nil
    }

    func isBusy(_ id: CGWindowID) -> Bool {
        busy.contains(id)
    }

    /// Moves `window` to `target`. `completion` gets the frame the window
    /// actually has once it settled, and is not called if another move for
    /// the same window starts in the meantime.
    func move(_ window: AXWindow, to target: CGRect, anchor: AnchorEdges = [],
              animated: Bool, completion: @escaping (CGRect) -> Void = { _ in }) {
        finishCurrent()

        let generation = (generations[window.id] ?? 0) + 1
        generations[window.id] = generation
        busy.insert(window.id)

        guard let start = window.frame else {
            settle(window, at: target, anchor: anchor, generation: generation, completion: completion)
            return
        }

        let targetScreen = Screen.containing(target)
        let sameScreen = targetScreen?.nsScreen == Screen.containing(start)?.nsScreen
        let shouldAnimate = animated
            && start != target
            && sameScreen // crossing displays mid-animation makes macOS clip and jump
            && !ProcessInfo.processInfo.isLowPowerModeEnabled

        guard shouldAnimate, let screen = targetScreen?.nsScreen else {
            settle(window, at: target, anchor: anchor, generation: generation, completion: completion)
            return
        }

        let enhancedUIWasOn = window.disableEnhancedUserInterface()
        window.setMessagingTimeout(AXWindow.animationTimeout)

        var current = start
        var end = target
        let mode: Mode
        if start.size != target.size && Settings.shared.resizeAnimation == .glass {
            let grows = target.width >= start.width && target.height >= start.height
            var windowSize = start.size
            if grows {
                // Resized at the end. Stop the overlay at a size limit seen before, if any.
                if let max = limits[window.id]?.maximum, max.width < target.width || max.height < target.height {
                    let size = CGSize(width: min(target.width, max.width), height: min(target.height, max.height))
                    end = CGRect(origin: Geometry.anchoredOrigin(for: target, actualSize: size, anchor: anchor), size: size)
                }
            } else {
                // Shrink right away so the window sits inside the overlay. This also
                // tells us the size the app really accepts (minimum sizes), so the
                // overlay can end exactly where the window will.
                window.setSize(target.size)
                windowSize = window.size ?? target.size
                learnLimits(of: window.id, asked: target.size, got: windowSize)
                let origin = Geometry.anchoredOrigin(for: start, actualSize: windowSize, anchor: anchor)
                window.setPosition(origin)
                current = CGRect(origin: origin, size: windowSize)
                end = CGRect(origin: Geometry.anchoredOrigin(for: target, actualSize: windowSize, anchor: anchor),
                             size: windowSize)
            }
            mode = .glass(windowSize: windowSize)
            overlay.show(at: start)
        } else {
            mode = .live
        }

        animation = Animation(window: window, target: target, anchor: anchor,
                              curve: FrameAnimation(from: start, to: end, duration: Self.duration),
                              mode: mode, startTime: CACurrentMediaTime(), enhancedUIWasOn: enhancedUIWasOn,
                              generation: generation, completion: completion, current: current)

        let link = screen.displayLink(target: self, selector: #selector(tick(_:)))
        let maxRate = Float(screen.maximumFramesPerSecond)
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: maxRate, preferred: maxRate)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    /// Jumps the running animation (if any) to its end.
    func finishCurrent() {
        guard let animation else { return }
        stopDisplayLink()
        self.animation = nil
        animation.window.setMessagingTimeout(AXWindow.defaultTimeout)
        settle(animation.window, at: animation.target, anchor: animation.anchor,
               generation: animation.generation, completion: animation.completion)
        animation.window.restoreEnhancedUserInterface(wasOn: animation.enhancedUIWasOn)
        if case .glass = animation.mode {
            // If the app refused the size (a maximum we did not know about),
            // snap the overlay onto the real frame before it fades, and remember.
            if let actual = animation.window.frame, actual != animation.curve.to {
                overlay.setFrame(actual)
                learnLimits(of: animation.window.id, asked: animation.target.size, got: actual.size)
            }
            overlay.dismiss()
        }
    }

    @objc private func tick(_ link: CADisplayLink) {
        guard var animation else {
            stopDisplayLink()
            return
        }

        let elapsed = CACurrentMediaTime() - animation.startTime
        if animation.curve.isFinished(at: elapsed) {
            finishCurrent()
            return
        }

        let frame = animation.curve.frame(at: elapsed)
        let stepStart = CACurrentMediaTime()

        switch animation.mode {
        case .live:
            guard frame != animation.current else { return }
            animation.current = animation.window.apply(frame, from: animation.current, anchor: animation.anchor)

        case .glass(let windowSize):
            overlay.setFrame(frame)
            let origin = Geometry.anchoredOrigin(for: frame, actualSize: windowSize, anchor: animation.anchor)
            guard !animation.windowFrozen, origin != animation.current.origin else { break }
            animation.window.setPosition(origin)
            animation.current.origin = origin
        }

        let wasSlow = CACurrentMediaTime() - stepStart > Self.slowStepThreshold
        animation.slowSteps = wasSlow ? animation.slowSteps + 1 : 0
        self.animation = animation

        if animation.slowSteps >= 2 {
            switch animation.mode {
            case .live:
                Log.info("App too slow to animate (pid \(animation.window.pid)), jumping to target")
                finishCurrent()
            case .glass:
                Log.info("App too slow to follow the overlay (pid \(animation.window.pid))")
                self.animation?.windowFrozen = true
            }
        }
    }

    private func learnLimits(of id: CGWindowID, asked: CGSize, got: CGSize) {
        var limit = limits[id] ?? SizeLimits()
        // Refused sizes tighten a limit
        if got.width > asked.width + 1 { limit.minimum.width = got.width }
        if got.height > asked.height + 1 { limit.minimum.height = got.height }
        if got.width < asked.width - 1 { limit.maximum.width = got.width }
        if got.height < asked.height - 1 { limit.maximum.height = got.height }
        // Sizes outside a learned limit prove it stale (the app changed it, or
        // macOS clipped the window to a smaller screen), so drop it
        if got.width < limit.minimum.width - 1 { limit.minimum.width = 0 }
        if got.height < limit.minimum.height - 1 { limit.minimum.height = 0 }
        if got.width > limit.maximum.width + 1 { limit.maximum.width = .infinity }
        if got.height > limit.maximum.height + 1 { limit.maximum.height = .infinity }
        limits[id] = limit
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    // MARK: - Settling

    /// Exact placement with AXEnhancedUserInterface off, then a delayed read-back.
    private func settle(_ window: AXWindow, at target: CGRect, anchor: AnchorEdges,
                        generation: Int, completion: @escaping (CGRect) -> Void) {
        let enhancedUIWasOn = window.disableEnhancedUserInterface()
        window.settle(at: target, anchor: anchor)
        window.restoreEnhancedUserInterface(wasOn: enhancedUIWasOn)

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.settleDelay)
            guard let self, self.generations[window.id] == generation else { return }
            self.busy.remove(window.id)
            self.generations[window.id] = nil
            let settled = window.frame ?? target
            self.learnLimits(of: window.id, asked: target.size, got: settled.size)
            completion(settled)
        }
    }
}
