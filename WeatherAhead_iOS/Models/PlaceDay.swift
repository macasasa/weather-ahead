import Foundation

/// One place on one calendar day — a single row in the timeline.
struct PlaceDay: Identifiable, Hashable {
    enum Kind: Hashable {
        case event
        case currentLocation
    }

    let day: Date
    let placeName: String
    let country: String?
    let coordinate: Coordinate?
    let kind: Kind
    var eventTitles: [String]
    /// Earliest source-event start; used to order places within a day.
    var sortKey: Date
    var weather: WeatherState = .loading

    var id: String {
        let kindTag = kind == .currentLocation ? "here" : "event"
        return "\(day.timeIntervalSinceReferenceDate)|\(kindTag)|\(placeName.lowercased())"
    }
}
