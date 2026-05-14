import SwiftUI

struct ModeSelectionView: View {
    /// Only **Widget Mode** continues to the GIF picker. Window and Overlay are UI-only placeholders.
    let onSelectWidget: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Choose display mode")
                .font(.title2.bold())

            activeModeBlock(
                title: "Widget Mode",
                placeholder: "TODO: configure window near desktop icon/background layer.",
                action: onSelectWidget
            )
            placeholderModeBlock(
                title: "Window Mode",
                placeholder: "TODO: configure as normal movable app window."
            )
            placeholderModeBlock(
                title: "Overlay Mode",
                placeholder: "TODO: configure as always-on-top floating overlay."
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

    private func placeholderModeBlock(title: String, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(title) {}
                .buttonStyle(.bordered)
                .disabled(true)

            Text(placeholder)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
