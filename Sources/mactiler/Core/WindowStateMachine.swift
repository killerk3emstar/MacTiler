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
        currentState.snapPosition.transition(
            direction: direction,
            enabledFractions: Settings.shared.enabledWidthFractions
        )
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
