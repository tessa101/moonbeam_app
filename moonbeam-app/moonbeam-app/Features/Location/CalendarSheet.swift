//
//  CalendarSheet.swift
//  moonbeam-app
//

import SwiftUI

/// The month calendar for jumping further than ‹ / › (DATE.md §2): a
/// graphical, date-only `DatePicker` limited to today ±366 days.
///
/// Tapping a date sets it and closes the sheet. Turning the month/year wheel
/// only moves the highlight, and Done confirms it. Both are decided in
/// `LocationViewModel.calendarDate`'s setter. Plain visuals, like the rest of
/// Step 2. A moon glyph per day needs a custom grid, which is V2 (§8).
struct CalendarSheet: View {

    @Bindable var viewModel: LocationViewModel
    let maximumHeight: CGFloat

    @Environment(\.dismiss) private var dismiss

    /// Stay at `.large` until the calendar and navigation area are measured.
    /// Content size is independent of scrolling; global edges are not.
    @State private var contentHeight: CGFloat?

    var body: some View {
        NavigationStack {
            ScrollView {
                DatePicker(
                    "Choose a date",
                    selection: $viewModel.calendarDate,
                    in: viewModel.calendarRange,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                // The grid shows the place's days, not the device's.
                .environment(\.timeZone, viewModel.calendarTimeZone)
                .environment(\.calendar, pickerCalendar)
                .padding(.horizontal)
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                Self.fittedContentHeight(geometry)
            } action: { _, height in
                contentHeight = height
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle("Choose a date")
            .navigationBarTitleDisplayMode(.inline)
            // Toolbar buttons stay on the system style (STEP-5.13 §4,
            // corrected 5.13.3c): any custom ButtonStyle turns a nav-bar item
            // into a squeezed custom view ("Tod…") and drops the system's
            // disabled look. The bar's glass gives the press feedback.
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // The only way back to today; nothing to do when already there.
                    Button("Today", action: viewModel.goToToday)
                        .disabled(viewModel.isOnToday)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                // Only after the wheel (or an ambiguous tap) moved the
                // highlight; a plain tap on a day picks it and closes.
                if viewModel.showsCalendarDone {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done", action: viewModel.confirmCalendarDraft)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        // Fit the calendar when it fits. Small screens fall back to the
        // system's large detent, and the ScrollView handles taller content.
        .presentationDetents([fittedDetent])
        .presentationDragIndicator(.visible)
    }

    private var fittedDetent: PresentationDetent {
        guard
            maximumHeight > 0,
            let contentHeight,
            contentHeight > 0
        else {
            return .large
        }
        guard contentHeight < maximumHeight else { return .large }
        return .height(contentHeight)
    }

    /// Include the navigation bar's inset, but leave the bottom safe area
    /// to `.height`, which adds it itself. Never include the scroll offset.
    static func fittedContentHeight(_ geometry: ScrollGeometry) -> CGFloat {
        geometry.contentSize.height + geometry.contentInsets.top
    }

    /// The user's own calendar, in the place's zone.
    private var pickerCalendar: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = viewModel.calendarTimeZone
        return calendar
    }
}
