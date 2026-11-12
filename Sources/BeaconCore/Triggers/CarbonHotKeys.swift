import AppKit
import Carbon.HIToolbox

/// Global shortcuts through the Carbon hotkey API. No permission needed, and it works while any app is frontmost.
@MainActor
public final class CarbonHotKeys {
    public var onPress: ((HotKeyAction) -> Void)?
    /// Actions whose shortcut the system refused (already taken by another app).
    public private(set) var failed: [HotKeyAction] = []

    private var refs: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    private static let signature: OSType = 0x4243_4E31  // 'BCN1'

    public init() {}

    public func register(_ keys: [HotKeyAction: HotKey]) {
        unregisterAll()
        failed = []
        installHandler()
        for (index, action) in HotKeyAction.allCases.enumerated() {
            guard let key = keys[action] else { continue }
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: Self.signature, id: UInt32(index))
            let status = RegisterEventHotKey(key.keyCode, key.modifiers, id, GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref { refs.append(ref) } else { failed.append(action) }
        }
    }

    public func unregisterAll() {
        for ref in refs { UnregisterEventHotKey(ref) }
        refs = []
    }

    deinit {
        MainActor.assumeIsolated {
            unregisterAll()
            if let handler { RemoveEventHandler(handler) }
        }
    }

    private func installHandler() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let status = GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                MemoryLayout<EventHotKeyID>.size, nil, &id
            )
            guard status == noErr, id.signature == CarbonHotKeys.signature else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<CarbonHotKeys>.fromOpaque(userData).takeUnretainedValue()
            // Carbon delivers hotkey events on the main thread.
            MainActor.assumeIsolated {
                if Int(id.id) < HotKeyAction.allCases.count { owner.onPress?(HotKeyAction.allCases[Int(id.id)]) }
            }
            return noErr
        }
        InstallEventHandler(
            GetApplicationEventTarget(), callback, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler
        )
    }
}
