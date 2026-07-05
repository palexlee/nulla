//
//  Theme.swift
//  Nulla — "Soft" design system
//
//  FONT SETUP (one-time):
//  1. Download Manrope from Google Fonts and add these .ttf files to the Xcode target:
//     Manrope-Regular, Manrope-Medium, Manrope-SemiBold, Manrope-Bold, Manrope-ExtraBold
//  2. In Info.plist add key "Fonts provided by application" (UIAppFonts) and list each file.
//  3. Build. FontFace.manrope(...) will then resolve; it falls back to the system font otherwise.
//

import SwiftUI

// MARK: - Palette

enum Theme {
    // Neutrals
    static let paper    = Color(hex: 0xFAF7F1)   // app background
    static let surface  = Color(hex: 0xEFE9DD)   // quiet fills / chips
    static let surface2 = Color(hex: 0xECE6DA)    // hairline rules
    static let card     = Color.white            // review cards, sheets content
    static let ink      = Color(hex: 0x23242A)   // primary text
    static let muted    = Color(hex: 0x97928A)   // secondary text
    static let faint    = Color(hex: 0xA29C8E)   // tertiary text

    // Primary action
    static let green    = Color(hex: 0x1F6B45)
    static let onGreen  = Color(hex: 0xEAFAF0)
    static let mint     = Color(hex: 0xD6ECDD)   // green tint surface
    static let mintChip = Color(hex: 0xC7E3D0)   // DUE badge bg

    // Accents (used sparingly)
    static let butter   = Color(hex: 0xF6E6C4)
    static let onButter = Color(hex: 0x8A6318)
    static let gold     = Color(hex: 0xD6A53E)   // streak dots
    static let goldFaint = Color(hex: 0xECCF8F)

    static let lavender = Color(hex: 0xE6E0F2)
    static let onLav    = Color(hex: 0x5B45A8)

    static let coral    = Color(hex: 0xF7DDD6)
    static let onCoral  = Color(hex: 0xC04D38)

    // Radii
    static let rHero: CGFloat = 26
    static let rCard: CGFloat = 20
    static let rTile: CGFloat = 18
    static let rPill: CGFloat = 16
}

// MARK: - Hex Color

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8)  & 0xFF) / 255,
                  blue:  Double( hex        & 0xFF) / 255,
                  opacity: alpha)
    }
}

// MARK: - Typography (Manrope)

enum FontFace {
    static func manrope(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .black, .heavy:  name = "Manrope-ExtraBold"
        case .bold:           name = "Manrope-Bold"
        case .semibold:       name = "Manrope-SemiBold"
        case .medium:         name = "Manrope-Medium"
        default:              name = "Manrope-Regular"
        }
        return .custom(name, size: size)
    }
}

extension View {
    /// Convenience: `.manrope(20, .bold)`
    func manrope(_ size: CGFloat, _ weight: Font.Weight = .regular) -> some View {
        font(FontFace.manrope(size, weight))
    }
}
