import SwiftUI

/// Brand mark from the asset catalog (wordmark or isotipo).
struct BrandLogo: View {
    enum Style {
        case wordmark
        case isotipo
    }

    var style: Style = .isotipo
    var height: CGFloat = 36

    var body: some View {
        Image(style == .wordmark ? "Wordmark" : "Isotipo")
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .accessibilityLabel("Rivalo")
    }
}
