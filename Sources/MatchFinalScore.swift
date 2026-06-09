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
            // No real metrics were collected — only give a non-zero score if the
            // user at least ran meaningful distance (>50 m). This prevents a
            // data-collection failure from generating a spurious score.
            overall = distanceM > 50 ? min(60, max(0, durationS / 60 * 2)) : 0
        } else {
            let totalWeight = components.reduce(0) { $0 + $1.weight }
            let weighted = components.reduce(0.0) { partial, item in
                partial + (Double(item.score) * item.weight / totalWeight)
            }
            // Apply a mild compression so 100 requires elite-level performance
            // across all dimensions (not just one metric maxing out).
            let raw = min(100.0, max(0.0, weighted))
            let compressed = raw * 0.92
            overall = Int(compressed.rounded())
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
        case 90...: return "ÉLITE"
        case 75..<90: return "FUERTE"
        case 60..<75: return "SÓLIDO"
        case 45..<60: return "EN PROGRESO"
        default: return "LIGERO"
        }
    }

    private static func intensityFromSamples(_ samples: [WorkoutSummary.Sample]) -> Int? {
        let hrs = samples.compactMap(\.hr)
        guard !hrs.isEmpty else { return nil }
        let avg = Double(hrs.reduce(0, +)) / Double(hrs.count)
        return HalftimeAnalytics.intensityScore(fromAverageHR: avg)
    }

    /// Elite amateur output: 110 m/min (10 km in 90 min) maps to 100.
    /// A typical recreational match (60-70 m/min) scores around 55-65.
    private static func distanceScore(meters: Double, durationS: Int) -> Int? {
        guard durationS > 0, meters > 0 else { return nil }
        let metersPerMinute = meters / (Double(durationS) / 60)
        return Int(min(100, max(0, (metersPerMinute / 110) * 100).rounded()))
    }

    /// 30 km/h maps to 100 (requires genuine sprint effort).
    private static func speedPoints(kmh: Double) -> Int {
        Int(min(100, max(0, (kmh / 30) * 100).rounded()))
    }

    /// ~15 sprints per 90 min maps to 100.
    private static func sprintScore(count: Int, durationS: Int) -> Int {
        guard durationS > 0 else { return min(100, count * 7) }
        let per90 = Double(count) / (Double(durationS) / 5400)
        return Int(min(100, max(0, (per90 / 15) * 100).rounded()))
    }
}
