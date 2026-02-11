import Foundation

struct PanelKeyEvent: Equatable {
    let keyCode: UInt16
    let charactersIgnoringModifiers: String?
    let isCommandDown: Bool

    init(keyCode: UInt16, charactersIgnoringModifiers: String? = nil, isCommandDown: Bool = false) {
        self.keyCode = keyCode
        self.charactersIgnoringModifiers = charactersIgnoringModifiers
        self.isCommandDown = isCommandDown
    }
}

enum PanelKeyCommand: Equatable {
    case close
    case openSettings
    case confirm
    case moveUp
    case moveDown
    case previousPage
    case nextPage
    case pasteCmdNumber(Int)

    static func interpret(_ event: PanelKeyEvent, pageSize: Int) -> PanelKeyCommand? {
        if event.keyCode == 53 { return .close } // Esc
        if event.isCommandDown, event.charactersIgnoringModifiers == "," { return .openSettings }
        if event.keyCode == 36 { return .confirm } // Return

        switch event.keyCode {
        case 126: return .moveUp
        case 125: return .moveDown
        case 123: return .previousPage
        case 124: return .nextPage
        default: break
        }

        if event.isCommandDown,
           let raw = event.charactersIgnoringModifiers,
           let number = Int(raw),
           (1...pageSize).contains(number) {
            return .pasteCmdNumber(number)
        }

        return nil
    }
}
