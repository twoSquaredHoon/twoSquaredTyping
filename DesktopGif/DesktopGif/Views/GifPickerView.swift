import SwiftUI

struct GifPickerView: View {
    let onSelectGif: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Choose a GIF")
                .font(.headline)
            Button("Select GIF…", action: onSelectGif)
                .keyboardShortcut("o", modifiers: .command)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.75))
        )
        .frame(minWidth: 280, minHeight: 160)
    }
}
