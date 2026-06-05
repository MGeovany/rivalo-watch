# PostHog post-wizard report

The wizard has completed a deep integration of PostHog analytics into the Rivalo Watch app. The posthog-ios SDK was added via Swift Package Manager, initialized in the app entry point, and 10 events were instrumented across 5 source files covering the full match lifecycle, court measurement, and phone-initiated interactions.

## Events instrumented

| Event | Description | File |
|---|---|---|
| `match_started` | User starts a new match on the watch. Properties: `mode`, `match_type`, `surface`, `has_court` | `Sources/WorkoutManager.swift` |
| `match_paused` | User pauses an active match. Properties: `elapsed_s`, `mode` | `Sources/WorkoutManager.swift` |
| `match_resumed` | User resumes a paused match. Properties: `elapsed_s`, `mode` | `Sources/WorkoutManager.swift` |
| `first_half_ended` | User ends the first half. Properties: `elapsed_s`, `distance_m`, `mode` | `Sources/WorkoutManager.swift` |
| `second_half_started` | User starts the second half after halftime. Properties: `break_elapsed_s`, `mode` | `Sources/WorkoutManager.swift` |
| `first_half_restarted` | User discards second-half data and restarts first half. Properties: `elapsed_s`, `mode` | `Sources/WorkoutManager.swift` |
| `match_ended` | Match completes and summary is computed. Properties: `duration_s`, `distance_m`, `sprints`, `mode`, `match_type`, `surface`, `has_court`, `match_rating`, `hr_avg` | `Sources/WorkoutManager.swift` |
| `summary_viewed` | Post-match summary screen appears. Properties: `duration_s`, `mode`, `match_type`, `score_tier`, `match_rating`, `hr_avg` | `Sources/SummaryView.swift` |
| `court_saved` | User saves a measured court. Properties: `measurement_method`, `length_m`, `width_m`, `has_gps` | `Sources/CourtStore.swift` |
| `match_started_from_phone` | Match initiated remotely from the iPhone companion app | `Sources/ContentView.swift` |

## Other changes

- **`Sources/RivaloWatchApp.swift`** — Added `PostHogEnv` enum for reading credentials from Xcode scheme environment variables, and `PostHogSDK.shared.setup(config)` call in the app initializer.
- **`RivaloWatch.xcodeproj/project.pbxproj`** — Added posthog-ios 3.58.0 as a Swift Package Manager dependency (`XCRemoteSwiftPackageReference`, `XCSwiftPackageProductDependency`, `PBXBuildFile`, `PBXFrameworksBuildPhase`).
- **`RivaloWatch.xcodeproj/xcshareddata/xcschemes/RivaloWatch.xcscheme`** — Created shared Xcode scheme with `POSTHOG_PROJECT_TOKEN` and `POSTHOG_HOST` environment variable slots. Fill in the actual token value in Xcode under **Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables**.

## Next steps

We've built a dashboard and five insights to monitor user behavior:

- **Dashboard**: [Analytics basics (wizard)](https://us.posthog.com/project/455314/dashboard/1672832)
- **Matches Started** (total count): [69ipga4A](https://us.posthog.com/project/455314/insights/69ipga4A)
- **Match Completion Funnel** (start → halftime → end → summary): [eCFi9hoF](https://us.posthog.com/project/455314/insights/eCFi9hoF)
- **Match Activity Over Time** (started vs completed): [SGzJBnWV](https://us.posthog.com/project/455314/insights/SGzJBnWV)
- **Courts Measured** (by method): [5NeU5zPR](https://us.posthog.com/project/455314/insights/5NeU5zPR)
- **Match Friction — Pauses & Restarts**: [BX95ww3C](https://us.posthog.com/project/455314/insights/BX95ww3C)

### Agent skill

We've left an agent skill folder in your project at `.claude/skills/integration-swift/`. You can use this context for further agent development when using Claude Code. This will help ensure the model provides the most up-to-date approaches for integrating PostHog.
