import AppKit

/// SwiftUI’s `NSHostingView` usually answers `mouseDownCanMoveWindow` with `false`, so
/// `isMovableByWindowBackground` never runs. This moves the borderless window explicitly
/// while still returning every event so controls keep working.
final class WindowDragController {
    static let shared = WindowDragController()

    private var monitor: Any?
    private var willCloseObserver: NSObjectProtocol?
    private weak var window: NSWindow?

    private var downScreen: NSPoint?
    private var frameOriginAtDown: NSPoint?

    private init() {}

    func attach(to window: NSWindow) {
        if self.window === window, monitor != nil { return }
        detach()
        self.window = window

        willCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.detach()
        }

        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    func detach() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        if let willCloseObserver {
            NotificationCenter.default.removeObserver(willCloseObserver)
        }
        willCloseObserver = nil
        window = nil
        downScreen = nil
        frameOriginAtDown = nil
    }

    private func handle(_ event: NSEvent) {
        guard let window else { return }
        guard event.window === window else { return }
        guard !window.ignoresMouseEvents else { return }

        switch event.type {
        case .leftMouseDown:
            downScreen = NSEvent.mouseLocation
            frameOriginAtDown = window.frame.origin

        case .leftMouseDragged:
            guard let downScreen, let frameOriginAtDown else { return }
            let now = NSEvent.mouseLocation
            let moved = hypot(now.x - downScreen.x, now.y - downScreen.y)
            if moved < 4 { return }

            window.setFrameOrigin(
                NSPoint(
                    x: frameOriginAtDown.x + (now.x - downScreen.x),
                    y: frameOriginAtDown.y + (now.y - downScreen.y)
                )
            )

        case .leftMouseUp:
            downScreen = nil
            frameOriginAtDown = nil

        default:
            break
        }
    }
}
