import Foundation

/// Rolling user averages for halftime comparison (iPhone sync + local match history).
@MainActor
final class UserMatchAveragesStore: ObservableObject {
    static let shared = UserMatchAveragesStore()

    @Published private(set) var halftime = UserHalftimeAverages.empty

    private let storageKey = "rivalo.user_halftime_averages"
    private let historyKey = "rivalo.local_match_halves"
    private let maxHistory = 24

    private struct HalfRecord: Codable {
        var distanceM: Double
        var sprints: Int
        var topSpeedKmh: Double?
    }

    private init() {
        loadPersisted()
    }

    func applyPhonePayload(_ payload: [String: Any]) {
        let averages = UserHalftimeAverages(
            avgDistanceM: payload["avg_distance_m"] as? Double,
            avgSprints: payload["avg_sprints"] as? Double,
            avgTopSpeedKmh: payload["avg_top_speed_kmh"] as? Double
        )
        guard averages != .empty else { return }
        halftime = averages
        persist()
    }

    func recordFinishedMatch(_ summary: WorkoutSummary) {
        let offset = summary.halftimeOffsetS ?? summary.durationS / 2
        let firstHalfSamples = summary.samples.filter { sample in
            if let half = sample.half { return half == 1 }
            return sample.tOffsetS < offset
        }
        let snap = HalftimeAnalytics.snapshot(
            samples: firstHalfSamples.isEmpty ? summary.samples : firstHalfSamples,
            distanceM: summary.halftimeOffsetS != nil
                ? summary.distanceM * Double(offset) / Double(max(summary.durationS, 1))
                : summary.distanceM / 2,
            durationS: offset,
            currentHeartRate: 0
        )

        var history = loadHistory()
        history.append(
            HalfRecord(
                distanceM: snap.distanceM,
                sprints: snap.sprints,
                topSpeedKmh: snap.topSpeedKmh
            )
        )
        if history.count > maxHistory {
            history = Array(history.suffix(maxHistory))
        }
        saveHistory(history)

        if halftime == .empty {
            halftime = averages(from: history)
            persist()
        }
    }

    private func averages(from records: [HalfRecord]) -> UserHalftimeAverages {
        guard !records.isEmpty else { return .empty }
        let distances = records.map(\.distanceM)
        let sprints = records.map { Double($0.sprints) }
        let speeds = records.compactMap(\.topSpeedKmh)
        return UserHalftimeAverages(
            avgDistanceM: distances.reduce(0, +) / Double(distances.count),
            avgSprints: sprints.reduce(0, +) / Double(sprints.count),
            avgTopSpeedKmh: speeds.isEmpty ? nil : speeds.reduce(0, +) / Double(speeds.count)
        )
    }

    private func loadPersisted() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode(StoredAverages.self, from: data)
        else { return }
        halftime = decoded.halftime
    }

    private func persist() {
        let payload = StoredAverages(halftime: halftime)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func loadHistory() -> [HalfRecord] {
        guard
            let data = UserDefaults.standard.data(forKey: historyKey),
            let decoded = try? JSONDecoder().decode([HalfRecord].self, from: data)
        else { return [] }
        return decoded
    }

    private func saveHistory(_ records: [HalfRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: historyKey)
    }

    private struct StoredAverages: Codable {
        var halftime: UserHalftimeAverages
    }
}

extension UserHalftimeAverages {
    var isEmpty: Bool {
        avgDistanceM == nil && avgSprints == nil && avgTopSpeedKmh == nil
    }
}
