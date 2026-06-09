import SwiftUI

/// Halftime: main stats, swipe for comparison and intensity chart.
struct HalftimeView: View {
    @ObservedObject var manager: WorkoutManager
    let snapshot: HalftimeSnapshot
    @ObservedObject private var averages = UserMatchAveragesStore.shared

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                mainPage
                comparisonPage
                intensityChartPage
            }
            .tabViewStyle(.carousel)

            startSecondHalfButton
                .padding(.horizontal, Theme.Spacing.medium)
                .padding(.top, 4)
                .padding(.bottom, 6)
        }
    }

    // MARK: - Pages

    private var mainPage: some View {
        ScrollView {
            VStack(spacing: 6) {
                Text("DESCANSO")
                    .font(Theme.Typography.statLabel(size: 10))
                    .foregroundStyle(Theme.Colors.accent)
                    .tracking(1.2)

                Text(breakClockText)
                    .font(Theme.Typography.metric(size: 34))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .monospacedDigit()

                VStack(spacing: 8) {
                    if snapshot.distanceM > 0 {
                        statRow(
                            value: formatDistance(snapshot.distanceM),
                            label: "DISTANCIA"
                        )
                    }
                    if snapshot.sprints > 0 {
                        statRow(value: "\(snapshot.sprints)", label: "SPRINTS")
                    }
                    if let speed = snapshot.topSpeedKmh, speed > 0 {
                        statRow(value: String(format: "%.1f", speed), label: "VEL MÁX km/h")
                    }
                    if let intensity = snapshot.intensity {
                        intensityRow(score: intensity)
                    }
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, Theme.Spacing.medium)
        }
    }

    private var comparisonPage: some View {
        VStack(alignment: .leading, spacing: 10) {
                Text("VS PROM")
                .font(Theme.Typography.statLabel(size: 10))
                .foregroundStyle(Theme.Colors.textSecondary)
                .tracking(1)

            if hasComparisonContent {
                if let avg = averages.halftime.avgDistanceM, avg > 0 {
                    comparisonRow(
                        label: "DIST",
                        currentText: formatDistance(snapshot.distanceM),
                        delta: HalftimeAnalytics.comparisonDelta(current: snapshot.distanceM, average: avg)
                    )
                }
                if snapshot.sprints > 0, let avg = averages.halftime.avgSprints, avg > 0 {
                    comparisonRow(
                        label: "SPR",
                        currentText: "\(snapshot.sprints)",
                        delta: HalftimeAnalytics.comparisonDelta(current: Double(snapshot.sprints), average: avg)
                    )
                }
                if let speed = snapshot.topSpeedKmh, speed > 0,
                   let avg = averages.halftime.avgTopSpeedKmh, avg > 0 {
                    comparisonRow(
                        label: "SPD",
                        currentText: String(format: "%.1f", speed),
                        delta: HalftimeAnalytics.comparisonDelta(current: speed, average: avg)
                    )
                }
            } else {
                Text("Juega más partidos")
                    .font(Theme.Typography.caption(size: 11))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, Theme.Spacing.medium)
        .padding(.top, 8)
    }

    private var intensityChartPage: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("INT / MIN")
                .font(Theme.Typography.statLabel(size: 10))
                .foregroundStyle(Theme.Colors.textSecondary)
                .tracking(1)

            if snapshot.intensityByMinute.isEmpty {
                Text("—")
                    .font(Theme.Typography.metric(size: 22))
                    .foregroundStyle(Theme.Colors.textSecondary)
            } else {
                HalftimeIntensityChart(values: snapshot.intensityByMinute)
                    .frame(height: 56)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, Theme.Spacing.medium)
        .padding(.top, 8)
    }

    // MARK: - Components

    private var startSecondHalfButton: some View {
        Button {
            manager.startSecondHalf()
        } label: {
            Text("INICIAR 2DO TIEMPO")
                .font(Theme.Typography.button(size: 11))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .background(Theme.Colors.accent)
        .clipShape(Capsule())
        .accessibilityLabel("Iniciar segundo tiempo")
    }

    private func statRow(value: String, label: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(value)
                .font(Theme.Typography.metric(size: 22))
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer(minLength: 8)
            Text(label)
                .font(Theme.Typography.statLabel(size: 9))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    private func intensityRow(score: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("\(score)")
                .font(Theme.Typography.metric(size: 22))
                .foregroundStyle(Theme.Colors.accent)
            Spacer(minLength: 8)
            Text("INTENSIDAD")
                .font(Theme.Typography.statLabel(size: 9))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    private func comparisonRow(
        label: String,
        currentText: String,
        delta: Double?
    ) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(Theme.Typography.statLabel(size: 9))
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: 28, alignment: .leading)

            Text(currentText)
                .font(Theme.Typography.metric(size: 18))
                .foregroundStyle(Theme.Colors.textPrimary)

            if let delta {
                Text(deltaText(delta))
                    .font(Theme.Typography.statLabel(size: 10))
                    .foregroundStyle(delta >= 0 ? Theme.Colors.accent : Theme.Colors.textSecondary)
            }

            Spacer(minLength: 0)
        }
    }

    private var hasComparisonContent: Bool {
        averages.halftime.avgDistanceM != nil
            || averages.halftime.avgSprints != nil
            || averages.halftime.avgTopSpeedKmh != nil
    }

    private var breakClockText: String {
        let total = manager.primaryClockSeconds
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.2f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
    }

    private func deltaText(_ percent: Double) -> String {
        let sign = percent >= 0 ? "+" : ""
        return "\(sign)\(Int(percent.rounded()))%"
    }
}

// MARK: - Chart

private struct HalftimeIntensityChart: View {
    let values: [Int]

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(value))
                    .frame(maxWidth: .infinity)
                    .frame(height: barHeight(value))
            }
        }
    }

    private func barHeight(_ value: Int) -> CGFloat {
        let normalized = CGFloat(value) / 100
        return max(4, normalized * 52)
    }

    private func barColor(_ value: Int) -> Color {
        if value >= 75 { return Theme.Colors.accent }
        if value >= 50 { return Theme.Colors.accent.opacity(0.55) }
        return Theme.Colors.surface
    }
}
