import AppKit
import Combine
import CoreGraphics
import SwiftUI

final class AppModel: ObservableObject {
    @Published private(set) var clickThrough = false

    /// Smoothed playback multiplier for the GIF (1 = normal, up to `burstSpeed` during typing bursts).
    @Published private(set) var playbackSpeedMultiplier: Double = 1.0

    /// `true` when the listen-only **CGEvent** session tap is installed (system-wide keyDown path).
    @Published private(set) var globalSessionTapActive = false

    /// Raised when the user chooses **File → Open…** (or ⌘O) so the window can show a panel even if clicks pass through the window.
    let openGIFPublisher = PassthroughSubject<Void, Never>()

    private var globalKeyTap: GlobalKeyEventTap?
    private var localKeyMonitor: Any?
    private var typingBurstTimer: Timer?
    private var lastKeyPressAt: Date?
    private var didBecomeActiveObserver: NSObjectProtocol?

    private let normalSpeed = 1.0
    private let burstSpeed = 3.0
    private let burstTimeout: TimeInterval = 0.4
    private let smoothingAmount = 0.25
    private let tickInterval: TimeInterval = 0.05

    init() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: NSEvent.EventTypeMask.keyDown) { [weak self] event in
            self?.handleKeyDown()
            return event
        }

        startTypingBurstTimer()

        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.installGlobalSessionTap()
        }

        requestListenEventAccessIfNeeded()

        DispatchQueue.main.async { [weak self] in
            self?.installGlobalSessionTap()
            self?.scheduleSessionTapRetry()
        }
    }

    deinit {
        if let didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(didBecomeActiveObserver)
        }
        globalKeyTap?.stop()
        globalKeyTap = nil
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
        }
        typingBurstTimer?.invalidate()
    }

    func openGIF() {
        openGIFPublisher.send()
    }

    func setClickThrough(_ enabled: Bool) {
        guard enabled != clickThrough else { return }
        clickThrough = enabled
    }

    /// Call after enabling **Input Monitoring** for DesktopGif in System Settings.
    func refreshTypingMonitors() {
        requestListenEventAccessIfNeeded()
        installGlobalSessionTap()
        scheduleSessionTapRetry()
    }

    func openInputMonitoringPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") else { return }
        NSWorkspace.shared.open(url)
    }

    private func installGlobalSessionTap() {
        globalKeyTap?.stop()
        globalKeyTap = nil

        let tap = GlobalKeyEventTap { [weak self] in
            self?.handleKeyDown()
        }
        let ok = tap.start()
        if ok {
            globalKeyTap = tap
        }
        globalSessionTapActive = ok
    }

    private func scheduleSessionTapRetry() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.requestListenEventAccessIfNeeded()
            self?.installGlobalSessionTap()
        }
    }

    private func requestListenEventAccessIfNeeded() {
        guard CGPreflightListenEventAccess() == false else { return }
        _ = CGRequestListenEventAccess()
    }

    private func handleKeyDown() {
        DispatchQueue.main.async { [weak self] in
            self?.lastKeyPressAt = Date()
        }
    }

    private func startTypingBurstTimer() {
        typingBurstTimer?.invalidate()
        let timer = Timer(timeInterval: tickInterval, repeats: true) { [weak self] _ in
            self?.typingBurstTick()
        }
        typingBurstTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func typingBurstTick() {
        let target: Double
        if let last = lastKeyPressAt, Date().timeIntervalSince(last) < burstTimeout {
            target = burstSpeed
        } else {
            target = normalSpeed
        }
        let next = playbackSpeedMultiplier + (target - playbackSpeedMultiplier) * smoothingAmount
        let clamped = min(max(next, normalSpeed), burstSpeed)
        if abs(clamped - playbackSpeedMultiplier) > 0.000_1 {
            playbackSpeedMultiplier = clamped
        }
    }
}
