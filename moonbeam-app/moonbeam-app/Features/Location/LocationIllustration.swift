//
//  LocationIllustration.swift
//  moonbeam-app
//

import SwiftUI

/// The calico art on a location failure screen (STEP-5.10a, Chunk 2): for
/// now the still, from the asset catalog. The screen only knows this view,
/// so Chunk 4's layered, animated version replaces the body, not the
/// screen. Decorative: hidden from VoiceOver.
struct LocationIllustration: View {

    /// Which drawing. Each has the moon inside it, so it takes the dimmed
    /// moon's place.
    nonisolated enum Kind: CaseIterable, Sendable {
        case locationNotFound
        case permissionOff
        case servicesOff
        case restricted

        /// The still in `Assets.xcassets/LocationIllustrations`
        /// (`design/d2-luminous-calico`).
        var stillImageName: String {
            switch self {
            case .locationNotFound: "d2-location-not-found"
            case .permissionOff: "d2-permission-off"
            case .servicesOff: "d2-services-off"
            case .restricted: "d2-restricted"
            }
        }
    }

    /// The art's canvas (its SVG viewBox), shared by every state, so one
    /// frame lines them all up.
    nonisolated static let designSize = CGSize(width: 400, height: 520)

    let kind: Kind

    var body: some View {
        Image(kind.stillImageName)
            .resizable()
            .scaledToFit()
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        ForEach(LocationIllustration.Kind.allCases, id: \.self) { kind in
            LocationIllustration(kind: kind)
        }
    }
    .background { ScreenBackground() }
}
