import Foundation
import Carbon.HIToolbox
import AppKit

/// Registers a global keyboard shortcut via Carbon's hot-key service. Works
/// without any special entitlement or permission (unlike NSEvent global
/// monitors for keys).
final class GlobalHotkey: @unchecked Sendable {
    private var hotKeyRef: EventHotKeyRef?
    private let id = UInt32(0xCAFE)

    /// Called from the event-tap thread on every hotkey press. The closure
    /// is routed to the main thread internally.
    var onFire: (() -> Void)?

    func register(keyCode: UInt32, modifiers: UInt32) {
        unregister()

        let hotKeyID = EventHotKeyID(signature: OSType(bitPattern: 0x4D524449) /* 'MRDI' */, id: id)

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let callback: EventHandlerUPP = { _, eventRef, userData in
            guard let userData = userData, let eventRef = eventRef else { return noErr }
            var id = EventHotKeyID()
            GetEventParameter(
                eventRef,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &id
            )
            let unmanaged = Unmanaged<GlobalHotkey>.fromOpaque(userData)
            DispatchQueue.main.async {
                unmanaged.takeUnretainedValue().onFire?()
            }
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            nil
        )

        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    deinit { unregister() }

    /// Convenience: ⌘⇧M key combo (the one advertised in the README).
    static func cmdShiftM() -> (key: UInt32, mods: UInt32) {
        (UInt32(kVK_ANSI_M), UInt32(cmdKey | shiftKey))
    }
}
