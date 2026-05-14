import AppKit
import Combine
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel

    @State private var selectedMode: DisplayMode?
    @State private var gifURL: URL?
    @State private var gifContentSize: CGSize?
    @State private var windowConfigured = false
    @State private var desktopWindow: NSWindow?

    var body: some View {
        Group {
            if let gifURL, let gifContentSize {
                AnimatedGIFView(url: gifURL)
                    .frame(width: gifContentSize.width, height: gifContentSize.height)
            } else if gifURL != nil {
                Text("Could not read this GIF.")
                    .padding(16)
                    .frame(minWidth: 240, minHeight: 120)
            } else if selectedMode != nil {
                GifPickerView(onSelectGif: pickGIF)
            } else {
                ModeSelectionView {
                    selectedMode = .widget
                }
            }
        }
        // Transparent SwiftUI views do not hit-test by default; without this, the window
        // does not receive mouse drags reliably for `WindowDragController`.
        .contentShape(Rectangle())
        .background(WindowAccessor { window in
            if desktopWindow !== window {
                desktopWindow = window
            }
            guard !windowConfigured else { return }
            configureDesktopWindow(window)
            window.ignoresMouseEvents = appModel.clickThrough
            windowConfigured = true
            syncWindowSizeToGIF(window: window)
        })
        .onChange(of: desktopWindow) { _, window in
            syncWindowSizeToGIF(window: window)
        }
        .onChange(of: gifContentSize) { _, _ in
            syncWindowSizeToGIF(window: desktopWindow)
        }
        .onReceive(appModel.$clickThrough) { on in
            desktopWindow?.ignoresMouseEvents = on
        }
        .onReceive(appModel.openGIFPublisher) { _ in
            if selectedMode != nil {
                pickGIF()
            }
        }
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
    }

    private func syncWindowSizeToGIF(window: NSWindow?) {
        guard let window, let size = gifContentSize, gifURL != nil else { return }
        window.setContentSize(NSSize(width: size.width, height: size.height))
    }

    private func configureDesktopWindow(_ window: NSWindow) {
        window.styleMask = [.borderless, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false

        // Slightly *above* `.desktopIconWindow` so Finder’s desktop layer does not eat
        // every mouse event; you can drag the window and use controls. (Level −1 looks
        // “under” the desktop but is not interactive.)
        let iconLevel = Int(CGWindowLevelForKey(.desktopIconWindow))
        window.level = NSWindow.Level(rawValue: iconLevel + 1)

        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        // `WindowDragController` moves the window; leaving `isMovableByWindowBackground`
        // true can let AppKit try the same drag and cause jitter.
        window.isMovableByWindowBackground = false
        WindowDragController.shared.attach(to: window)
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
    }
}
