//
//  LocationFailureView.swift
//  moonbeam-app
//

import SwiftUI

/// Why a location search came up empty and what to do next
/// (STEP-5.10a-LOCATION-FAILURE.md, Option D): the cause's calico art in
/// the moon's place, the headline and body (and, where Settings can fix
/// it, the path there), and the buttons pinned to the bottom. No sentence
/// and no card.
///
/// The message is the same `MessageText` + `MessageActions` the launch
/// loader's messages use (LOADER.md §10.3), with this screen's spacing.
/// Copy, art and actions come from `LocationFailure`. Open Settings is
/// handled here; search goes to the caller. No fix has no button: the view
/// model looks again when the app comes back (Chunk 2b).
struct LocationFailureView: View {

    let failure: LocationFailure
    /// Search for a city instead, and restricted's Search for a city: the
    /// search sheet, field focused.
    let onSearch: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState private var headlineIsFocused: Bool

    /// The tallest cause's message at each copy scale, keyed by scale, and
    /// the action block's height: what `LocationFailureLayout` fits.
    @State private var messageHeights: [MeasureKey: CGFloat] = [:]
    @State private var actionsHeight: CGFloat = 0

    // MARK: - Constants

    /// STEP-5.10a Layout: 14 pt headline → body, 6 pt button → link.
    private static let headlineToBody: CGFloat = 14
    private static let buttonToLink: CGFloat = 6

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let top = proxy.safeAreaInsets.top
            let bottom = proxy.safeAreaInsets.bottom
            let layout = LocationFailureLayout.resolve(
                screenHeight: proxy.size.height + top + bottom,
                safeAreaTop: top,
                safeAreaBottom: bottom,
                actionsHeight: actionsHeight,
                tallestMessage: (tallest(compact: false), tallest(compact: true)),
                textSize: textSize
            )

            VStack(spacing: 0) {
                Color.clear.frame(height: LocationFailureLayout.artTop(safeAreaTop: top))
                // Hidden at AX4+ when the copy needs the room.
                if let artSize = layout.artSize {
                    LocationIllustration(kind: failure.illustration)
                        .frame(width: artSize.width, height: artSize.height)
                        .failureLoadIn(.illustration, hasPath: failure.pathChipLines != nil, isEnabled: true)
                    Color.clear.frame(height: LocationFailureLayout.artToHeadline)
                }
                message(layout)
                actions
                Color.clear.frame(height: LocationFailureLayout.bottomInset(safeAreaBottom: bottom))
            }
            .padding(.horizontal, Theme.Metrics.onboardingMargin)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .overlay {
                // At the visible copy's width, inside the same margins.
                measurements.padding(.horizontal, Theme.Metrics.onboardingMargin)
            }
        }
        .onAppear {
            // Focus moves to the headline when the screen appears.
            headlineIsFocused = true
        }
    }

    /// Which of the layout's large-text steps are allowed.
    private var textSize: LocationFailureLayout.TextSize {
        if dynamicTypeSize >= .accessibility4 { return .largeAccessibility }
        return dynamicTypeSize.isAccessibilitySize ? .accessibility : .standard
    }

    // MARK: - Message

    @ViewBuilder
    private func message(_ layout: LocationFailureLayout) -> some View {
        let text = MessageText(
            copy: failure.copy,
            textScale: layout.textScale,
            headlineToBody: Self.headlineToBody,
            headlineFocus: $headlineIsFocused,
            failureLoadIn: true
        )
        if layout.scrollsMessage {
            // §10.5: only the message region scrolls; the buttons stay put.
            ScrollView { text.frame(maxWidth: .infinity) }
                .scrollIndicators(.hidden)
            Color.clear.frame(height: LocationFailureLayout.minimumMessageToActions)
        } else {
            text
            Spacer(minLength: LocationFailureLayout.minimumMessageToActions)
        }
    }

    // MARK: - Actions

    private var actions: some View {
        MessageActions(
            copy: failure.copy,
            buttonToLink: Self.buttonToLink,
            onPrimary: primary,
            onLink: onSearch,
            failureLoadIn: true
        )
        // Its natural height always: a scrolling message above mustn't
        // squeeze the link into truncation (SE 3 at AX5).
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
            actionsHeight = height
        }
    }

    private func primary() {
        switch failure.primaryAction {
        case .openSettings:
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            openURL(url)
        case .search, .requestPermission:
            onSearch()
        case nil:
            break
        }
    }

    // MARK: - Measuring

    private struct MeasureKey: Hashable {
        let failure: LocationFailure
        let compact: Bool
    }

    private func tallest(compact: Bool) -> CGFloat {
        messageHeights.filter { $0.key.compact == compact }.values.max() ?? 0
    }

    /// Every cause's message at both scales, hidden and off the
    /// accessibility tree, reporting natural heights at the current Dynamic
    /// Type size, so the layout is the same whichever cause shows.
    private var measurements: some View {
        ZStack {
            ForEach(LocationFailure.allCases, id: \.self) { cause in
                measured(cause, compact: false)
                measured(cause, compact: true)
            }
        }
        .hidden()
        .accessibilityHidden(true)
    }

    private func measured(_ cause: LocationFailure, compact: Bool) -> some View {
        MessageText(
            copy: cause.copy,
            textScale: compact ? LocationFailureLayout.compactTextScale : 1,
            headlineToBody: Self.headlineToBody
        )
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
            messageHeights[MeasureKey(failure: cause, compact: compact)] = height
        }
    }
}

#Preview("No fix") {
    LocationFailureView(failure: .noFix, onSearch: {})
        .background { ScreenBackground() }
}

#Preview("Permission off") {
    LocationFailureView(failure: .permissionDenied, onSearch: {})
        .background { ScreenBackground() }
}

#Preview("Services off") {
    LocationFailureView(failure: .servicesOff, onSearch: {})
        .background { ScreenBackground() }
}

#Preview("Restricted") {
    LocationFailureView(failure: .restricted, onSearch: {})
        .background { ScreenBackground() }
}
