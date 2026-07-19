import Foundation
import MapKit

/// Resolves event location strings to coordinates and coordinates to place
/// names (city + country), with a persistent cache — geocoding is rate-limited,
/// so every resolution is remembered across launches.
final class GeocodingService {
    struct ResolvedPlace: Codable, Hashable {
        var name: String
        var country: String?
        var coordinate: Coordinate
    }

    /// A city + country pair without coordinates, from reverse geocoding.
    struct NamedPlace: Codable, Hashable {
        var name: String
        var country: String?
    }

    private struct ForwardEntry: Codable {
        var place: ResolvedPlace?
        var resolvedAt: Date
    }

    private struct ReverseEntry: Codable {
        var place: NamedPlace?
        var resolvedAt: Date
    }

    private struct CacheFile: Codable {
        var forward: [String: ForwardEntry] = [:]
        var reverse: [String: ReverseEntry] = [:]
    }

    private var cache = CacheFile()
    private let failureRetryInterval: TimeInterval = 7 * 24 * 3600

    private var cacheURL: URL {
        // v2: cache shape changed (country added); ignore any v1 file.
        URL.applicationSupportDirectory.appending(path: "geocode-cache-v2.json")
    }

    init() {
        if let data = try? Data(contentsOf: cacheURL),
           let stored = try? JSONDecoder().decode(CacheFile.self, from: data) {
            cache = stored
        }
    }

    /// Forward-geocode an event's location text ("Hotellitie 5, Espoo, Finland").
    func resolve(_ text: String) async -> ResolvedPlace? {
        let key = normalized(text)
        if let entry = cache.forward[key] {
            if let place = entry.place { return place }
            if Date.now.timeIntervalSince(entry.resolvedAt) < failureRetryInterval { return nil }
        }

        var place: ResolvedPlace?
        if let request = MKGeocodingRequest(addressString: text),
           let item = try? await request.mapItems.first {
            let name = item.addressRepresentations?.cityName
                ?? item.name
                ?? Self.firstComponent(of: text)
            place = ResolvedPlace(name: name,
                                  country: item.addressRepresentations?.regionName,
                                  coordinate: Coordinate(item.location))
        }
        cache.forward[key] = ForwardEntry(place: place, resolvedAt: .now)
        persist()
        return place
    }

    /// Reverse-geocode to a short place name + country ("Espoo", "Finland").
    func placeName(for coordinate: Coordinate) async -> NamedPlace? {
        let key = coordinate.cacheKey
        if let entry = cache.reverse[key] {
            if let place = entry.place { return place }
            if Date.now.timeIntervalSince(entry.resolvedAt) < failureRetryInterval { return nil }
        }

        var place: NamedPlace?
        if let request = MKReverseGeocodingRequest(location: coordinate.location),
           let item = try? await request.mapItems.first,
           let name = item.addressRepresentations?.cityName ?? item.name {
            place = NamedPlace(name: name, country: item.addressRepresentations?.regionName)
        }
        cache.reverse[key] = ReverseEntry(place: place, resolvedAt: .now)
        persist()
        return place
    }

    static func firstComponent(of text: String) -> String {
        let first = text.components(separatedBy: CharacterSet(charactersIn: ",\n")).first ?? text
        return first.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalized(_ text: String) -> String {
        text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func persist() {
        try? FileManager.default.createDirectory(at: .applicationSupportDirectory,
                                                 withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(cache) {
            try? data.write(to: cacheURL, options: .atomic)
        }
    }
}
