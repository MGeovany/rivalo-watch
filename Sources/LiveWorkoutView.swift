import SwiftUI

/// Live match: clock, metrics, and half-based controls (quick / structured).
struct LiveWorkoutView: View {
    @ObservedObject var manager: WorkoutManager
    @State private var showRestartConfirm = false

    private var isCompactLayout: Bool {
        manager.usesHalfFlow && manager.matchSegment == .secondHalf
    }

    var body: some View {
        VStack(spacing: isCompactLayout ? 4 : Theme.Spacing.small) {
            if let error = manager.errorMessage {
                Text(error)
                    .font(Theme.Typography.caption(size: 9))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Colors.accent)
            }

            segmentHeader

            Text(clockText)
                .font(Theme.Typography.metric(size: isCompactLayout ? 26 : (manager.isHalftime ? 28 : 30)))
                .foregroundStyle(Theme.Colors.accent)
                .monospacedDigit()
                .minimumScaleFactor(0.75)
                .lineLimit(1)

            if manager.isHalftime {
                Text("Juego pausado")
                    .font(Theme.Typography.caption(size: 9))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            if manager.isHalftime, let half = manager.firstHalfStats {
                halftimeMetrics(half)
            } else {
                HStack(spacing: Theme.Spacing.medium) {
                    metric(value: heartRateText, label: "BPM", compact: isCompactLayout)
                    metric(value: distanceText, label: "KM", compact: isCompactLayout)
                }
            }

            if manager.usesHalfFlow {
                halfFlowControls
            } else {
                matchButton("Finalizar", style: .primary, compact: false) {
                    Task { await manager.end() }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.medium)
        .padding(.vertical, 6)
        .confirmationDialog(
            "¿Reiniciar 1.er tiempo?",
            isPresented: $showRestartConfirm,
            titleVisibility: .visible
        ) {
            Button("Reiniciar", role: .destructive) {
                manager.restartFirstHalf()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(
                "No podrás reanudar el 2.º tiempo. Se perderán las métricas del segundo tiempo."
            )
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var segmentHeader: some View {
        if manager.usesHalfFlow {
            switch manager.matchSegment {
            case .firstHalf:
                Text("1.er TIEMPO")
                    .font(Theme.Typography.statLabel(size: 10))
                    .foregroundStyle(Theme.Colors.textSecondary)
            case .halftimeBreak:
                Text("DESCANSO")
                    .font(Theme.Typography.statLabel(size: 11))
                    .foregroundStyle(Theme.Colors.accent)
            case .secondHalf:
                Text("2.º TIEMPO")
                    .font(Theme.Typography.statLabel(size: 10))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }

    // MARK: - Controls

    @ViewBuilder
    private var halfFlowControls: some View {
        switch manager.matchSegment {
        case .firstHalf:
            matchButton("Fin 1.er tiempo", style: .primary, compact: false) {
                manager.finishFirstHalf()
            }
            .accessibilityLabel("Finalizar primer tiempo")

        case .halftimeBreak:
            matchButton("2.º tiempo", style: .primary, compact: false) {
                manager.startSecondHalf()
            }
            .accessibilityLabel("Iniciar segundo tiempo")

        case .secondHalf:
            HStack(spacing: 5) {
                matchButton("Finalizar", style: .primary, compact: true) {
                    Task { await manager.end() }
                }
                .accessibilityLabel("Finalizar partido")

                matchButton("Reiniciar", style: .secondary, compact: true) {
                    showRestartConfirm = true
                }
                .accessibilityLabel("Reiniciar primer tiempo")
            }
        }
    }

    // MARK: - Components

    private enum MatchButtonStyle {
        case primary
        case secondary
    }

    private func matchButton(
        _ title: String,
        style: MatchButtonStyle,
        compact: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Typography.button(size: compact ? 11 : 12))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(style == .primary ? Color.black : Theme.Colors.accent)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, compact ? 4 : 8)
                .padding(.vertical, compact ? 7 : 9)
        }
        .buttonStyle(.plain)
        .background(style == .primary ? Theme.Colors.accent : Theme.Colors.surface)
        .clipShape(Capsule())
    }

    private func metric(value: String, label: String, compact: Bool) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(Theme.Typography.metric(size: compact ? 17 : 19))
            Text(label)
                .font(Theme.Typography.statLabel(size: 10))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func halftimeMetrics(_ half: FirstHalfStats) -> some View {
        VStack(spacing: 3) {
            Text("1.er tiempo")
                .font(Theme.Typography.statLabel(size: 9))
                .foregroundStyle(Theme.Colors.textSecondary)

            HStack(spacing: 4) {
                metric(value: formatDuration(half.durationS), label: "TIEMPO", compact: true)
                metric(value: formatDistanceKm(half.distanceM), label: "KM", compact: true)
            }
            HStack(spacing: 4) {
                metric(
                    value: half.averageHeartRate.map { "\($0)" } ?? "--",
                    label: "MEDIA",
                    compact: true
                )
                metric(value: "\(half.activeKcal)", label: "KCAL", compact: true)
            }

            HStack(spacing: 4) {
                Text("Ahora")
                    .font(Theme.Typography.statLabel(size: 9))
                    .foregroundStyle(Theme.Colors.textSecondary)
                Text(heartRateText)
                    .font(Theme.Typography.metric(size: 15))
                Text("BPM")
                    .font(Theme.Typography.statLabel(size: 9))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func formatDistanceKm(_ meters: Double) -> String {
        String(format: "%.2f", meters / 1000)
    }

    private var clockText: String {
        let total = manager.primaryClockSeconds
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var heartRateText: String {
        manager.heartRate > 0 ? "\(Int(manager.heartRate))" : "--"
    }

    private var distanceText: String {
        String(format: "%.2f", manager.distanceM / 1000)
    }
}
