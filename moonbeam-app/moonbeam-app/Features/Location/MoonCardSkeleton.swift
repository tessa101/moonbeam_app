//
//  MoonCardSkeleton.swift
//  moonbeam-app
//

import SwiftUI

/// LOADER.md §12.2–12.3, §12.9: the card's slot on the main screen. Holds the
/// real card, the skeleton during a slow explicit location replacement, or
/// before the skeleton an empty slot of the same size. The
/// prior card is used only as an invisible size template; none of its
/// content or accessibility survives.
struct PlaceCardRegion: View {

    let viewModel: LocationViewModel

    /// §12.2 step 4: the skeleton cross-fades into the real card.
    private static let replacementAnimation = Animation.easeOut(duration: 0.5)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var isCardFocused: Bool

    /// Fade plus the usual 8 pt rise (an offset: nothing else moves).
    private var riseTransition: AnyTransition {
        .opacity.combined(with: .offset(y: ContentLoadIn.rise))
    }

    /// 5.10a.6: the card lands just after the city line begins.
    /// Reduce Motion keeps its existing instant swap.
    private func landingTransition(_ transition: AnyTransition) -> AnyTransition {
        reduceMotion ? .identity : transition.animation(ContentLoadIn.cardLandingAnimation)
    }

    var body: some View {
        let isReplacing = viewModel.isReplacingPlace
        ZStack {
            if let placeholder = viewModel.cardPlaceholder {
                if let layoutTable = viewModel.skeletonLayoutTable {
                    MoonCardSkeleton(
                        viewModel: viewModel,
                        layoutTable: layoutTable,
                        placeholder: placeholder
                    )
                    // Appears at once; leaves slowly, over the card's own
                    // frame, while the content rises in beneath it.
                    .transition(.asymmetric(insertion: .opacity, removal: landingTransition(.opacity)))
                    .zIndex(1)
                } else if placeholder == .failed {
                    // No card to size against (nothing was showing): the
                    // message on its own.
                    LocationFailureCard()
                        .transition(.opacity)
                }
            } else if let moonTable = viewModel.moonTable {
                MoonCard(viewModel: viewModel, table: moonTable)
                    .accessibilityFocused($isCardFocused)
                    // The whole card moves in, like the compass does (Tessa,
                    // 2026-10-09); the replaced place's card is gone at once.
                    .transition(.asymmetric(insertion: landingTransition(riseTransition), removal: .identity))
            } else if let layoutTable = viewModel.skeletonLayoutTable {
                // §12.9: from the first frame the old card leaves until the
                // skeleton or the new card is in, an invisible slot with the
                // replaced card's frame, so nothing below moves.
                MoonCard(viewModel: viewModel, table: layoutTable)
                    .hidden()
                    .accessibilityHidden(true)
            }
        }
        // 5.10a.7: the moment a replacement begins, the old card goes and
        // the skeleton shows in one frame, whatever animation is in flight
        // (the search sheet's dismissal included). A removal that merely
        // animates as `.identity` would leave the old card on screen for
        // the whole animation. Innermost, so it wins over the two below.
        .transaction(value: isReplacing) { transaction in
            if isReplacing { transaction.disablesAnimations = true }
        }
        .animation(reduceMotion ? nil : Self.replacementAnimation, value: viewModel.cardPlaceholder)
        .animation(reduceMotion ? nil : Self.replacementAnimation, value: viewModel.moonTable != nil)
        .accessibilityElement(children: .contain)
        // §12.3: VoiceOver focus moves from the skeleton to the card when it
        // lands.
        .onChange(of: viewModel.cardPlaceholder) { previous, current in
            if previous != nil, current == nil, viewModel.moonTable != nil {
                isCardFocused = true
            }
        }
    }
}

/// §12.3 placeholder A (5.10a.3): the card's shape drawn as quiet blocks
/// where the moon, the two header lines, ‹ › and the rise/set cells go, with
/// a shimmer sweeping across them. No text while finding, so the real card's
/// text never ghosts through the cross-fade. A failure keeps the blocks still
/// and says so in the header's place.
private struct MoonCardSkeleton: View {

    let viewModel: LocationViewModel
    let layoutTable: MoonTableViewModel
    let placeholder: LocationViewModel.CardPlaceholder

    // MARK: - Constants

    private static let moonSize: CGFloat = 44
    private static let stepButtonSize: CGFloat = 32
    private static let stepButtonSpacing: CGFloat = 8
    private static let headerSpacing: CGFloat = 12
    private static let headerLineSpacing: CGFloat = 8
    private static let cellSpacing: CGFloat = 6
    private static let cellBarSpacing: CGFloat = 8
    private static let cellPaddingVertical: CGFloat = 8
    private static let cellPaddingHorizontal: CGFloat = 10

    private static let dateBarWidth: CGFloat = 96
    private static let dateBarHeight: CGFloat = 10
    private static let phaseBarWidth: CGFloat = 160
    private static let phaseBarHeight: CGFloat = 14
    private static let labelBarWidth: CGFloat = 58
    private static let labelBarHeight: CGFloat = 10
    private static let timeBarWidth: CGFloat = 92
    private static let timeBarHeight: CGFloat = 22
    private static let directionBarWidth: CGFloat = 48
    private static let directionBarHeight: CGFloat = 10

    static let failedText = "Couldn't find your location. Try again, or search for a city."
    private static let findingAccessibilityText = "Finding your location"

    // MARK: - Body

    var body: some View {
        MoonCard(viewModel: viewModel, table: layoutTable)
            .hidden()
            .accessibilityHidden(true)
            .overlay {
                skeleton
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(placeholder == .failed ? Self.failedText : Self.findingAccessibilityText)
    }

    private var isFinding: Bool { placeholder == .finding }

    private var skeleton: some View {
        // The blocks shimmer; the card's frame and divider are the rough
        // outline of the real card.
        VStack(alignment: .leading, spacing: Theme.Metrics.cardSpacing) {
            header
            Rectangle()
                .fill(Theme.Colors.stroke)
                .frame(height: Theme.Metrics.hairline)
            HStack(spacing: Self.cellSpacing) {
                skeletonCell
                skeletonCell
            }
        }
        .shimmering(isActive: isFinding)
        .padding(.vertical, Theme.Metrics.cardPaddingVertical)
        .padding(.horizontal, Theme.Metrics.cardPaddingHorizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.Colors.surface, in: cardShape)
        .overlay {
            cardShape.strokeBorder(Theme.Colors.stroke, lineWidth: Theme.Metrics.hairline)
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(spacing: Self.headerSpacing) {
            Circle()
                .fill(Theme.Colors.surfaceRaised)
                .frame(width: Self.moonSize, height: Self.moonSize)

            if isFinding {
                VStack(alignment: .leading, spacing: Self.headerLineSpacing) {
                    skeletonBar(width: Self.dateBarWidth, height: Self.dateBarHeight)
                    skeletonBar(width: Self.phaseBarWidth, height: Self.phaseBarHeight)
                }
            } else {
                Text(Self.failedText)
                    .font(Theme.Fonts.label)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)

            HStack(spacing: Self.stepButtonSpacing) {
                Circle().fill(Theme.Colors.surfaceRaised)
                    .frame(width: Self.stepButtonSize, height: Self.stepButtonSize)
                Circle().fill(Theme.Colors.surfaceRaised)
                    .frame(width: Self.stepButtonSize, height: Self.stepButtonSize)
            }
        }
    }

    private var skeletonCell: some View {
        VStack(alignment: .leading, spacing: Self.cellBarSpacing) {
            skeletonBar(width: Self.labelBarWidth, height: Self.labelBarHeight)
            skeletonBar(width: Self.timeBarWidth, height: Self.timeBarHeight)
            skeletonBar(width: Self.directionBarWidth, height: Self.directionBarHeight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Self.cellPaddingVertical)
        .padding(.horizontal, Self.cellPaddingHorizontal)
    }

    private func skeletonBar(width: CGFloat, height: CGFloat) -> some View {
        Capsule()
            .fill(Theme.Colors.surfaceRaised)
            .frame(width: width, height: height)
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
    }
}

// MARK: - Shimmer

/// A soft highlight sweeping left to right across a view's opaque parts
/// (the skeleton's blocks), never beyond them. Reduce Motion: still blocks.
private struct Shimmer: ViewModifier {

    let isActive: Bool

    private static let sweep = Animation.linear(duration: 1.4).repeatForever(autoreverses: false)
    /// The highlight's width, as a share of the view's.
    private static let bandShare: CGFloat = 0.6
    private static let highlightOpacity = 0.10

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -Shimmer.bandShare

    func body(content: Content) -> some View {
        content
            .overlay {
                if isActive, !reduceMotion {
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [.clear, Theme.Colors.textPrimary.opacity(Self.highlightOpacity), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: proxy.size.width * Self.bandShare)
                        .offset(x: phase * proxy.size.width)
                    }
                    .mask(content)
                    .allowsHitTesting(false)
                    .onAppear {
                        withAnimation(Self.sweep) { phase = 1 }
                    }
                }
            }
    }
}

private extension View {
    func shimmering(isActive: Bool) -> some View {
        modifier(Shimmer(isActive: isActive))
    }
}

/// The failure line when there was no card to size the skeleton against.
private struct LocationFailureCard: View {
    var body: some View {
        Text(MoonCardSkeleton.failedText)
            .font(Theme.Fonts.body)
            .foregroundStyle(Theme.Colors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Theme.Metrics.cardPaddingVertical)
            .padding(.horizontal, Theme.Metrics.cardPaddingHorizontal)
            .background(
                Theme.Colors.surface,
                in: RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
            )
    }
}
