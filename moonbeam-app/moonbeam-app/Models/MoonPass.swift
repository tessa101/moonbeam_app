//
//  MoonPass.swift
//  moonbeam-app
//

import Foundation

/// One trip of the moon across the sky, moonrise to moonset, with its
/// direction sampled along the way. The compass draws it as the moon arc
/// (DESIGN-1.1.md §3.3a).
///
/// The rise and set can fall on different days from the selected one: the
/// pass under way at 1 AM began the evening before. The path is sampled
/// rather than inferred from the two ends, because the short way round
/// between them is often wrong: in the southern hemisphere the moon crosses
/// the north, and near overhead it swings through a wide angle quickly.
///
/// `nonisolated`: an inert value, not main-actor state.
nonisolated struct MoonPass: Equatable, Sendable {

    /// How often the path is sampled (§3.3a: "every ~15 min"). The moon's
    /// azimuth moves about 4° in that time, except near overhead.
    static let sampleInterval: TimeInterval = 15 * 60

    let rise: MoonEvent
    let set: MoonEvent

    /// Degrees clockwise from true north, at the rise, then every
    /// `sampleInterval`, then at the set. Unwrapped: neighbours differ by
    /// less than 180°, so values can fall outside `0..<360`, and the last
    /// minus the first is the signed sweep (negative: anticlockwise, through
    /// the north).
    let path: [Double]

    /// Where `azimuth`, the moon's direction at `date`, sits along `path`:
    /// the same direction, unwrapped next to the sample nearest in time.
    func pathAzimuth(for azimuth: Double, at date: Date) -> Double {
        guard !path.isEmpty else { return azimuth }
        let elapsed = date.timeIntervalSince(rise.date) / Self.sampleInterval
        let index = min(max(Int(elapsed.rounded()), 0), path.count - 1)
        let nearest = path[index]
        return nearest + Self.signedDifference(from: nearest, to: azimuth)
    }

    // MARK: - Unwrapping

    private static let fullTurn = 360.0
    private static let halfTurn = 180.0

    /// Shifts each azimuth by whole turns so it's within half a turn of the
    /// one before: 350, 5, 20 becomes 350, 365, 380.
    static func unwrapped(_ azimuths: [Double]) -> [Double] {
        var result: [Double] = []
        result.reserveCapacity(azimuths.count)
        for azimuth in azimuths {
            guard let previous = result.last else {
                result.append(azimuth)
                continue
            }
            result.append(previous + signedDifference(from: previous, to: azimuth))
        }
        return result
    }

    /// The turn from `start` to `end` the short way, in `-180..<180`.
    private static func signedDifference(from start: Double, to end: Double) -> Double {
        let difference = (end - start).truncatingRemainder(dividingBy: fullTurn)
        if difference >= halfTurn { return difference - fullTurn }
        if difference < -halfTurn { return difference + fullTurn }
        return difference
    }
}
