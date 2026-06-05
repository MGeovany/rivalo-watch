import Foundation
import PostHog

enum PostHogEnv {
    static var projectToken: String {
        value(forKey: "PostHogProjectToken", envKey: "POSTHOG_PROJECT_TOKEN")
    }

    static var host: String {
        value(forKey: "PostHogHost", envKey: "POSTHOG_HOST")
    }

    private static func value(forKey plistKey: String, envKey: String) -> String {
        if let bundled = Bundle.main.object(forInfoDictionaryKey: plistKey) as? String,
           !bundled.isEmpty {
            return bundled
        }
        if let env = ProcessInfo.processInfo.environment[envKey], !env.isEmpty {
            return env
        }
        fatalError("Missing PostHog config: add \(plistKey) to Info.plist or set \(envKey) in the scheme.")
    }
}

enum PostHogAnalytics {

    static func captureError(
        _ error: Error,
        context: String,
        extra: [String: Any] = [:]
    ) {
        var properties = extra
        properties["context"] = context
        properties["platform"] = "watchos"
        PostHogSDK.shared.captureException(error, properties: properties)
        PostHogSDK.shared.captureLog(
            "Watch exception captured",
            level: .error,
            attributes: properties.merging(["message": error.localizedDescription]) { _, new in new }
        )
    }

    static func captureErrorMessage(
        _ message: String,
        context: String,
        extra: [String: Any] = [:]
    ) {
        captureError(
            NSError(
                domain: "com.mgeovany.rivalo.watch",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]
            ),
            context: context,
            extra: extra
        )
    }
}
