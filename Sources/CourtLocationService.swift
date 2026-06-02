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
    @Published private(set) var status: String?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        let auth = manager.authorizationStatus
        switch auth {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            status = "Location off — pick a saved court"
        @unknown default:
            status = nil
        }
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

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            status = "Could not get GPS"
            CourtStore.shared.refreshNearby(latitude: nil, longitude: nil)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            requestLocation()
        }
    }
}
