import CoreGraphics
import Testing
@testable import MacTilerCore

struct GeometryTests {
    // 1512x982 MacBook screen with a 37pt menu bar, in AX coordinates
    private let visible = CGRect(x: 0, y: 37, width: 1512, height: 945)

    @Test func cocoaToAX() {
        // Primary 1000 tall; a screen above it (Cocoa y = 1000) has negative AX y
        let cocoa = CGRect(x: 0, y: 1000, width: 800, height: 600)
        #expect(Geometry.toAX(cocoa, primaryHeight: 1000) == CGRect(x: 0, y: -600, width: 800, height: 600))
        // Visible frame below a 25pt menu bar
        let menu = CGRect(x: 0, y: 0, width: 1440, height: 875)
        #expect(Geometry.toAX(menu, primaryHeight: 900) == CGRect(x: 0, y: 25, width: 1440, height: 875))
    }

    @Test func halvesWithoutGap() {
        #expect(Geometry.frame(for: .leftHalf(), in: visible, gap: 0) == CGRect(x: 0, y: 37, width: 756, height: 945))
        #expect(Geometry.frame(for: .rightHalf(), in: visible, gap: 0) == CGRect(x: 756, y: 37, width: 756, height: 945))
        #expect(Geometry.frame(for: .maximized, in: visible, gap: 0) == visible)
        #expect(Geometry.frame(for: .floating, in: visible, gap: 0) == nil)
    }

    @Test func gapIsEvenEverywhere() throws {
        let gap: CGFloat = 10
        let left = try #require(Geometry.frame(for: .leftHalf(), in: visible, gap: gap))
        let right = try #require(Geometry.frame(for: .rightHalf(), in: visible, gap: gap))
        let topLeft = try #require(Geometry.frame(for: .leftHalf(.top), in: visible, gap: gap))
        let bottomLeft = try #require(Geometry.frame(for: .leftHalf(.bottom), in: visible, gap: gap))

        #expect(left.minX == visible.minX + gap)
        #expect(right.maxX == visible.maxX - gap)
        #expect(right.minX - left.maxX == gap)
        #expect(bottomLeft.minY - topLeft.maxY == gap)
        #expect(bottomLeft.maxY == visible.maxY - gap)
    }

    @Test func tilesShareExactEdges() throws {
        // Thirds of an odd width produce fractions; rounding must not open a 1px seam
        let odd = CGRect(x: 0, y: 25, width: 1001, height: 700)
        let third = try #require(Geometry.frame(for: .tiled(side: .left, width: .third, vertical: .full), in: odd, gap: 0))
        let twoThirds = try #require(Geometry.frame(for: .tiled(side: .right, width: .twoThirds, vertical: .full), in: odd, gap: 0))
        #expect(third.maxX == twoThirds.minX)
        #expect(twoThirds.maxX == odd.maxX)
        #expect(third.width == third.width.rounded())
    }

    @Test func centeredShrinksToFit() {
        let frame = Geometry.centered(CGSize(width: 2000, height: 400), in: visible)
        #expect(frame.width == visible.width)
        #expect(frame.minX == visible.minX)
        #expect(abs(frame.midY - visible.midY) <= 0.5)
    }

    @Test func anchorKeepsRightAndBottomEdges() {
        let target = CGRect(x: 1134, y: 37, width: 378, height: 945)
        // App refused to go narrower than 500
        let origin = Geometry.anchoredOrigin(for: target, actualSize: CGSize(width: 500, height: 945), anchor: [.right])
        #expect(origin.x + 500 == target.maxX)
        #expect(origin.y == target.minY)

        let bottom = Geometry.anchoredOrigin(for: target, actualSize: CGSize(width: 378, height: 1000), anchor: [.bottom])
        #expect(bottom.y + 1000 == target.maxY)

        let none = Geometry.anchoredOrigin(for: target, actualSize: CGSize(width: 500, height: 1000), anchor: [])
        #expect(none == target.origin)
    }

    @Test func drift() {
        let frame = CGRect(x: 0, y: 37, width: 756, height: 945)
        #expect(!Geometry.hasDrifted(frame.offsetBy(dx: 3, dy: -3), from: frame))
        #expect(Geometry.hasDrifted(frame.offsetBy(dx: 40, dy: 0), from: frame))
        #expect(Geometry.hasDrifted(CGRect(x: 0, y: 37, width: 700, height: 945), from: frame))
    }

    @Test func bestScreenByOverlap() {
        let screens = [CGRect(x: 0, y: 0, width: 1000, height: 800), CGRect(x: 1000, y: 0, width: 1000, height: 800)]
        // Center is on screen 0, but most of the window is on screen 1
        let window = CGRect(x: 600, y: 100, width: 1000, height: 300)
        #expect(Geometry.bestScreenIndex(for: window, screens: screens) == 1)
        // Fully off-screen picks the nearest
        #expect(Geometry.bestScreenIndex(for: CGRect(x: 2500, y: 100, width: 100, height: 100), screens: screens) == 1)
        #expect(Geometry.bestScreenIndex(for: window, screens: []) == nil)
    }

    @Test func adjacentScreens() {
        let main = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let right = CGRect(x: 1000, y: 100, width: 1000, height: 800)
        let above = CGRect(x: 200, y: -600, width: 800, height: 600)
        let screens = [main, right, above]

        #expect(Geometry.adjacentScreenIndex(to: main, in: screens, direction: .right) == 1)
        #expect(Geometry.adjacentScreenIndex(to: main, in: screens, direction: .up) == 2)
        #expect(Geometry.adjacentScreenIndex(to: main, in: screens, direction: .left) == nil)
        #expect(Geometry.adjacentScreenIndex(to: right, in: screens, direction: .left) == 0)
        #expect(Geometry.adjacentScreenIndex(to: above, in: screens, direction: .down) == 0)
    }
}
