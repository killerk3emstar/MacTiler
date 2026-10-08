import AppKit
import MacTilerCore
import QuartzCore

/// Moves windows to target frames, animated or not, and reports where they
/// really ended up once the app has settled.
///
/// Animation runs on the target screen's display link, so it ticks at the
/// display's refresh rate (up to 120 Hz on ProMotion) instead of a fixed timer.
/// Each tick writes one interpolated frame in the order described by
/// `FrameWritePlan`. If the app is too slow to keep up, the animation is
/// dropped and the window jumps to the target, which looks better than a
/// stutter.
@MainActor
final class WindowMover: NSObject {
    static let shared = WindowMover()

    static let duration: TimeInterval = 0.2
    /// An AX step slower than this is a dropped frame. Two in a row means the
    /// app cannot keep up, so the animation is abandoned.
    private static let slowStepThreshold: CFTimeInterval = 0.05
    /// Time to let an app finish its own layout before reading the final frame.
    /// Catalyst and SwiftUI apps (Messages) often apply sizes a few frames late.
    private static let settleDelay: Duration = .milliseconds(150)

    private struct Animation {
        let window: AXWindow
        let target: CGRect
        let anchor: AnchorEdges
        let curve: FrameAnimation
        let startTime: CFTimeInterval
        let enhancedUIWasOn: Bool
        let generation: Int
        let completion: (CGRect) -> Void
        var current: CGRect
        var slowSteps = 0
    }

    private var animation: Animation?
    private var displayLink: CADisplayLink?
    /// Bumped per move. A pending settle check only reports if it is still the latest.
    private var generations: [CGWindowID: Int] = [:]
    /// Windows we are moving or waiting to settle. Move events for them are ours, not the user's.
    private var busy: Set<CGWindowID> = []

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

        animation = Animation(window: window, target: target, anchor: anchor,
                              curve: FrameAnimation(from: start, to: target, duration: Self.duration),
                              startTime: CACurrentMediaTime(), enhancedUIWasOn: enhancedUIWasOn,
                              generation: generation, completion: completion, current: start)

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

        let next = animation.curve.frame(at: elapsed)
        guard next != animation.current else { return }

        let stepStart = CACurrentMediaTime()
        animation.current = animation.window.apply(next, from: animation.current, anchor: animation.anchor)
        let wasSlow = CACurrentMediaTime() - stepStart > Self.slowStepThreshold
        animation.slowSteps = wasSlow ? animation.slowSteps + 1 : 0
        self.animation = animation

        if animation.slowSteps >= 2 {
            Log.info("App too slow to animate (pid \(animation.window.pid)), jumping to target")
            finishCurrent()
        }
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    /// Final exact placement, then a delayed read-back of the real frame.
    private func settle(_ window: AXWindow, at target: CGRect, anchor: AnchorEdges,
                        generation: Int, completion: @escaping (CGRect) -> Void) {
        window.settle(at: target, anchor: anchor)

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.settleDelay)
            guard let self, self.generations[window.id] == generation else { return }
            self.busy.remove(window.id)
            self.generations[window.id] = nil
            completion(window.frame ?? target)
        }
    }
}
