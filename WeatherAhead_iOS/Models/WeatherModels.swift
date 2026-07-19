import Foundation

/// A compact, Codable snapshot of one day's weather at one place. Carries the
/// full set of fields WeatherKit exposes so the detail screen can show
/// "everything" without a second fetch.
struct DailySummary: Hashable, Codable {
    var date: Date
    var symbolName: String
    /// `WeatherCondition.rawValue` — drives the animated sky precisely
    /// (symbol names can't tell hail from sleet, or dust from smoke).
    var conditionCode: String
    var conditionDescription: String
    var highCelsius: Double
    var lowCelsius: Double
    var precipitationChance: Double
    var precipitationType: String
    var precipitationAmountMm: Double
    var snowfallCm: Double
    var maxUVIndex: Int
    var uvCategory: String
    var maxHumidity: Double?
    var minHumidity: Double?
    var windKph: Double
    var windGustKph: Double?
    var windCompass: String
    var windDirectionDegrees: Double
    var moonPhaseSymbol: String?
    var moonPhaseText: String?
    var sunrise: Date?
    var sunset: Date?
    var civilDawn: Date?
    var civilDusk: Date?
}

/// One hour's weather at a place, for the detail screen's charts and strip.
struct HourSummary: Hashable, Codable, Identifiable {
    var date: Date
    var symbolName: String
    var conditionCode: String
    var temperatureCelsius: Double
    var apparentTemperatureCelsius: Double
    var precipitationChance: Double
    var precipitationAmountMm: Double
    var humidity: Double
    var dewPointCelsius: Double
    var pressureHectopascals: Double
    var pressureTrend: String
    var cloudCover: Double
    var visibilityKm: Double
    var windKph: Double
    var windGustKph: Double?
    var uvIndex: Int
    var isDaylight: Bool

    var id: Date { date }
}

/// Climate-normal averages for a place in a given month — shown for dates
/// beyond WeatherKit's forecast horizon ("Typical for mid-October").
struct SeasonalSummary: Hashable, Codable {
    /// 1-12
    var month: Int
    var averageHighCelsius: Double
    var averageLowCelsius: Double
    /// Total precipitation typically falling in this month. (The API's
    /// precipitation *probability* is "any rain at all this month" — ~100%
    /// nearly everywhere, so useless for display.)
    var averagePrecipitationAmountMm: Double
    var averageSnowfallCm: Double
}

enum WeatherState: Hashable {
    /// Why a day shows climate normals instead of a real forecast.
    enum SeasonalReason: Hashable {
        /// The date is genuinely beyond the forecast range — expected.
        case beyondForecastRange
        /// A forecast should exist but couldn't be fetched — transient.
        case forecastUnavailable
    }

    case loading
    case ready(DailySummary)
    case seasonal(SeasonalSummary, reason: SeasonalReason)
    case unavailable
}

// MARK: - Formatting helpers

enum TemperatureText {
    /// e.g. "22°". Rounded, locale-aware unit.
    static func format(celsius: Double) -> String {
        Measurement(value: celsius, unit: UnitTemperature.celsius)
            .formatted(.measurement(width: .narrow, usage: .weather,
                                    numberFormatStyle: .number.precision(.fractionLength(0))))
    }

    /// Bare rounded degree with the degree sign but no unit letter, for tight
    /// spots like chart annotations ("22°").
    static func degrees(celsius: Double) -> String {
        let localized = Measurement(value: celsius, unit: UnitTemperature.celsius)
            .converted(to: localeUnit)
        return localized.value.formatted(.number.precision(.fractionLength(0))) + "°"
    }

    /// The temperature value in the viewer's preferred unit, for charts that
    /// plot a bare number (the axis carries the unit).
    static func localeValue(celsius: Double) -> Double {
        Measurement(value: celsius, unit: UnitTemperature.celsius)
            .converted(to: localeUnit).value
    }

    static var localeUnit: UnitTemperature {
        Locale.current.measurementSystem == .metric ? .celsius : .fahrenheit
    }
}
