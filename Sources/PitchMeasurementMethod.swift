import Foundation

/// How a pitch is measured (V2-F). Both methods run on Apple Watch.
enum PitchMeasurementMethod: String, CaseIterable, Identifiable {
    case walk
    case manual

    var id: String { rawValue }

    var watchTitle: String {
        switch self {
        case .walk: "Run pitch"
        case .manual: "Manual"
        }
    }

    var watchSubtitle: String {
        switch self {
        case .walk: "GPS: run length, then width"
        case .manual: "Set length & width in meters"
        }
    }

    var watchDeviceTags: [String] {
        ["Watch"]
    }

    var systemImage: String {
        switch self {
        case .walk: "figure.run"
        case .manual: "ruler"
        }
    }

    var runsOnWatch: Bool { true }

    var requiresPhone: Bool { false }
}
