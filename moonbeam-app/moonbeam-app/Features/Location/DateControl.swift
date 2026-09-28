//
//  DateControl.swift
//  moonbeam-app
//

import SwiftUI

/// The date row under the city: ‹ [📅 Sun, Sep 27 ⌄] › (DATE.md §1, §5).
/// Going back to today is the calendar sheet's Today button.
///
/// The field fills the space between the arrows, so the row doesn't shift as
/// the date text changes length.
///
/// Plain visuals, like the rest of Step 2. All decisions live in
/// `LocationViewModel`; this view only lays out and announces.
struct DateControl: View {

    let viewModel: LocationViewModel

    /// DATE.md §5: at least 44×44 pt for ‹ and ›.
    private static let minimumHitTarget: CGFloat = 44

    // MARK: - Row

    var body: some View {
        HStack(spacing: 4) {
            arrowButton("Previous day", systemImage: "chevron.left", enabled: viewModel.canGoBack) {
                viewModel.previousDay()
            }
            dateField
            arrowButton("Next day", systemImage: "chevron.right", enabled: viewModel.canGoForward) {
                viewModel.nextDay()
            }
        }
    }

    /// Opens the calendar sheet. For VoiceOver it's also adjustable: swipe
    /// up or down moves a day, and the new value is read automatically.
    private var dateField: some View {
        Button(action: viewModel.presentCalendar) {
            HStack {
                Image(systemName: "calendar")
                    .accessibilityHidden(true)
                Text(viewModel.dateLabel)
                Image(systemName: "chevron.down")
                    .accessibilityHidden(true)
            }
            // Fill the space between the arrows, content centred.
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Date")
        .accessibilityValue(viewModel.dateAccessibilityValue)
        .accessibilityHint("Opens calendar")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: viewModel.nextDay()
            case .decrement: viewModel.previousDay()
            @unknown default: break
            }
        }
    }

    private func arrowButton(
        _ title: String,
        systemImage: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            announceDate()
        } label: {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .frame(minWidth: Self.minimumHitTarget, minHeight: Self.minimumHitTarget)
                .contentShape(Rectangle())
        }
        .disabled(!enabled)
    }

    // MARK: - Accessibility

    /// DATE.md §5: changing the day with ‹ or › announces the new date. The
    /// adjustable field doesn't need this, since VoiceOver reads its new
    /// value.
    private func announceDate() {
        AccessibilityNotification.Announcement(viewModel.dateAccessibilityValue).post()
    }
}

// MARK: - Previews

#Preview("Today") {
    DateControl(viewModel: previewViewModel(dayOffset: 0))
        .padding()
}

#Preview("Picked day") {
    DateControl(viewModel: previewViewModel(dayOffset: 7))
        .padding()
}

/// A view model showing Mar Vista, moved `dayOffset` days from today.
private func previewViewModel(dayOffset: Int) -> LocationViewModel {
    let viewModel = LocationViewModel(
        locationService: FakeLocationService(),
        placeSearch: FakePlaceSearchService(),
        placeStore: InMemoryPlaceStore(),
        moonService: FakeMoonService(),
        headingService: FakeHeadingService()
    )
    viewModel.select(SpikeMoonTableViewModel.marVista)
    for _ in 0..<dayOffset {
        viewModel.nextDay()
    }
    return viewModel
}
