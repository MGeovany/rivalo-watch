import Foundation

/// Geodesy helpers for the "walk two points" pitch measurement: distance,
/// bearing and midpoint between two GPS coordinates (accurate at pitch scale).
enum GeoMath {
    /// Great-circle distance in meters (haversine).
    static func distanceM(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let r = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        return r * 2 * atan2(sqrt(a), sqrt(1 - a))
    }

    /// Initial bearing A→B in degrees from true north (0…360).
    static func bearingDeg(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let p1 = lat1 * .pi / 180
        let p2 = lat2 * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let y = sin(dLon) * cos(p2)
        let x = cos(p1) * sin(p2) - sin(p1) * cos(p2) * cos(dLon)
        let deg = atan2(y, x) * 180 / .pi
        return (deg + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Midpoint between two coordinates (plain average; fine at pitch scale).
    static func midpoint(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> (lat: Double, lon: Double) {
        ((lat1 + lat2) / 2, (lon1 + lon2) / 2)
    }
}
