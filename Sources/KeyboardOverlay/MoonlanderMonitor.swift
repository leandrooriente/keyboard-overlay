import Foundation
import IOKit.hid

enum MoonlanderStatus: Equatable {
    case stopped
    case searching
    case connecting
    case connected
    case unavailable
}

/// Oryx protocol v4/v5 frames are unnumbered, 32-byte raw HID reports.
/// Spec: https://github.com/zsa/qmk_modules/blob/main/oryx/oryx.h
enum MoonlanderReport: Equatable {
    case protocolVersion(Int)
    case paired
    case layer(Int)
    case key(row: Int, column: Int, pressed: Bool)
    case error(UInt8)

    init?(bytes: [UInt8]) {
        guard bytes.count == 32 else { return nil }
        switch bytes[0] {
        case 0xFE where bytes[2] == 0xFE:
            self = .protocolVersion(Int(bytes[1]))
        case 0x04 where bytes[1] == 0xFE:
            self = .paired
        case 0x05 where bytes[2] == 0xFE:
            self = .layer(Int(bytes[1]))
        case 0x06 where bytes[3] == 0xFE, 0x07 where bytes[3] == 0xFE:
            guard bytes[1] < 7, bytes[2] < 12 else { return nil }
            self = .key(row: Int(bytes[2]), column: Int(bytes[1]), pressed: bytes[0] == 0x06)
        case 0xFF:
            self = .error(bytes[1])
        default:
            return nil
        }
    }
}

/// The caller starts this only after the user enables Follow Moonlander and
/// stops it when the overlay hides. It opens only the vendor-defined interface,
/// without seizing the keyboard or changing its layout, lighting, or firmware.
@MainActor final class MoonlanderMonitor {
    var onLayer: (Int) -> Void = { _ in }
    var onPhysicalKey: (String, Bool) -> Void = { _, _ in }
    var onStatus: (MoonlanderStatus) -> Void = { _ in }
    var onReset: () -> Void = {}
    private(set) var status: MoonlanderStatus = .stopped
    private(set) var lastError: String?
    var isConnected: Bool { status == .connected }

    private var manager: IOHIDManager?
    private var device: IOHIDDevice?
    private var reportBuffer: UnsafeMutablePointer<UInt8>?
    private var handshakeTimer: Timer?
    private var pairingRequested = false

    func start() {
        if status == .unavailable { stop() }
        guard manager == nil else { return }
        lastError = nil
        setStatus(.searching)
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = manager
        // Both currently shipped Moonlander revisions share Oryx's raw interface.
        let matches = [0x1969, 0x1972].map { productID in
            [kIOHIDVendorIDKey: 0x3297, kIOHIDProductIDKey: productID,
             kIOHIDDeviceUsagePageKey: 0xFF60, kIOHIDDeviceUsageKey: 0x61]
        }
        IOHIDManagerSetDeviceMatchingMultiple(manager, matches as CFArray)
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, result, _, device in
            guard result == kIOReturnSuccess, let context else { return }
            MainActor.assumeIsolated {
                Unmanaged<MoonlanderMonitor>.fromOpaque(context).takeUnretainedValue().attach(device)
            }
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, device in
            guard let context else { return }
            MainActor.assumeIsolated {
                let monitor = Unmanaged<MoonlanderMonitor>.fromOpaque(context).takeUnretainedValue()
                if let current = monitor.device, CFEqual(current, device) {
                    monitor.detach()
                    monitor.setStatus(.searching)
                }
            }
        }, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if result != kIOReturnSuccess {
            lastError = "Could not open the Moonlander's Oryx interface (\(result)). Close other keyboard tools and retry."
            stop()
            setStatus(.unavailable)
        }
    }

    func stop() {
        detach()
        if let manager {
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        manager = nil
        setStatus(.stopped)
    }

    private func attach(_ device: IOHIDDevice) {
        guard self.device == nil else { return }
        self.device = device
        pairingRequested = false
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 32)
        buffer.initialize(repeating: 0, count: 32)
        reportBuffer = buffer
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(device, buffer, 32, { context, result, _, _, reportID, report, length in
            guard result == kIOReturnSuccess, reportID == 0, let context else { return }
            MainActor.assumeIsolated {
                let monitor = Unmanaged<MoonlanderMonitor>.fromOpaque(context).takeUnretainedValue()
                guard let frame = MoonlanderReport(bytes: Array(UnsafeBufferPointer(start: report, count: length))) else { return }
                monitor.receive(frame)
            }
        }, context)
        setStatus(.connecting)
        armHandshakeTimeout()
        // This read-only query ensures older pairing-challenge protocols are not
        // mistaken for the immediate-pairing protocol supported here.
        send(command: 0xFE)
    }

    private func receive(_ report: MoonlanderReport) {
        guard device != nil else { return }
        switch report {
        case .protocolVersion(let version):
            guard version == 4 || version == 5 else {
                fail("This Oryx firmware uses protocol \(version). Update the layout's firmware in Oryx, then reconnect.")
                return
            }
            if !pairingRequested {
                pairingRequested = true
                send(command: 0x01)
            }
        case .paired:
            guard pairingRequested else { return }
            handshakeTimer?.invalidate()
            handshakeTimer = nil
            setStatus(.connected)
        case .layer(let layer):
            if isConnected { onLayer(layer) }
        case .key(let row, let column, let pressed):
            if isConnected, let id = MoonlanderMatrix.keyID(row: row, column: column) {
                onPhysicalKey(id, pressed)
            }
        case .error(let code):
            if !isConnected { fail("The keyboard rejected the Oryx connection (error \(code)).") }
        }
    }

    private func send(command: UInt8) {
        guard let device else { return }
        var report = [UInt8](repeating: 0, count: 32)
        report[0] = command
        let result = report.withUnsafeBufferPointer {
            IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, 0, $0.baseAddress!, $0.count)
        }
        if result != kIOReturnSuccess { fail("Could not communicate with the Moonlander's Oryx interface (\(result)).") }
    }

    private func armHandshakeTimeout() {
        handshakeTimer?.invalidate()
        let timer = Timer(timeInterval: 3, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.isConnected else { return }
                self.fail("The keyboard did not respond. Close Oryx Live Training or Keymapp, and check that Oryx firmware is installed.")
            }
        }
        handshakeTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func fail(_ message: String) {
        lastError = message
        detach()
        setStatus(.unavailable)
    }

    private func detach() {
        handshakeTimer?.invalidate()
        handshakeTimer = nil
        if let device, let buffer = reportBuffer {
            IOHIDDeviceRegisterInputReportCallback(device, buffer, 32, nil, nil)
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        device = nil
        pairingRequested = false
        reportBuffer?.deinitialize(count: 32)
        reportBuffer?.deallocate()
        reportBuffer = nil
        onReset()
        // Oryx defines command 0x03 but does not implement it in protocol v4/v5.
        // Do not send it: closing the host interface ends our observation.
    }

    private func setStatus(_ status: MoonlanderStatus) {
        self.status = status
        onStatus(status)
    }
}
