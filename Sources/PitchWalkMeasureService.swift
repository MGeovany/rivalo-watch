import CoreLocation
import Foundation

/// Tracks GPS distance while the user runs one edge of the pitch (length or width).
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

    private let manager = CLLocationManager()
    private var lastLocation: CLLocation?
    private var accumulatedM: Double = 0

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
        manager.distanceFilter = 2
    }

    func startLength() {
        guard CLLocationManager.locationServicesEnabled() else {
            status = "Turn on Location Services"
            return
        }
        resetAccumulation()
        phase = .measuringLength
        status = "Run along one goal line, then tap Done"
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func finishLength() {
        manager.stopUpdatingLocation()
        lengthM = max(accumulatedM, 0)
        phase = .readyWidth
        liveMeters = 0
        status = String(format: "Length %.0f m — now run the width", lengthM)
    }

    func startWidth() {
        resetAccumulation()
        phase = .measuringWidth
        status = "Run along the sideline, then tap Done"
        manager.startUpdatingLocation()
    }

    func finishWidth() {
        manager.stopUpdatingLocation()
        let widthM = max(accumulatedM, 0)
        phase = .finished(lengthM: lengthM, widthM: widthM)
        status = String(format: "Done · %.0f × %.0f m", lengthM, widthM)
    }

    func reset() {
        manager.stopUpdatingLocation()
        phase = .readyLength
        lengthM = 0
        liveMeters = 0
        status = nil
        resetAccumulation()
    }

    private func resetAccumulation() {
        accumulatedM = 0
        liveMeters = 0
        lastLocation = nil
    }
}

extension PitchWalkMeasureService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0, location.horizontalAccuracy < 25 else {
            return
        }
        Task { @MainActor in
            if let last = lastLocation {
                let delta = location.distance(from: last)
                if delta > 0.5, delta < 80 {
                    accumulatedM += delta
                    liveMeters = accumulatedM
                }
            }
            lastLocation = location
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let authorization = manager.authorizationStatus
        Task { @MainActor in
            switch authorization {
            case .denied, .restricted:
                status = "Location denied — enable in Settings"
            default:
                break
            }
        }
    }
}
