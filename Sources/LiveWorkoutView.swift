import SwiftUI

/// Live match screen: timer and metrics with pause/resume and finish controls.
struct LiveWorkoutView: View {
    @ObservedObject var manager: WorkoutManager

    var body: some View {
        VStack(spacing: Theme.Spacing.small) {
            Text(elapsedText)
                .font(Theme.Typography.metric(size: 34))
                .foregroundStyle(Theme.Colors.accent)
                .monospacedDigit()

            HStack(spacing: Theme.Spacing.medium) {
                metric(value: heartRateText, label: "BPM")
                metric(value: distanceText, label: "KM")
            }

            Spacer(minLength: Theme.Spacing.small)

            HStack(spacing: Theme.Spacing.small) {
                Button {
                    manager.phase == .paused ? manager.resume() : manager.pause()
                } label: {
                    Image(systemName: manager.phase == .paused ? "play.fill" : "pause.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .background(Theme.Colors.surface)
                .foregroundStyle(Theme.Colors.textPrimary)
                .clipShape(Capsule())

                Button {
                    Task { await manager.end() }
                } label: {
                    Image(systemName: "stop.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .background(Theme.Colors.accent)
                .foregroundStyle(Color.black)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, Theme.Spacing.medium)
        .padding(.vertical, Theme.Spacing.small)
    }

    private func metric(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Theme.Typography.metric(size: 20))
            Text(label)
                .font(Theme.Typography.statLabel(size: 11))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var elapsedText: String {
        let total = Int(manager.elapsed)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var heartRateText: String {
        manager.heartRate > 0 ? "\(Int(manager.heartRate))" : "--"
    }

    private var distanceText: String {
        String(format: "%.2f", manager.distanceM / 1000)
    }
}
