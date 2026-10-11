//
//  LocationFailureLayout.swift
//  moonbeam-app
//

import CoreGraphics

/// How the failure screen fits (STEP-5.10a, "Layout"): the art's size (or
/// none), the copy's scale, and whether only the message scrolls.
///
/// Decided from the **tallest** of the four causes' messages, not the one
/// showing, so the art frame, headline and primary button sit at the same
/// height on every cause (Tessa's decision), small screens included.
///
/// Fallback order, each step only if the one before doesn't fit: the art
/// scales down (240 → 160 pt wide), then the copy (to 0.8×); at
/// accessibility sizes the art drops on to ~96 pt, and from AX4 it's hidden
/// (Tessa, 2026-10-10: the SE 3 at AX5 had ~1.5 lines of headline left).
/// Only then does the message region scroll. The button stays 56 pt and
/// always on screen.
///
/// `nonisolated`: a plain value, testable without a view.
nonisolated struct LocationFailureLayout: Equatable {

    /// How large the text is, for the steps only large text may take.
    enum TextSize: Equatable {
        /// Up to xxxLarge.
        case standard
        /// AX1–AX3: the art may drop to ~96 pt.
        case accessibility
        /// AX4 and AX5: the art may also be hidden.
        case largeAccessibility
    }

    /// `nil`: hidden.
    let artSize: CGSize?
    let textScale: CGFloat
    let scrollsMessage: Bool

    // MARK: - Constants

    /// The 400 × 520 art at 240 pt wide.
    static let artWidth: CGFloat = 240
    /// Small screens and large text: the art's first step down.
    static let compactArtWidth: CGFloat = 160
    /// Accessibility sizes: the art's last step before it's hidden.
    static let accessibilityArtWidth: CGFloat = 96
    /// The art's top from the screen's top (not the safe area's): the mock's
    /// 90 pt on the 393 pt screen. The art has its own margin inside. With
    /// the art hidden, the headline starts here.
    static let artTopFromScreenTop: CGFloat = 90
    /// The headline starts ~4 pt under the art's frame.
    static let artToHeadline: CGFloat = 4
    /// The copy's step down, as the loader's (§10.5).
    static let compactTextScale: CGFloat = 0.8
    /// The least gap between the message and the button.
    static let minimumMessageToActions: CGFloat = 24
    /// STEP-5.10a Layout: 6 pt from the button to the link. The loader's
    /// messages use it too, so their actions sit at the same heights
    /// (Chunk 2b).
    static let buttonToLink: CGFloat = 6
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

    /// The art's top (or, with no art, the headline's) inside the safe area.
    static func artTop(safeAreaTop: CGFloat) -> CGFloat {
        max(artTopFromScreenTop - safeAreaTop, 0)
    }

    /// From the safe area's bottom to the bottom of the link: the doc's 18 +
    /// 30 pt from the screen's edge, less the home indicator's inset.
    static func bottomInset(safeAreaBottom: CGFloat) -> CGFloat {
        max(belowLink + bottomPadding - safeAreaBottom, minimumAboveHomeIndicator)
    }

    /// The art's frame for the loader's moon to sit in, so the moon
    /// screens line up with these (Chunk 2b): full size, or the compact
    /// step's when the loader's message needs the room.
    static func artFrameSize(compact: Bool) -> CGSize {
        artSize(width: compact ? compactArtWidth : artWidth)
    }

    /// The headline's top inside the safe area, under an art frame of
    /// `artHeight`.
    static func headlineTop(underArtOfHeight artHeight: CGFloat, safeAreaTop: CGFloat) -> CGFloat {
        artTop(safeAreaTop: safeAreaTop) + artHeight + artToHeadline
    }

    /// The headline's top from the screen's top.
    func headlineTop(safeAreaTop: CGFloat) -> CGFloat {
        let art = artSize.map { $0.height + Self.artToHeadline } ?? 0
        return safeAreaTop + Self.artTop(safeAreaTop: safeAreaTop) + art
    }

    // MARK: - Fitting

    /// The steps `textSize` may take, most preferred first. The last is
    /// also the one that scrolls when nothing fits.
    static func steps(for textSize: TextSize) -> [LocationFailureLayout] {
        func step(_ width: CGFloat?, _ scale: CGFloat) -> LocationFailureLayout {
            LocationFailureLayout(artSize: width.map(artSize(width:)), textScale: scale, scrollsMessage: false)
        }
        var steps = [
            step(artWidth, 1),
            step(compactArtWidth, 1),
            step(compactArtWidth, compactTextScale),
        ]
        if textSize != .standard {
            steps.append(step(accessibilityArtWidth, compactTextScale))
        }
        if textSize == .largeAccessibility {
            steps.append(step(nil, compactTextScale))
        }
        return steps
    }

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
        tallestMessage: (regular: CGFloat, compact: CGFloat),
        textSize: TextSize = .standard
    ) -> LocationFailureLayout {
        guard tallestMessage.regular > 0 else { return .regular }

        let actionsTop = screenHeight - safeAreaBottom - bottomInset(safeAreaBottom: safeAreaBottom) - actionsHeight
        func fits(_ layout: LocationFailureLayout) -> Bool {
            let height = layout.textScale == 1 ? tallestMessage.regular : tallestMessage.compact
            // Not measured at this scale yet: assume it fits for now.
            guard height > 0 else { return true }
            return height <= actionsTop - minimumMessageToActions - layout.headlineTop(safeAreaTop: safeAreaTop)
        }

        let steps = steps(for: textSize)
        if let fitting = steps.first(where: fits) { return fitting }
        // Nothing fits: only the message scrolls, at the last step.
        let last = steps.last ?? .regular
        return LocationFailureLayout(artSize: last.artSize, textScale: last.textScale, scrollsMessage: true)
    }
}
