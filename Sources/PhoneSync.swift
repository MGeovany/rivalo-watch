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
        static let methodKey = "method"
        static let startMatch = "startMatch"
        static let measureCourt = "measureCourt"
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

    /// Asks the paired iPhone to open pitch measurement (manual).
    func requestMeasureCourt(on method: PitchMeasurementMethod) -> String {
        guard method.requiresPhone else { return "Use Run the pitch on this Watch." }
        guard WCSession.isSupported() else { return "iPhone not reachable." }

        let session = WCSession.default
        let payload: [String: Any] = [
            Command.actionKey: Command.measureCourt,
            Command.methodKey: method.rawValue,
        ]

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { _ in }
            return "Opening on iPhone…"
        }

        do {
            var context = session.applicationContext
            context[Command.actionKey] = Command.measureCourt
            context[Command.methodKey] = method.rawValue
            try session.updateApplicationContext(context)
            return "Open Rivalo on your iPhone."
        } catch {
            return "Open Rivalo on iPhone first."
        }
    }

    func sendLiveEvent(mode: String, elapsedS: Int, heartRate: Int, distanceM: Double, segment: String) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.isReachable else { return }
        let payload: [String: Any] = [
            Command.actionKey: Command.liveEvent,
            "mode": mode,
            "elapsed_s": elapsedS,
            "heart_rate": heartRate,
            "distance_m": distanceM,
            "segment": segment,
        ]
        session.sendMessage(payload, replyHandler: nil) { _ in }
    }

    func send(_ summary: WorkoutSummary) {
        guard WCSession.isSupported() else { return }
        WCSession.default.transferUserInfo(summary.asUserInfo())
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
