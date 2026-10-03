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
        /// The Up now row's fill, a step up from `surface` (COMPASS-1.1.md §3).
        static let surfaceInset = Color(hex: 0x251C22)
        /// Decorative marks only, under 3:1: the moon-down dot (§3), the
        /// dial's 2° ticks and its crosshair (COMPASS-1.1.md §4).
        static let faint = Color(hex: 0x5E4D57)
        /// The dial's 10° ticks and degree numbers (COMPASS-1.1.md §4):
        /// 5.1:1 on `dialTop`, 5.9:1 on `dialBottom`.
        static let dialNumber = Color(hex: 0xA8939C)
        /// Card border, hairlines, onboarding info box border.
        static let stroke = Color(hex: 0x3D3139)
        /// ‹ › and secondary-button border.
        static let strokeRaised = Color(hex: 0x4A3B45)
        /// Body text, times, headings.
        static let textPrimary = Color(hex: 0xF5EADB)
        /// Labels: "↑ Moonrise", the card's date, "75% lit".
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
        /// Tightened in 5.4.6 (COMPASS-1.1.md §9.2): 16 / 18 / 14 before.
        static let cardPaddingVertical: CGFloat = 12
        static let cardPaddingHorizontal: CGFloat = 12
        static let cardSpacing: CGFloat = 10

        /// ‹ › (§2): a 32 pt circle inside the 44 pt hit area.
        static let stepButtonSize: CGFloat = 32

        /// The main screen (§2 "Spacing"): side margins, the gap under the
        /// status bar, and the gaps between the sentence, card and compass.
        static let screenMargin: CGFloat = 20
        static let contentTopSpacing: CGFloat = 12
        /// Opened up in 5.4.6b (COMPASS-1.1.md §9.7): 20 / 24 before.
        static let sentenceToCard: CGFloat = 28
        static let cardToCompass: CGFloat = 32
        /// The sentence sits a little further in than the card (the HTML's
        /// `h2` margin).
        static let sentenceInset: CGFloat = 4

        /// Secondary buttons (§2): capsule, full width.
        static let secondaryButtonHeight: CGFloat = 52
        /// Primary buttons (§2): capsule, full width.
        static let primaryButtonHeight: CGFloat = 56

        /// Onboarding screens' side margins (§2, §5).
        static let onboardingMargin: CGFloat = 28
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
    /// `relativeTo:`, except the dial's numbers and target labels, which the
    /// spec fixes.
    enum Fonts {
        /// The madlib sentence. Line height is `sentenceLineHeightMultiple`.
        static let sentenceSize: CGFloat = 27
        static let sentence = Font.custom(FontName.youngSerif, size: sentenceSize, relativeTo: .title)
        /// 1.5 until 5.4.6b (COMPASS-1.1.md §9.1).
        static let sentenceLineHeightMultiple: CGFloat = 1.2
        /// At the default size the sentence's lines shrink together this
        /// far (about 19 pt) before one wraps (§3.1a).
        static let sentenceMinimumScale: CGFloat = 0.7
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

        /// Moonrise/moonset times.
        static let displaySize: CGFloat = 24
        static let display = Font.custom(FontName.youngSerif, size: displaySize, relativeTo: .title2)
        /// `display` shrunk to fit ("After midnight", COMPASS-1.1.md §9.12),
        /// still scaling with Dynamic Type.
        static func display(scale: CGFloat) -> Font {
            .custom(FontName.youngSerif, size: displaySize * scale, relativeTo: .title2)
        }
        /// A time's day period ("PM"), smaller than its digits but in the
        /// same face and text style, so the two scale together.
        static let dayPeriodScale: CGFloat = 0.6
        static let dayPeriod = Font.custom(
            FontName.youngSerif,
            size: displaySize * dayPeriodScale,
            relativeTo: .title2
        )

        /// The phase name.
        static let phaseNameSize: CGFloat = 17
        static let phaseName = Font.custom(FontName.nunitoSansSemiBold, size: phaseNameSize, relativeTo: .headline)
        /// The card header's phase line shrunk to fit one line
        /// (COMPASS-1.1.md §9.10), still scaling with Dynamic Type.
        static func phaseName(scale: CGFloat) -> Font {
            .custom(FontName.nunitoSansSemiBold, size: phaseNameSize * scale, relativeTo: .headline)
        }
        /// Body text and "No moonrise today".
        static let body = Font.custom(FontName.nunitoSansRegular, size: 17, relativeTo: .body)
        /// Primary button titles.
        static let button = Font.custom(FontName.nunitoSansBold, size: 17, relativeTo: .body)
        /// Secondary button titles (Nunito 600 in the HTML).
        static let secondaryButton = Font.custom(FontName.nunitoSansSemiBold, size: 17, relativeTo: .body)
        /// Text links ("Search for a city instead").
        static let link = Font.custom(FontName.nunitoSansSemiBold, size: 16, relativeTo: .callout)
        /// The onboarding info box ("Keep Precise Location on…"). Nunito 400
        /// at 15 in the HTML; the §2 table doesn't list it.
        static let infoNote = Font.custom(FontName.nunitoSansRegular, size: 15, relativeTo: .subheadline)
        /// The illumination line and directions ("58° ENE").
        static let detail = Font.custom(FontName.nunitoSansRegular, size: 14, relativeTo: .subheadline)
        /// The card's date label and the "↑ Moonrise" labels.
        static let label = Font.custom(FontName.nunitoSansSemiBold, size: 13, relativeTo: .footnote)
        /// Notes under the dial.
        static let note = Font.custom(FontName.nunitoSansRegular, size: 13, relativeTo: .footnote)
        /// The "!" in a note's amber circle (Nunito 700).
        static let noteMark = Font.custom(FontName.nunitoSansBold, size: 13, relativeTo: .footnote)
        /// The Up now bar's rise and set times (COMPASS-1.1.md §3).
        static let caption = Font.custom(FontName.nunitoSansRegular, size: 11, relativeTo: .caption2)

        /// Dial letters N/E/S/W, in Young Serif since Compass 1.1, scale
        /// with `.subheadline` from this size but stop at
        /// `dialLetterMaxSize`, so the dial's geometry holds at AX sizes
        /// (§4). The view scales the size and builds the font with
        /// `dialLetter(size:dialScale:)`; both sizes are for the 196 pt dial
        /// and grow with a bigger one (COMPASS-1.1.md §9.3).
        static let dialLetterSize: CGFloat = 15
        static let dialLetterMaxSize: CGFloat = 17
        static func dialLetter(size: CGFloat, dialScale: CGFloat = 1) -> Font {
            .custom(FontName.youngSerif, fixedSize: min(size, dialLetterMaxSize) * dialScale)
        }

        /// The heading readout and the lock pill: the degrees at the card's
        /// time size, the direction letters ("ENE") real capitals at 0.7x,
        /// same face and text style (COMPASS-1.1.md §9.12; 20 pt with 0.6x
        /// letters in 5.4.6b). Readout and pill match, so nothing jumps on
        /// lock.
        static let readout = display
        static let readoutDirectionScale: CGFloat = 0.7
        static let readoutDirection = Font.custom(
            FontName.youngSerif,
            size: displaySize * readoutDirectionScale,
            relativeTo: .title2
        )

        /// The dial's degree numbers (30, 60 …), fixed in size: no Dynamic
        /// Type, decorative (COMPASS-1.1.md §4).
        static let dialNumber = Font.custom(FontName.nunitoSansSemiBold, fixedSize: 11)

        /// The targets' labels outside the arc ("↑ Rise", "↓ Set", "Now"),
        /// fixed in size (COMPASS-1.1.md §5).
        static let dialTargetLabel = Font.custom(FontName.nunitoSansBold, fixedSize: 12)
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
