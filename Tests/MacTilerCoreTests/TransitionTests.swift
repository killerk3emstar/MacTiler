import CoreGraphics
import Testing
@testable import MacTilerCore

/// Mirrors the transition table in the README. If you change behavior,
/// change the README table and this test together.
struct TransitionTests {
    private let L = SnapPosition.leftHalf()
    private let R = SnapPosition.rightHalf()
    private let TL = SnapPosition.leftHalf(.top)
    private let TR = SnapPosition.rightHalf(.top)
    private let BL = SnapPosition.leftHalf(.bottom)
    private let BR = SnapPosition.rightHalf(.bottom)

    private func action(_ from: SnapPosition, _ direction: SnapDirection,
                        fractions: [WidthFraction] = [.half]) -> SnapAction {
        from.transition(direction: direction, enabledFractions: fractions)
    }

    @Test func readmeTable() {
        let table: [(SnapPosition, [SnapDirection: SnapAction])] = [
            (.floating,   [.up: .snapTo(.maximized), .down: .minimize, .left: .snapTo(L), .right: .snapTo(R)]),
            (.maximized,  [.up: .snapTo(.topHalf), .down: .restore, .left: .snapTo(L), .right: .snapTo(R)]),
            (.topHalf,    [.up: .snapTo(.maximized), .down: .restore, .left: .snapTo(TL), .right: .snapTo(TR)]),
            (.bottomHalf, [.up: .snapTo(.topHalf), .down: .restore, .left: .snapTo(BL), .right: .snapTo(BR)]),
            (L,  [.up: .snapTo(TL), .down: .snapTo(BL), .left: .noOp, .right: .restore]),
            (R,  [.up: .snapTo(TR), .down: .snapTo(BR), .left: .restore, .right: .noOp]),
            (TL, [.up: .snapTo(.maximized), .down: .snapTo(L), .left: .snapTo(L), .right: .snapTo(TR)]),
            (TR, [.up: .snapTo(.maximized), .down: .snapTo(R), .left: .snapTo(TL), .right: .snapTo(R)]),
            (BL, [.up: .snapTo(L), .down: .restore, .left: .snapTo(L), .right: .snapTo(BR)]),
            (BR, [.up: .snapTo(R), .down: .restore, .left: .snapTo(BL), .right: .snapTo(R)]),
        ]

        for (from, row) in table {
            for (direction, expected) in row {
                #expect(action(from, direction) == expected, "\(from) + \(direction)")
            }
        }
    }

    @Test func sameEdgeCyclesEnabledWidths() {
        let fractions: [WidthFraction] = [.quarter, .half, .threeQuarters]
        func left(_ w: WidthFraction) -> SnapPosition { .tiled(side: .left, width: w, vertical: .full) }

        #expect(action(left(.half), .left, fractions: fractions) == .snapTo(left(.threeQuarters)))
        #expect(action(left(.threeQuarters), .left, fractions: fractions) == .snapTo(left(.quarter)))
        #expect(action(left(.quarter), .left, fractions: fractions) == .snapTo(left(.half)))
    }

    @Test func narrowTilesBehaveLikeHalves() {
        let sidebar = SnapPosition.tiled(side: .right, width: .quarter, vertical: .full)
        #expect(action(sidebar, .left) == .restore)
        #expect(action(sidebar, .up) == .snapTo(TR))
        #expect(action(sidebar, .down) == .snapTo(BR))
    }

    @Test func disabledCurrentWidthJumpsToNextLarger() {
        #expect(SnapPosition.nextFraction(after: .third, in: [.half, .threeQuarters]) == .half)
        #expect(SnapPosition.nextFraction(after: .threeQuarters, in: [.quarter, .half]) == .quarter)
        #expect(SnapPosition.nextFraction(after: .half, in: [.half]) == nil)
    }

    @Test func maximizeAndRestoreShortcuts() {
        #expect(SnapPosition.maximized.maximizeAction == .noOp)
        #expect(L.maximizeAction == .snapTo(.maximized))
        #expect(SnapPosition.floating.restoreAction == .noOp)
        #expect(TR.restoreAction == .restore)
    }

    @Test func anchors() {
        #expect(L.anchor == [])
        #expect(R.anchor == [.right])
        #expect(BL.anchor == [.bottom])
        #expect(BR.anchor == [.right, .bottom])
        #expect(SnapPosition.bottomHalf.anchor == [.bottom])
    }
}

/// Width cycling with a window that cannot get as narrow as some enabled widths.
struct MinimumWidthCyclingTests {
    private func right(_ w: WidthFraction) -> SnapPosition { .tiled(side: .right, width: w, vertical: .full) }
    private let enabled: [WidthFraction] = [.quarter, .half, .threeQuarters]

    private func next(_ from: WidthFraction, minimum: CGFloat) -> SnapAction {
        right(from).transition(direction: .right, enabledFractions: enabled, minimumFraction: minimum)
    }

    @Test func unknownMinimumCyclesEverything() {
        #expect(next(.half, minimum: 0) == .snapTo(right(.threeQuarters)))
        #expect(next(.threeQuarters, minimum: 0) == .snapTo(right(.quarter)))
        #expect(next(.quarter, minimum: 0) == .snapTo(right(.half)))
    }

    @Test func minimumAboveHalfSkipsDeadStep() {
        // Discord on a laptop: minimum is about 0.55, so 1/4 and 1/2 look the same
        #expect(next(.threeQuarters, minimum: 0.55) == .snapTo(right(.quarter)))
        #expect(next(.quarter, minimum: 0.55) == .snapTo(right(.threeQuarters)))
        #expect(next(.half, minimum: 0.55) == .snapTo(right(.threeQuarters)))
    }

    @Test func minimumBetweenQuarterAndHalf() {
        #expect(next(.quarter, minimum: 0.3) == .snapTo(right(.half)))
        #expect(next(.threeQuarters, minimum: 0.3) == .snapTo(right(.quarter)))
    }

    @Test func everythingBelowMinimumDoesNothing() {
        #expect(next(.half, minimum: 0.8) == .noOp)
    }
}
