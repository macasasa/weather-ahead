#if DEBUG
import EventKit
import Foundation

/// Dev-only: launch with `--seed-demo-events` (and calendar access already
/// granted, e.g. `simctl privacy … grant calendar`) to fill the simulator
/// calendar with events that exercise every timeline case.
enum DemoSeeder {
    static func seedIfRequested() async {
        guard CommandLine.arguments.contains("--seed-demo-events") else { return }
        guard !UserDefaults.standard.bool(forKey: "didSeedDemoEvents.v3") else { return }

        let store = EKEventStore()
        var granted = EKEventStore.authorizationStatus(for: .event) == .fullAccess
        if !granted {
            granted = (try? await store.requestFullAccessToEvents()) ?? false
        }
        guard granted else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        func day(_ offset: Int, hour: Int) -> Date {
            calendar.date(byAdding: DateComponents(day: offset, hour: hour), to: today)!
        }

        // (title, location, start, end) — two places in one day, a multi-day
        // hotel stay, a horizon-edge day (+10), a seasonal-range event (+30),
        // and one beyond the 1-year window (+400) for the footer.
        let samples: [(String, String, Date, Date)] = [
            ("Leaving home", "Espoo, Finland", day(1, hour: 8), day(1, hour: 9)),
            ("Train to Joensuu", "Joensuu, Finland", day(1, hour: 12), day(1, hour: 16)),
            ("Hotel Atlas", "Kauppakatu 32, Joensuu, Finland", day(2, hour: 14), day(5, hour: 12)),
            // Near-term, in a timezone west of the device: exercises the
            // day-range padding in WeatherProvider (a place one hour behind
            // used to lose the last requested day of its forecast).
            ("Meeting in Berlin", "Berlin, Germany", day(5, hour: 10), day(6, hour: 16)),
            ("Day trip to Kuopio", "Kuopio, Finland", day(10, hour: 9), day(10, hour: 20)),
            ("Conference in Berlin", "Berlin, Germany", day(30, hour: 9), day(31, hour: 17)),
            ("Honeymoon in Kyoto", "Kyoto, Japan", day(400, hour: 10), day(407, hour: 12)),
        ]

        for (title, location, start, end) in samples {
            let event = EKEvent(eventStore: store)
            event.title = title
            event.location = location
            event.startDate = start
            event.endDate = end
            event.calendar = store.defaultCalendarForNewEvents
            try? store.save(event, span: .thisEvent)
        }
        UserDefaults.standard.set(true, forKey: "didSeedDemoEvents.v3")
    }
}
#endif
