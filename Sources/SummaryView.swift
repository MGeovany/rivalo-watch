import SwiftUI

/// Post-match summary: combined score + final stats.
struct SummaryView: View {
    @ObservedObject var manager: WorkoutManager

    var body: some View {
        VStack(spacing: 0) {
            if let summary = manager.summary {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        header
                        scoreHero(summary: summary)
                        statsGrid(summary: summary)
                    }
                    .padding(.horizontal, Theme.Spacing.medium)
                    .padding(.top, 4)
                    .padding(.bottom, 4)
                }
                .frame(maxHeight: .infinity)
            } else {
                Text("FULL TIME")
                    .font(Theme.Typography.statLabel(size: 10))
                    .foregroundStyle(Theme.Colors.accent)
            }

            doneButton
                .padding(.horizontal, Theme.Spacing.medium)
                .padding(.bottom, 6)
        }
    }

    private var header: some View {
        Text("FULL TIME")
            .font(Theme.Typography.statLabel(size: 10))
            .foregroundStyle(Theme.Colors.accent)
            .tracking(1.4)
    }

    private func scoreHero(summary: WorkoutSummary) -> some View {
        let result = MatchFinalScore.compute(from: summary)

        return VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 5)
                    .frame(width: 88, height: 88)

                Circle()
                    .trim(from: 0, to: CGFloat(result.overall) / 100)
                    .stroke(
                        LinearGradient(
                            colors: [Theme.Colors.accentBright, Theme.Colors.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .frame(width: 88, height: 88)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(result.overall)")
                        .font(Theme.Typography.metric(size: 32))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text("SCORE")
                        .font(Theme.Typography.statLabel(size: 8))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .tracking(0.8)
                }
            }

            Text(result.tier)
                .font(Theme.Typography.statLabel(size: 11))
                .foregroundStyle(Theme.Colors.accentBright)
                .tracking(1.2)

            scoreBreakdownBar(result: result)
        }
        .padding(.vertical, 4)
    }

    private func scoreBreakdownBar(result: MatchScoreResult) -> some View {
        HStack(spacing: 3) {
            if let intensity = result.intensityPoints {
                breakdownSegment(fraction: CGFloat(intensity) / 100, color: Theme.Colors.accent)
            }
            if let distance = result.distancePoints {
                breakdownSegment(fraction: CGFloat(distance) / 100, color: Theme.Colors.accentBright)
            }
            if let speed = result.speedPoints {
                breakdownSegment(fraction: CGFloat(speed) / 100, color: Color(red: 1, green: 0.85, blue: 0.35))
            }
            if let sprints = result.sprintPoints {
                breakdownSegment(fraction: CGFloat(sprints) / 100, color: Color(red: 0.45, green: 0.85, blue: 1))
            }
        }
        .frame(height: 4)
        .frame(maxWidth: 120)
    }

    private func breakdownSegment(fraction: CGFloat, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color.opacity(0.85))
            .frame(width: max(4, 28 * fraction))
    }

    private func statsGrid(summary: WorkoutSummary) -> some View {
        let tiles = statTiles(for: summary)

        return VStack(alignment: .leading, spacing: 6) {
            Text("MATCH STATS")
                .font(Theme.Typography.statLabel(size: 9))
                .foregroundStyle(Theme.Colors.textSecondary)
                .tracking(1)

            if tiles.isEmpty {
                Text("—")
                    .font(Theme.Typography.metric(size: 18))
                    .foregroundStyle(Theme.Colors.textSecondary)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 5),
                        GridItem(.flexible(), spacing: 5),
                    ],
                    spacing: 5
                ) {
                    ForEach(Array(tiles.enumerated()), id: \.offset) { _, tile in
                        SummaryStatTile(label: tile.label, value: tile.value, icon: tile.icon)
                    }
                }
            }
        }
    }

    private struct StatTile: Equatable {
        let label: String
        let value: String
        let icon: String
    }

    private func statTiles(for summary: WorkoutSummary) -> [StatTile] {
        var tiles: [StatTile] = [
            StatTile(label: "TIME", value: summary.durationText, icon: "clock.fill"),
        ]

        if summary.distanceM > 0 {
            tiles.append(StatTile(label: "DIST", value: formatDistance(summary.distanceM), icon: "figure.run"))
        }
        if let hr = summary.hrAvg {
            tiles.append(StatTile(label: "AVG HR", value: "\(hr)", icon: "heart.fill"))
        }
        if let maxHr = summary.hrMax {
            tiles.append(StatTile(label: "MAX HR", value: "\(maxHr)", icon: "heart.circle.fill"))
        }
        if summary.sprints > 0 {
            tiles.append(StatTile(label: "SPRINTS", value: "\(summary.sprints)", icon: "hare.fill"))
        }
        if let speed = summary.speedMaxKmh, speed > 0 {
            tiles.append(StatTile(label: "TOP SPD", value: String(format: "%.1f", speed), icon: "speedometer"))
        }
        if let intensity = summary.intensity {
            tiles.append(StatTile(label: "INT", value: String(format: "%.0f", intensity), icon: "flame.fill"))
        }

        return tiles
    }

    private var doneButton: some View {
        Button {
            manager.reset()
        } label: {
            Text("DONE")
                .font(Theme.Typography.button(size: 12))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .background(Theme.Colors.accent)
        .clipShape(Capsule())
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.2f", meters / 1000)
        }
        return String(format: "%.0f", meters)
    }
}

private struct SummaryStatTile: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.Colors.accent.opacity(0.9))

            Text(value)
                .font(Theme.Typography.metric(size: 17))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(label)
                .font(Theme.Typography.statLabel(size: 8))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        }
    }
}
