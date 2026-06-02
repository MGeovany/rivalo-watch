import SwiftUI

/// Routes between the home, live, and summary screens based on the workout phase.
struct ContentView: View {
    @StateObject private var manager = WorkoutManager()

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            switch manager.phase {
            case .idle:
                StartView(manager: manager)
            case .running, .paused:
                LiveWorkoutView(manager: manager)
            case .ended:
                SummaryView(manager: manager)
            }
        }
        .foregroundStyle(Theme.Colors.textPrimary)
        .onReceive(NotificationCenter.default.publisher(for: .rivaloStartMatchFromPhone)) { _ in
            guard manager.phase == .idle else { return }
            Task { await manager.start() }
        }
    }
}

#Preview {
    ContentView()
}
