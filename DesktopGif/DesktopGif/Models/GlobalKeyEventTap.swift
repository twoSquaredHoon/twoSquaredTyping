import AppKit
import CoreGraphics

/// System-wide **keyDown** observation using a **listen-only** `CGEvent` session tap.
/// Pairs with **`CGRequestListenEventAccess`** / **Input Monitoring**; does not modify events.
final class GlobalKeyEventTap {
    private var tapPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let onKeyDown: () -> Void

    init(onKeyDown: @escaping () -> Void) {
        self.onKeyDown = onKeyDown
    }

    deinit {
        stop()
    }

    /// Returns whether the tap was created (still requires TCC approval for events to flow).
    @discardableResult
    func start() -> Bool {
        stop()

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: Self.eventTapCallback,
            userInfo: userInfo
        ) else {
            return false
        }

        tapPort = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        return true
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        if let tapPort {
            CGEvent.tapEnable(tap: tapPort, enable: false)
            CFMachPortInvalidate(tapPort)
            self.tapPort = nil
        }
    }

    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }
        let box = Unmanaged<GlobalKeyEventTap>.fromOpaque(userInfo).takeUnretainedValue()

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let port = box.tapPort {
                CGEvent.tapEnable(tap: port, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        if type == .keyDown {
            box.onKeyDown()
        }
        return Unmanaged.passUnretained(event)
    }
}
