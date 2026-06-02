import Foundation

/// Aggregated result of a finished match, built on the watch. Mirrors the
/// payload the phone will send to the backend (source = "watch"). Sent to the
/// iPhone via WatchConnectivity in a later phase.
struct WorkoutSummary: Equatable {
    var startedAt: Date
    var endedAt: Date
    var durationS: Int
    var distanceM: Double
    var hrAvg: Int?
    var hrMax: Int?
    var speedMaxKmh: Double?
    var sprints: Int
    var intensity: Double?
    var caloriesKcal: Double?
    var source: String

    /// Serializes the summary into a WatchConnectivity `userInfo` dictionary
    /// matching the backend session payload (snake_case keys, ISO8601 dates).
    func asUserInfo() -> [String: Any] {
        let formatter = ISO8601DateFormatter()
        var dict: [String: Any] = [
            "started_at": formatter.string(from: startedAt),
            "ended_at": formatter.string(from: endedAt),
            "duration_s": durationS,
            "distance_m": distanceM,
            "sprints": sprints,
            "source": source,
        ]
        if let hrAvg { dict["hr_avg"] = hrAvg }
        if let hrMax { dict["hr_max"] = hrMax }
        if let speedMaxKmh { dict["speed_max_kmh"] = speedMaxKmh }
        if let intensity { dict["intensity"] = intensity }
        if let caloriesKcal { dict["calories_kcal"] = caloriesKcal }
        return dict
    }

    var distanceKmText: String { String(format: "%.2f km", distanceM / 1000) }

    var durationText: String {
        let minutes = durationS / 60
        let seconds = durationS % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
