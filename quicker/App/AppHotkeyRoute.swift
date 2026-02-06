import Foundation

enum AppHotkeyRoute: Equatable {
    case clipboard
    case textBlock

    init(action: HotkeyAction) {
        switch action {
        case .clipboardPanel:
            self = .clipboard
        case .textBlockPanel:
            self = .textBlock
        }
    }
}
