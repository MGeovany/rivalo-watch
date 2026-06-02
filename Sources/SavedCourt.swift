import Foundation

/// A court the user has played at before (synced from iPhone or saved on-watch).
struct SavedCourt: Equatable, Codable, Identifiable {
    let id: String
    var name: String
    var latitude: Double
    var longitude: Double
    var lastPlayedAt: Date?
    var playCount: Int

    var distanceM: Double?

    func distance(from latitude: Double, longitude: Double) -> Double {
        let earthRadius = 6_371_000.0
        let lat1 = latitude * .pi / 180
        let lat2 = self.latitude * .pi / 180
        let dLat = (self.latitude - latitude) * .pi / 180
        let dLon = (self.longitude - longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadius * c
    }
}
