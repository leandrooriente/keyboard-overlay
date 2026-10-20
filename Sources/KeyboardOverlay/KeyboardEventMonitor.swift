import AppKit
import Carbon

enum KeyMonitoringStatus: Equatable {
    case localOnly
    case live
    case secureInput
    case unavailable
}

/// A listen-only tap: keystrokes continue to the foreground app unchanged.
/// The tap exists only while the overlay is visible, and never reads typed text.
@MainActor final class KeyboardEventMonitor {
    var onEvent: (CGEventType, UInt16, NSEvent.ModifierFlags) -> Void = { _, _, _ in }
    var onReset: () -> Void = {}
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var isRunning: Bool { eventTap != nil }

    func refresh() -> KeyMonitoringStatus {
        guard CGPreflightListenEventAccess() else {
            stop()
            return .localOnly
        }
        if eventTap == nil {
            let mask = [CGEventType.keyDown, .keyUp, .flagsChanged].reduce(CGEventMask(0)) {
                $0 | (CGEventMask(1) << $1.rawValue)
            }
            guard let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
                eventsOfInterest: mask,
                callback: { _, type, event, context in
                    if let context {
                        // This tap's source is attached exclusively to the main run loop.
                        MainActor.assumeIsolated {
                            let monitor = Unmanaged<KeyboardEventMonitor>.fromOpaque(context).takeUnretainedValue()
                            monitor.receive(type, event: event)
                        }
                    }
                    return Unmanaged.passUnretained(event)
                },
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            ) else { return .unavailable }
            guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
                CFMachPortInvalidate(tap)
                return .unavailable
            }
            eventTap = tap
            runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        if IsSecureEventInputEnabled() {
            onReset()
            return .secureInput
        }
        return .live
    }

    func stop() {
        let wasRunning = eventTap != nil
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = eventTap { CFMachPortInvalidate(tap) }
        runLoopSource = nil
        eventTap = nil
        if wasRunning { onReset() }
    }

    private func receive(_ type: CGEventType, event: CGEvent) {
        guard let tap = eventTap else { return }
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            onReset()
            if CGPreflightListenEventAccess() { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        guard !IsSecureEventInputEnabled() else { onReset(); return }
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let modifiers = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))
        onEvent(type, keyCode, modifiers)
    }
}
