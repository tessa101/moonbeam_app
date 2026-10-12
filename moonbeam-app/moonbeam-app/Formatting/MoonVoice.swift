import Foundation

/// Today-only guidance. Event explanations win over phase and altitude copy;
/// every time comes from the selected place's actual events and time zone.
nonisolated struct MoonVoice {
    private let times: MoonTableFormatter
    private let compass = CompassFormatter()
    init(locale: Locale = .autoupdatingCurrent) { times = MoonTableFormatter(locale: locale) }

    func message(day: MoonDay, position: MoonPosition, pass: MoonPass?, nextRise: MoonEvent?, nextSet: MoonEvent?, exactPhase: MoonPhase?, at now: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = day.place.timeZone
        func time(_ event: MoonEvent) -> String { times.time(event.date, in: day.place.timeZone) }
        func tomorrow(_ date: Date) -> Bool {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: now) else { return false }
            return calendar.isDate(date, inSameDayAs: nextDay)
        }
        func nextRiseMessage(_ rise: MoonEvent) -> String {
            if tomorrow(rise.date) { return "Rises after midnight at \(time(rise))." }
            if !calendar.isDate(rise.date, inSameDayAs: now) { return "No moonrise today." }
            let direction = compass.spokenName(for: rise.azimuth)
            if rise.date.timeIntervalSince(now) < 60 { return "Rising now. Look \(direction)." }
            return "Up at \(time(rise)). Look \(direction)."
        }
        if day.rise == nil {
            if position.isUp, let pass,
               let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
               calendar.isDate(pass.rise.date, inSameDayAs: yesterday),
               calendar.isDate(pass.set.date, inSameDayAs: now) {
                return "Rose last night. Sets today at \(time(pass.set))."
            }
            if !position.isUp, let nextRise { return nextRiseMessage(nextRise) }
            return "No moonrise today."
        }
        if day.set == nil {
            if position.isUp, let pass, tomorrow(pass.set.date) {
                return "Stays up past midnight. Sets \(time(pass.set))."
            }
            if !position.isUp, let nextRise, let nextSet,
               calendar.isDate(nextRise.date, inSameDayAs: now),
               nextSet.date > nextRise.date, tomorrow(nextSet.date) {
                return "Up at \(time(nextRise)), until after midnight."
            }
            return "No moonset today."
        }
        if !position.isUp, let nextRise, tomorrow(nextRise.date) { return nextRiseMessage(nextRise) }
        if exactPhase == .new { return "New moon. Close to the sun, hard to spot." }
        if exactPhase == .full {
            if position.isUp { return "Full moon. A bright night for moonwatching." }
            if let nextRise { return "Full moon. Up at \(time(nextRise))." }
            return "Full moon today."
        }
        if position.isUp {
            let direction = compass.spokenName(for: position.azimuth)
            switch position.altitude {
            case ..<10: return "Low on the horizon. Find a clear view \(direction)."
            case ..<30: return "Low in the sky. Look \(direction)."
            case ..<60: return "Partway up the sky. Look \(direction)."
            case ..<80: return "High in the sky. Look \(direction)."
            default: return "Nearly overhead. Look up."
            }
        }
        if let nextRise { return nextRiseMessage(nextRise) }
        return "The moon is below the horizon."
    }
}
