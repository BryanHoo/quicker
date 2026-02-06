import Carbon
import Foundation

final class HotkeyManager {
    private var hotKeyRefs: [HotkeyAction: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?
    private let onHotkeyAction: (HotkeyAction) -> Void

    convenience init(onHotkey: @escaping () -> Void) {
        self.init(onHotkeyAction: { action in
            guard action == .clipboardPanel else { return }
            onHotkey()
        })
    }

    init(onHotkeyAction: @escaping (HotkeyAction) -> Void) {
        self.onHotkeyAction = onHotkeyAction
    }

    @discardableResult
    func register(_ hotkey: Hotkey) -> OSStatus {
        register(hotkey, for: .clipboardPanel)
    }

    @discardableResult
    func register(_ hotkey: Hotkey, for action: HotkeyAction) -> OSStatus {
        installEventHandlerIfNeeded()
        unregister(action: action)

        var hotKeyRef: EventHotKeyRef?
        var id = HotkeyRouteCodec.makeID(for: action)
        let status = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.modifiers,
            id,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let hotKeyRef {
            hotKeyRefs[action] = hotKeyRef
        }
        return status
    }

    func unregister(action: HotkeyAction) {
        if let ref = hotKeyRefs[action] {
            UnregisterEventHotKey(ref)
            hotKeyRefs[action] = nil
        }
    }

    func unregisterAll() {
        for action in HotkeyAction.allCases {
            unregister(action: action)
        }

        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    deinit {
        unregisterAll()
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData else { return noErr }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.handleHotkey(event)
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    private func handleHotkey(_ event: EventRef?) {
        guard let event else { return }
        var id = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &id
        )

        guard status == noErr, let action = HotkeyRouteCodec.decode(id) else { return }
        onHotkeyAction(action)
    }
}
