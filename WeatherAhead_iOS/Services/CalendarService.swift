import EventKit
import Foundation

/// A calendar event projected onto a single day.
struct EventOccurrence {
    let day: Date
    let eventTitle: String
    let locationText: String
    let coordinate: Coordinate?
    let eventStart: Date
}

final class CalendarService {
    private let store = EKEventStore()

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    func requestFullAccess() async -> Bool {
        (try? await store.requestFullAccessToEvents()) ?? false
    }

    /// All events in the range that carry a location, expanded so a multi-day
    /// event (e.g. a hotel booking) yields one occurrence per day it spans.
    func locatedOccurrences(from start: Date, to end: Date) -> [EventOccurrence] {
        guard authorizationStatus == .fullAccess else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)
        let calendar = Calendar.current

        var occurrences: [EventOccurrence] = []
        for event in events {
            let structured = event.structuredLocation
            let locationText = (structured?.title ?? event.location ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !locationText.isEmpty, let eventStart = event.startDate else { continue }

            let coordinate = structured?.geoLocation.map(Coordinate.init)
            let eventEnd = event.endDate ?? eventStart

            var firstDay = calendar.startOfDay(for: eventStart)
            var lastDay = calendar.startOfDay(for: eventEnd)
            // An event ending exactly at midnight doesn't occupy that day.
            if lastDay > firstDay && eventEnd == lastDay {
                lastDay = calendar.date(byAdding: .day, value: -1, to: lastDay) ?? firstDay
            }
            firstDay = max(firstDay, calendar.startOfDay(for: start))
            lastDay = min(lastDay, calendar.startOfDay(for: end))

            var day = firstDay
            while day <= lastDay {
                occurrences.append(EventOccurrence(
                    day: day,
                    eventTitle: event.title ?? "",
                    locationText: locationText,
                    coordinate: coordinate,
                    eventStart: eventStart
                ))
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }
        return occurrences
    }

    /// The earliest located event after the given date (looking ~3 years out,
    /// within EventKit's 4-year predicate limit) — powers the timeline footer.
    func nextLocatedEvent(after date: Date) -> (title: String, start: Date)? {
        guard authorizationStatus == .fullAccess,
              let horizon = Calendar.current.date(byAdding: .year, value: 3, to: date) else { return nil }
        let predicate = store.predicateForEvents(withStart: date, end: horizon, calendars: nil)
        let event = store.events(matching: predicate)
            .filter { event in
                let text = (event.structuredLocation?.title ?? event.location ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return !text.isEmpty
            }
            .min { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }
        guard let event, let start = event.startDate else { return nil }
        return (event.title ?? String(localized: "Trip"), start)
    }
}
