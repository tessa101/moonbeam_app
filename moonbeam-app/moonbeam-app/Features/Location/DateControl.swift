//
//  DateControl.swift
//  moonbeam-app
//

import SwiftUI

/// The date row under the city: ‹ [📅 Today · Sat, Sep 26, 2026 ⌄] › and a
/// Today chip when off today (DATE.md §1, §5).
///
/// Plain visuals, like the rest of Step 2. All decisions live in
/// `LocationViewModel`; this view only lays out and announces.
struct DateControl: View {

    let viewModel: LocationViewModel

    /// DATE.md §5: at least 44×44 pt for ‹ and ›.
    private static let minimumHitTarget: CGFloat = 44

    var body: some View {
        // At large Dynamic Type sizes the row won't fit on one line, so the
        // chip moves under it.
        ViewThatFits(in: .horizontal) {
            HStack {
                dayRow
                todayChip
            }
            VStack(alignment: .leading) {
                dayRow
                todayChip
            }
        }
    }

    // MARK: - Row

    private var dayRow: some View {
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

    // MARK: - Today chip

    @ViewBuilder
    private var todayChip: some View {
        if viewModel.showsTodayChip {
            Button("Today") {
                viewModel.goToToday()
                announceDate()
            }
            .buttonStyle(.bordered)
            // NFR4: the bordered capsule is ~34 pt tall. Pad the tap area to
            // 44 pt without changing how it looks.
            .frame(minHeight: Self.minimumHitTarget)
            .contentShape(Rectangle())
            .accessibilityLabel("Go to today")
        }
    }

    // MARK: - Accessibility

    /// DATE.md §5: changing the day announces the new date. The adjustable
    /// field doesn't need this, since VoiceOver reads its new value.
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
        moonService: FakeMoonService()
    )
    viewModel.select(SpikeMoonTableViewModel.marVista)
    for _ in 0..<dayOffset {
        viewModel.nextDay()
    }
    return viewModel
}
