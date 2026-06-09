import Foundation

/// Pre-match choices on the watch. Unset fields use defaults when starting.
struct MatchSetup: Equatable, Codable {
    var mode: String
    var matchType: String
    var surface: String
    var pitchId: String?
    var pitchName: String?
    var pitchLatitude: Double?
    var pitchLongitude: Double?

    static let `default` = MatchSetup(
        mode: "quick",
        matchType: "11-a-side",
        surface: "Artificial turf",
        pitchId: nil,
        pitchName: nil,
        pitchLatitude: nil,
        pitchLongitude: nil
    )

    /// Resolved values sent to HealthKit / phone (never empty).
    var resolved: MatchSetup {
        MatchSetup(
            mode: mode.isEmpty ? "quick" : mode,
            matchType: matchType.isEmpty ? "11-a-side" : matchType,
            surface: surface.isEmpty ? "Artificial turf" : surface,
            pitchId: pitchId,
            pitchName: pitchName,
            pitchLatitude: pitchLatitude,
            pitchLongitude: pitchLongitude
        )
    }
}

enum MatchModeOption: String, CaseIterable, Identifiable {
    case quick
    case structured
    case training

    var id: String { rawValue }

    var label: String {
        switch self {
        case .quick: "Rápido"
        case .structured: "Estructurado"
        case .training: "Entrenamiento"
        }
    }
}

enum FootballFormatOption: String, CaseIterable, Identifiable {
    case five = "5-a-side"
    case seven = "7-a-side"
    case nine = "9-a-side"
    case eleven = "11-a-side"

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .five: "5v5"
        case .seven: "7v7"
        case .nine: "9v9"
        case .eleven: "11v11"
        }
    }

    /// Large digit for the watch grid (avoids truncation in a 4-across row).
    var watchCount: String {
        switch self {
        case .five: "5"
        case .seven: "7"
        case .nine: "9"
        case .eleven: "11"
        }
    }
}

enum SurfaceOption: String, CaseIterable, Identifiable {
    case natural = "Natural grass"
    case turf = "Artificial turf"
    case indoor = "Indoor"
    case concrete = "Concrete"
    case other = "Other"

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .natural: "Césped"
        case .turf: "C. artificial"
        case .indoor: "Indoor"
        case .concrete: "Concreto"
        case .other: "Otro"
        }
    }
}

// MARK: - Last setup persistence

enum LastSetupStore {
    private static let key = "lastMatchSetup"

    static func save(_ setup: MatchSetup) {
        guard let data = try? JSONEncoder().encode(setup) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load() -> MatchSetup? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let setup = try? JSONDecoder().decode(MatchSetup.self, from: data)
        else { return nil }
        return setup
    }
}
