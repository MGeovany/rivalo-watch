import SwiftUI

/// Pre-match setup: start first, optional mode / format / surface / court.
struct StartView: View {
    @ObservedObject var manager: WorkoutManager
    @StateObject private var courts = CourtStore.shared
    @StateObject private var location = CourtLocationService()

    @State private var setup = MatchSetup.default
    @State private var selectedMode: MatchModeOption = .quick
    @State private var selectedFormat: FootballFormatOption = .eleven
    @State private var selectedSurface: SurfaceOption = .turf
    @State private var selectedCourtId: String?
    @State private var showMeasureCourt = false

    var body: some View {
        NavigationStack {
            startScroll
                .navigationDestination(isPresented: $showMeasureCourt) {
                    MeasureCourtView(
                        matchType: selectedFormat.rawValue,
                        surface: selectedSurface.rawValue
                    )
                }
        }
        .onAppear {
            restoreLastSetup()
        }
    }

    private func restoreLastSetup() {
        guard let last = LastSetupStore.load() else { return }
        selectedMode = MatchModeOption(rawValue: last.mode) ?? .quick
        selectedFormat = FootballFormatOption(rawValue: last.matchType) ?? .eleven
        selectedSurface = SurfaceOption(rawValue: last.surface) ?? .turf
        selectedCourtId = last.pitchId
    }

    private var startScroll: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.medium) {
                if let error = manager.errorMessage {
                    Text(error)
                        .font(Theme.Typography.caption())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.Colors.accent)
                }

                startButton
                courtMeasureArea

                modeSection
                formatSection
                surfaceSection
                courtSection
            }
            .padding(.horizontal, Theme.Spacing.medium)
            .padding(.vertical, Theme.Spacing.small)
        }
        .onAppear {
            location.requestLocation()
            courts.refreshNearby(latitude: location.latitude, longitude: location.longitude)
        }
        .onChange(of: location.latitude) { _, _ in
            courts.refreshNearby(latitude: location.latitude, longitude: location.longitude)
        }
    }

    // MARK: - Start (top)

    private var startButton: some View {
        Button {
            Task { await manager.start(setup: buildSetup()) }
        } label: {
            Text(manager.isStarting ? "Starting…" : "Start match")
                .font(Theme.Typography.button(size: 16))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Theme.Colors.accentBright, Theme.Colors.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
        }
        .buttonStyle(.plain)
        .disabled(manager.isStarting)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var courtMeasureArea: some View {
        if let court = displayCourt, court.hasDimensions {
            courtDimensionsCard(court)
        } else {
            measureCourtButton
        }
    }

    private var displayCourt: SavedCourt? {
        if let id = selectedCourtId {
            return courts.nearbyCourts.first { $0.id == id }
        }
        return courts.nearbyCourts.first { court in
            court.hasDimensions && (court.distanceM ?? .infinity) < 200
        }
    }

    private func courtDimensionsCard(_ court: SavedCourt) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(court.name)
                .font(Theme.Typography.body(size: 14))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
            if let dimensions = court.dimensionsText {
                Text(dimensions)
                    .font(Theme.Typography.metric(size: 22))
                    .foregroundStyle(Theme.Colors.accent)
            }
            if let meters = court.distanceM, meters < 200 {
                Text(String(format: "%.0f m away", meters))
                    .font(Theme.Typography.caption(size: 10))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Theme.Colors.accent.opacity(0.35), lineWidth: 1)
        }
        .onTapGesture {
            selectedCourtId = court.id
        }
    }

    private var measureCourtButton: some View {
        Button {
            showMeasureCourt = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "ruler")
                    .font(.system(size: 14, weight: .semibold))
                Text("Measure court")
                    .font(Theme.Typography.button(size: 15))
            }
            .foregroundStyle(Theme.Colors.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [Theme.Colors.accentBright.opacity(0.8), Theme.Colors.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sections

    private var modeSection: some View {
        WatchSetupSection(title: "Mode") {
            VStack(spacing: 6) {
                ForEach(MatchModeOption.allCases) { option in
                    WatchSetupChip(
                        title: option.label,
                        isSelected: selectedMode == option
                    ) {
                        selectedMode = option
                    }
                }
            }
        }
    }

    private var formatSection: some View {
        WatchSetupSection(title: "Football") {
            WatchFootballFormatGrid(selection: $selectedFormat)
        }
    }

    private var surfaceSection: some View {
        WatchSetupSection(title: "Surface") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(SurfaceOption.allCases) { option in
                        WatchSetupChip(
                            title: option.shortLabel,
                            isSelected: selectedSurface == option,
                            compact: true
                        ) {
                            selectedSurface = option
                        }
                    }
                }
            }
        }
    }

    private var courtSection: some View {
        WatchSetupSection(title: "Court") {
            VStack(alignment: .leading, spacing: 6) {
                if let status = location.status {
                    Text(status)
                        .font(Theme.Typography.caption(size: 11))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                WatchSetupChip(
                    title: "No court",
                    subtitle: "Set later on iPhone",
                    isSelected: selectedCourtId == nil
                ) {
                    selectedCourtId = nil
                }

                ForEach(courts.nearbyCourts.prefix(4)) { court in
                    WatchSetupChip(
                        title: court.name,
                        subtitle: courtSubtitle(court),
                        isSelected: selectedCourtId == court.id
                    ) {
                        selectedCourtId = court.id
                    }
                }
            }
        }
    }

    private func courtSubtitle(_ court: SavedCourt) -> String? {
        if let dimensions = court.dimensionsText {
            return dimensions
        }
        if let meters = court.distanceM {
            if meters < 200 {
                return String(format: "%.0f m away", meters)
            }
            return String(format: "%.1f km", meters / 1000)
        }
        if court.playCount > 0 {
            return "\(court.playCount) matches here"
        }
        return nil
    }

    private func buildSetup() -> MatchSetup {
        let court = courts.nearbyCourts.first { $0.id == selectedCourtId }
        let setup = MatchSetup(
            mode: selectedMode.rawValue,
            matchType: selectedFormat.rawValue,
            surface: selectedSurface.rawValue,
            pitchId: selectedCourtId,
            pitchName: court?.name,
            pitchLatitude: court?.latitude,
            pitchLongitude: court?.longitude
        ).resolved
        LastSetupStore.save(setup)
        return setup
    }
}

// MARK: - Components

/// 2×2 grid so player counts (5 / 7 / 9 / 11) stay legible on narrow watch screens.
private struct WatchFootballFormatGrid: View {
    @Binding var selection: FootballFormatOption

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(FootballFormatOption.allCases) { option in
                Button {
                    selection = option
                } label: {
                    Text(option.watchCount)
                        .font(Theme.Typography.metric(size: 26))
                        .foregroundStyle(
                            selection == option ? Theme.Colors.accent : Theme.Colors.textPrimary
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                selection == option
                                    ? Theme.Colors.accent.opacity(0.15)
                                    : Color.white.opacity(0.04)
                            )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                selection == option
                                    ? Theme.Colors.accent.opacity(0.7)
                                    : Color.white.opacity(0.06),
                                lineWidth: selection == option ? 1.5 : 1
                            )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.shortLabel)
            }
        }
    }
}

private struct WatchSetupSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(Theme.Typography.statLabel(size: 9))
                .foregroundStyle(Theme.Colors.textSecondary)
                .tracking(0.8)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct WatchSetupChip: View {
    let title: String
    var subtitle: String?
    let isSelected: Bool
    var compact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typography.body(size: compact ? 13 : 14))
                    .foregroundStyle(isSelected ? Theme.Colors.accent : Theme.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if let subtitle {
                    Text(subtitle)
                        .font(Theme.Typography.caption(size: 10))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: compact ? nil : .infinity, alignment: .leading)
            .padding(.horizontal, compact ? 10 : 12)
            .padding(.vertical, compact ? 8 : 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Theme.Colors.accent.opacity(0.15) : Color.white.opacity(0.04))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isSelected ? Theme.Colors.accent.opacity(0.7) : Color.white.opacity(0.06),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
        }
        .buttonStyle(.plain)
    }
}
