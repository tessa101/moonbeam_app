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

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
            .navigationTitle("Choose a date")
            .navigationBarTitleDisplayMode(.inline)
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
        // §2: medium, or large when Dynamic Type needs the room.
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium])
        .presentationDragIndicator(.visible)
    }

    /// The user's own calendar, in the place's zone.
    private var pickerCalendar: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = viewModel.calendarTimeZone
        return calendar
    }
}
