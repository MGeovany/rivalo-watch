import Foundation
@preconcurrency import HealthKit

/// Drives a match capture using a HealthKit workout session: start, live
/// metrics (heart rate, distance, energy), pause/resume, and finish with
/// aggregate computation.
/// Playing phase for football-style matches on the watch.
enum MatchSegment: Equatable {
    case firstHalf
    case halftimeBreak
    case secondHalf
}


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
    @Published private(set) var isStarting = false

    /// Selected match mode: "quick", "structured" or "training".
    @Published var mode: String = "quick"
    private var matchSetup = MatchSetup.default
    private var startLatitude: Double?
    private var startLongitude: Double?
    /// Match segment for quick / structured modes (halves + break).
    @Published private(set) var matchSegment: MatchSegment = .firstHalf
    /// Elapsed break time while in `.halftimeBreak`.
    @Published var breakElapsed: TimeInterval = 0
    /// Metrics frozen when the first half ended (shown during break).
    @Published private(set) var halftimeSnapshot: HalftimeSnapshot?

    /// Current half (1 or 2) for half-based modes.
    @Published private(set) var currentHalf = 1

    var usesHalfFlow: Bool {
        mode == "structured" || mode == "quick"
    }

    var isHalftime: Bool { matchSegment == .halftimeBreak }

    private var halftimeOffsetS: Int?
    private var breakStartedAt: Date?
    private var breakTimerTask: Task<Void, Never>?

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var startDate: Date?
    private var timerTask: Task<Void, Never>?
    private let pathRecorder = MatchPathRecorder()

    // Time series captured during the match (sampled every few seconds).
    private let sampleIntervalS = 10
    private var samples: [WorkoutSummary.Sample] = []
    private var lastSampleAt = -10
    private var lastSampleDistanceM: Double = 0

    private let hrUnit = HKUnit.count().unitDivided(by: .minute())
    private let speedUnit = HKUnit.meter().unitDivided(by: .second())

    override init() {
        super.init()
        PhoneSync.shared.activate()
        observePhoneCommands()
    }

    private func observePhoneCommands() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(handlePauseFromPhone),
            name: .rivaloMatchPause, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleResumeFromPhone),
            name: .rivaloMatchResume, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleHalftimeFromPhone),
            name: .rivaloMatchHalftime, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleEndFromPhone),
            name: .rivaloMatchEnd, object: nil
        )
    }

    @objc private func handlePauseFromPhone() { pause() }
    @objc private func handleResumeFromPhone() {
        if matchSegment == .halftimeBreak {
            startSecondHalf()
        } else {
            resume()
        }
    }
    @objc private func handleHalftimeFromPhone() { finishFirstHalf() }
    @objc private func handleEndFromPhone() { Task { await end() } }

    // MARK: - Lifecycle

    /// Starts a new match: requests authorization, opens a workout session and
    /// begins collecting live data.
    func start(setup: MatchSetup = .default) async {
        guard phase == .idle, !isStarting else {
            WorkoutLog.debug("start ignored phase=\(String(describing: phase)) isStarting=\(isStarting)")
            return
        }
        isStarting = true
        errorMessage = nil
        defer { isStarting = false }

        let resolved = setup.resolved
        matchSetup = resolved
        mode = resolved.mode
        startLatitude = CourtLocationService.sharedLastLatitude
        startLongitude = CourtLocationService.sharedLastLongitude
        WorkoutLog.info("start match mode=\(mode)")

        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "Health data is not available on this device."
            WorkoutLog.error("HealthKit unavailable")
            return
        }
        do {
            try await requestAuthorization()
            WorkoutLog.info("HealthKit authorized")

            discardStaleWorkoutSession()

            let configuration = HKWorkoutConfiguration()
            configuration.activityType = .soccer
            configuration.locationType = .outdoor

            WorkoutLog.info("creating HKWorkoutSession…")
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )
            session.delegate = self
            builder.delegate = self

            let start = Date()
            self.session = session
            self.builder = builder
            self.startDate = start

            WorkoutLog.info("session.prepare()")
            session.prepare()
            try await Task.sleep(for: .milliseconds(800))

            WorkoutLog.info("session.startActivity()")
            session.startActivity(with: start)

            resetMetrics()
            lastSampleDistanceM = 0
            tickElapsed()
            phase = .running
            startTimer()
            pathRecorder.start()
            WorkoutLog.info("phase=running clock=\(Int(elapsed))s (live)")

            // beginCollection often hangs on-device; never block the match clock on it.
            startDataCollection(at: start, builder: builder)
        } catch {
            errorMessage = error.localizedDescription
            WorkoutLog.error("start failed: \(error.localizedDescription)")
            discardStaleWorkoutSession()
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

    /// Ends the first half and starts the break clock.
    func finishFirstHalf() {
        guard usesHalfFlow, matchSegment == .firstHalf, phase == .running else { return }
        let durationS = Int(elapsed)
        halftimeSnapshot = HalftimeAnalytics.snapshot(
            samples: samples,
            distanceM: distanceM,
            durationS: durationS,
            currentHeartRate: heartRate
        )
        session?.pause()
        phase = .paused
        matchSegment = .halftimeBreak
        breakStartedAt = Date()
        breakElapsed = 0
        startBreakTimer()
    }

    /// Resumes play for the second half.
    func startSecondHalf() {
        guard usesHalfFlow, matchSegment == .halftimeBreak else { return }
        halftimeOffsetS = Int(elapsed)
        currentHalf = 2
        matchSegment = .secondHalf
        breakStartedAt = nil
        breakTimerTask?.cancel()
        session?.resume()
        phase = .running
    }

    /// Discards second-half data and returns to the first half (no undo).
    func restartFirstHalf() {
        guard usesHalfFlow, matchSegment == .secondHalf else { return }
        if let offset = halftimeOffsetS {
            samples.removeAll { $0.tOffsetS >= offset }
        } else {
            samples.removeAll { $0.half == 2 }
        }
        halftimeOffsetS = nil
        currentHalf = 1
        matchSegment = .firstHalf
        breakElapsed = 0
        breakStartedAt = nil
        session?.resume()
        phase = .running
    }

    /// Seconds shown on the main clock for the current segment.
    var primaryClockSeconds: Int {
        switch matchSegment {
        case .halftimeBreak:
            Int(breakElapsed)
        case .secondHalf:
            if let offset = halftimeOffsetS {
                max(0, Int(elapsed) - offset)
            } else {
                Int(elapsed)
            }
        case .firstHalf:
            Int(elapsed)
        }
    }

    /// Ends the match, finalizes collection and computes the aggregate summary.
    func end() async {
        guard let session, let builder, let startDate else { return }
        timerTask?.cancel()
        breakTimerTask?.cancel()
        WorkoutLog.info("ending match…")

        let end = Date()
        session.stopActivity(with: end)
        session.end()
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { try await builder.endCollection(at: end) }
                group.addTask {
                    try await Task.sleep(for: .seconds(10))
                    throw CollectionTimeout()
                }
                _ = try await group.next()
                group.cancelAll()
            }
            _ = try? await builder.finishWorkout()
            WorkoutLog.info("workout saved to Health")
        } catch is CollectionTimeout {
            WorkoutLog.error("endCollection timed out")
        } catch {
            errorMessage = error.localizedDescription
            WorkoutLog.error("end failed: \(error.localizedDescription)")
        }

        let path = pathRecorder.stop(start: startDate)
        let result = makeSummary(start: startDate, end: end, builder: builder, path: path)
        summary = result
        UserMatchAveragesStore.shared.recordFinishedMatch(result)
        PhoneSync.shared.send(result)
        phase = .ended
        self.session = nil
        self.builder = nil
        self.startDate = nil
    }

    /// Returns to the idle home screen, discarding the finished summary.
    func reset() {
        discardStaleWorkoutSession()
        summary = nil
        errorMessage = nil
        resetMetrics()
        phase = .idle
    }

    // MARK: - Internals

    private struct CollectionTimeout: Error {}

    /// Ends any leftover HealthKit session so `beginCollection` does not hang on the next start.
    private func discardStaleWorkoutSession() {
        guard session != nil || builder != nil else { return }
        WorkoutLog.info("discarding stale workout session")
        timerTask?.cancel()
        breakTimerTask?.cancel()
        pathRecorder.cancel()
        session?.end()
        session = nil
        builder = nil
        startDate = nil
    }

    /// Starts HK live metrics collection without blocking the UI clock.
    private func startDataCollection(at start: Date, builder: HKLiveWorkoutBuilder) {
        Task { @MainActor [weak self] in
            WorkoutLog.info("beginCollection waiting…")
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask { try await builder.beginCollection(at: start) }
                    group.addTask {
                        try await Task.sleep(for: .seconds(15))
                        throw CollectionTimeout()
                    }
                    _ = try await group.next()
                    group.cancelAll()
                }
                WorkoutLog.info("beginCollection ok")
                self?.tickElapsed()
            } catch is CollectionTimeout {
                WorkoutLog.error("beginCollection timed out after 15s — clock still runs; restart Watch if metrics stay at 0")
            } catch {
                WorkoutLog.error("beginCollection failed: \(error.localizedDescription)")
            }
        }
    }

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
        matchSegment = .firstHalf
        breakElapsed = 0
        breakStartedAt = nil
        breakTimerTask?.cancel()
        halftimeSnapshot = nil
        lastSampleDistanceM = 0
    }

    private func startBreakTimer() {
        breakTimerTask?.cancel()
        breakTimerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.matchSegment == .halftimeBreak,
                      let start = self.breakStartedAt else { continue }
                self.breakElapsed = Date().timeIntervalSince(start)
            }
        }
    }

    /// HealthKit `elapsedTime` is often 0 at session start; fall back to wall clock.
    private func tickElapsed() {
        let fromBuilder = builder?.elapsedTime ?? 0
        let fromStart = startDate.map { Date().timeIntervalSince($0) } ?? 0
        elapsed = max(fromBuilder, fromStart)
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { @MainActor [weak self] in
            var lastEventSent = -5
            var lastLoggedSecond = -1
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.phase == .running else { continue }
                self.tickElapsed()

                let offset = Int(self.elapsed)
                if offset != lastLoggedSecond, offset % 10 == 0 {
                    lastLoggedSecond = offset
                    let builderS = Int(self.builder?.elapsedTime ?? 0)
                    WorkoutLog.debug("tick elapsed=\(offset)s builder=\(builderS)s")
                }
                if offset - self.lastSampleAt >= self.sampleIntervalS {
                    self.lastSampleAt = offset
                    let speedKmh = self.estimateSpeedKmh(at: offset)
                    self.samples.append(WorkoutSummary.Sample(
                        tOffsetS: offset,
                        hr: self.heartRate > 0 ? Int(self.heartRate) : nil,
                        speedKmh: speedKmh,
                        half: self.usesHalfFlow ? self.currentHalf : nil
                    ))
                    self.lastSampleDistanceM = self.distanceM
                }

                // Send live event to iPhone every 5 seconds.
                if offset - lastEventSent >= 5 {
                    lastEventSent = offset
                    let segment: String
                    switch self.matchSegment {
                    case .firstHalf: segment = "firstHalf"
                    case .halftimeBreak: segment = "halftimeBreak"
                    case .secondHalf: segment = "secondHalf"
                    }
                    PhoneSync.shared.sendLiveEvent(
                        mode: self.mode,
                        elapsedS: self.primaryClockSeconds,
                        heartRate: Int(self.heartRate),
                        distanceM: self.distanceM,
                        segment: segment
                    )
                }
            }
        }
    }

    private func estimateSpeedKmh(at offsetS: Int) -> Double? {
        if let stats = builder?.statistics(for: HKQuantityType(.runningSpeed)),
           let value = stats.mostRecentQuantity()?.doubleValue(for: speedUnit) {
            return value * 3.6
        }
        let priorOffset = samples.last?.tOffsetS ?? 0
        let deltaS = offsetS - priorOffset
        guard deltaS > 0 else { return nil }
        let deltaM = distanceM - lastSampleDistanceM
        guard deltaM > 0 else { return nil }
        return (deltaM / Double(deltaS)) * 3.6
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

    private func makeSummary(start: Date, end: Date, builder: HKLiveWorkoutBuilder, path: [WorkoutSummary.PathPoint]) -> WorkoutSummary {
        let hrStats = builder.statistics(for: HKQuantityType(.heartRate))
        let hrAvg = hrStats?.averageQuantity()?.doubleValue(for: hrUnit)
        let hrMax = hrStats?.maximumQuantity()?.doubleValue(for: hrUnit)
        let distance = builder.statistics(for: HKQuantityType(.distanceWalkingRunning))?
            .sumQuantity()?.doubleValue(for: .meter()) ?? 0
        let kcal = builder.statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?.doubleValue(for: .kilocalorie())

        let durationS = Int(end.timeIntervalSince(start))
        let snap = HalftimeAnalytics.snapshot(
            samples: samples,
            distanceM: distance,
            durationS: durationS,
            currentHeartRate: hrAvg ?? 0
        )

        let score = MatchFinalScore.compute(
            durationS: durationS,
            distanceM: distance,
            hrAvg: hrAvg.map { Int($0.rounded()) },
            speedMaxKmh: snap.topSpeedKmh,
            sprints: snap.sprints,
            intensity: snap.intensity,
            samples: samples
        )

        let summary = WorkoutSummary(
            startedAt: start,
            endedAt: end,
            durationS: durationS,
            distanceM: distance,
            hrAvg: hrAvg.map { Int($0.rounded()) },
            hrMax: hrMax.map { Int($0.rounded()) },
            speedMaxKmh: snap.topSpeedKmh,
            sprints: snap.sprints,
            intensity: snap.intensity.map(Double.init),
            matchRating: Double(score.overall),
            caloriesKcal: kcal,
            source: "watch",
            mode: mode,
            matchType: matchSetup.matchType,
            surface: matchSetup.surface,
            pitchId: matchSetup.pitchId,
            pitchName: matchSetup.pitchName,
            pitchLatitude: matchSetup.pitchLatitude,
            pitchLongitude: matchSetup.pitchLongitude,
            halftimeOffsetS: halftimeOffsetS,
            samples: samples,
            path: path
        )

        if let pitchId = matchSetup.pitchId {
            CourtStore.shared.recordVisit(
                pitchId: pitchId,
                at: startLatitude,
                longitude: startLongitude
            )
        }

        return summary
    }

}

// MARK: - HealthKit delegates

extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        WorkoutLog.info("session \(String(describing: fromState)) → \(String(describing: toState))")
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        let message = error.localizedDescription
        WorkoutLog.error("session failed: \(message)")
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
