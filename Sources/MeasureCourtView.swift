import SwiftUI

/// choose how to measure a court (walk or manual on Apple Watch).
struct MeasureCourtView: View {
    var matchType: String?
    var surface: String?

    @State private var walkMeasureActive = false
    @State private var manualMeasureActive = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                Text("Save size to compare sessions here.")
                    .font(Theme.Typography.caption(size: 11))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(PitchMeasurementMethod.allCases) { method in
                    WatchMeasureMethodCard(method: method) {
                        select(method)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.medium)
            .padding(.vertical, Theme.Spacing.small)
        }
        .navigationTitle("Measure court")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $walkMeasureActive) {
            WalkPitchMeasureView(matchType: matchType, surface: surface)
        }
        .navigationDestination(isPresented: $manualMeasureActive) {
            ManualPitchMeasureView(matchType: matchType, surface: surface)
        }
    }

    private func select(_ method: PitchMeasurementMethod) {
        switch method {
        case .walk:
            walkMeasureActive = true
        case .manual:
            manualMeasureActive = true
        }
    }
}

// MARK: - Card

private struct WatchMeasureMethodCard: View {
    let method: PitchMeasurementMethod
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: method.systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Colors.accent)
                        .frame(width: 24, height: 24)

                    Text(method.watchTitle)
                        .font(Theme.Typography.body(size: 14))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text(method.watchSubtitle)
                    .font(Theme.Typography.caption(size: 10))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                WatchDeviceTagsRow(tags: method.watchDeviceTags)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct WatchDeviceTagsRow: View {
    let tags: [String]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(Theme.Typography.statLabel(size: 9))
                    .foregroundStyle(Theme.Colors.accent)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Theme.Colors.accent.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
    }
}
