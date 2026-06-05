import Foundation
import WatchConnectivity

extension Notification.Name {
    static let rivaloStartMatchFromPhone = Notification.Name("rivalo.startMatchFromPhone")
    static let rivaloMatchPause = Notification.Name("rivalo.matchPause")
    static let rivaloMatchResume = Notification.Name("rivalo.matchResume")
    static let rivaloMatchHalftime = Notification.Name("rivalo.matchHalftime")
    static let rivaloMatchEnd = Notification.Name("rivalo.matchEnd")
}

/// Sends finished sessions to the iPhone and handles remote start / live match commands.
final class PhoneSync: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = PhoneSync()

    private enum Command {
        static let actionKey = "action"
        static let startMatch = "startMatch"
        static let savePitch = "savePitch"
        static let liveEvent = "liveMatchEvent"
        static let matchPause = "matchPause"
        static let matchResume = "matchResume"
        static let matchHalftime = "matchHalftime"
        static let matchEnd = "matchEnd"
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        if session.activationState != .activated {
            session.activate()
        }
    }

    /// Pushes live match state to iPhone via application context.
    /// Includes the absolute match start timestamp so the iPhone can drive its
    /// own clock rather than relying on elapsed_s from the watch.
    func sendLiveEvent(
        mode: String,
        startedAtMs: Double,
        heartRate: Int,
        distanceM: Double,
        segment: String,
        halftimeOffsetS: Int?,
        halftimeStartedAtMs: Double?
    ) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        var payload: [String: Any] = [
            Command.actionKey: Command.liveEvent,
            "mode": mode,
            "started_at_ms": startedAtMs,
            "heart_rate": heartRate,
            "distance_m": distanceM,
            "segment": segment,
        ]
        if let halftimeOffsetS { payload["halftime_offset_s"] = halftimeOffsetS }
        if let halftimeStartedAtMs { payload["halftime_started_at_ms"] = halftimeStartedAtMs }

        do {
            var context = session.applicationContext
            for (key, value) in payload {
                context[key] = value
            }
            try session.updateApplicationContext(context)
        } catch {
            // Throttled or unchanged context — safe to ignore.
        }
    }

    func send(_ summary: WorkoutSummary) {
        guard WCSession.isSupported() else { return }
        WCSession.default.transferUserInfo(summary.asUserInfo())
    }

    /// Sends a measured court to the iPhone for `POST /v1/pitches`.
    func sendPitchToPhone(
        name: String,
        lengthM: Double,
        widthM: Double,
        latitude: Double?,
        longitude: Double?,
        measurementMethod: String,
        matchType: String?,
        surface: String?
    ) {
        guard WCSession.isSupported() else { return }
        var payload: [String: Any] = [
            Command.actionKey: Command.savePitch,
            "name": name,
            "length_m": lengthM,
            "width_m": widthM,
            "measurement_method": measurementMethod,
        ]
        if let latitude { payload["latitude"] = latitude }
        if let longitude { payload["longitude"] = longitude }
        if let matchType { payload["type"] = matchType }
        if let surface { payload["surface"] = surface }
        WCSession.default.transferUserInfo(payload)
    }

    // MARK: WCSessionDelegate

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        if isStartMatch(message) {
            postStartMatch()
            replyHandler(["status": "ok"])
            return
        }
        if let command = message[Command.actionKey] as? String {
            handleRemoteCommand(command)
            replyHandler(["status": "ok"])
        } else {
            replyHandler(["status": "ok"])
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        if let courts = applicationContext["courts"] as? [[String: Any]],
           let data = try? JSONSerialization.data(withJSONObject: courts) {
            DispatchQueue.main.async {
                guard let decoded = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                    return
                }
                CourtStore.shared.mergeFromPhone(decoded)
            }
        }
        if let userAverages = applicationContext["user_averages"] as? [String: Any],
           let data = try? JSONSerialization.data(withJSONObject: userAverages),
           let copy = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            DispatchQueue.main.async {
                UserMatchAveragesStore.shared.applyPhonePayload(copy)
            }
        }
        if isStartMatch(applicationContext) {
            postStartMatch()
        }
        if let command = applicationContext[Command.actionKey] as? String {
            DispatchQueue.main.async {
                self.handleRemoteCommand(command)
            }
        }
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    private func handleRemoteCommand(_ command: String) {
        switch command {
        case Command.matchPause:
            NotificationCenter.default.post(name: .rivaloMatchPause, object: nil)
        case Command.matchResume:
            NotificationCenter.default.post(name: .rivaloMatchResume, object: nil)
        case Command.matchHalftime:
            NotificationCenter.default.post(name: .rivaloMatchHalftime, object: nil)
        case Command.matchEnd:
            NotificationCenter.default.post(name: .rivaloMatchEnd, object: nil)
        default:
            break
        }
    }

    private func isStartMatch(_ payload: [String: Any]) -> Bool {
        payload[Command.actionKey] as? String == Command.startMatch
    }

    private func postStartMatch() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .rivaloStartMatchFromPhone, object: nil)
        }
    }
}
