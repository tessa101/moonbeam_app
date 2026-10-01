//
//  ThemeTests.swift
//  moonbeam-appTests
//

import SwiftUI
import Testing
import UIKit
@testable import moonbeam_app

/// Guards the Design 1.1 theme (DESIGN-1.1.md §2): the bundled fonts load,
/// and the color tokens meet the contrast the spec's table claims.
@Suite("Theme")
struct ThemeTests {

    // MARK: - Fonts

    /// A missing file or `UIAppFonts` entry, or a wrong PostScript name, makes
    /// `Font.custom` silently fall back to the system font. This catches it.
    @Test("Bundled font is registered", arguments: Theme.FontName.all)
    func fontIsRegistered(name: String) {
        #expect(UIFont(name: name, size: UIFont.systemFontSize) != nil)
    }

    // MARK: - Contrast (WCAG 2.1)

    private static let textMinimum = 4.5
    private static let nonTextMinimum = 3.0

    /// Text pairs from §2's table, with the ratio it states. The ratio is
    /// checked to the table's one decimal, and must clear AA for text.
    @Test("Text color meets its documented contrast", arguments: [
        (Theme.Colors.textPrimary, Theme.Colors.bg, 15.1),
        (Theme.Colors.textPrimary, Theme.Colors.surface, 14.8),
        (Theme.Colors.textSecondary, Theme.Colors.surface, 9.0),
        (Theme.Colors.textBody, Theme.Colors.bg, 12.6),
        (Theme.Colors.accent, Theme.Colors.bg, 10.9),
        (Theme.Colors.accent, Theme.Colors.surface, 10.7),
        (Theme.Colors.onAccent, Theme.Colors.accent, 10.9)
    ])
    func textContrast(foreground: Color, background: Color, documented: Double) {
        let ratio = Self.contrast(foreground, background)
        #expect(abs(ratio - documented) < 0.1)
        #expect(ratio >= Self.textMinimum)
    }

    /// `#807075` from 5.4 (DESIGN-1.1.md §2): 3.15:1 on `dialTop`, 3.6:1 on
    /// `dialBottom`, so ticks clear 3:1 anywhere on the face (5.1's
    /// `#7E6C72` was 2.997:1 on `dialTop`).
    @Test("Dial ticks meet non-text contrast across the whole face")
    func tickContrast() {
        #expect(Self.contrast(Theme.Colors.tick, Theme.Colors.dialBottom) >= Self.nonTextMinimum)
        #expect(Self.contrast(Theme.Colors.tick, Theme.Colors.dialTop) >= Self.nonTextMinimum)
    }

    // MARK: - Helpers

    private static func contrast(_ first: Color, _ second: Color) -> Double {
        let luminances = [luminance(first), luminance(second)].sorted(by: >)
        let flare = 0.05
        return (luminances[0] + flare) / (luminances[1] + flare)
    }

    /// WCAG relative luminance, from the resolved color's linear components.
    private static func luminance(_ color: Color) -> Double {
        let resolved = color.resolve(in: EnvironmentValues())
        return 0.2126 * Double(resolved.linearRed)
            + 0.7152 * Double(resolved.linearGreen)
            + 0.0722 * Double(resolved.linearBlue)
    }
}
