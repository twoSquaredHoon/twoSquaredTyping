import SwiftUI

/// Hover the top-trailing zone: a ring fills around the lock icon; when complete, toggles pass-through.
struct InteractionLockOverlay: View {
    @EnvironmentObject private var appModel: AppModel

    @Binding var pointerInZone: Bool
    /// After a successful hold, ignore the zone until the pointer leaves (prevents instant re-toggle).
    @Binding var requiresZoneExit: Bool

    @State private var ringProgress: CGFloat = 0
    @State private var holdTask: Task<Void, Never>?

    private let controlSize: CGFloat = 40
    private let hotSize: CGFloat = 72
    private let holdDuration: TimeInterval = 0.75
    private let progressSteps = 30

    var body: some View {
        VStack {
            HStack {
                Spacer()
                lockGlyph
                    .opacity(pointerInZone ? 1 : 0)
                    .scaleEffect(pointerInZone ? 1 : 0.88)
                    .animation(.easeOut(duration: 0.16), value: pointerInZone)
            }
            Spacer()
        }
        .padding(8)
        .overlay(alignment: .topTrailing) {
            Color.clear
                .frame(width: hotSize, height: hotSize)
                .contentShape(Rectangle())
                .onHover { hovering in
                    guard !appModel.clickThrough else { return }
                    if hovering {
                        guard !requiresZoneExit else { return }
                        pointerInZone = true
                    } else {
                        requiresZoneExit = false
                        pointerInZone = false
                    }
                }
        }
        .onChange(of: pointerInZone) { _, inZone in
            if inZone {
                guard !requiresZoneExit else { return }
                startHoldProgress()
            } else {
                requiresZoneExit = false
                cancelHoldProgress()
            }
        }
        .onChange(of: appModel.clickThrough) { _, _ in
            cancelHoldProgress()
        }
    }

    private var lockGlyph: some View {
        ZStack {
            Circle()
                .strokeBorder(.white.opacity(0.28), lineWidth: 2.5)

            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(
                    .white,
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Image(systemName: appModel.clickThrough ? "lock.fill" : "lock.open.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
        }
        .frame(width: controlSize, height: controlSize)
        .padding(6)
        .background(.black.opacity(0.35), in: Circle())
        .accessibilityLabel(appModel.clickThrough ? "Hover to unlock" : "Hover to lock")
        .accessibilityValue(ringProgress > 0 ? "Holding" : "Idle")
    }

    private func startHoldProgress() {
        holdTask?.cancel()
        ringProgress = 0

        holdTask = Task { @MainActor in
            let stepNanos = UInt64(holdDuration / Double(progressSteps) * 1_000_000_000)
            for step in 1...progressSteps {
                try? await Task.sleep(nanoseconds: stepNanos)
                guard !Task.isCancelled, pointerInZone else { return }
                ringProgress = CGFloat(step) / CGFloat(progressSteps)
            }
            guard !Task.isCancelled, pointerInZone else { return }
            completeHold()
        }
    }

    private func cancelHoldProgress() {
        holdTask?.cancel()
        holdTask = nil
        withAnimation(.easeOut(duration: 0.12)) {
            ringProgress = 0
        }
    }

    private func completeHold() {
        let locking = !appModel.clickThrough
        requiresZoneExit = true
        ringProgress = 0
        holdTask = nil
        pointerInZone = false
        appModel.setClickThrough(locking)
    }
}
