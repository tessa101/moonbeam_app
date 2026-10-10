//
//  LocationIllustration.swift
//  moonbeam-app
//

import SwiftUI

/// The calico art on a location failure screen (STEP-5.10a): the cause's
/// layers from `IllustrationSpec`, stacked on the shared 400 × 520 canvas
/// (Chunk 4), still for now; Chunk 5 moves the parts. The screen only knows
/// this view. Decorative: hidden from VoiceOver.
struct LocationIllustration: View {

    /// Which drawing. Each has the moon inside it, so it takes the dimmed
    /// moon's place.
    nonisolated enum Kind: CaseIterable, Sendable {
        case locationNotFound
        case permissionOff
        case servicesOff
        case restricted

        var spec: IllustrationSpec {
            IllustrationSpec.spec(for: self)
        }
    }

    /// The art's canvas (its SVG viewBox), shared by every state, so one
    /// frame lines them all up.
    nonisolated static let designSize = IllustrationSpec.viewBox

    let kind: Kind

    var body: some View {
        ZStack {
            ForEach(kind.spec.layers, id: \.asset) { layer in
                Image(layer.asset)
                    .resizable()
            }
        }
        .aspectRatio(Self.designSize, contentMode: .fit)
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
