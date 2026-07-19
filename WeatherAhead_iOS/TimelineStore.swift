import EventKit
import Foundation
import Observation
import OSLog

/// Composes the calendar, geocoding, location and weather services into the
/// day sections the timeline renders.
@Observable
final class TimelineStore {
    static let futureDays = 365

    var sections: [DaySection] = []
    /// Trips beyond the forecast window, one card per consecutive-day run.
    var laterGroups: [MonthGroup] = []
    var hasEventEntries = false
    /// Earliest located event beyond the 1-year window, for the footer.
    var beyondWindowEvent: (title: String, start: Date)?
    var isLoading = false
    var calendarStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    var locationAuthorized = false

    let calendarService = CalendarService()
    let geocodingService = GeocodingService()
    let weatherProvider = WeatherProvider()
    let locationService = LocationService()

    private var refreshTask: Task<Void, Never>?

    var needsCalendarAccess: Bool {
        calendarStatus != .fullAccess
    }

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "WeatherAhead",
                                    category: "timeline")

    func refresh() {
        refreshTask?.cancel()
        refreshTask = Task { await performRefresh() }
    }

    private func performRefresh(allowRetry: Bool = true) async {
        calendarStatus = calendarService.authorizationStatus
        locationAuthorized = locationService.isAuthorized
        guard calendarStatus == .fullAccess else {
            sections = []
            return
        }
        isLoading = true
        defer { isLoading = false }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let end = calendar.date(byAdding: .day, value: Self.futureDays, to: today) else { return }

        let occurrences = calendarService.locatedOccurrences(from: today, to: end)
        beyondWindowEvent = calendarService.nextLocatedEvent(after: end)

        struct EntryKey: Hashable {
            let day: Date
            let placeKey: String
        }
        var entries: [EntryKey: PlaceDay] = [:]

        for occurrence in occurrences {
            if Task.isCancelled { return }

            let name: String
            var country: String?
            let coordinate: Coordinate?
            if let known = occurrence.coordinate {
                coordinate = known
                let resolved = await geocodingService.placeName(for: known)
                name = resolved?.name ?? GeocodingService.firstComponent(of: occurrence.locationText)
                country = resolved?.country
            } else if let resolved = await geocodingService.resolve(occurrence.locationText) {
                coordinate = resolved.coordinate
                name = resolved.name
                country = resolved.country
            } else {
                coordinate = nil
                name = GeocodingService.firstComponent(of: occurrence.locationText)
            }

            let key = EntryKey(day: occurrence.day, placeKey: name.lowercased())
            if var existing = entries[key] {
                if !occurrence.eventTitle.isEmpty && !existing.eventTitles.contains(occurrence.eventTitle) {
                    existing.eventTitles.append(occurrence.eventTitle)
                }
                existing.sortKey = min(existing.sortKey, occurrence.eventStart)
                entries[key] = existing
            } else {
                entries[key] = PlaceDay(
                    day: occurrence.day,
                    placeName: name,
                    country: country,
                    coordinate: coordinate,
                    kind: .event,
                    eventTitles: occurrence.eventTitle.isEmpty ? [] : [occurrence.eventTitle],
                    sortKey: occurrence.eventStart,
                    weather: initialState(coordinate: coordinate, day: occurrence.day)
                )
            }
        }

        if locationAuthorized, let location = await locationService.currentLocation() {
            let coordinate = Coordinate(location)
            let resolved = await geocodingService.placeName(for: coordinate)
            let key = EntryKey(day: today, placeKey: "\u{0}current-location")
            entries[key] = PlaceDay(
                day: today,
                placeName: resolved?.name ?? String(localized: "Current location"),
                country: resolved?.country,
                coordinate: coordinate,
                kind: .currentLocation,
                eventTitles: [],
                sortKey: .distantPast,
                weather: initialState(coordinate: coordinate, day: today)
            )
        }

        if Task.isCancelled { return }

        // Within the forecast window: per-day sections. Beyond: one card per
        // trip (climate normals are monthly, so per-day rows would repeat).
        let lastForecastDay = calendar.date(byAdding: .day, value: WeatherProvider.forecastHorizonDays,
                                            to: today) ?? today
        let nearEntries = entries.values.filter { $0.day <= lastForecastDay }
        let laterEntries = entries.values.filter { $0.day > lastForecastDay }

        var byDay: [Date: [PlaceDay]] = [:]
        for entry in nearEntries {
            byDay[entry.day, default: []].append(entry)
        }
        if byDay[today] == nil {
            byDay[today] = []
        }
        sections = byDay.keys.sorted().map { day in
            DaySection(day: day, entries: byDay[day]!.sorted {
                ($0.sortKey, $0.placeName) < ($1.sortKey, $1.placeName)
            })
        }
        laterGroups = Self.buildMonthGroups(from: laterEntries, calendar: calendar)
        hasEventEntries = entries.values.contains { $0.kind == .event }

        var needed: [Coordinate: [Date]] = [:]
        for entry in entries.values {
            guard case .loading = entry.weather, let coordinate = entry.coordinate else { continue }
            needed[coordinate.rounded, default: []].append(entry.day)
        }

        await withTaskGroup(of: Void.self) { group in
            for (coordinate, days) in needed {
                group.addTask { @MainActor [weatherProvider] in
                    let states = await weatherProvider.summaries(for: coordinate, days: days)
                    self.apply(states, coordinate: coordinate)
                }
            }
        }

        // Transient fetch failures surface as seasonal(.forecastUnavailable)
        // or unavailable. Retry once after a pause; a new refresh (or app
        // foreground) cancels this and starts its own pass.
        guard allowRetry, !Task.isCancelled else { return }
        let needsRetry = sections.contains { section in
            section.entries.contains { entry in
                guard entry.coordinate != nil else { return false }
                switch entry.weather {
                case .seasonal(_, .forecastUnavailable), .unavailable: return true
                case .loading, .ready, .seasonal(_, .beyondForecastRange): return false
                }
            }
        }
        if needsRetry {
            Self.log.info("Near-term days missing real forecasts; retrying in 25s")
            try? await Task.sleep(for: .seconds(25))
            guard !Task.isCancelled else { return }
            await performRefresh(allowRetry: false)
        }
    }

    private func initialState(coordinate: Coordinate?, day: Date) -> WeatherState {
        guard let coordinate else { return .unavailable }
        return weatherProvider.cachedState(for: coordinate, day: day) ?? .loading
    }

    private func apply(_ states: [Date: WeatherState], coordinate: Coordinate) {
        for sectionIndex in sections.indices {
            for entryIndex in sections[sectionIndex].entries.indices {
                let entry = sections[sectionIndex].entries[entryIndex]
                guard entry.coordinate?.rounded == coordinate,
                      let state = states[entry.day] else { continue }
                sections[sectionIndex].entries[entryIndex].weather = state
            }
        }
        for groupIndex in laterGroups.indices {
            for tripIndex in laterGroups[groupIndex].trips.indices {
                let trip = laterGroups[groupIndex].trips[tripIndex]
                guard trip.coordinate?.rounded == coordinate,
                      let state = states[trip.startDay] else { continue }
                laterGroups[groupIndex].trips[tripIndex].weather = state
            }
        }
    }

    /// Collapses per-day entries into consecutive-day trips per place, grouped
    /// by the month each trip starts in.
    private static func buildMonthGroups(from entries: [PlaceDay], calendar: Calendar) -> [MonthGroup] {
        let byPlace = Dictionary(grouping: entries) { $0.placeName.lowercased() }
        var trips: [TripSpan] = []

        for (_, placeEntries) in byPlace {
            let sorted = placeEntries.sorted { $0.day < $1.day }
            var runStart = 0
            for index in sorted.indices {
                let isLast = index == sorted.count - 1
                let breaksRun = !isLast && (calendar.dateComponents(
                    [.day], from: sorted[index].day, to: sorted[index + 1].day).day ?? 0) != 1
                guard isLast || breaksRun else { continue }

                let run = Array(sorted[runStart...index])
                let first = run[0]
                var titles: [String] = []
                for entry in run where !entry.eventTitles.isEmpty {
                    for title in entry.eventTitles where !titles.contains(title) {
                        titles.append(title)
                    }
                }
                trips.append(TripSpan(
                    placeName: first.placeName,
                    country: first.country,
                    coordinate: first.coordinate,
                    startDay: first.day,
                    endDay: run[run.count - 1].day,
                    eventTitles: titles,
                    weather: first.weather,
                    firstDay: first
                ))
                runStart = index + 1
            }
        }

        let byMonth = Dictionary(grouping: trips) { trip in
            calendar.date(from: calendar.dateComponents([.year, .month], from: trip.startDay)) ?? trip.startDay
        }
        return byMonth.keys.sorted().map { month in
            MonthGroup(monthStart: month, trips: byMonth[month]!.sorted { $0.startDay < $1.startDay })
        }
    }
}
