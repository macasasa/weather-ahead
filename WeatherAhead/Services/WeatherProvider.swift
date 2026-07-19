import Foundation
import OSLog
import WeatherKit

/// Fetches daily summaries, hourly detail, and — for dates the forecast can't
/// reach — seasonal climate normals from WeatherKit. Everything is cached on
/// disk so relaunches and scrolling don't re-request.
final class WeatherProvider {
    static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "WeatherAhead",
                            category: "weather")
    /// Apple Weather's daily forecast covers 10 days *including today*, so the
    /// last reachable day is today+9 — confirmed empirically: requesting
    /// today+10 returns 404 (same-timezone places) or only the neighboring day
    /// (overlapping timezones). Days beyond this go straight to climate
    /// normals; the response-gap fallback still catches any variance.
    static let forecastHorizonDays = 9

    private struct CachedDay: Codable {
        var summary: DailySummary
        var fetchedAt: Date
    }

    private struct CachedHourly: Codable {
        var hours: [HourSummary]
        var fetchedAt: Date
    }

    private struct CachedSeasonal: Codable {
        var summary: SeasonalSummary
        var fetchedAt: Date
    }

    private let service = WeatherService.shared
    private var dayCache: [String: CachedDay] = [:]
    private var hourlyCache: [String: CachedHourly] = [:]
    private var seasonalCache: [String: CachedSeasonal] = [:]

    private let forecastFreshness: TimeInterval = 3600
    private let hourlyFreshness: TimeInterval = 3600
    private let seasonalFreshness: TimeInterval = 30 * 24 * 3600

    private var dayCacheURL: URL { URL.applicationSupportDirectory.appending(path: "weather-cache-v3.json") }
    private var hourlyCacheURL: URL { URL.applicationSupportDirectory.appending(path: "hourly-cache-v2.json") }
    private var seasonalCacheURL: URL { URL.applicationSupportDirectory.appending(path: "seasonal-cache.json") }

    init() {
        dayCache = Self.load(dayCacheURL) ?? [:]
        hourlyCache = Self.load(hourlyCacheURL) ?? [:]
        seasonalCache = Self.load(seasonalCacheURL) ?? [:]
    }

    // MARK: - Synchronous cache reads (for instant first paint)

    func cachedState(for coordinate: Coordinate, day: Date) -> WeatherState? {
        if isBeyondHorizon(day) {
            if let cached = seasonalCache[seasonalKey(coordinate, day)] {
                return .seasonal(cached.summary, reason: .beyondForecastRange)
            }
            return nil
        }
        guard let cached = dayCache[dayKey(coordinate, day)], isFresh(cached) else { return nil }
        return .ready(cached.summary)
    }

    func cachedHourly(for coordinate: Coordinate, day: Date) -> [HourSummary]? {
        guard let cached = hourlyCache[dayKey(coordinate, day)] else { return nil }
        let isPast = day < Calendar.current.startOfDay(for: .now)
        if isPast || Date.now.timeIntervalSince(cached.fetchedAt) < hourlyFreshness {
            return cached.hours
        }
        return nil
    }

    // MARK: - Daily summaries / seasonal normals

    /// Daily state for several days at one place, batching the WeatherKit
    /// calls. Days the forecast doesn't actually cover (WeatherKit's horizon
    /// is ~10 days but varies, so any "near" day can come back missing) fall
    /// back to seasonal climate normals rather than an error.
    func summaries(for coordinate: Coordinate, days: [Date]) async -> [Date: WeatherState] {
        let calendar = Calendar.current
        var result: [Date: WeatherState] = [:]
        var forecastNeeded: [Date] = []
        // Day → why it needs climate normals; the reason reaches the UI so a
        // transient fetch failure is never presented as "no forecast exists".
        var seasonalNeeded: [Date: WeatherState.SeasonalReason] = [:]

        for day in days {
            if isBeyondHorizon(day) {
                if let cached = seasonalCache[seasonalKey(coordinate, day)], isFresh(cached) {
                    result[day] = .seasonal(cached.summary, reason: .beyondForecastRange)
                } else {
                    seasonalNeeded[day] = .beyondForecastRange
                }
            } else if let cached = dayCache[dayKey(coordinate, day)], isFresh(cached) {
                result[day] = .ready(cached.summary)
            } else {
                forecastNeeded.append(day)
            }
        }

        if let first = forecastNeeded.min(), let last = forecastNeeded.max() {
            // Pad the range: we build it from *device*-local midnights, but
            // WeatherKit snaps it to the *place's* local days. For a place west
            // of the device the window lands inside its previous local day and
            // the last day we asked for falls off the end of the response.
            // A day of slack each side covers any timezone within ±14h.
            let paddedStart = calendar.date(byAdding: .day, value: -1, to: first) ?? first
            let paddedEnd = calendar.date(byAdding: .day, value: 2, to: last) ?? last
            let fetched = await fetchDaily(coordinate: coordinate, start: paddedStart, end: paddedEnd)
            for day in forecastNeeded {
                if let summary = fetched[day] {
                    dayCache[dayKey(coordinate, day)] = CachedDay(summary: summary, fetchedAt: .now)
                    result[day] = .ready(summary)
                } else if fetched.isEmpty {
                    // Whole request failed (network/service): a forecast for
                    // this day exists, we just couldn't get it right now.
                    Self.log.info("Fetch failed for near day \(day.dayKey, privacy: .public) at \(coordinate.cacheKey, privacy: .public); showing normals until retry")
                    seasonalNeeded[day] = .forecastUnavailable
                } else {
                    // Request succeeded but this day wasn't covered — it's
                    // past the provider's actual horizon.
                    Self.log.info("Forecast gap at \(coordinate.cacheKey, privacy: .public) \(day.dayKey, privacy: .public); falling back to seasonal")
                    seasonalNeeded[day] = .beyondForecastRange
                }
            }
        }

        if !seasonalNeeded.isEmpty {
            let byMonth = await fetchSeasonal(coordinate: coordinate)
            for (day, reason) in seasonalNeeded {
                let month = calendar.component(.month, from: day)
                if let summary = byMonth[month] {
                    seasonalCache[seasonalKey(coordinate, day)] = CachedSeasonal(summary: summary, fetchedAt: .now)
                    result[day] = .seasonal(summary, reason: reason)
                } else {
                    Self.log.error("No seasonal data for \(coordinate.cacheKey, privacy: .public) month \(month); marking unavailable")
                    result[day] = .unavailable
                }
            }
        }

        persistAll()
        return result
    }

    // MARK: - Hourly detail

    func hourly(for coordinate: Coordinate, day: Date) async -> [HourSummary]? {
        if let cached = cachedHourly(for: coordinate, day: day) { return cached }

        let calendar = Calendar.current
        guard let end = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
        guard let forecast = try? await service.weather(
            for: coordinate.location,
            including: .hourly(startDate: day, endDate: end)
        ) else { return nil }

        let hours = forecast.map { hour in
            HourSummary(
                date: hour.date,
                symbolName: hour.symbolName,
                conditionCode: hour.condition.rawValue,
                temperatureCelsius: hour.temperature.converted(to: .celsius).value,
                apparentTemperatureCelsius: hour.apparentTemperature.converted(to: .celsius).value,
                precipitationChance: hour.precipitationChance,
                precipitationAmountMm: hour.precipitationAmount.converted(to: .millimeters).value,
                humidity: hour.humidity,
                dewPointCelsius: hour.dewPoint.converted(to: .celsius).value,
                pressureHectopascals: hour.pressure.converted(to: .hectopascals).value,
                pressureTrend: hour.pressureTrend.description,
                cloudCover: hour.cloudCover,
                visibilityKm: hour.visibility.converted(to: .kilometers).value,
                windKph: hour.wind.speed.converted(to: .kilometersPerHour).value,
                windGustKph: hour.wind.gust?.converted(to: .kilometersPerHour).value,
                uvIndex: hour.uvIndex.value,
                isDaylight: hour.isDaylight
            )
        }
        hourlyCache[dayKey(coordinate, day)] = CachedHourly(hours: hours, fetchedAt: .now)
        persist(hourlyCache, to: hourlyCacheURL)
        return hours
    }

    /// Currently active weather alerts for a location (most meaningful for today).
    func alerts(for coordinate: Coordinate) async -> [WeatherAlert] {
        let result = try? await service.weather(for: coordinate.location, including: .alerts)
        return result.flatMap { $0 } ?? []
    }

    var attribution: WeatherAttribution? {
        get async { try? await service.attribution }
    }

    // MARK: - WeatherKit → model

    private func fetchDaily(coordinate: Coordinate, start: Date, end: Date) async -> [Date: DailySummary] {
        let forecast: Forecast<DayWeather>
        do {
            forecast = try await service.weather(
                for: coordinate.location,
                including: .daily(startDate: start, endDate: end)
            )
        } catch {
            Self.log.error("Daily fetch failed for \(coordinate.cacheKey, privacy: .public) \(start.dayKey, privacy: .public)…\(end.dayKey, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return [:]
        }

        let calendar = Calendar.current
        var summaries: [Date: DailySummary] = [:]
        for day in forecast {
            // day.date is midnight in the *place's* timezone; keying by the
            // device-timezone civil date of the place's local noon keeps far
            // east/west places (Kyoto from Helsinki) on the right day.
            let key = calendar.startOfDay(for: day.date.addingTimeInterval(12 * 3600))
            summaries[key] = DailySummary(
                date: key,
                symbolName: day.symbolName,
                conditionCode: day.condition.rawValue,
                conditionDescription: day.condition.description,
                highCelsius: day.highTemperature.converted(to: .celsius).value,
                lowCelsius: day.lowTemperature.converted(to: .celsius).value,
                precipitationChance: day.precipitationChance,
                precipitationType: day.precipitation.description,
                precipitationAmountMm: day.precipitationAmountByType.precipitation.converted(to: .millimeters).value,
                snowfallCm: day.precipitationAmountByType.snowfallAmount.amount.converted(to: .centimeters).value,
                maxUVIndex: day.uvIndex.value,
                uvCategory: day.uvIndex.category.description,
                maxHumidity: day.maximumHumidity,
                minHumidity: day.minimumHumidity,
                windKph: day.wind.speed.converted(to: .kilometersPerHour).value,
                windGustKph: day.highWindSpeed?.converted(to: .kilometersPerHour).value,
                windCompass: day.wind.compassDirection.abbreviation,
                windDirectionDegrees: day.wind.direction.converted(to: .degrees).value,
                moonPhaseSymbol: day.moon.phase.symbolName,
                moonPhaseText: day.moon.phase.description,
                sunrise: day.sun.sunrise,
                sunset: day.sun.sunset,
                civilDawn: day.sun.civilDawn,
                civilDusk: day.sun.civilDusk
            )
        }

        // Log the days we actually got back, not just the count — a response
        // shifted by a timezone shows up here immediately.
        let covered = summaries.keys.sorted()
        let coverage = covered.isEmpty ? "none"
            : "\(covered[0].dayKey)…\(covered[covered.count - 1].dayKey)"
        Self.log.info("Daily \(coordinate.cacheKey, privacy: .public) requested \(start.dayKey, privacy: .public)…\(end.dayKey, privacy: .public): \(summaries.count) days covering \(coverage, privacy: .public)")
        return summaries
    }

    private func fetchSeasonal(coordinate: Coordinate) async -> [Int: SeasonalSummary] {
        let temperature: MonthlyWeatherStatistics<MonthTemperatureStatistics>
        let precipitation: MonthlyWeatherStatistics<MonthPrecipitationStatistics>
        do {
            (temperature, precipitation) = try await service.monthlyStatistics(
                for: coordinate.location,
                including: .temperature, .precipitation
            )
        } catch {
            Self.log.error("Seasonal fetch failed for \(coordinate.cacheKey, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return [:]
        }

        var precipByMonth: [Int: MonthPrecipitationStatistics] = [:]
        for stat in precipitation.months { precipByMonth[stat.month] = stat }

        var result: [Int: SeasonalSummary] = [:]
        for stat in temperature.months {
            let precip = precipByMonth[stat.month]
            result[stat.month] = SeasonalSummary(
                month: stat.month,
                averageHighCelsius: stat.averageHighTemperature.converted(to: .celsius).value,
                averageLowCelsius: stat.averageLowTemperature.converted(to: .celsius).value,
                averagePrecipitationAmountMm: precip?.averagePrecipitationAmount.converted(to: .millimeters).value ?? 0,
                averageSnowfallCm: precip?.averageSnowfallAmount.converted(to: .centimeters).value ?? 0
            )
        }
        return result
    }

    // MARK: - Freshness & keys

    private func isBeyondHorizon(_ day: Date) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let horizon = calendar.date(byAdding: .day, value: Self.forecastHorizonDays, to: today) else {
            return false
        }
        return day > horizon
    }

    private func isFresh(_ cached: CachedDay) -> Bool {
        Date.now.timeIntervalSince(cached.fetchedAt) < forecastFreshness
    }

    private func isFresh(_ cached: CachedSeasonal) -> Bool {
        Date.now.timeIntervalSince(cached.fetchedAt) < seasonalFreshness
    }

    private func dayKey(_ coordinate: Coordinate, _ day: Date) -> String {
        "\(coordinate.cacheKey)|\(day.dayKey)"
    }

    private func seasonalKey(_ coordinate: Coordinate, _ day: Date) -> String {
        let comps = Calendar.current.dateComponents([.year, .month], from: day)
        return "\(coordinate.cacheKey)|\(comps.year ?? 0)-\(comps.month ?? 0)"
    }

    // MARK: - Persistence

    private static func load<T: Decodable>(_ url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func persist<T: Encodable>(_ value: T, to url: URL) {
        try? FileManager.default.createDirectory(at: .applicationSupportDirectory,
                                                 withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(value) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func persistAll() {
        persist(dayCache, to: dayCacheURL)
        persist(seasonalCache, to: seasonalCacheURL)
    }
}

extension Date {
    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var dayKey: String {
        Self.dayKeyFormatter.string(from: self)
    }
}
