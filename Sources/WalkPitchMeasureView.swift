import SwiftUI

/// GPS walk/run measurement of pitch length and width on the watch.
struct WalkPitchMeasureView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var measure = PitchWalkMeasureService()
    @State private var courtName = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                Text("Run length, then width.")
                    .font(Theme.Typography.caption(size: 11))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let status = measure.status {
                    Text(status)
                        .font(Theme.Typography.caption(size: 10))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if isMeasuring {
                    Text(String(format: "%.0f m", measure.liveMeters))
                        .font(Theme.Typography.metric(size: 32))
                        .foregroundStyle(Theme.Colors.accent)
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

    private func finishedSection(lengthM: Double, widthM: Double) -> some View {
        VStack(spacing: 8) {
            TextField("Court name", text: $courtName)
                .font(Theme.Typography.body(size: 13))

            primaryButton("Save court") {
                let name = courtName.trimmingCharacters(in: .whitespacesAndNewlines)
                CourtStore.shared.saveMeasuredCourt(
                    name: name.isEmpty ? "My court" : name,
                    lengthM: lengthM,
                    widthM: widthM,
                    latitude: CourtLocationService.sharedLastLatitude,
                    longitude: CourtLocationService.sharedLastLongitude
                )
                dismiss()
            }
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
