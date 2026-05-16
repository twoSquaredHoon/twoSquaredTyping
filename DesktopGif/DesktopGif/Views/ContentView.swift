import AppKit
import Combine
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel

    @State private var selectedMode: DisplayMode?
    @State private var gifURL: URL?
    @State private var gifContentSize: CGSize?
    @State private var didPerformBaseWindowSetup = false
    @State private var desktopWindow: NSWindow?
    @State private var pointerInControlZone = false
    @State private var requiresZoneExitBeforeHold = false
    @State private var globalMouseMonitor: Any?
    @State private var leaveZoneWorkItem: DispatchWorkItem?

    private let controlHotSize: CGFloat = 72
    private let leaveZoneDelay: TimeInterval = 0.2

    var body: some View {
        Group {
            if let gifURL, let gifContentSize {
                desktopGIFStage(url: gifURL, size: gifContentSize)
            } else if gifURL != nil {
                Text("Could not read this GIF.")
                    .padding(16)
                    .frame(minWidth: 240, minHeight: 120)
            } else if selectedMode != nil {
                GifPickerView(onSelectGif: pickGIF)
            } else {
                ModeSelectionView(
                    onSelectWidget: { selectedMode = .widget },
                    onSelectOverlay: { selectedMode = .overlay }
                )
            }
        }
        .contentShape(Rectangle())
        .background(WindowAccessor { window in
            if desktopWindow !== window {
                desktopWindow = window
            }
            if !didPerformBaseWindowSetup {
                performBaseWindowSetup(window)
                didPerformBaseWindowSetup = true
            }
            applyDisplayMode(to: window, mode: resolvedDisplayModeForWindow())
            syncMousePassthrough()
            syncWindowSizeToGIF(window: window)
        })
        .onChange(of: desktopWindow) { _, _ in
            syncWindowSizeToGIF(window: desktopWindow)
            refreshGlobalMouseMonitor()
        }
        .onChange(of: gifURL) { _, _ in
            refreshGlobalMouseMonitor()
        }
        .onChange(of: gifContentSize) { _, _ in
            syncWindowSizeToGIF(window: desktopWindow)
        }
        .onChange(of: selectedMode) { _, _ in
            if let window = desktopWindow {
                applyDisplayMode(to: window, mode: resolvedDisplayModeForWindow())
                window.orderFrontRegardless()
            }
        }
        .onChange(of: appModel.clickThrough) { _, _ in
            syncMousePassthrough()
            refreshGlobalMouseMonitor()
        }
        .onChange(of: pointerInControlZone) { _, _ in
            syncMousePassthrough()
        }
        .onReceive(appModel.openGIFPublisher) { _ in
            if selectedMode != nil {
                pickGIF()
            }
        }
        .onDisappear {
            stopGlobalMouseMonitor()
        }
    }

    @ViewBuilder
    private func desktopGIFStage(url: URL, size: CGSize) -> some View {
        ZStack(alignment: .topTrailing) {
            AnimatedGIFView(appModel: appModel, url: url)
                .frame(width: size.width, height: size.height)
                .allowsHitTesting(!appModel.clickThrough)

            InteractionLockOverlay(
                pointerInZone: $pointerInControlZone,
                requiresZoneExit: $requiresZoneExitBeforeHold
            )
            .frame(width: size.width, height: size.height, alignment: .topTrailing)
        }
        .frame(width: size.width, height: size.height)
    }

    private func pickGIF() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.gif]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.begin { response in
            if response == .OK, let url = panel.url {
                adoptGIF(at: url)
            }
        }
    }

    private func adoptGIF(at url: URL) {
        guard let image = NSImage(contentsOf: url),
              image.size.width > 0, image.size.height > 0 else {
            gifContentSize = nil
            gifURL = url
            return
        }
        let size = CGSize(width: image.size.width, height: image.size.height)
        gifContentSize = size
        gifURL = url
        syncWindowSizeToGIF(window: desktopWindow)
        refreshGlobalMouseMonitor()
    }

    private func syncWindowSizeToGIF(window: NSWindow?) {
        guard let window, let size = gifContentSize, gifURL != nil else { return }
        window.setContentSize(NSSize(width: size.width, height: size.height))
    }

    /// Until the user picks a mode, match the historical default (desktop sticker layer) for the mode picker UI.
    private func resolvedDisplayModeForWindow() -> DisplayMode {
        selectedMode ?? .widget
    }

    /// Borderless transparent shell shared by all display modes (level / Spaces behavior varies).
    private func performBaseWindowSetup(_ window: NSWindow) {
        window.styleMask = [.borderless, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isMovableByWindowBackground = false
        WindowDragController.shared.attach(to: window) {
            appModel.clickThrough == false
        }
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
    }

    private func applyDisplayMode(to window: NSWindow, mode: DisplayMode) {
        switch mode {
        case .widget:
            let iconLevel = Int(CGWindowLevelForKey(.desktopIconWindow))
            window.level = NSWindow.Level(rawValue: iconLevel + 1)
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.hidesOnDeactivate = false
        case .overlay:
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.hidesOnDeactivate = false
        }
    }

    private func refreshGlobalMouseMonitor() {
        let shouldTrack = gifURL != nil
            && gifContentSize != nil
            && appModel.clickThrough

        if shouldTrack {
            startGlobalMouseMonitorIfNeeded()
        } else {
            stopGlobalMouseMonitor()
            syncMousePassthrough()
        }
    }

    private func startGlobalMouseMonitorIfNeeded() {
        guard globalMouseMonitor == nil else { return }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { _ in
            DispatchQueue.main.async {
                evaluatePointerNearControls()
            }
        }
        evaluatePointerNearControls()
    }

    private func stopGlobalMouseMonitor() {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
        }
        globalMouseMonitor = nil
    }

    private func evaluatePointerNearControls() {
        guard appModel.clickThrough, let window = desktopWindow else { return }
        let near = interactionControlHotRect(for: window).contains(NSEvent.mouseLocation)
        setPointerInControlZone(near)
    }

    private func interactionControlHotRect(for window: NSWindow) -> NSRect {
        let frame = window.frame
        return NSRect(
            x: frame.maxX - controlHotSize,
            y: frame.maxY - controlHotSize,
            width: controlHotSize,
            height: controlHotSize
        )
    }

    private func setPointerInControlZone(_ inZone: Bool) {
        leaveZoneWorkItem?.cancel()
        if inZone {
            guard !requiresZoneExitBeforeHold else { return }
            pointerInControlZone = true
            return
        }
        requiresZoneExitBeforeHold = false
        let work = DispatchWorkItem {
            pointerInControlZone = false
        }
        leaveZoneWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + leaveZoneDelay, execute: work)
    }

    private func syncMousePassthrough() {
        guard let window = desktopWindow else { return }
        if appModel.clickThrough {
            window.ignoresMouseEvents = !pointerInControlZone
        } else {
            window.ignoresMouseEvents = false
        }
    }
}
