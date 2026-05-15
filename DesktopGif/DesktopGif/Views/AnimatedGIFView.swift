import AppKit
import ImageIO
import SwiftUI

/// GIF playback with per-frame delays from ImageIO; speed follows **`playbackSpeedMultiplier`**
/// (`delay / multiplier`).
struct AnimatedGIFView: NSViewRepresentable {
    @ObservedObject var appModel: AppModel
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(appModel: appModel)
    }

    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleNone
        imageView.imageAlignment = .alignCenter
        imageView.animates = false
        context.coordinator.attach(imageView: imageView)
        context.coordinator.reloadIfNeeded(url: url)
        return imageView
    }

    func updateNSView(_ imageView: NSImageView, context: Context) {
        context.coordinator.appModel = appModel
        context.coordinator.attach(imageView: imageView)
        context.coordinator.reloadIfNeeded(url: url)
    }

    static func dismantleNSView(_ nsView: NSImageView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator {
        weak var appModel: AppModel?
        private weak var imageView: NSImageView?

        private var frames: [(cgImage: CGImage, delay: TimeInterval)] = []
        private var frameIndex: Int = 0
        private var timer: Timer?
        private var loadedURL: URL?
        private var logicalSize = NSSize(width: 1, height: 1)

        init(appModel: AppModel) {
            self.appModel = appModel
        }

        func attach(imageView: NSImageView) {
            self.imageView = imageView
        }

        func reloadIfNeeded(url: URL) {
            if loadedURL == url, !frames.isEmpty {
                return
            }
            stopTimer()
            loadedURL = url
            frames = Self.decodeGIF(url: url) ?? []
            if frames.isEmpty {
                imageView?.animates = true
                imageView?.image = NSImage(contentsOf: url)
                return
            }
            imageView?.animates = false
            frameIndex = 0
            let first = frames[0].cgImage
            logicalSize = NSSize(width: first.width, height: first.height)
            showCurrentFrame()
            scheduleNextFrame()
        }

        func stop() {
            stopTimer()
            frames = []
            loadedURL = nil
        }

        private func stopTimer() {
            timer?.invalidate()
            timer = nil
        }

        private func showCurrentFrame() {
            guard !frames.isEmpty else { return }
            let cgImage = frames[frameIndex].cgImage
            imageView?.image = NSImage(cgImage: cgImage, size: logicalSize)
        }

        private func scheduleNextFrame() {
            stopTimer()
            guard !frames.isEmpty else { return }
            let baseDelay = frames[frameIndex].delay
            let multiplier = max(appModel?.playbackSpeedMultiplier ?? 1.0, 0.01)
            let adjustedDelay = baseDelay / multiplier
            let interval = max(0.02, adjustedDelay)

            timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
                self?.advanceFrame()
            }
            if let timer {
                RunLoop.main.add(timer, forMode: .common)
            }
        }

        private func advanceFrame() {
            guard !frames.isEmpty else { return }
            frameIndex = (frameIndex + 1) % frames.count
            showCurrentFrame()
            scheduleNextFrame()
        }

        private static func decodeGIF(url: URL) -> [(cgImage: CGImage, delay: TimeInterval)]? {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            let count = CGImageSourceGetCount(source)
            guard count > 0 else { return nil }

            var result: [(CGImage, TimeInterval)] = []
            result.reserveCapacity(count)
            for index in 0 ..< count {
                guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
                let delay = frameDelay(for: source, at: index)
                result.append((cgImage, delay))
            }
            return result.isEmpty ? nil : result
        }

        private static func frameDelay(for source: CGImageSource, at index: Int) -> TimeInterval {
            var delay = 0.1
            guard let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
                  let gif = props[kCGImagePropertyGIFDictionary] as? [CFString: Any] else {
                return delay
            }
            if let unclamped = gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double, unclamped > 0 {
                delay = unclamped
            } else if let clamped = gif[kCGImagePropertyGIFDelayTime] as? Double, clamped > 0 {
                delay = clamped
            }
            if delay < 0.02 {
                delay = 0.1
            }
            return delay
        }
    }
}
