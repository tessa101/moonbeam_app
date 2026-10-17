//
//  NoCityActions.swift
//  moonbeam-app
//

import SwiftUI

/// The `noCity` state's bottom block (ONBOARDING-MOD-MAIN.md): the flat
/// Enable location / Open Settings CTA, and "Start with [city]" under it.
/// What each shows is `LocationViewModel`'s call; either may be absent.
struct NoCityActions: View {

    let action: LocationViewModel.NoCityAction?
    /// The device time zone's city, or `nil` to hide the link.
    let startCity: Place?
    let onEnableLocation: () -> Void
    let onOpenSettings: () -> Void
    let onStartWithCity: () -> Void

    /// The onboarding pages' gap between the primary and the text link.
    private static let actionSpacing: CGFloat = 10
    private static let bottomPadding: CGFloat = 8

    var body: some View {
        VStack(spacing: Self.actionSpacing) {
            switch action {
            case .enableLocation:
                Button(OnboardingCopy.enableLocation, action: onEnableLocation)
                    .buttonStyle(.primary)
            case .openSettings:
                Button(OnboardingCopy.openSettings, action: onOpenSettings)
                    .buttonStyle(.primary)
            case nil:
                EmptyView()
            }
            if let startCity {
                Button(OnboardingCopy.startWith(startCity.shortName), action: onStartWithCity)
                    .buttonStyle(.textLink)
            }
        }
        .padding(.horizontal, Theme.Metrics.screenMargin)
        .padding(.bottom, Self.bottomPadding)
    }
}

#Preview {
    NoCityActions(
        action: .enableLocation,
        startCity: TimeZoneCity.losAngeles,
        onEnableLocation: {},
        onOpenSettings: {},
        onStartWithCity: {}
    )
    .background { ScreenBackground() }
}
