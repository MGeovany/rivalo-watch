import Foundation

/// Combined 0–100 match score from distance, effort, speed, and sprints.
struct MatchScoreResult: Equatable {
    let overall: Int
    let tier: String
    let intensityPoints: Int?
    let distancePoints: Int?
    let speedPoints: Int?
    let sprintPoints: Int?
}

enum MatchFinalScore {
    /// Weights for components that are present (renormalized when some are missing).
    private static let weightIntensity = 0.35
    private static let weightDistance = 0.25
    private static let weightSpeed = 0.20
    private static let weightSprints = 0.20

    static func compute(
        durationS: Int,
        distanceM: Double,
        hrAvg: Int?,
        speedMaxKmh: Double?,
        sprints: Int,
        intensity: Int?,
        samples: [WorkoutSummary.Sample]
    ) -> MatchScoreResult {
        let resolvedIntensity = intensity
            ?? hrAvg.map { HalftimeAnalytics.intensityScore(fromAverageHR: Double($0)) }
            ?? intensityFromSamples(samples)

        var components: [(weight: Double, score: Int)] = []

        if let resolvedIntensity {
            components.append((weightIntensity, resolvedIntensity))
        }

        if let distance = distanceScore(meters: distanceM, durationS: durationS) {
            components.append((weightDistance, distance))
        }

        if let speed = speedMaxKmh, speed > 0 {
            let points = speedPoints(kmh: speed)
            components.append((weightSpeed, points))
        }

        if sprints > 0 {
            components.append((weightSprints, sprintScore(count: sprints, durationS: durationS)))
        }

        let overall: Int
        if components.isEmpty {
            overall = min(100, max(0, durationS / 60 * 3))
        } else {
            let totalWeight = components.reduce(0) { $0 + $1.weight }
            let weighted = components.reduce(0.0) { partial, item in
                partial + (Double(item.score) * item.weight / totalWeight)
            }
            overall = Int(min(100, max(0, weighted.rounded())))
        }

        return MatchScoreResult(
            overall: overall,
            tier: tier(for: overall),
            intensityPoints: resolvedIntensity,
            distancePoints: distanceScore(meters: distanceM, durationS: durationS),
            speedPoints: speedMaxKmh.map { speedPoints(kmh: $0) },
            sprintPoints: sprints > 0 ? sprintScore(count: sprints, durationS: durationS) : nil
        )
    }

    static func compute(from summary: WorkoutSummary) -> MatchScoreResult {
        compute(
            durationS: summary.durationS,
            distanceM: summary.distanceM,
            hrAvg: summary.hrAvg,
            speedMaxKmh: summary.speedMaxKmh,
            sprints: summary.sprints,
            intensity: summary.intensity.map { Int($0.rounded()) },
            samples: summary.samples
        )
    }

    private static func tier(for score: Int) -> String {
        switch score {
        case 90...: return "ELITE"
        case 75..<90: return "STRONG"
        case 60..<75: return "SOLID"
        case 45..<60: return "BUILDING"
        default: return "LIGHT"
        }
    }

    private static func intensityFromSamples(_ samples: [WorkoutSummary.Sample]) -> Int? {
        let hrs = samples.compactMap(\.hr)
        guard !hrs.isEmpty else { return nil }
        let avg = Double(hrs.reduce(0, +)) / Double(hrs.count)
        return HalftimeAnalytics.intensityScore(fromAverageHR: avg)
    }

    /// ~95 m/min at peak amateur output maps to 100.
    private static func distanceScore(meters: Double, durationS: Int) -> Int? {
        guard durationS > 0, meters > 0 else { return nil }
        let metersPerMinute = meters / (Double(durationS) / 60)
        return Int(min(100, max(0, (metersPerMinute / 95) * 100).rounded()))
    }

    /// 28 km/h sprint-level maps to 100.
    private static func speedPoints(kmh: Double) -> Int {
        Int(min(100, max(0, (kmh / 28) * 100).rounded()))
    }

    /// ~12 sprints per 90 min maps to 100.
    private static func sprintScore(count: Int, durationS: Int) -> Int {
        guard durationS > 0 else { return min(100, count * 10) }
        let per90 = Double(count) / (Double(durationS) / 5400)
        return Int(min(100, max(0, (per90 / 12) * 100).rounded()))
    }
}
