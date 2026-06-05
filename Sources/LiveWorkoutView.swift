import SwiftUI

/// Live match: clock, metrics, and half-based controls (quick / structured).
struct LiveWorkoutView: View {
    @ObservedObject var manager: WorkoutManager
    @State private var showRestartConfirm = false

    private var isCompactLayout: Bool {
        manager.usesHalfFlow && manager.matchSegment == .secondHalf
    }

    var body: some View {
        Group {
            if manager.isHalftime, let snapshot = manager.halftimeSnapshot {
                HalftimeView(manager: manager, snapshot: snapshot)
            } else {
                activePlayView
            }
        }
        .confirmationDialog(
            "Restart 1st half?",
            isPresented: $showRestartConfirm,
            titleVisibility: .visible
        ) {
            Button("Restart", role: .destructive) {
                manager.restartFirstHalf()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "You cannot resume the 2nd half. Second-half metrics will be lost."
            )
        }
    }

    private var activePlayView: some View {
        VStack(spacing: 0) {
            VStack(spacing: isCompactLayout ? 4 : 6) {
                scrollableContent
            }
            .padding(.horizontal, Theme.Spacing.medium)
            .padding(.top, 2)
            .frame(maxWidth: .infinity, alignment: .top)

            Spacer(minLength: 12)

            liveControls
                .padding(.horizontal, Theme.Spacing.medium)
                .padding(.bottom, 6)
        }
    }

    @ViewBuilder
    private var scrollableContent: some View {
        if let error = manager.errorMessage {
            Text(error)
                .font(Theme.Typography.caption(size: 9))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.Colors.accent)
        }

        segmentHeader

        Text(clockText)
            .font(Theme.Typography.metric(size: isCompactLayout ? 26 : 28))
            .foregroundStyle(Theme.Colors.accent)
            .monospacedDigit()
            .minimumScaleFactor(0.75)
            .lineLimit(1)

        HStack(spacing: Theme.Spacing.medium) {
            metric(value: heartRateText, label: "BPM", compact: isCompactLayout)
            metric(value: distanceText, label: "KM", compact: isCompactLayout)
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var liveControls: some View {
        if manager.usesHalfFlow {
            halfFlowControls
        } else {
            matchButton("Finish", style: .primary, compact: false) {
                Task { await manager.end() }
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var segmentHeader: some View {
        if manager.usesHalfFlow {
            switch manager.matchSegment {
            case .firstHalf:
                Text("1ST HALF")
                    .font(Theme.Typography.statLabel(size: 10))
                    .foregroundStyle(Theme.Colors.textSecondary)
            case .halftimeBreak:
                EmptyView()
            case .secondHalf:
                Text("2ND HALF")
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
            VStack(spacing: 4) {
                matchButton("End 1st half", style: .primary, compact: false) {
                    manager.finishFirstHalf()
                }
                .accessibilityLabel("End first half")

                HStack(spacing: 5) {
                    matchButton(manager.phase == .paused ? "Resume" : "Pause", style: .secondary, compact: true) {
                        if manager.phase == .paused { manager.resume() } else { manager.pause() }
                    }
                    matchButton("End match", style: .secondary, compact: true) {
                        Task { await manager.end() }
                    }
                }
            }

        case .halftimeBreak:
            EmptyView()

        case .secondHalf:
            VStack(spacing: 4) {
                HStack(spacing: 5) {
                    matchButton("Finish", style: .primary, compact: true) {
                        Task { await manager.end() }
                    }
                    .accessibilityLabel("Finish match")

                    matchButton("Restart", style: .secondary, compact: true) {
                        showRestartConfirm = true
                    }
                    .accessibilityLabel("Restart first half")
                }

                matchButton(manager.phase == .paused ? "Resume" : "Pause", style: .secondary, compact: false) {
                    if manager.phase == .paused { manager.resume() } else { manager.pause() }
                }
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
        VStack(spacing: 2) {
            Text(value)
                .font(Theme.Typography.metric(size: compact ? 17 : 19))
            Text(label)
                .font(Theme.Typography.statLabel(size: 10))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
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
