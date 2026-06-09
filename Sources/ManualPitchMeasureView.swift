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
    // "Walk two points": A = own goal-line center, B = rival goal-line center.
    @State private var walkA: (lat: Double, lon: Double)?
    @State private var walkB: (lat: Double, lon: Double)?
    @State private var walkCenter: (lat: Double, lon: Double)?

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

                walkSection

                Button {
                    _ = CourtStore.shared.saveMeasuredCourt(
                        name: defaultName,
                        lengthM: Double(lengthM),
                        widthM: Double(widthM),
                        latitude: walkCenter?.lat ?? location.latitude ?? CourtLocationService.sharedLastLatitude,
                        longitude: walkCenter?.lon ?? location.longitude ?? CourtLocationService.sharedLastLongitude,
                        headingDeg: capturedHeading,
                        measurementMethod: walkCenter != nil ? "walk" : "manual",
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
            location.startTracking()
        }
        .onDisappear {
            location.stopHeading()
            location.stopTracking()
        }
    }

    /// Walk-two-points: mark A (your goal line), walk, mark B (rival goal line).
    /// Derives length, orientation and center automatically.
    @ViewBuilder
    private var walkSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("OR WALK IT")
                .font(Theme.Typography.statLabel(size: 9))
                .foregroundStyle(Theme.Colors.textSecondary)
            Text("Sets size + orientation. Stand on your goal line for A, the rival goal line for B.")
                .font(Theme.Typography.caption(size: 11))
                .foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 5) {
                walkButton(walkA == nil ? "Mark A" : "A ✓") {
                    if let lat = location.latitude, let lon = location.longitude {
                        walkA = (lat, lon); applyWalkIfComplete()
                    }
                }
                walkButton(walkB == nil ? "Mark B" : "B ✓") {
                    if let lat = location.latitude, let lon = location.longitude {
                        walkB = (lat, lon); applyWalkIfComplete()
                    }
                }
                .disabled(walkA == nil)
            }
            if walkCenter != nil, let heading = capturedHeading {
                Text(String(format: "✓ %d × %d m · %.0f°", lengthM, widthM, heading))
                    .font(Theme.Typography.caption(size: 11))
                    .foregroundStyle(Theme.Colors.accent)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func walkButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Typography.button(size: 12))
                .foregroundStyle(Theme.Colors.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Capsule().stroke(Theme.Colors.accent, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func applyWalkIfComplete() {
        guard let a = walkA, let b = walkB else { return }
        let length = Self.distanceM(lat1: a.lat, lon1: a.lon, lat2: b.lat, lon2: b.lon)
        guard length > 0 else { return }
        lengthM = Int(length.rounded())
        capturedHeading = Self.bearingDeg(lat1: a.lat, lon1: a.lon, lat2: b.lat, lon2: b.lon)
        walkCenter = ((a.lat + b.lat) / 2, (a.lon + b.lon) / 2)
    }

    /// Great-circle distance in meters (haversine).
    private static func distanceM(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let r = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let aa = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        return r * 2 * atan2(sqrt(aa), sqrt(1 - aa))
    }

    /// Initial bearing A→B in degrees from true north (0…360).
    private static func bearingDeg(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let p1 = lat1 * .pi / 180
        let p2 = lat2 * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let y = sin(dLon) * cos(p2)
        let x = cos(p1) * sin(p2) - sin(p1) * cos(p2) * cos(dLon)
        let deg = atan2(y, x) * 180 / .pi
        return (deg + 360).truncatingRemainder(dividingBy: 360)
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
                 ? "If you typed the size, point toward the rival goal and fix the direction."
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
