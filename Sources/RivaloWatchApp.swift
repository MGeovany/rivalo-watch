import SwiftUI
import PostHog

@main
struct RivaloWatchApp: App {
    init() {
        Theme.registerFonts()

        let config = PostHogConfig(
            apiKey: PostHogEnv.projectToken,
            host: PostHogEnv.host
        )
        config.captureApplicationLifecycleEvents = true
        PostHogSDK.shared.setup(config)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
