import Foundation

/// Local store of courts the user has played at (GPS + history).
@MainActor
final class CourtStore: ObservableObject {
    static let shared = CourtStore()

    @Published private(set) var courts: [SavedCourt] = []
    @Published private(set) var nearbyCourts: [SavedCourt] = []

    private let storageKey = "rivalo.watch.courts.v1"
    private let defaults = UserDefaults.standard

    private init() {
        load()
        if courts.isEmpty {
            seedDemoCourtsIfNeeded()
        }
    }

    func refreshNearby(latitude: Double?, longitude: Double?) {
        guard let latitude, let longitude else {
            nearbyCourts = courts.sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }
            return
        }

        nearbyCourts = courts
            .map { court -> SavedCourt in
                var copy = court
                copy.distanceM = court.distance(from: latitude, longitude: longitude)
                return copy
            }
            .sorted { lhs, rhs in
                let lhsNear = (lhs.distanceM ?? .infinity) < 200
                let rhsNear = (rhs.distanceM ?? .infinity) < 200
                if lhsNear != rhsNear { return lhsNear }
                if let ld = lhs.distanceM, let rd = rhs.distanceM, abs(ld - rd) > 5 {
                    return ld < rd
                }
                return (lhs.lastPlayedAt ?? .distantPast) > (rhs.lastPlayedAt ?? .distantPast)
            }
    }

    @discardableResult
    func saveMeasuredCourt(
        name: String,
        lengthM: Double,
        widthM: Double,
        latitude: Double?,
        longitude: Double?,
        measurementMethod: String = PitchMeasurementMethod.walk.rawValue,
        matchType: String? = nil,
        surface: String? = nil
    ) -> String {
        let id = UUID().uuidString
        let lat = latitude ?? courts.first?.latitude ?? 14.0723
        let lon = longitude ?? courts.first?.longitude ?? -87.1921
        courts.append(SavedCourt(
            id: id,
            name: name,
            latitude: lat,
            longitude: lon,
            lastPlayedAt: Date(),
            playCount: 0,
            lengthM: lengthM,
            widthM: widthM,
            measurementMethod: measurementMethod
        ))
        persist()
        refreshNearby(latitude: latitude, longitude: longitude)
        PhoneSync.shared.sendPitchToPhone(
            name: name,
            lengthM: lengthM,
            widthM: widthM,
            latitude: lat,
            longitude: lon,
            measurementMethod: measurementMethod,
            matchType: matchType,
            surface: surface
        )
        return id
    }

    func recordVisit(pitchId: String, at latitude: Double?, longitude: Double?) {
        guard let index = courts.firstIndex(where: { $0.id == pitchId }) else { return }
        courts[index].lastPlayedAt = Date()
        courts[index].playCount += 1
        if let latitude, let longitude {
            courts[index].latitude = latitude
            courts[index].longitude = longitude
        }
        persist()
    }

    func mergeFromPhone(_ payload: [[String: Any]]) {
        for item in payload {
            guard
                let id = item["id"] as? String,
                let name = item["name"] as? String,
                let lat = item["latitude"] as? Double,
                let lon = item["longitude"] as? Double
            else { continue }

            let lastPlayed: Date? = {
                if let raw = item["last_played_at"] as? String {
                    return ISO8601DateFormatter().date(from: raw)
                }
                return nil
            }()
            let count = item["play_count"] as? Int ?? 1
            let lengthM = item["length_m"] as? Double
            let widthM = item["width_m"] as? Double
            let method = item["measurement_method"] as? String

            if let index = courts.firstIndex(where: { $0.id == id }) {
                courts[index].name = name
                courts[index].latitude = lat
                courts[index].longitude = lon
                courts[index].playCount = max(courts[index].playCount, count)
                if let lengthM { courts[index].lengthM = lengthM }
                if let widthM { courts[index].widthM = widthM }
                if let method { courts[index].measurementMethod = method }
                if let lastPlayed {
                    courts[index].lastPlayedAt = max(courts[index].lastPlayedAt ?? .distantPast, lastPlayed)
                }
            } else {
                courts.append(SavedCourt(
                    id: id,
                    name: name,
                    latitude: lat,
                    longitude: lon,
                    lastPlayedAt: lastPlayed,
                    playCount: count,
                    lengthM: lengthM,
                    widthM: widthM,
                    measurementMethod: method
                ))
            }

            if lengthM != nil, widthM != nil {
                courts.removeAll { local in
                    local.id != id
                        && local.hasDimensions
                        && local.name == name
                        && local.distance(from: lat, longitude: lon) < 40
                }
            }
        }
        persist()
    }

    // MARK: - Private

    private func load() {
        guard
            let data = defaults.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([SavedCourt].self, from: data)
        else { return }
        courts = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(courts) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func seedDemoCourtsIfNeeded() {
        courts = [
            SavedCourt(
                id: "demo-court-1",
                name: "Cancha Los Proceres",
                latitude: 14.0723,
                longitude: -87.1921,
                lastPlayedAt: Date().addingTimeInterval(-86400 * 7),
                playCount: 5
            ),
            SavedCourt(
                id: "demo-court-2",
                name: "Complejo Fútbol 11",
                latitude: 14.0788,
                longitude: -87.1855,
                lastPlayedAt: Date().addingTimeInterval(-86400 * 14),
                playCount: 3
            ),
        ]
        persist()
    }
}
