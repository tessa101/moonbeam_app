//
//  CompassNote.swift
//  moonbeam-app
//

import SwiftUI

/// A note under the dial (DESIGN-1.1.md §3.3): a rounded pill in `accent`
/// 10% with a 20 pt amber "!" circle and footnote text, at most 330 pt wide.
/// The design draws it for low accuracy; the same style carries Nearby,
/// Precise Location, location off, Far and the aha line (proposed in §3.3).
/// The copy is `CompassViewModel`'s, unchanged.
struct CompassNote: View {

    let text: String

    @ScaledMetric(relativeTo: .footnote) private var markSize = Self.markBaseSize

    // MARK: - Constants

    private static let markBaseSize: CGFloat = 20
    private static let maxWidth: CGFloat = 330
    private static let cornerRadius: CGFloat = 16
    private static let fillOpacity = 0.10
    private static let spacing: CGFloat = 10
    private static let paddingVertical: CGFloat = 8
    private static let paddingHorizontal: CGFloat = 14
    private static let mark = "!"

    // MARK: - Body

    var body: some View {
        HStack(alignment: .center, spacing: Self.spacing) {
            Text(Self.mark)
                .font(Theme.Fonts.noteMark)
                .foregroundStyle(Theme.Colors.onAccent)
                .frame(width: markSize, height: markSize)
                .background(Theme.Colors.accent, in: Circle())
                .accessibilityHidden(true)

            Text(text)
                .font(Theme.Fonts.note)
                .foregroundStyle(Theme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Self.paddingVertical)
        .padding(.horizontal, Self.paddingHorizontal)
        .background(
            Theme.Colors.accent.opacity(Self.fillOpacity),
            in: RoundedRectangle(cornerRadius: Self.cornerRadius)
        )
        .frame(maxWidth: Self.maxWidth)
    }
}

#Preview {
    CompassNote(text: CompassViewModel.interferenceTip)
        .padding()
        .background(Theme.Colors.bg)
}
