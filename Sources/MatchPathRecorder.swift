import CoreLocation
import Foundation

/// Captures the GPS trajectory of a match on the watch. Records raw fixes while
/// active and converts them into `WorkoutSummary.PathPoint`s (t_offset relative
/// to the match start) when the match ends. Best-effort: if location is denied
/// or unavailable, it simply yields an empty path and the match still saves.
@MainActor
final class MatchPathRecorder: NSObject, ObservableObject {
    private let manager = CLLocationManager()
    private var fixes: [(at: Date, latitude: Double, longitude: Double)] = []
    private var isRecording = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 3
    }

    /// Begins accumulating fixes. Requests authorization if needed; safe to call
    /// even when permission is missing (no points are produced).
    func start() {
        fixes.removeAll()
        isRecording = true
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            WorkoutLog.info("path recorder: location not authorized — skipping trajectory")
        }
    }

    /// Stops accumulating and discards any captured fixes (no summary built).
    func cancel() {
        isRecording = false
        manager.stopUpdatingLocation()
        fixes.removeAll()
    }

    /// Stops accumulating and returns the trajectory as offset-tagged points.
    func stop(start: Date) -> [WorkoutSummary.PathPoint] {
        isRecording = false
        manager.stopUpdatingLocation()
        let points = fixes.map { fix in
            WorkoutSummary.PathPoint(
                tOffsetS: max(0, Int(fix.at.timeIntervalSince(start))),
                latitude: fix.latitude,
                longitude: fix.longitude
            )
        }
        fixes.removeAll()
        WorkoutLog.info("path recorder: captured \(points.count) GPS points")
        return points
    }
}

extension MatchPathRecorder: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let snapshot = locations.map { (at: $0.timestamp, lat: $0.coordinate.latitude, lon: $0.coordinate.longitude) }
        Task { @MainActor in
            guard self.isRecording else { return }
            for fix in snapshot {
                self.fixes.append((at: fix.at, latitude: fix.lat, longitude: fix.lon))
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            WorkoutLog.error("path recorder: location error \(error.localizedDescription)")
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard self.isRecording else { return }
            let status = self.manager.authorizationStatus
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.manager.startUpdatingLocation()
            }
        }
    }
}
