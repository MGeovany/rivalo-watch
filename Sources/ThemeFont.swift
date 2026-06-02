import CoreText
import SwiftUI
import UIKit

extension Theme {
    /// Registers bundled .ttf files so `Font.custom` resolves (call once at launch).
    static func registerFonts() {
        for file in fontFiles {
            guard let url = Bundle.main.url(forResource: file, withExtension: "ttf") else { continue }
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        }
    }

    private static let fontFiles = [
        "Michroma-Regular",
        "Rajdhani-Regular",
        "Rajdhani-Medium",
        "Rajdhani-SemiBold",
        "Rajdhani-Bold",
        "SpaceMono-Regular",
        "SpaceMono-Bold",
    ]
}

enum ThemeFont {
    static func font(name: String, size: CGFloat) -> Font {
        if UIFont(name: name, size: size) != nil {
            return .custom(name, size: size)
        }
        return .custom(name, size: size)
    }
}
