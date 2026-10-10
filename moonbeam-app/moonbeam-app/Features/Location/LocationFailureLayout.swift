//
//  LocationFailureLayout.swift
//  moonbeam-app
//

import CoreGraphics

/// How the failure screen fits (STEP-5.10a, "Layout"): the art's size, the
/// copy's scale, and whether only the message scrolls.
///
/// Decided from the **tallest** of the four causes' messages, not the one
/// showing, so the art frame, headline and primary button sit at the same
/// height on every cause (Tessa's decision), small screens included.
///
/// Fallback order, LOADER.md §10.5's rule: the art scales down first (240 →
/// 160 pt wide), then the copy (to 0.8×); the button stays 56 pt; if it
/// still doesn't fit, the message region scrolls.
///
/// `nonisolated`: a plain value, testable without a view.
nonisolated struct LocationFailureLayout: Equatable {

    let artSize: CGSize
    let textScale: CGFloat
    let scrollsMessage: Bool

    // MARK: - Constants

    /// The 400 × 520 art at 240 pt wide.
    static let artWidth: CGFloat = 240
    /// Small screens and large text: the art's first step down.
    static let compactArtWidth: CGFloat = 160
    /// The art's top from the screen's top (not the safe area's): the mock's
    /// 90 pt on the 393 pt screen. The art has its own margin inside.
    static let artTopFromScreenTop: CGFloat = 90
    /// The headline starts ~4 pt under the art's frame.
    static let artToHeadline: CGFloat = 4
    /// The copy's step down, as the loader's (§10.5).
    static let compactTextScale: CGFloat = 0.8
    /// The least gap between the message and the button.
    static let minimumMessageToActions: CGFloat = 24
    /// Under the link: an 18 pt spacer, then 30 pt to the screen's edge.
    static let belowLink: CGFloat = 18
    static let bottomPadding: CGFloat = 30
    /// Never closer than this to the home indicator.
    static let minimumAboveHomeIndicator: CGFloat = 8

    static let regular = LocationFailureLayout(
        artSize: artSize(width: artWidth),
        textScale: 1,
        scrollsMessage: false
    )

    // MARK: - Placement

    static func artSize(width: CGFloat) -> CGSize {
        CGSize(
            width: width,
            height: width * LocationIllustration.designSize.height / LocationIllustration.designSize.width
        )
    }

    /// The art's top inside the safe area.
    static func artTop(safeAreaTop: CGFloat) -> CGFloat {
        max(artTopFromScreenTop - safeAreaTop, 0)
    }

    /// From the safe area's bottom to the bottom of the link: the doc's 18 +
    /// 30 pt from the screen's edge, less the home indicator's inset.
    static func bottomInset(safeAreaBottom: CGFloat) -> CGFloat {
        max(belowLink + bottomPadding - safeAreaBottom, minimumAboveHomeIndicator)
    }

    /// The headline's top from the screen's top.
    func headlineTop(safeAreaTop: CGFloat) -> CGFloat {
        safeAreaTop + Self.artTop(safeAreaTop: safeAreaTop) + artSize.height + Self.artToHeadline
    }

    // MARK: - Fitting

    /// - Parameters:
    ///   - screenHeight: the whole screen's, safe areas included.
    ///   - actionsHeight: the button and link block's measured height.
    ///   - tallestMessage: the tallest cause's message at full-size copy,
    ///     and at `compactTextScale`. Zero before it's measured.
    static func resolve(
        screenHeight: CGFloat,
        safeAreaTop: CGFloat,
        safeAreaBottom: CGFloat,
        actionsHeight: CGFloat,
        tallestMessage: (regular: CGFloat, compact: CGFloat)
    ) -> LocationFailureLayout {
        guard tallestMessage.regular > 0 else { return .regular }

        let actionsTop = screenHeight - safeAreaBottom - bottomInset(safeAreaBottom: safeAreaBottom) - actionsHeight
        func room(for layout: LocationFailureLayout) -> CGFloat {
            actionsTop - minimumMessageToActions - layout.headlineTop(safeAreaTop: safeAreaTop)
        }

        if tallestMessage.regular <= room(for: .regular) { return .regular }

        let smallArt = LocationFailureLayout(
            artSize: artSize(width: compactArtWidth),
            textScale: 1,
            scrollsMessage: false
        )
        if tallestMessage.regular <= room(for: smallArt) { return smallArt }

        let smallArtAndText = LocationFailureLayout(
            artSize: smallArt.artSize,
            textScale: compactTextScale,
            scrollsMessage: false
        )
        guard tallestMessage.compact > 0, tallestMessage.compact > room(for: smallArtAndText) else {
            return smallArtAndText
        }
        return LocationFailureLayout(artSize: smallArt.artSize, textScale: compactTextScale, scrollsMessage: true)
    }
}
