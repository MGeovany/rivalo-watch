import CoreLocation
import Foundation
import WatchKit

/// Tracks GPS distance while the user walks one edge of the pitch (length or width).
/// Uses WKExtendedRuntimeSession to keep the app alive and GPS running when the
/// display turns off, and CLLocationManager with allowsBackgroundLocationUpdates.
@MainActor
final class PitchWalkMeasureService: NSObject, ObservableObject {
    enum Phase: Equatable {
        case readyLength
        case measuringLength
        case readyWidth
        case measuringWidth
        case finished(lengthM: Double, widthM: Double)
    }

    @Published private(set) var phase: Phase = .readyLength
    @Published private(set) var liveMeters: Double = 0
    @Published private(set) var lengthM: Double = 0
    @Published private(set) var status: String?
    /// Current horizontal GPS accuracy in meters. `.infinity` = not yet acquired.
    @Published private(set) var gpsAccuracy: Double = .infinity

    private let manager = CLLocationManager()
    private var lastLocation: CLLocation?
    private var accumulatedM: Double = 0
    private var lastReportedMeters: Double = -1
    private var extendedSession: WKExtendedRuntimeSession?
    /// True when we called requestWhenInUseAuthorization and are waiting for the callback.
    private var pendingStart = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
        manager.distanceFilter = 1
        manager.allowsBackgroundLocationUpdates = true
    }

    func startLength() {
        PhoneSync.shared.activate()
        guard CLLocationManager.locationServicesEnabled() else {
            status = "Turn on Location Services in Settings"
            return
        }
        startExtendedSession()
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            beginLengthMeasure()
        case .notDetermined:
            pendingStart = true
            status = "Waiting for GPS permission…"
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            status = "Location denied — enable in Watch Settings"
            stopExtendedSession()
        @unknown default:
            break
        }
    }

    func finishLength() {
        manager.stopUpdatingLocation()
        lengthM = max(accumulatedM, 0)
        phase = .readyWidth
        liveMeters = 0
        gpsAccuracy = .infinity
        status = String(format: "Length: %.0f m  —  stand at a touchline corner", lengthM)
        reportProgress(force: true, phaseOverride: "length_finished")
    }

    func startWidth() {
        resetAccumulation()
        phase = .measuringWidth
        status = "Walk along the touchline to the far corner, then tap Done"
        manager.startUpdatingLocation()
        reportProgress(force: true)
    }

    func finishWidth() {
        manager.stopUpdatingLocation()
        let widthM = max(accumulatedM, 0)
        phase = .finished(lengthM: lengthM, widthM: widthM)
        status = String(format: "Done — %.0f × %.0f m", lengthM, widthM)
        reportProgress(force: true, phaseOverride: "width_finished", widthM: widthM)
        stopExtendedSession()
    }

    func reset() {
        manager.stopUpdatingLocation()
        stopExtendedSession()
        pendingStart = false
        phase = .readyLength
        lengthM = 0
        liveMeters = 0
        gpsAccuracy = .infinity
        status = nil
        lastReportedMeters = -1
        resetAccumulation()
    }

    // MARK: - Private

    private func reportProgress(force: Bool = false, phaseOverride: String? = nil, widthM: Double? = nil) {
        let phaseKey: String
        if let phaseOverride {
            phaseKey = phaseOverride
        } else {
            switch phase {
            case .measuringLength: phaseKey = "measuring_length"
            case .measuringWidth: phaseKey = "measuring_width"
            default: return
            }
        }

        let meters = phaseOverride == "length_finished"
            ? lengthM
            : (phaseOverride == "width_finished" ? (widthM ?? accumulatedM) : liveMeters)

        guard force || abs(meters - lastReportedMeters) >= 2 else { return }
        lastReportedMeters = meters

        let reportedLength: Double? = switch phaseOverride {
        case "length_finished", "width_finished": lengthM
        case "measuring_width": lengthM
        default: nil
        }

        PhoneSync.shared.sendPitchWalkProgress(
            phase: phaseKey,
            liveMeters: meters,
            lengthM: reportedLength,
            gpsAccuracyM: gpsAccuracy
        )
    }

    private func beginLengthMeasure() {
        pendingStart = false
        resetAccumulation()
        phase = .measuringLength
        status = "Walk along the goal line to the far corner, then tap Done"
        manager.startUpdatingLocation()
        reportProgress(force: true)
    }

    private func resetAccumulation() {
        accumulatedM = 0
        liveMeters = 0
        lastLocation = nil
        lastReportedMeters = -1
    }

    private func startExtendedSession() {
        guard extendedSession == nil else { return }
        let session = WKExtendedRuntimeSession()
        session.delegate = self
        session.start()
        extendedSession = session
    }

    private func stopExtendedSession() {
        extendedSession?.invalidate()
        extendedSession = nil
    }
}

// MARK: - CLLocationManagerDelegate

extension PitchWalkMeasureService: CLLocationManagerDelegate {
    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last, location.horizontalAccuracy >= 0 else { return }
        Task { @MainActor in
            gpsAccuracy = location.horizontalAccuracy
            // Only accumulate distance when GPS is accurate enough
            guard location.horizontalAccuracy < 25 else { return }
            if let last = lastLocation {
                let delta = location.distance(from: last)
                // Ignore micro-jitter (<0.5m) and implausible jumps (>50m in one update)
                if delta >= 0.5, delta < 50 {
                    accumulatedM += delta
                    liveMeters = accumulatedM
                    reportProgress()
                }
            }
            lastLocation = location
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let authStatus = manager.authorizationStatus
        Task { @MainActor in
            switch authStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                if pendingStart { beginLengthMeasure() }
            case .denied, .restricted:
                status = "Location denied — enable in Watch Settings"
                pendingStart = false
                stopExtendedSession()
            default:
                break
            }
        }
    }
}

// MARK: - WKExtendedRuntimeSessionDelegate

extension PitchWalkMeasureService: WKExtendedRuntimeSessionDelegate {
    nonisolated func extendedRuntimeSessionDidStart(
        _ extendedRuntimeSession: WKExtendedRuntimeSession
    ) {}

    nonisolated func extendedRuntimeSessionWillExpire(
        _ extendedRuntimeSession: WKExtendedRuntimeSession
    ) {
        Task { @MainActor in
            status = "GPS session expiring — save your measurement soon"
        }
    }

    nonisolated func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: (any Error)?
    ) {}
}
