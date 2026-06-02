import SwiftUI

/// Home screen: choose a mode and start a new match.
struct StartView: View {
    @ObservedObject var manager: WorkoutManager
    @State private var mode = "quick"

    private let modes: [(id: String, label: String)] = [
        ("quick", "Quick"),
        ("structured", "Structured"),
        ("training", "Training"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.small) {
                BrandLogo(style: .isotipo, height: 28)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)

                if let error = manager.errorMessage {
                    Text(error)
                        .font(Theme.Typography.caption())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.Colors.accent)
                }

                ForEach(modes, id: \.id) { item in
                    Button {
                        mode = item.id
                    } label: {
                        HStack {
                            Text(item.label)
                                .font(Theme.Typography.button(size: 15))
                            Spacer()
                            if mode == item.id {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(mode == item.id ? Color.black : Theme.Colors.textPrimary)
                    .background(mode == item.id ? Theme.Colors.accent : Theme.Colors.surface)
                    .clipShape(Capsule())
                }

                Button {
                    Task { await manager.start(mode: mode) }
                } label: {
                    Text("Start match")
                        .font(Theme.Typography.button())
                        .foregroundStyle(Theme.Colors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .overlay(Capsule().stroke(Theme.Colors.accent, lineWidth: 1.5))
                .padding(.top, 4)
            }
            .padding(.horizontal, Theme.Spacing.medium)
            .padding(.bottom, Theme.Spacing.small)
        }
    }
}
