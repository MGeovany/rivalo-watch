import SwiftUI

/// GPS walk measurement of pitch length and width on the watch.
/// Guides the user corner-to-corner with live distance feedback.
struct WalkPitchMeasureView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var measure = PitchWalkMeasureService()
    var matchType: String?
    var surface: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                phaseInstructions

                if measure.gpsAccuracy < .infinity {
                    gpsAccuracyRow
                }

                if isMeasuring {
                    Text(String(format: "%.1f m", measure.liveMeters))
                        .font(Theme.Typography.metric(size: 30))
                        .foregroundStyle(Theme.Colors.accent)
                        .monospacedDigit()
                }

                if let status = measure.status {
                    Text(status)
                        .font(Theme.Typography.caption(size: 10))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                phaseButtons

                if case let .finished(lengthM, widthM) = measure.phase {
                    finishedSection(lengthM: lengthM, widthM: widthM)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.medium)
        }
        .navigationTitle("Run pitch")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isMeasuring: Bool {
        measure.phase == .measuringLength || measure.phase == .measuringWidth
    }

    // MARK: - Phase instructions

    @ViewBuilder
    private var phaseInstructions: some View {
        switch measure.phase {
        case .readyLength:
            VStack(alignment: .leading, spacing: 6) {
                stepRow("1", "Stand at one corner of the goal line")
                stepRow("2", "Tap Start, then walk straight to the opposite goal line corner")
            }
        case .measuringLength:
            EmptyView()
        case .readyWidth:
            VStack(alignment: .leading, spacing: 6) {
                stepRow("3", "Now stand at a corner of the touchline")
                stepRow("4", "Tap Start, then walk along the side to the far corner")
            }
        case .measuringWidth, .finished:
            EmptyView()
        }
    }

    private var gpsAccuracyRow: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(gpsColor)
                .frame(width: 7, height: 7)
            Text(gpsLabel)
                .font(Theme.Typography.caption(size: 10))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    private var gpsColor: Color {
        let acc = measure.gpsAccuracy
        if acc < 10 { return .green }
        if acc < 25 { return Theme.Colors.accent }
        return .orange
    }

    private var gpsLabel: String {
        let acc = measure.gpsAccuracy
        if acc == .infinity { return "Acquiring GPS…" }
        if acc < 10 { return "GPS ready" }
        if acc < 25 { return String(format: "GPS ±%.0f m", acc) }
        return String(format: "GPS weak ±%.0f m — wait", acc)
    }

    // MARK: - Phase buttons

    @ViewBuilder
    private var phaseButtons: some View {
        switch measure.phase {
        case .readyLength:
            primaryButton("Start length") { measure.startLength() }
        case .measuringLength:
            primaryButton("Done — length") { measure.finishLength() }
        case .readyWidth:
            primaryButton("Start width") { measure.startWidth() }
        case .measuringWidth:
            primaryButton("Done — width") { measure.finishWidth() }
        case .finished:
            EmptyView()
        }
    }

    // MARK: - Finished

    private func finishedSection(lengthM: Double, widthM: Double) -> some View {
        let name = CourtDefaultName.make()
        return VStack(alignment: .leading, spacing: 8) {
            Text(String(format: "%.0f × %.0f m", lengthM, widthM))
                .font(Theme.Typography.metric(size: 22))
                .foregroundStyle(Theme.Colors.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("NAME")
                    .font(Theme.Typography.statLabel(size: 9))
                    .foregroundStyle(Theme.Colors.textSecondary)
                Text(name)
                    .font(Theme.Typography.caption(size: 11))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(2)
            }

            Text("Rename later on iPhone")
                .font(Theme.Typography.caption(size: 10))
                .foregroundStyle(Theme.Colors.textSecondary)

            primaryButton("Save court") {
                _ = CourtStore.shared.saveMeasuredCourt(
                    name: name,
                    lengthM: lengthM,
                    widthM: widthM,
                    latitude: CourtLocationService.sharedLastLatitude,
                    longitude: CourtLocationService.sharedLastLongitude,
                    matchType: matchType,
                    surface: surface
                )
                dismiss()
            }
        }
    }

    // MARK: - Helpers

    private func stepRow(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(Theme.Typography.statLabel(size: 11))
                .foregroundStyle(.black)
                .frame(width: 20, height: 20)
                .background(Theme.Colors.accent)
                .clipShape(Circle())
            Text(text)
                .font(Theme.Typography.caption(size: 11))
                .foregroundStyle(Theme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Typography.button(size: 14))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Capsule().fill(Theme.Colors.accent))
        }
        .buttonStyle(.plain)
    }
}
