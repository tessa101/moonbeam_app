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
    private static let replacementAnimation = Animation.easeOut(duration: 0.2)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var isCardFocused: Bool

    var body: some View {
        ZStack {
            if let placeholder = viewModel.cardPlaceholder {
                if let layoutTable = viewModel.skeletonLayoutTable {
                    MoonCardSkeleton(
                        viewModel: viewModel,
                        layoutTable: layoutTable,
                        placeholder: placeholder
                    )
                    .transition(.opacity)
                } else if placeholder == .failed {
                    // No card to size against (nothing was showing): the
                    // message on its own.
                    LocationFailureCard()
                        .transition(.opacity)
                }
            } else if let moonTable = viewModel.moonTable {
                MoonCard(viewModel: viewModel, table: moonTable)
                    .accessibilityFocused($isCardFocused)
                    .transition(.opacity)
            } else if let layoutTable = viewModel.skeletonLayoutTable {
                // §12.9: from the first frame the old card leaves until the
                // skeleton or the new card is in, an invisible slot with the
                // replaced card's frame, so nothing below moves.
                MoonCard(viewModel: viewModel, table: layoutTable)
                    .hidden()
                    .accessibilityHidden(true)
            }
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

/// §12.3 placeholder A: the card's shape with a breathing moon outline and
/// quiet bars, so nothing moves when the real card replaces it.
private struct MoonCardSkeleton: View {

    let viewModel: LocationViewModel
    let layoutTable: MoonTableViewModel
    let placeholder: LocationViewModel.CardPlaceholder

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Constants

    /// §12.3: opacity 0.4 ↔ 0.7 over 1.6 s; still at 0.55 with Reduce Motion.
    private static let breath = Animation.easeInOut(duration: 1.6).repeatForever(autoreverses: true)
    private static let breathLow = 0.4
    private static let breathHigh = 0.7
    private static let stillOpacity = 0.55

    private static let moonSize: CGFloat = 44
    private static let moonStrokeWidth: CGFloat = 3
    private static let headerSpacing: CGFloat = 12
    private static let headerLineSpacing: CGFloat = 6
    private static let cellSpacing: CGFloat = 6
    private static let cellBarSpacing: CGFloat = 8
    private static let cellPaddingVertical: CGFloat = 8
    private static let cellPaddingHorizontal: CGFloat = 10

    private static let barHeight: CGFloat = 10
    private static let phaseBarWidth: CGFloat = 104
    private static let labelBarWidth: CGFloat = 58
    private static let timeBarWidth: CGFloat = 76
    private static let directionBarWidth: CGFloat = 48

    static let findingText = "Finding your location…"
    static let failedText = "Couldn't find your location. Try again, or search for a city."

    @State private var moonOpacity = breathLow

    // MARK: - Body

    var body: some View {
        MoonCard(viewModel: viewModel, table: layoutTable)
            .hidden()
            .accessibilityHidden(true)
            .overlay {
                skeleton
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
    }

    private var line: String {
        placeholder == .failed ? Self.failedText : Self.findingText
    }

    /// "Finding your location", without the ellipsis VoiceOver would read.
    private var accessibilityText: String {
        placeholder == .failed ? Self.failedText : "Finding your location"
    }

    private var skeleton: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.cardSpacing) {
            HStack(spacing: Self.headerSpacing) {
                moonOutline

                // §12.3: the line sits where the date line goes.
                VStack(alignment: .leading, spacing: Self.headerLineSpacing) {
                    Text(line)
                        .font(Theme.Fonts.label)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if placeholder == .finding {
                        skeletonBar(width: Self.phaseBarWidth)
                    }
                }
                Spacer(minLength: 0)
            }

            Rectangle()
                .fill(Theme.Colors.stroke)
                .frame(height: Theme.Metrics.hairline)

            HStack(spacing: Self.cellSpacing) {
                skeletonCell
                skeletonCell
            }
        }
        .padding(.vertical, Theme.Metrics.cardPaddingVertical)
        .padding(.horizontal, Theme.Metrics.cardPaddingHorizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.Colors.surface, in: cardShape)
        .overlay {
            cardShape.strokeBorder(Theme.Colors.stroke, lineWidth: Theme.Metrics.hairline)
        }
    }

    // MARK: - Pieces

    /// Breathes only while a fix is pending; a failure holds it still.
    private var moonOutline: some View {
        Circle()
            .stroke(Theme.Colors.moonEarthshine, lineWidth: Self.moonStrokeWidth)
            .frame(width: Self.moonSize, height: Self.moonSize)
            .opacity(reduceMotion || placeholder == .failed ? Self.stillOpacity : moonOpacity)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(Self.breath) {
                    moonOpacity = Self.breathHigh
                }
            }
    }

    private var skeletonCell: some View {
        VStack(alignment: .leading, spacing: Self.cellBarSpacing) {
            skeletonBar(width: Self.labelBarWidth)
            skeletonBar(width: Self.timeBarWidth)
            skeletonBar(width: Self.directionBarWidth)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Self.cellPaddingVertical)
        .padding(.horizontal, Self.cellPaddingHorizontal)
    }

    private func skeletonBar(width: CGFloat) -> some View {
        Capsule()
            .fill(Theme.Colors.surfaceRaised)
            .frame(width: width, height: Self.barHeight)
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
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
