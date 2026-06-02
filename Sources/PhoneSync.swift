import Foundation
import WatchConnectivity

extension Notification.Name {
    static let rivaloStartMatchFromPhone = Notification.Name("rivalo.startMatchFromPhone")
}

/// Sends finished sessions to the iPhone and handles remote start commands.
final class PhoneSync: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = PhoneSync()

    private enum Command {
        static let actionKey = "action"
        static let startMatch = "startMatch"
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        if session.activationState != .activated {
            session.activate()
        }
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
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    private func isStartMatch(_ payload: [String: Any]) -> Bool {
        payload[Command.actionKey] as? String == Command.startMatch
    }

    private func postStartMatch() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .rivaloStartMatchFromPhone, object: nil)
        }
    }
}
