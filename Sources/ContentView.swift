import SwiftUI

/// Placeholder home screen for Phase 1. The real workout flow (start, live
/// metrics, finish) is implemented in a later phase.
struct ContentView: View {
    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: Theme.Spacing.medium)

                VStack(spacing: Theme.Spacing.small) {
                    Text("RIVALO")
                        .font(Theme.Typography.logo(size: 22))
                        .tracking(5)
                        .foregroundStyle(Theme.Colors.accent)

                    Text("Ready to play")
                        .font(Theme.Typography.body())
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Spacer()

                Button {
                    // Placeholder: starting a match is wired up in a later phase.
                } label: {
                    Text("Start match")
                        .font(Theme.Typography.button())
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .background(Theme.Colors.accent)
                .clipShape(Capsule())
            }
            .padding(.horizontal, Theme.Spacing.medium)
            .padding(.bottom, Theme.Spacing.small)
        }
        .foregroundStyle(Theme.Colors.textPrimary)
    }
}

#Preview {
    ContentView()
}
