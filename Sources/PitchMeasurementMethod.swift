import Foundation

/// How a pitch is measured (V2-F). Walk on Watch/iPhone; manual on iPhone.
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
        case .manual: "Type meters on iPhone"
        }
    }

    var watchDeviceTags: [String] {
        switch self {
        case .walk: ["Watch", "iPhone"]
        case .manual: ["iPhone"]
        }
    }

    var systemImage: String {
        switch self {
        case .walk: "figure.run"
        case .manual: "ruler"
        }
    }

    var runsOnWatch: Bool {
        self == .walk
    }

    var requiresPhone: Bool {
        self == .manual
    }
}
