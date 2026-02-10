import Foundation

enum SnapDirection {
    case up
    case down
    case left
    case right
}

/// Special actions that aren't just position changes
enum SpecialAction {
    case minimize
    case restore
}

extension SnapPosition {
    /// Returns the next position, or nil if a special action should be taken
    func transition(direction: SnapDirection) -> SnapPosition? {
        switch (self, direction) {
        // From floating
        case (.floating, .up): return .maximized
        case (.floating, .down): return nil  // Special: minimize
        case (.floating, .left): return .leftHalf
        case (.floating, .right): return .rightHalf

        // From maximized - up goes to topHalf (shrink upward)
        case (.maximized, .up): return .topHalf
        case (.maximized, .down): return nil  // Special: restore
        case (.maximized, .left): return .leftHalf
        case (.maximized, .right): return .rightHalf

        // From leftHalf
        case (.leftHalf, .up): return .topLeftQuarter
        case (.leftHalf, .down): return .bottomLeftQuarter
        case (.leftHalf, .left): return .leftStrip
        case (.leftHalf, .right): return .rightHalf

        // From rightHalf
        case (.rightHalf, .up): return .topRightQuarter
        case (.rightHalf, .down): return .bottomRightQuarter
        case (.rightHalf, .left): return .leftHalf
        case (.rightHalf, .right): return .rightStrip

        // From topLeftQuarter - up/down expand to half first
        case (.topLeftQuarter, .up): return .maximized
        case (.topLeftQuarter, .down): return .leftHalf  // Expand down to fill left side
        case (.topLeftQuarter, .left): return .leftStrip
        case (.topLeftQuarter, .right): return .topRightQuarter

        // From topRightQuarter - up/down expand to half first
        case (.topRightQuarter, .up): return .maximized
        case (.topRightQuarter, .down): return .rightHalf  // Expand down to fill right side
        case (.topRightQuarter, .left): return .topLeftQuarter
        case (.topRightQuarter, .right): return .rightStrip

        // From bottomLeftQuarter - up expands, down restores
        case (.bottomLeftQuarter, .up): return .leftHalf  // Expand up to fill left side
        case (.bottomLeftQuarter, .down): return nil  // Special: restore (nowhere to go)
        case (.bottomLeftQuarter, .left): return .leftStrip
        case (.bottomLeftQuarter, .right): return .bottomRightQuarter

        // From bottomRightQuarter - up expands, down restores
        case (.bottomRightQuarter, .up): return .rightHalf  // Expand up to fill right side
        case (.bottomRightQuarter, .down): return nil  // Special: restore (nowhere to go)
        case (.bottomRightQuarter, .left): return .bottomLeftQuarter
        case (.bottomRightQuarter, .right): return .rightStrip

        // From topHalf
        case (.topHalf, .up): return .maximized
        case (.topHalf, .down): return nil  // Special: restore
        case (.topHalf, .left): return .topLeftQuarter
        case (.topHalf, .right): return .topRightQuarter

        // From bottomHalf
        case (.bottomHalf, .up): return .topHalf
        case (.bottomHalf, .down): return nil  // Special: restore
        case (.bottomHalf, .left): return .bottomLeftQuarter
        case (.bottomHalf, .right): return .bottomRightQuarter

        // From leftStrip
        case (.leftStrip, .up): return .topLeftQuarter
        case (.leftStrip, .down): return .bottomLeftQuarter
        case (.leftStrip, .left): return nil  // Special: restore
        case (.leftStrip, .right): return .leftHalf

        // From rightStrip
        case (.rightStrip, .up): return .topRightQuarter
        case (.rightStrip, .down): return .bottomRightQuarter
        case (.rightStrip, .left): return .rightHalf
        case (.rightStrip, .right): return nil  // Special: restore
        }
    }

    /// Determines what special action to take when transition returns nil
    func specialAction(direction: SnapDirection) -> SpecialAction {
        switch (self, direction) {
        case (.floating, .down):
            return .minimize
        default:
            return .restore
        }
    }
}
