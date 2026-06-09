import SwiftUI

/// Enter length and width on the watch (saved with a default date/time name).
struct ManualPitchMeasureView: View {
    @Environment(\.dismiss) private var dismiss

    let matchType: String?
    let surface: String?

    @State private var lengthM = 105
    @State private var widthM = 68
    @StateObject private var location = CourtLocationService()
    /// Captured pitch orientation (own goal -> rival goal). nil until the user fixes it.
    @State private var capturedHeading: Double?

    private let defaultName = CourtDefaultName.make()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                Text("Type pitch size in meters. Rename the court later on iPhone.")
                    .font(Theme.Typography.caption(size: 11))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("NAME")
                        .font(Theme.Typography.statLabel(size: 9))
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text(defaultName)
                        .font(Theme.Typography.body(size: 13))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                dimensionStepper(label: "Length", value: $lengthM, range: 15...150)
                dimensionStepper(label: "Width", value: $widthM, range: 10...100)

                Text(String(format: "%.0f × %.0f m", Double(lengthM), Double(widthM)))
                    .font(Theme.Typography.metric(size: 22))
                    .foregroundStyle(Theme.Colors.accent)
                    .frame(maxWidth: .infinity)

                orientationSection

                Button {
                    _ = CourtStore.shared.saveMeasuredCourt(
                        name: defaultName,
                        lengthM: Double(lengthM),
                        widthM: Double(widthM),
                        latitude: location.latitude ?? CourtLocationService.sharedLastLatitude,
                        longitude: location.longitude ?? CourtLocationService.sharedLastLongitude,
                        headingDeg: capturedHeading,
                        measurementMethod: "manual",
                        matchType: matchType,
                        surface: surface
                    )
                    dismiss()
                } label: {
                    Text("Save court")
                        .font(Theme.Typography.button(size: 14))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Theme.Colors.accent))
                }
                .buttonStyle(.plain)
            }
            .padding(Theme.Spacing.medium)
        }
        .navigationTitle("Manual")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            location.requestLocation()
            location.startHeading()
        }
        .onDisappear { location.stopHeading() }
    }

    /// Capture the pitch orientation: the user points toward the rival goal and
    /// fixes the current compass heading. Optional — heatmaps fall back to
    /// movement spread when it's not set.
    @ViewBuilder
    private var orientationSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ORIENTATION")
                .font(Theme.Typography.statLabel(size: 9))
                .foregroundStyle(Theme.Colors.textSecondary)
            Text(capturedHeading == nil
                 ? "Point toward the rival goal, then fix."
                 : String(format: "Fixed at %.0f°", capturedHeading!))
                .font(Theme.Typography.caption(size: 11))
                .foregroundStyle(capturedHeading == nil ? Theme.Colors.textSecondary : Theme.Colors.accent)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                capturedHeading = location.headingDeg
            } label: {
                Text(capturedHeading == nil ? "Fix orientation" : "Re-fix")
                    .font(Theme.Typography.button(size: 12))
                    .foregroundStyle(Theme.Colors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Capsule().stroke(Theme.Colors.accent, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(location.headingDeg == nil)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func dimensionStepper(label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(label)
                .font(Theme.Typography.body(size: 14))
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            Button {
                value.wrappedValue = max(range.lowerBound, value.wrappedValue - 1)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 12, weight: .bold))
            }
            .buttonStyle(.plain)
            .frame(width: 28, height: 28)
            .background(Theme.Colors.surface)
            .clipShape(Circle())

            Text("\(value.wrappedValue) m")
                .font(Theme.Typography.metric(size: 18))
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(minWidth: 52)

            Button {
                value.wrappedValue = min(range.upperBound, value.wrappedValue + 1)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
            }
            .buttonStyle(.plain)
            .frame(width: 28, height: 28)
            .background(Theme.Colors.surface)
            .clipShape(Circle())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Theme.Colors.surface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
