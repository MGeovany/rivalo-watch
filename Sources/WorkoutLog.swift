import os

/// Workout lifecycle logs — filter Console.app by subsystem `com.mgeovany.rivalo.watch`.
enum WorkoutLog {
    private static let log = Logger(
        subsystem: "com.mgeovany.rivalo.watch",
        category: "workout"
    )

    static func info(_ message: String) {
        log.info("\(message, privacy: .public)")
    }

    static func error(_ message: String) {
        log.error("\(message, privacy: .public)")
    }

    static func debug(_ message: String) {
        log.debug("\(message, privacy: .public)")
    }
}
