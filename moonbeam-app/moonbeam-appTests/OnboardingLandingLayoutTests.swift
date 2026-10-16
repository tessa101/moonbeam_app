//
//  OnboardingLandingLayoutTests.swift
//  moonbeam-appTests
//

import SwiftUI
import Testing
@testable import moonbeam_app

@Suite("Onboarding landing layout")
struct OnboardingLandingLayoutTests {

    @Test("Searching art follows the shared responsive widths")
    func artWidths() {
        #expect(OnboardingLandingLayout.artSize(for: .large)?.width == 240)
        #expect(OnboardingLandingLayout.artSize(for: .xxxLarge)?.width == 160)
        #expect(OnboardingLandingLayout.artSize(for: .accessibility1)?.width == 96)
        #expect(OnboardingLandingLayout.artSize(for: .accessibility3)?.width == 96)
    }

    @Test("Searching art is hidden at AX4 and above")
    func artHiddenAtAX4() {
        #expect(OnboardingLandingLayout.artSize(for: .accessibility4) == nil)
        #expect(OnboardingLandingLayout.artSize(for: .accessibility5) == nil)
    }
}
