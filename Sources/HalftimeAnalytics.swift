import Foundation

/// Live metrics for the first half, frozen at halftime.
struct HalftimeSnapshot: Equatable, Codable {
    let distanceM: Double
    let sprints: Int
    let topSpeedKmh: Double?
    let intensity: Int?
    /// Intensity 0–100 per elapsed minute (index 0 = minute 1).
    let intensityByMinute: [Int]
}

/// User rolling averages for halftime comparison (synced from iPhone or local history).
struct UserHalftimeAverages: Equatable, Codable {
    let avgDistanceM: Double?
    let avgSprints: Double?
    let avgTopSpeedKmh: Double?

    static let empty = UserHalftimeAverages(
        avgDistanceM: nil,
        avgSprints: nil,
        avgTopSpeedKmh: nil
    )
}

enum HalftimeAnalytics {
    static let sprintSpeedKmh = 20.0
    static let sprintExitKmh = 17.0

    static func snapshot(
        samples: [WorkoutSummary.Sample],
        distanceM: Double,
        durationS: Int,
        currentHeartRate: Double
    ) -> HalftimeSnapshot {
        let firstHalf = firstHalfSamples(from: samples, durationS: durationS)
        let speeds = speedsKmh(from: firstHalf, totalDistanceM: distanceM, durationS: durationS)
        let topSpeed = speeds.map(\.speed).max()
        let sprints = countSprints(speeds: speeds.map(\.speed))
        let hrValues = firstHalf.compactMap(\.hr)
        let avgHR: Double? = hrValues.isEmpty
            ? (currentHeartRate > 0 ? currentHeartRate : nil)
            : Double(hrValues.reduce(0, +)) / Double(hrValues.count)
        let intensity = avgHR.map(intensityScore(fromAverageHR:))
        let byMinute = intensityByMinute(samples: firstHalf, durationS: durationS)

        return HalftimeSnapshot(
            distanceM: distanceM,
            sprints: sprints,
            topSpeedKmh: topSpeed,
            intensity: intensity,
            intensityByMinute: byMinute
        )
    }

    static func firstHalfSamples(
        from samples: [WorkoutSummary.Sample],
        durationS: Int
    ) -> [WorkoutSummary.Sample] {
        let byHalf = samples.filter { $0.half == 1 }
        if !byHalf.isEmpty { return byHalf }
        return samples.filter { $0.tOffsetS <= durationS }
    }

    private static func speedsKmh(
        from samples: [WorkoutSummary.Sample],
        totalDistanceM: Double,
        durationS: Int
    ) -> [(t: Int, speed: Double)] {
        let sorted = samples.sorted { $0.tOffsetS < $1.tOffsetS }
        var speeds: [(Int, Double)] = sorted.compactMap { sample in
            guard let speed = sample.speedKmh else { return nil }
            return (sample.tOffsetS, speed)
        }

        if speeds.isEmpty, durationS > 0, totalDistanceM > 0 {
            let avg = (totalDistanceM / Double(durationS)) * 3.6
            speeds.append((durationS, avg))
        }
        return speeds
    }

    static func countSprints(speeds: [Double]) -> Int {
        guard !speeds.isEmpty else { return 0 }
        var count = 0
        var inSprint = false
        for speed in speeds {
            if speed >= sprintSpeedKmh, !inSprint {
                count += 1
                inSprint = true
            } else if speed < sprintExitKmh {
                inSprint = false
            }
        }
        return count
    }

    static func intensityByMinute(
        samples: [WorkoutSummary.Sample],
        durationS: Int
    ) -> [Int] {
        let minutes = max(1, Int(ceil(Double(durationS) / 60)))
        var buckets = Array(repeating: [Int](), count: minutes)

        for sample in samples {
            guard let hr = sample.hr else { continue }
            let index = min(minutes - 1, max(0, sample.tOffsetS / 60))
            buckets[index].append(hr)
        }

        return buckets.compactMap { hrs in
            guard !hrs.isEmpty else { return nil }
            let avg = Double(hrs.reduce(0, +)) / Double(hrs.count)
            return intensityScore(fromAverageHR: avg)
        }
    }

    static func intensityScore(fromAverageHR avg: Double) -> Int {
        Int(min(100, max(0, ((avg - 60) / (190 - 60) * 100).rounded())))
    }

    static func comparisonDelta(current: Double, average: Double?) -> Double? {
        guard let average, average > 0 else { return nil }
        return ((current - average) / average) * 100
    }
}
