import SwiftUI

/// Visual theme for the watch app: a dark, sporty look consistent with iOS.
enum Theme {
    enum Colors {
        static let background = Color(red: 0.05, green: 0.06, blue: 0.07)
        static let surface = Color(red: 0.11, green: 0.12, blue: 0.14)
        static let accent = Color(red: 0.0, green: 0.85, blue: 0.45)
        static let textPrimary = Color.white
        static let textSecondary = Color(white: 0.65)
    }

    enum Typography {
        private enum Family {
            static let logo = "Michroma-Regular"
            static let rajdhaniRegular = "Rajdhani-Regular"
            static let rajdhaniMedium = "Rajdhani-Medium"
            static let rajdhaniSemiBold = "Rajdhani-SemiBold"
            static let rajdhaniBold = "Rajdhani-Bold"
            static let spaceMonoRegular = "SpaceMono-Regular"
            static let spaceMonoBold = "SpaceMono-Bold"
        }

        static func logo(size: CGFloat = 18) -> Font {
            .custom(Family.logo, size: size)
        }

        static func title(size: CGFloat = 16) -> Font {
            .custom(Family.rajdhaniSemiBold, size: size)
        }

        static func button(size: CGFloat = 15) -> Font {
            .custom(Family.rajdhaniSemiBold, size: size)
        }

        static func body(size: CGFloat = 14) -> Font {
            .custom(Family.rajdhaniRegular, size: size)
        }

        static func caption(size: CGFloat = 13) -> Font {
            .custom(Family.rajdhaniMedium, size: size)
        }

        static func metric(size: CGFloat = 28) -> Font {
            .custom(Family.spaceMonoBold, size: size)
        }

        static func statLabel(size: CGFloat = 12) -> Font {
            .custom(Family.spaceMonoRegular, size: size)
        }
    }
}
