//
//  OnboardingLandingLayout.swift
//  moonbeam-app
//

import SwiftUI

/// Responsive searching-cat sizing for the landing screen (STEP-5.14 §1).
/// It follows the failure-screen art steps while leaving the shared page
/// scrollable, so the primary action remains reachable at every text size.
nonisolated enum OnboardingLandingLayout {

    static let topSpacing: CGFloat = 24
    static let artToTextSpacing: CGFloat = 4

    static func artSize(for dynamicTypeSize: DynamicTypeSize) -> CGSize? {
        if dynamicTypeSize >= .accessibility4 {
            return nil
        }
        if dynamicTypeSize.isAccessibilitySize {
            return LocationFailureLayout.artSize(width: LocationFailureLayout.accessibilityArtWidth)
        }
        if dynamicTypeSize >= .xxxLarge {
            return LocationFailureLayout.artSize(width: LocationFailureLayout.compactArtWidth)
        }
        return LocationFailureLayout.artSize(width: LocationFailureLayout.artWidth)
    }
}
