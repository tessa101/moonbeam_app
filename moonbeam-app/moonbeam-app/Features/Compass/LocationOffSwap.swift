//
//  LocationOffSwap.swift
//  moonbeam-app
//

import Foundation

/// The swap between the location-off block and the live compass
/// (LOCATION-OFF-FLOW.md §5.2), on the app's existing timings: no new ones.
///
/// **Off to on.** The block stays, held and not interactive, while the
/// compass comes in behind it at opacity 0 and waits for its first heading.
/// Once the compass's entrance has left `.waitingForHeading` (a heading, or
/// its 0.5 s wait), one crossfade: the block out over `blockOutDuration` with
/// no rise, while the dial fades in over `CompassEntrance`'s own 300 ms with
/// its usual readout and settle. No blank slot.
///
/// **On to off.** The dial out over `dialOutDuration`, then the block in over
/// `blockInDuration` with the screen's 8 pt rise, so the two are never both at
/// full opacity. The sensors stop as before: visibility decides that, not the
/// animation.
///
/// Reduce Motion: the same fades, no rise.
///
/// Main-actor isolated (the project default), since its timings are
/// `ContentLoadIn`'s; the view model and the view are too.
struct LocationOffSwap: Equatable, Sendable {

    // MARK: - Timings (§5.2: existing ones only)

    /// The block coming in: the screen's load-in fade (LOADER.md §2.1).
    static let blockInDuration = ContentLoadIn.duration

    /// The block going: the phase cycle's fade out (LOADER.md §2.1).
    static let blockOutDuration = LaunchStage.phaseCycleFadeOutDuration

    /// The dial going, on to off: the same fade out.
    static let dialOutDuration = LaunchStage.phaseCycleFadeOutDuration

    /// On to off, the block waits for the dial to be gone.
    static let blockInDelay = dialOutDuration

    /// The dial coming in: `CompassView`'s entrance fade, unchanged.
    static let dialInDuration = ContentLoadIn.duration

    /// Where the block starts as it comes in, below its place. Reduce
    /// Motion: no rise.
    static func blockInRise(reduceMotion: Bool) -> CGFloat {
        ContentLoadIn.startOffset(reduceMotion: reduceMotion)
    }

    /// The slot's height change rides with the arriving side's fade, so the
    /// content below moves with it: the dial's 300 ms off to on, the dial's
    /// 200 ms going on to off.
    static let heightDurationLocationOn = dialInDuration
    static let heightDurationLocationOff = dialOutDuration

    // MARK: - Hand-over (off to on)

    /// The block that was showing when location came on.
    let block: LocationOffBlock

    /// The entrance generation at that moment. Only a newer entrance counts:
    /// the one in place may be left over from before location went off.
    let afterGeneration: Int

    /// The block can go once a newer entrance than the one in place when
    /// location came on is past `.waitingForHeading`: the dial is fading in.
    func isReady(for entrance: CompassEntrance) -> Bool {
        entrance.generation > afterGeneration && entrance.showsCompass
    }
}
