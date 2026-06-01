import SwiftUI

/// Placeholder home screen for Phase 1. The real workout flow (start, live
/// metrics, finish) is implemented in a later phase.
struct ContentView: View {
    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            VStack(spacing: 12) {
                Text("RIVALO")
                    .font(Theme.Typography.logo())
                    .tracking(2)
                    .foregroundStyle(Theme.Colors.accent)

                Text("Ready to play")
                    .font(Theme.Typography.caption())
                    .foregroundStyle(Theme.Colors.textSecondary)

                Button {
                    // Placeholder: starting a match is wired up in a later phase.
                } label: {
                    Text("Start match")
                        .font(Theme.Typography.button())
                        .frame(maxWidth: .infinity)
                }
                .tint(Theme.Colors.accent)
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
