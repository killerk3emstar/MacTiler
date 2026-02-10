import AppKit

enum SnapAction {
    case snapTo(SnapPosition)
    case restore
    case minimize
    case noOp
}

final class WindowStateMachine {
    static let shared = WindowStateMachine()

    private init() {}

    func determineAction(currentState: WindowState, direction: SnapDirection) -> SnapAction {
        let currentPosition = currentState.snapPosition

        // Get the next position from transition table
        if let nextPosition = currentPosition.transition(direction: direction) {
            return .snapTo(nextPosition)
        }

        // No direct transition - check what special action to take
        let special = currentPosition.specialAction(direction: direction)
        switch special {
        case .minimize:
            return .minimize
        case .restore:
            return .restore
        }
    }

    func actionForMaximize(currentState: WindowState) -> SnapAction {
        if currentState.snapPosition == .maximized {
            return .noOp
        }
        return .snapTo(.maximized)
    }

    func actionForRestore(currentState: WindowState) -> SnapAction {
        if currentState.snapPosition == .floating {
            return .noOp
        }
        return .restore
    }

}
