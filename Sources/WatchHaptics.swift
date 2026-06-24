import WatchKit

/// Semantic haptic cues for match events and selections.
/// WKInterfaceDevice must be driven from the main thread; all callers are
/// SwiftUI actions or @MainActor manager code.
@MainActor
enum WatchHaptics {
    /// Light click for chips, pickers and navigation taps.
    static func selection() { play(.click) }

    /// Match kicked off (also fires when the iPhone starts the match).
    static func matchStarted() { play(.start) }

    static func paused() { play(.stop) }

    static func resumed() { play(.start) }

    /// First half ended — milestone reached.
    static func halftime() { play(.notification) }

    static func secondHalfStarted() { play(.start) }

    /// Match complete, summary ready.
    static func matchEnded() { play(.success) }

    /// Destructive action confirmed (e.g. restart first half).
    static func destructive() { play(.retry) }

    static func error() { play(.failure) }

    /// Data saved (court measurement, etc.).
    static func saved() { play(.success) }

    private static func play(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }
}
