//
//  Theme.swift
//  moonbeam-app
//

import SwiftUI

/// Design 1.1 tokens (DESIGN-1.1.md §2): the one place colors and type are
/// defined, so views never carry raw hex values or point sizes.
///
/// Token names match the spec's tables so the two can be read side by side.
/// Dark only for 1.1; the app is forced dark in Info.plist (§11 Q1).
/// `nonisolated`: the tokens are immutable values, usable from any context.
nonisolated enum Theme {

    // MARK: - Colors

    enum Colors {
        /// Screen background and the status bar backing.
        static let bg = Color(hex: 0x1B1519)
        /// The moon card.
        static let surface = Color(hex: 0x1E171C)
        /// ‹ › buttons and secondary buttons.
        static let surfaceRaised = Color(hex: 0x2A2127)
        /// Card border, hairlines, onboarding info box border.
        static let stroke = Color(hex: 0x3D3139)
        /// ‹ › and secondary-button border.
        static let strokeRaised = Color(hex: 0x4A3B45)
        /// Body text, times, headings.
        static let textPrimary = Color(hex: 0xF5EADB)
        /// Labels: "↑ Moonrise", the card's date, "75% lit at midnight".
        static let textSecondary = Color(hex: 0xC9B7A6)
        /// Onboarding body copy.
        static let textBody = Color(hex: 0xE4D6C6)
        /// Tokens, directions, N, ↑/↓, primary buttons, the lock pill. Kept
        /// in step with the `AccentColor` asset, which is the same amber so
        /// system controls pick it up too.
        static let accent = Color(hex: 0xF2C27B)
        /// Text on amber.
        static let onAccent = Color(hex: 0x1B1519)
        /// Phase glyph and dial dots.
        static let moonLit = Color(hex: 0xF2E6CF)
        /// Dial face, a radial gradient from top to bottom.
        static let dialTop = Color(hex: 0x30252C)
        static let dialBottom = Color(hex: 0x221A1F)
        /// Dial ticks (non-text): 3.15:1 on `dialTop`, 3.6:1 on `dialBottom`,
        /// so ≥ 3:1 across the face (5.4; was `#7E6C72`, 2.997:1 on `dialTop`).
        static let tick = Color(hex: 0x807075)
    }

    // MARK: - Metrics

    /// §2 spacing and radii shared across components. Each step adds the
    /// ones it uses; values only one view needs stay in that view.
    enum Metrics {
        /// Hairlines and borders.
        static let hairline: CGFloat = 1
        /// The smallest tap target for any control.
        static let minimumHitTarget: CGFloat = 44

        /// The moon card (§2 "Card").
        static let cardCornerRadius: CGFloat = 24
        static let cardPaddingVertical: CGFloat = 16
        static let cardPaddingHorizontal: CGFloat = 18
        static let cardSpacing: CGFloat = 14

        /// ‹ › (§2): a 32 pt circle inside the 44 pt hit area.
        static let stepButtonSize: CGFloat = 32

        /// The main screen (§2 "Spacing"): side margins, the gap under the
        /// status bar, and the gaps between the sentence, card and compass.
        static let screenMargin: CGFloat = 20
        static let contentTopSpacing: CGFloat = 12
        static let sentenceToCard: CGFloat = 20
        static let cardToCompass: CGFloat = 24
        /// The sentence sits a little further in than the card (the HTML's
        /// `h2` margin).
        static let sentenceInset: CGFloat = 4

        /// Secondary buttons (§2): capsule, full width.
        static let secondaryButtonHeight: CGFloat = 52
    }

    // MARK: - Fonts

    /// PostScript names of the bundled fonts (`Resources/Fonts`, listed in
    /// `UIAppFonts`). Nunito Sans ships as three static weights rather than
    /// the variable font, so each weight is an exact name lookup.
    enum FontName {
        static let youngSerif = "YoungSerif-Regular"
        static let nunitoSansRegular = "NunitoSans-Regular"
        static let nunitoSansSemiBold = "NunitoSans-SemiBold"
        static let nunitoSansBold = "NunitoSans-Bold"

        static let all = [youngSerif, nunitoSansRegular, nunitoSansSemiBold, nunitoSansBold]
    }

    /// The type scale. Every size scales with Dynamic Type through
    /// `relativeTo:`, except the dial's ↑/↓, which the spec fixes.
    enum Fonts {
        /// The madlib sentence. Line height is `sentenceLineHeightMultiple`.
        static let sentenceSize: CGFloat = 27
        static let sentence = Font.custom(FontName.youngSerif, size: sentenceSize, relativeTo: .title)
        static let sentenceLineHeightMultiple: CGFloat = 1.5
        /// The sentence's lines shrink together this far before one wraps
        /// (§3.1a).
        static let sentenceMinimumScale: CGFloat = 0.8
        /// The sentence at an exact size: its three lines share one scale,
        /// applied by the view to the Dynamic Type size of `sentenceSize`
        /// (scaled relative to `.title`, like `sentence`).
        static func sentence(fixedSize size: CGFloat) -> Font {
            .custom(FontName.youngSerif, fixedSize: size)
        }

        /// Onboarding hero ("Moon Signal").
        static let onboardingHero = Font.custom(FontName.youngSerif, size: 40, relativeTo: .largeTitle)
        /// Onboarding screen titles.
        static let onboardingTitle = Font.custom(FontName.youngSerif, size: 30, relativeTo: .title)

        /// Moonrise/moonset times, the heading readout and the lock pill.
        static let display = Font.custom(FontName.youngSerif, size: 24, relativeTo: .title2)

        /// The phase name.
        static let phaseName = Font.custom(FontName.nunitoSansSemiBold, size: 17, relativeTo: .headline)
        /// Body text and "No moonrise today".
        static let body = Font.custom(FontName.nunitoSansRegular, size: 17, relativeTo: .body)
        /// Primary button titles.
        static let button = Font.custom(FontName.nunitoSansBold, size: 17, relativeTo: .body)
        /// Secondary button titles (Nunito 600 in the HTML).
        static let secondaryButton = Font.custom(FontName.nunitoSansSemiBold, size: 17, relativeTo: .body)
        /// Text links ("Search for a city instead").
        static let link = Font.custom(FontName.nunitoSansSemiBold, size: 16, relativeTo: .callout)
        /// The illumination line and directions ("58° ENE").
        static let detail = Font.custom(FontName.nunitoSansRegular, size: 14, relativeTo: .subheadline)
        /// The card's date label and the "↑ Moonrise" labels.
        static let label = Font.custom(FontName.nunitoSansSemiBold, size: 13, relativeTo: .footnote)
        /// Notes under the dial.
        static let note = Font.custom(FontName.nunitoSansRegular, size: 13, relativeTo: .footnote)
        /// The "!" in a note's amber circle (Nunito 700).
        static let noteMark = Font.custom(FontName.nunitoSansBold, size: 13, relativeTo: .footnote)

        /// Dial letters N/E/S/W scale with `.subheadline` from this size but
        /// stop at `dialLetterMaxSize`, so the dial's geometry holds at AX
        /// sizes (§4). The view scales the size and builds the font with
        /// `dialLetter(size:)`.
        static let dialLetterSize: CGFloat = 15
        static let dialLetterMaxSize: CGFloat = 17
        static func dialLetter(size: CGFloat) -> Font {
            .custom(FontName.nunitoSansSemiBold, fixedSize: min(size, dialLetterMaxSize))
        }

        /// The dial's ↑/↓ target labels, fixed in size.
        static let dialArrow = Font.custom(FontName.nunitoSansBold, fixedSize: 14)
    }
}

// MARK: - Hex colors

nonisolated private extension Color {

    /// sRGB from a 0xRRGGBB literal, the form the spec's tables use.
    init(hex: UInt32) {
        let channelMax = 255.0
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / channelMax,
            green: Double((hex >> 8) & 0xFF) / channelMax,
            blue: Double(hex & 0xFF) / channelMax
        )
    }
}
