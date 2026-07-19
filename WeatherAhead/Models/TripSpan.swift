import Foundation

/// A run of consecutive days at one place beyond the forecast window,
/// rendered as a single card — climate normals have monthly granularity, so
/// per-day rows there would just repeat the same numbers.
struct TripSpan: Identifiable, Hashable {
    let placeName: String
    let country: String?
    let coordinate: Coordinate?
    let startDay: Date
    let endDay: Date
    var eventTitles: [String]
    var weather: WeatherState
    /// The span's first PlaceDay as built (its weather may be stale).
    let firstDay: PlaceDay

    /// Navigation value for the existing detail screen — computed so weather
    /// updates applied to the trip reach the pushed detail, instead of
    /// freezing whatever state (often .loading) existed at build time.
    var representativeDay: PlaceDay {
        var day = firstDay
        day.weather = weather
        return day
    }

    var id: String { firstDay.id }

    var isSingleDay: Bool {
        Calendar.current.isDate(startDay, inSameDayAs: endDay)
    }
}

/// Trips beyond the forecast window, grouped under one month header.
struct MonthGroup: Identifiable {
    let monthStart: Date
    var trips: [TripSpan]

    var id: Date { monthStart }
}
