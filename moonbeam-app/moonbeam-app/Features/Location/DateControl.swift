//
//  DateControl.swift
//  moonbeam-app
//

import SwiftUI

/// The calendar field under the city: [📅 Sun, Sep 27 ⌄] (DATE.md §1).
/// Going back to today is the calendar sheet's Today button.
///
/// Interim for Design 1.1: ‹ › and VoiceOver's day stepping moved to the
/// moon card's header (DESIGN-1.1.md §3.2, Step 5.2). This only opens the
/// calendar until 5.3's date token replaces it. All decisions live in
/// `LocationViewModel`.
struct DateControl: View {

    let viewModel: LocationViewModel

    var body: some View {
        Button(action: viewModel.presentCalendar) {
            HStack {
                Image(systemName: "calendar")
                    .accessibilityHidden(true)
                Text(viewModel.dateLabel)
                Image(systemName: "chevron.down")
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Date")
        .accessibilityValue(viewModel.dateAccessibilityValue)
        .accessibilityHint("Opens calendar")
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
    viewModel.select(Place.marVista)
    for _ in 0..<dayOffset {
        viewModel.nextDay()
    }
    return viewModel
}
