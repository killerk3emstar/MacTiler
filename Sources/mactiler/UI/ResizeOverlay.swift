import AppKit
import MacTilerCore

/// Look of the resize overlay.
enum OverlayStyle: String, CaseIterable {
    case liquidGlass, clearGlass, frosted, accent, outline

    var title: String {
        switch self {
        case .liquidGlass: return "Liquid Glass"
        case .clearGlass: return "Clear Glass"
        case .frosted: return "Frosted"
        case .accent: return "Accent"
        case .outline: return "Outline"
        }
    }
}

/// A shape drawn above all windows, used to animate a resize smoothly while
/// the real window changes size only once.
///
/// Resizing another app's window costs a full relayout in that app per frame,
/// which heavy apps cannot do at display refresh rate. This overlay is our own
/// window, so moving it every frame is cheap no matter how slow the app
/// underneath is. It draws nothing from the target window, so no screen
/// recording permission is needed.
@MainActor
final class ResizeOverlay {
    private static let cornerRadius: CGFloat = 12

    /// Look settings. `opacity` is the alpha of the whole overlay; `tint` is
    /// how much solid window-background color covers the blur, which hides
    /// the window underneath better (it still has its old size mid-animation).
    struct Appearance: Equatable {
        var style: OverlayStyle
        var opacity: Double
        var tint: Double

        @MainActor static var current: Appearance {
            let settings = Settings.shared
            return Appearance(style: settings.overlayStyle, opacity: settings.overlayOpacity, tint: settings.overlayTint)
        }
    }

    private let panel: NSPanel
    private var appearance: Appearance?

    init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        panel.isReleasedWhenClosed = false
    }

    /// Shows the overlay at `frame` (AX coordinates).
    func show(at frame: CGRect, appearance: Appearance = .current) {
        if self.appearance != appearance {
            panel.contentView = Self.makeContent(appearance.style, tint: appearance.tint)
            self.appearance = appearance
        }
        // Zero-duration group overrides a fade-out that may still be running
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            panel.animator().alphaValue = appearance.opacity
        }
        setFrame(frame)
        panel.orderFrontRegardless()
    }

    func setFrame(_ frame: CGRect) {
        panel.setFrame(Self.cocoa(frame), display: true)
    }

    /// Fades out and hides.
    func dismiss(duration: TimeInterval = 0.12) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            panel.animator().alphaValue = 0
        } completionHandler: { [panel] in
            MainActor.assumeIsolated {
                if panel.alphaValue == 0 { panel.orderOut(nil) }
            }
        }
    }

    func hideNow() {
        panel.orderOut(nil)
    }

    /// Plays a sample shrink and grow around `frame` (AX coordinates), for the Preferences preview.
    func preview(around frame: CGRect) {
        let small = frame.insetBy(dx: frame.width * 0.25, dy: frame.height * 0.2)
        show(at: frame)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(Self.cocoa(small), display: true)
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.35
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    self.panel.animator().setFrame(Self.cocoa(frame), display: true)
                } completionHandler: { [weak self] in
                    MainActor.assumeIsolated { self?.dismiss() }
                }
            }
        }
    }

    private static func makeContent(_ style: OverlayStyle, tint: Double) -> NSView {
        let tintColor = NSColor.windowBackgroundColor.withAlphaComponent(tint)

        switch style {
        case .liquidGlass, .clearGlass:
            if #available(macOS 26, *) {
                let glass = NSGlassEffectView()
                glass.style = style == .clearGlass ? .clear : .regular
                glass.cornerRadius = cornerRadius
                if tint > 0 { glass.tintColor = tintColor }
                return glass
            }
            return makeContent(.frosted, tint: tint)

        case .frosted:
            let blur = NSVisualEffectView()
            blur.material = .hudWindow
            blur.blendingMode = .behindWindow
            blur.state = .active
            rounded(blur, border: NSColor.white.withAlphaComponent(0.25), width: 1)

            let cover = NSView()
            cover.wantsLayer = true
            cover.layer?.backgroundColor = tintColor.cgColor
            cover.autoresizingMask = [.width, .height]
            blur.addSubview(cover)
            return blur

        case .accent:
            let view = NSView()
            rounded(view, border: .controlAccentColor, width: 2)
            let fill = 0.2 + 0.8 * tint
            view.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(fill).cgColor
            return view

        case .outline:
            let view = NSView()
            rounded(view, border: .controlAccentColor, width: 3)
            return view
        }
    }

    private static func rounded(_ view: NSView, border: NSColor, width: CGFloat) {
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.masksToBounds = true
        view.layer?.borderWidth = width
        view.layer?.borderColor = border.cgColor
    }

    private static func cocoa(_ ax: CGRect) -> CGRect {
        // The AX <-> Cocoa flip is its own inverse
        Geometry.toAX(ax, primaryHeight: NSScreen.screens.first?.frame.height ?? 0)
    }
}
