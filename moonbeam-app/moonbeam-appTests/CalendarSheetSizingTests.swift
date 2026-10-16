import SwiftUI
import Testing
@testable import moonbeam_app

@Suite("Calendar sheet sizing")
@MainActor
struct CalendarSheetSizingTests {
    @Test("Scrolling and overscroll never change the fitted height",
          arguments: [-100.0, -66.0, 0.0, 200.0, 600.0])
    func scrollingKeepsHeight(offset: Double) {
        let geometry = ScrollGeometry(
            contentOffset: CGPoint(x: 0, y: offset),
            contentSize: CGSize(width: 359, height: 345),
            contentInsets: EdgeInsets(top: 66, leading: 0, bottom: 34, trailing: 0),
            containerSize: CGSize(width: 359, height: 300)
        )
        // Navigation space belongs in the detent; the system adds the
        // bottom safe area. Neither scroll position nor viewport does.
        #expect(CalendarSheet.fittedContentHeight(geometry) == 411)
    }

    @Test("A taller calendar updates the fitted height")
    func contentChangesUpdateHeight() {
        let geometry = ScrollGeometry(
            contentOffset: .zero,
            contentSize: CGSize(width: 359, height: 420),
            contentInsets: EdgeInsets(top: 66, leading: 0, bottom: 0, trailing: 0),
            containerSize: CGSize(width: 359, height: 300)
        )
        #expect(CalendarSheet.fittedContentHeight(geometry) == 486)
    }
}
