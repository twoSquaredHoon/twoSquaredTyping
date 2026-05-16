import SwiftUI

struct ModeSelectionView: View {
    let onSelectWidget: () -> Void
    let onSelectOverlay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Choose display mode")
                .font(.title2.bold())

            activeModeBlock(
                title: "Widget Mode",
                placeholder: "Sits just above the desktop icon layer—like a desktop sticker.",
                action: onSelectWidget
            )
            activeModeBlock(
                title: "Overlay Mode",
                placeholder: "Floats above normal windows (always-on-top). Drag to reposition.",
                action: onSelectOverlay
            )
        }
        .padding(28)
        .frame(minWidth: 360, minHeight: 280)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.75))
        )
    }

    private func activeModeBlock(title: String, placeholder: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(title, action: action)
                .buttonStyle(.borderedProminent)

            Text(placeholder)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
