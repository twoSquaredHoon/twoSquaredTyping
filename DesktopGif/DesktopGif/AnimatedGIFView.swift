import AppKit
import SwiftUI

/// Renders an animated GIF using AppKit so frame animation actually plays.
struct AnimatedGIFView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleNone
        imageView.imageAlignment = .alignCenter
        imageView.animates = true
        imageView.image = NSImage(contentsOf: url)
        return imageView
    }

    func updateNSView(_ imageView: NSImageView, context: Context) {
        imageView.animates = true
        imageView.image = NSImage(contentsOf: url)
    }
}
