import SwiftUI

/// Post-match summary shown on the watch after finishing.
struct SummaryView: View {
    @ObservedObject var manager: WorkoutManager

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.small) {
                Text("FULL TIME")
                    .font(Theme.Typography.logo(size: 14))
                    .tracking(2)
                    .foregroundStyle(Theme.Colors.accent)

                if let summary = manager.summary {
                    row("Duration", summary.durationText)
                    row("Distance", summary.distanceKmText)
                    row("Avg HR", summary.hrAvg.map { "\($0) bpm" } ?? "--")
                    row("Max HR", summary.hrMax.map { "\($0) bpm" } ?? "--")
                    row("Sprints", "\(summary.sprints)")
                    row("Intensity", summary.intensity.map { String(format: "%.0f", $0) } ?? "--")
                    row("Calories", summary.caloriesKcal.map { String(format: "%.0f kcal", $0) } ?? "--")
                }

                Button {
                    manager.reset()
                } label: {
                    Text("Done")
                        .font(Theme.Typography.button())
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .background(Theme.Colors.accent)
                .clipShape(Capsule())
                .padding(.top, Theme.Spacing.small)
            }
            .padding(.horizontal, Theme.Spacing.medium)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.Typography.caption())
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(Theme.Typography.statLabel(size: 14))
        }
        .padding(.vertical, 4)
    }
}
