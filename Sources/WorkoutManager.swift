import Foundation
import HealthKit

/// Drives a match capture using a HealthKit workout session: start, live
/// metrics (heart rate, distance, energy), pause/resume, and finish with
/// aggregate computation.
@MainActor
final class WorkoutManager: NSObject, ObservableObject {
    enum Phase: Equatable {
        case idle
        case running
        case paused
        case ended
    }

    @Published var phase: Phase = .idle
    @Published var elapsed: TimeInterval = 0
    @Published var heartRate: Double = 0
    @Published var distanceM: Double = 0
    @Published var activeKcal: Double = 0
    @Published var summary: WorkoutSummary?
    @Published var errorMessage: String?

    /// Selected match mode: "quick", "structured" or "training".
    @Published var mode: String = "quick"
    /// True while paused at half-time of a structured match.
    @Published var isHalftime: Bool = false
    /// Current half (1 or 2) for structured matches.
    @Published private(set) var currentHalf = 1

    private var halftimeOffsetS: Int?

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var startDate: Date?
    private var timerTask: Task<Void, Never>?

    // Time series captured during the match (sampled every few seconds).
    private let sampleIntervalS = 10
    private var samples: [WorkoutSummary.Sample] = []
    private var lastSampleAt = -10

    private let hrUnit = HKUnit.count().unitDivided(by: .minute())

    override init() {
        super.init()
        PhoneSync.shared.activate()
    }

    // MARK: - Lifecycle

    /// Starts a new match: requests authorization, opens a workout session and
    /// begins collecting live data.
    func start(mode: String = "quick") async {
        guard phase == .idle else { return }
        self.mode = mode
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "Health data is not available on this device."
            return
        }
        do {
            try await requestAuthorization()

            let configuration = HKWorkoutConfiguration()
            configuration.activityType = .soccer
            configuration.locationType = .outdoor

            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            session.delegate = self
            builder.delegate = self

            let start = Date()
            self.session = session
            self.builder = builder
            self.startDate = start

            session.startActivity(with: start)
            try await builder.beginCollection(at: start)

            resetMetrics()
            phase = .running
            startTimer()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func pause() {
        session?.pause()
        phase = .paused
    }

    func resume() {
        session?.resume()
        phase = .running
    }

    /// Structured match: pause at half-time.
    func markHalftime() {
        guard mode == "structured", phase == .running else { return }
        session?.pause()
        phase = .paused
        isHalftime = true
    }

    /// Structured match: resume into the second half, recording the boundary.
    func startSecondHalf() {
        guard mode == "structured", isHalftime else { return }
        halftimeOffsetS = Int(elapsed)
        currentHalf = 2
        isHalftime = false
        session?.resume()
        phase = .running
    }

    /// Ends the match, finalizes collection and computes the aggregate summary.
    func end() async {
        guard let session, let builder, let startDate else { return }
        timerTask?.cancel()

        let end = Date()
        session.end()
        do {
            try await builder.endCollection(at: end)
            _ = try? await builder.finishWorkout()
        } catch {
            errorMessage = error.localizedDescription
        }

        let result = makeSummary(start: startDate, end: end, builder: builder)
        summary = result
        PhoneSync.shared.send(result)
        phase = .ended
    }

    /// Returns to the idle home screen, discarding the finished summary.
    func reset() {
        session = nil
        builder = nil
        startDate = nil
        summary = nil
        errorMessage = nil
        resetMetrics()
        phase = .idle
    }

    // MARK: - Internals

    private func requestAuthorization() async throws {
        let share: Set<HKSampleType> = [
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKObjectType.workoutType(),
        ]
        let read: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.activeEnergyBurned),
        ]
        try await healthStore.requestAuthorization(toShare: share, read: read)
    }

    private func resetMetrics() {
        elapsed = 0
        heartRate = 0
        distanceM = 0
        activeKcal = 0
        samples = []
        lastSampleAt = -sampleIntervalS
        currentHalf = 1
        halftimeOffsetS = nil
        isHalftime = false
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.phase == .running else { continue }
                self.elapsed = self.builder?.elapsedTime ?? self.startDate.map { Date().timeIntervalSince($0) } ?? 0

                let offset = Int(self.elapsed)
                if offset - self.lastSampleAt >= self.sampleIntervalS {
                    self.lastSampleAt = offset
                    self.samples.append(WorkoutSummary.Sample(
                        tOffsetS: offset,
                        hr: self.heartRate > 0 ? Int(self.heartRate) : nil,
                        speedKmh: nil,
                        half: self.mode == "structured" ? self.currentHalf : nil
                    ))
                }
            }
        }
    }

    /// Re-reads the latest metrics from the builder after a data collection event.
    fileprivate func refreshMetrics() {
        guard let builder else { return }
        if let stats = builder.statistics(for: HKQuantityType(.heartRate)),
           let value = stats.mostRecentQuantity()?.doubleValue(for: hrUnit) {
            heartRate = value
        }
        if let stats = builder.statistics(for: HKQuantityType(.distanceWalkingRunning)),
           let value = stats.sumQuantity()?.doubleValue(for: .meter()) {
            distanceM = value
        }
        if let stats = builder.statistics(for: HKQuantityType(.activeEnergyBurned)),
           let value = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) {
            activeKcal = value
        }
    }

    private func makeSummary(start: Date, end: Date, builder: HKLiveWorkoutBuilder) -> WorkoutSummary {
        let hrStats = builder.statistics(for: HKQuantityType(.heartRate))
        let hrAvg = hrStats?.averageQuantity()?.doubleValue(for: hrUnit)
        let hrMax = hrStats?.maximumQuantity()?.doubleValue(for: hrUnit)
        let distance = builder.statistics(for: HKQuantityType(.distanceWalkingRunning))?
            .sumQuantity()?.doubleValue(for: .meter()) ?? 0
        let kcal = builder.statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?.doubleValue(for: .kilocalorie())

        return WorkoutSummary(
            startedAt: start,
            endedAt: end,
            durationS: Int(end.timeIntervalSince(start)),
            distanceM: distance,
            hrAvg: hrAvg.map { Int($0.rounded()) },
            hrMax: hrMax.map { Int($0.rounded()) },
            // speed_max and sprints need a per-sample speed series; left for a
            // later phase. Intensity is a simple normalization of average HR.
            speedMaxKmh: nil,
            sprints: 0,
            intensity: hrAvg.map(intensity(fromAverageHR:)),
            caloriesKcal: kcal,
            source: "watch",
            mode: mode,
            halftimeOffsetS: halftimeOffsetS,
            samples: samples
        )
    }

    /// Maps an average heart rate to a 0-100 effort score (simple MVP heuristic).
    private func intensity(fromAverageHR avg: Double) -> Double {
        let normalized = (avg - 60) / (190 - 60) * 100
        return min(100, max(0, normalized))
    }
}

// MARK: - HealthKit delegates

extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {}

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor [weak self] in
            self?.errorMessage = message
        }
    }
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        Task { @MainActor [weak self] in
            self?.refreshMetrics()
        }
    }
}
