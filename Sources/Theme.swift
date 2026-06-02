import CoreText
import SwiftUI
import UIKit

/// Visual theme for the watch app: a dark, sporty look consistent with iOS.
enum Theme {
    private static let fontFiles = [
        "Michroma-Regular",
        "Rajdhani-Regular",
        "Rajdhani-Medium",
        "Rajdhani-SemiBold",
        "Rajdhani-Bold",
        "SpaceMono-Regular",
        "SpaceMono-Bold",
    ]

    /// Registers bundled .ttf files so `Font.custom` resolves (call once at launch).
    static func registerFonts() {
        for file in fontFiles {
            guard let url = Bundle.main.url(forResource: file, withExtension: "ttf") else { continue }
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        }
    }
    enum Colors {
        static let background = Color(red: 4 / 255, green: 5 / 255, blue: 6 / 255)
        static let surface = Color(red: 36 / 255, green: 37 / 255, blue: 38 / 255)
        static let accent = Color(red: 1.0, green: 90 / 255, blue: 0)
        static let accentBright = Color(red: 1.0, green: 157 / 255, blue: 0)
        static let textPrimary = Color(red: 245 / 255, green: 245 / 255, blue: 245 / 255)
        static let textSecondary = Color(red: 102 / 255, green: 102 / 255, blue: 102 / 255)
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

private enum ThemeFont {
    static func font(name: String, size: CGFloat) -> Font {
        if UIFont(name: name, size: size) != nil {
            return .custom(name, size: size)
        }
        return .custom(name, size: size)
    }
}
