import CoreLocation
import Foundation

/// One-shot location for matching nearby courts on the watch.
@MainActor
final class CourtLocationService: NSObject, ObservableObject {
    /// Last fix from any active instance (used when the match starts).
    static var sharedLastLatitude: Double?
    static var sharedLastLongitude: Double?

    @Published private(set) var latitude: Double?
    @Published private(set) var longitude: Double?
    /// Live compass heading (degrees from true north) while measuring a pitch.
    @Published private(set) var headingDeg: Double?
    @Published private(set) var status: String?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        // Pitch-level precision: a 100 m accuracy fix is useless for geo-
        // referencing a ~100 m field, so request the best available.
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() {
        let auth = manager.authorizationStatus
        switch auth {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            status = "Ubicación apagada — elige una cancha guardada"
        @unknown default:
            status = nil
        }
    }

    /// Starts compass updates so `headingDeg` tracks where the user points.
    func startHeading() {
        guard CLLocationManager.headingAvailable() else { return }
        manager.startUpdatingHeading()
    }

    func stopHeading() {
        manager.stopUpdatingHeading()
    }

    /// Streams live location (for the "walk two points" measurement).
    func startTracking() {
        let auth = manager.authorizationStatus
        if auth == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.startUpdatingLocation()
    }

    func stopTracking() {
        manager.stopUpdatingLocation()
    }
}

extension CourtLocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            latitude = location.coordinate.latitude
            longitude = location.coordinate.longitude
            Self.sharedLastLatitude = latitude
            Self.sharedLastLongitude = longitude
            status = nil
            CourtStore.shared.refreshNearby(latitude: latitude, longitude: longitude)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // trueHeading is -1 when the heading is invalid (needs calibration).
        guard newHeading.trueHeading >= 0 else { return }
        let heading = newHeading.trueHeading
        Task { @MainActor in
            self.headingDeg = heading
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            status = "No se pudo obtener GPS"
            CourtStore.shared.refreshNearby(latitude: nil, longitude: nil)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            requestLocation()
        }
    }
}
