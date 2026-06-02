import Foundation
import WatchConnectivity

/// Sends a finished match summary to the paired iPhone over WatchConnectivity.
/// `transferUserInfo` queues the payload for guaranteed background delivery, so
/// the session is not lost if the phone is unreachable at the moment it ends.
final class PhoneSync: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = PhoneSync()

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

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}
}
