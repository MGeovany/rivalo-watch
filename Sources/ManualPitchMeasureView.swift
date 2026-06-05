import SwiftUI

/// Enter length and width on the watch (saved with a default date/time name).
struct ManualPitchMeasureView: View {
    @Environment(\.dismiss) private var dismiss

    let matchType: String?
    let surface: String?

    @State private var lengthM = 105
    @State private var widthM = 68

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

                Button {
                    _ = CourtStore.shared.saveMeasuredCourt(
                        name: defaultName,
                        lengthM: Double(lengthM),
                        widthM: Double(widthM),
                        latitude: CourtLocationService.sharedLastLatitude,
                        longitude: CourtLocationService.sharedLastLongitude,
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
