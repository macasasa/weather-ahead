import CoreLocation

/// A Hashable/Codable stand-in for CLLocationCoordinate2D.
nonisolated struct Coordinate: Hashable, Codable {
    var latitude: Double
    var longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(_ location: CLLocation) {
        self.init(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    /// Rounded to ~1 km so nearby lookups share cache entries and weather requests.
    var rounded: Coordinate {
        Coordinate(
            latitude: (latitude * 100).rounded() / 100,
            longitude: (longitude * 100).rounded() / 100
        )
    }

    var cacheKey: String {
        let r = rounded
        return "\(r.latitude),\(r.longitude)"
    }
}
