//
//  LocationOffDialog.swift
//  moonbeam-app
//

import SwiftUI
import UIKit

/// The custom "Location Off" dialog from LOCATION.md §4, in its denied,
/// services-off and restricted variants, styled per LOCATION-SHEET.md (5.12a).
///
/// Custom rather than a system alert so the copy can carry the Settings path
/// and offer search as an alternative.
///
/// Every word comes from the cause's `LocationFailure`
/// (STEP-5.10a-LOCATION-CONSOLIDATION.md, Chunk 1), including the secondary's
/// "Search for a city instead", so the dialog and the failure screen say the
/// same thing.
///
/// The floating shape, inset, corners and scrim are the system sheet's (iOS 26
/// and later); this view only sets its fill, its height and what's inside.
struct LocationOffDialog: View {

    let variant: LocationViewModel.LocationOffVariant

    /// "Search for a city instead" / "Search for a city".
    let onSearch: () -> Void

    /// Called after Settings has been asked to open, so the dialog can close.
    let onOpenedSettings: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    /// The content's measured height, which the sheet's one detent fits.
    @State private var contentHeight: CGFloat = Layout.initialHeight
    /// The sheet's own bottom safe area: on Face ID iPhones the floating
    /// sheet adds about 30 pt, on the SE none.
    @State private var bottomSafeArea: CGFloat = 0

    // MARK: - Layout (LOCATION-SHEET.md §3)

    private enum Layout {
        /// Clears the system grabber (5 pt, 6 pt from the top) and the close
        /// button's visual circle.
        static let topPadding: CGFloat = 32
        static let sidePadding: CGFloat = 24
        /// Below the last action, counting the sheet's own safe area: keeps
        /// it clear of the home indicator with nothing empty beyond that.
        static let homeIndicatorClearance: CGFloat = 34
        static let titleToBody: CGFloat = 8
        static let bodyToPath: CGFloat = 16
        static let toPrimary: CGFloat = 24
        static let primaryToSecondary: CGFloat = 8

        static let pathCornerRadius: CGFloat = 20
        static let pathPadding: CGFloat = 16
        static let pathMinHeight: CGFloat = 52

        static let closeVisualSize: CGFloat = 30
        static let closeGlyphSize: CGFloat = 12
        /// The close button's visual circle sits this far from the top and
        /// trailing edges; its 44 pt target extends around it.
        static let closeEdgeInset: CGFloat = 16
        /// Keeps a wrapping title out from under the close button.
        static let titleTrailingReserve: CGFloat = 28

        /// Before the first measurement: about the denied sheet at default
        /// size, so the sheet doesn't jump much when it lands.
        static let initialHeight: CGFloat = 360
    }

    var body: some View {
        ScrollView {
            content
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    contentHeight = height
                }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.safeAreaInsets.bottom
        } action: { inset in
            bottomSafeArea = inset
        }
        // Scrolls only when the content is taller than the sheet can be
        // (large Dynamic Type sizes).
        .scrollBounceBehavior(.basedOnSize)
        .overlay(alignment: .topTrailing) { closeButton }
        .accessibilityElement(children: .contain)
        .presentationDetents([.height(contentHeight)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.Colors.surfaceRaised)
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(copy.headline)
                .font(Theme.Fonts.display)
                .themeLineHeight(Theme.Fonts.sheetTitleLineHeightMultiple)
                .foregroundStyle(Theme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, Layout.titleTrailingReserve)
                .accessibilityAddTraits(.isHeader)

            Text(copy.body)
                .font(Theme.Fonts.body)
                .themeLineHeight(Theme.Fonts.sheetBodyLineHeightMultiple)
                .foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Layout.titleToBody)

            // One pointer, not numbered steps (§2). Restricted has none.
            if let path = copy.pathChipLines?.joined(separator: " ") {
                pathGroup(path)
                    .padding(.top, Layout.bodyToPath)
            }

            actions
                .padding(.top, Layout.toPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Layout.sidePadding)
        .padding(.top, Layout.topPadding)
        .padding(.bottom, max(0, Layout.homeIndicatorClearance - bottomSafeArea))
    }

    /// An inset group rather than a pill, so it reads as a pointer, not a
    /// third action.
    private func pathGroup(_ path: String) -> some View {
        Text(path)
            .font(Theme.Fonts.sheetPath)
            .themeLineHeight(Theme.Fonts.sheetPathLineHeightMultiple)
            .foregroundStyle(Theme.Colors.textBody)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Layout.pathPadding)
            .frame(minHeight: Layout.pathMinHeight)
            .background(
                RoundedRectangle(cornerRadius: Layout.pathCornerRadius, style: .continuous)
                    .fill(Theme.Colors.surface)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(copy.pathChipAccessibilityLabel ?? path)
    }

    /// The cause's primary; for the Settings causes, search as the quieter
    /// second action. Every variant's cause has a primary; only No fix has
    /// none, and it's never a dialog.
    @ViewBuilder
    private var actions: some View {
        if let primaryTitle = copy.primaryTitle {
            VStack(spacing: Layout.primaryToSecondary) {
                if variant.offersSettings {
                    Button(primaryTitle, action: openSettings)
                        .buttonStyle(.primary)
                    Button(LocationFailure.searchInsteadTitle, action: onSearch)
                        .buttonStyle(.outlined)
                } else {
                    Button(primaryTitle, action: onSearch)
                        .buttonStyle(.primary)
                }
            }
        }
    }

    /// Dismisses like the grabber and an outside tap: no search, no Settings.
    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: Layout.closeGlyphSize, weight: .bold))
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: Layout.closeVisualSize, height: Layout.closeVisualSize)
                .background(Circle().fill(Theme.Colors.surface))
                .frame(width: Theme.Metrics.minimumHitTarget, height: Theme.Metrics.minimumHitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, closeOuterInset)
        .padding(.trailing, closeOuterInset)
        .accessibilityLabel("Close")
        // Read last: title, body, path, actions, then Close (§5).
        .accessibilitySortPriority(-1)
    }

    /// Places the 30 pt circle `closeEdgeInset` from the edges inside its
    /// 44 pt target.
    private var closeOuterInset: CGFloat {
        Layout.closeEdgeInset - (Theme.Metrics.minimumHitTarget - Layout.closeVisualSize) / 2
    }

    // MARK: - Copy

    private var copy: MessageCopy { variant.failure.copy }

    // MARK: - Actions

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
        onOpenedSettings()
    }
}

#Preview("Denied") {
    LocationOffDialog(variant: .denied, onSearch: {}, onOpenedSettings: {})
}

#Preview("Services off") {
    LocationOffDialog(variant: .servicesOff, onSearch: {}, onOpenedSettings: {})
}

#Preview("Restricted") {
    LocationOffDialog(variant: .restricted, onSearch: {}, onOpenedSettings: {})
}
