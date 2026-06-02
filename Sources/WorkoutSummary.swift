import Foundation

/// Aggregated result of a finished match, built on the watch. Mirrors the
/// payload the phone will send to the backend (source = "watch"). Sent to the
/// iPhone via WatchConnectivity in a later phase.
struct WorkoutSummary: Equatable {
    /// One point in the match time series.
    struct Sample: Equatable {
        var tOffsetS: Int
        var hr: Int?
        var speedKmh: Double?
        /// 1 or 2 for structured matches; nil otherwise.
        var half: Int?
    }

    /// One GPS point on the match trajectory (V2 session_path).
    struct PathPoint: Equatable {
        var tOffsetS: Int
        var latitude: Double
        var longitude: Double
    }

    var startedAt: Date
    var endedAt: Date
    var durationS: Int
    var distanceM: Double
    var hrAvg: Int?
    var hrMax: Int?
    var speedMaxKmh: Double?
    var sprints: Int
    var intensity: Double?
    /// Combined performance score (0–100) from all tracked metrics.
    var matchRating: Double?
    var caloriesKcal: Double?
    var source: String
    var mode: String
    var matchType: String?
    var surface: String?
    var pitchId: String?
    var pitchName: String?
    var pitchLatitude: Double?
    var pitchLongitude: Double?
    var halftimeOffsetS: Int?
    var samples: [Sample]
    /// GPS trajectory captured during the match (empty when no location).
    var path: [PathPoint] = []

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
            "mode": mode,
        ]
        if let matchType { dict["match_type"] = matchType }
        if let surface { dict["surface"] = surface }
        if let pitchId { dict["pitch_id"] = pitchId }
        if let pitchName { dict["pitch_name"] = pitchName }
        if let pitchLatitude { dict["pitch_latitude"] = pitchLatitude }
        if let pitchLongitude { dict["pitch_longitude"] = pitchLongitude }
        if let hrAvg { dict["hr_avg"] = hrAvg }
        if let hrMax { dict["hr_max"] = hrMax }
        if let speedMaxKmh { dict["speed_max_kmh"] = speedMaxKmh }
        if let intensity { dict["intensity"] = intensity }
        if let matchRating { dict["match_rating"] = matchRating }
        if let caloriesKcal { dict["calories_kcal"] = caloriesKcal }
        if let halftimeOffsetS { dict["halftime_offset_s"] = halftimeOffsetS }
        if !samples.isEmpty {
            dict["samples"] = samples.map { sample -> [String: Any] in
                var point: [String: Any] = ["t_offset_s": sample.tOffsetS]
                if let hr = sample.hr { point["hr"] = hr }
                if let speed = sample.speedKmh { point["speed_kmh"] = speed }
                if let half = sample.half { point["half"] = half }
                return point
            }
        }
        if !path.isEmpty {
            dict["path"] = path.map { point -> [String: Any] in
                [
                    "t_offset_s": point.tOffsetS,
                    "latitude": point.latitude,
                    "longitude": point.longitude,
                ]
            }
        }
        return dict
    }

    var distanceKmText: String { String(format: "%.2f km", distanceM / 1000) }

    var durationText: String {
        let minutes = durationS / 60
        let seconds = durationS % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
