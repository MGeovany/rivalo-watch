import SwiftUI

/// Visual theme for the watch app: a dark, sporty look consistent with iOS.
enum Theme {
    enum Colors {
        static let background = Color(red: 0.05, green: 0.06, blue: 0.07)
        static let surface = Color(red: 0.11, green: 0.12, blue: 0.14)
        /// Brand primary (#ff571b) — logo, buttons, and highlights.
        static let accent = Color(red: 1.0, green: 87 / 255, blue: 27 / 255)
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

        static func logo(size: CGFloat = 20) -> Font {
            ThemeFont.font(name: Family.logo, size: size)
        }

        static func title(size: CGFloat = 16) -> Font {
            ThemeFont.font(name: Family.rajdhaniSemiBold, size: size)
        }

        static func button(size: CGFloat = 15) -> Font {
            ThemeFont.font(name: Family.rajdhaniSemiBold, size: size)
        }

        static func body(size: CGFloat = 14) -> Font {
            ThemeFont.font(name: Family.rajdhaniRegular, size: size)
        }

        static func caption(size: CGFloat = 13) -> Font {
            ThemeFont.font(name: Family.rajdhaniMedium, size: size)
        }

        static func metric(size: CGFloat = 28) -> Font {
            ThemeFont.font(name: Family.spaceMonoBold, size: size)
        }

        static func statLabel(size: CGFloat = 12) -> Font {
            ThemeFont.font(name: Family.spaceMonoRegular, size: size)
        }
    }

    enum Spacing {
        static let small: CGFloat = 6
        static let medium: CGFloat = 10
        static let large: CGFloat = 16
    }

    enum Radius {
        static let button: CGFloat = 20
    }
}
