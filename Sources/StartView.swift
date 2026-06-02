import SwiftUI

/// Home screen: start a new match.
struct StartView: View {
    @ObservedObject var manager: WorkoutManager

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: Theme.Spacing.medium)

            VStack(spacing: Theme.Spacing.small) {
                Image("Isotipo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 36)
                    .frame(maxWidth: .infinity)

                Text(manager.errorMessage ?? "Ready to play")
                    .font(Theme.Typography.body())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(manager.errorMessage == nil ? Theme.Colors.textSecondary : Theme.Colors.accent)
            }

            Spacer()

            Button {
                Task { await manager.start() }
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
}
