import SwiftUI

/// Every condition WeatherKit reports, plus the day/night flag, resolved into
/// the one value the animated sky and palettes are built from.
///
/// Keyed off `WeatherCondition.rawValue` where available — symbol names can't
/// distinguish hail from sleet or dust from smoke — with a symbol-name
/// fallback for rows cached before the code was stored.
enum SkyCondition: String, CaseIterable, Hashable {
    case blizzard, blowingDust, blowingSnow, breezy, clear, cloudy, drizzle
    case flurries, foggy, freezingDrizzle, freezingRain, frigid, hail, haze
    case heavyRain, heavySnow, hot, hurricane, isolatedThunderstorms
    case mostlyClear, mostlyCloudy, partlyCloudy, rain, scatteredThunderstorms
    case sleet, smoky, snow, strongStorms, sunFlurries, sunShowers
    case thunderstorms, tropicalStorm, windy, wintryMix

    static func from(code: String, symbolName: String) -> SkyCondition {
        if let exact = SkyCondition(rawValue: code) { return exact }
        // Fallback for summaries cached before conditionCode existed.
        let s = symbolName.lowercased()
        if s.contains("bolt") { return .thunderstorms }
        if s.contains("snow") || s.contains("flurries") { return .snow }
        if s.contains("sleet") { return .sleet }
        if s.contains("hail") { return .hail }
        if s.contains("drizzle") { return .drizzle }
        if s.contains("rain") { return .rain }
        if s.contains("fog") { return .foggy }
        if s.contains("haze") { return .haze }
        if s.contains("smoke") { return .smoky }
        if s.contains("dust") { return .blowingDust }
        if s.contains("wind") || s.contains("hurricane") || s.contains("tornado") { return .windy }
        if s.contains("cloud") { return .cloudy }
        return .clear
    }

    /// Human-readable name for the effects gallery.
    var displayName: String {
        rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2",
                                      options: .regularExpression)
            .capitalized
    }

    /// Roughly how much precipitation/turbulence, 0…1 — scales particle counts.
    var severity: Double {
        switch self {
        case .drizzle, .freezingDrizzle, .flurries, .sunFlurries, .breezy: return 0.4
        case .rain, .snow, .sleet, .hail, .wintryMix, .sunShowers, .windy,
             .isolatedThunderstorms, .blowingDust, .blowingSnow: return 0.7
        case .heavyRain, .heavySnow, .freezingRain, .thunderstorms,
             .scatteredThunderstorms, .strongStorms: return 1.0
        case .blizzard, .hurricane, .tropicalStorm: return 1.25
        default: return 0.6
        }
    }
}

extension SkyCondition {
    /// The layers that make up this condition's sky, back to front.
    func layers(isNight: Bool) -> [SkyLayer] {
        switch self {
        case .clear, .mostlyClear:
            return isNight ? [.stars, .moon] : [.sun]
        case .hot:
            return [.sun, .heatHaze]
        case .frigid:
            return isNight ? [.stars, .iceCrystals] : [.iceCrystals]

        case .partlyCloudy:
            return (isNight ? [.stars, .moon] : [.sun]) + [.clouds(.light)]
        case .mostlyCloudy:
            return [.clouds(.medium)]
        case .cloudy:
            return [.clouds(.heavy)]

        case .drizzle:
            return [.clouds(.medium), .precipitation(.drizzle)]
        case .freezingDrizzle:
            return [.clouds(.medium), .precipitation(.drizzle), .iceCrystals]
        case .rain:
            return [.clouds(.medium), .precipitation(.rain)]
        case .heavyRain:
            return [.clouds(.heavy), .precipitation(.heavyRain)]
        case .freezingRain:
            return [.clouds(.heavy), .precipitation(.rain), .iceCrystals]
        case .sunShowers:
            return [.sun, .clouds(.light), .precipitation(.rain)]

        case .snow:
            return [.clouds(.medium), .precipitation(.snow)]
        case .heavySnow:
            return [.clouds(.heavy), .precipitation(.heavySnow)]
        case .flurries:
            return [.clouds(.light), .precipitation(.flurries)]
        case .sunFlurries:
            return [.sun, .clouds(.light), .precipitation(.flurries)]
        case .blowingSnow:
            return [.clouds(.medium), .precipitation(.snow), .wind(.strong)]
        case .blizzard:
            return [.clouds(.heavy), .precipitation(.heavySnow), .wind(.severe)]
        case .sleet:
            return [.clouds(.medium), .precipitation(.sleet)]
        case .wintryMix:
            return [.clouds(.medium), .precipitation(.sleet), .precipitation(.flurries)]
        case .hail:
            return [.clouds(.heavy), .precipitation(.hail)]

        case .isolatedThunderstorms:
            return [.clouds(.heavy), .precipitation(.rain), .lightning(.rare)]
        case .scatteredThunderstorms:
            return [.clouds(.heavy), .precipitation(.rain), .lightning(.occasional)]
        case .thunderstorms:
            return [.clouds(.heavy), .precipitation(.heavyRain), .lightning(.frequent)]
        case .strongStorms:
            return [.clouds(.heavy), .precipitation(.heavyRain), .wind(.strong), .lightning(.frequent)]
        case .hurricane, .tropicalStorm:
            return [.clouds(.heavy), .precipitation(.heavyRain), .wind(.severe), .lightning(.occasional)]

        case .foggy:
            return [.atmosphere(.fog)]
        case .haze:
            return (isNight ? [] : [.sun]) + [.atmosphere(.haze)]
        case .smoky:
            return [.atmosphere(.smoke)]
        case .blowingDust:
            return [.atmosphere(.dust), .wind(.strong)]

        case .breezy:
            return (isNight ? [.stars] : [.sun]) + [.clouds(.light), .wind(.gentle)]
        case .windy:
            return [.clouds(.medium), .wind(.strong)]
        }
    }

    /// Sky gradient, horizon at the bottom. Kept dark enough that white text
    /// clears WCAG AA over any of them (measured in Phase 6).
    func skyColors(isNight: Bool) -> [Color] {
        if isNight, [.clear, .mostlyClear, .partlyCloudy, .breezy, .hot, .frigid].contains(self) {
            return [rgb(0.04, 0.06, 0.20), rgb(0.10, 0.14, 0.34), rgb(0.20, 0.24, 0.44)]
        }
        switch self {
        case .clear, .mostlyClear:
            return [rgb(0.13, 0.42, 0.78), rgb(0.30, 0.60, 0.88), rgb(0.52, 0.75, 0.92)]
        case .hot:
            return [rgb(0.62, 0.36, 0.16), rgb(0.80, 0.52, 0.22), rgb(0.88, 0.68, 0.36)]
        case .frigid:
            return [rgb(0.32, 0.46, 0.60), rgb(0.46, 0.60, 0.72), rgb(0.60, 0.72, 0.80)]
        case .partlyCloudy, .breezy:
            return [rgb(0.20, 0.40, 0.62), rgb(0.35, 0.53, 0.70), rgb(0.50, 0.64, 0.76)]
        case .mostlyCloudy, .cloudy, .windy:
            return [rgb(0.26, 0.33, 0.42), rgb(0.37, 0.45, 0.54), rgb(0.48, 0.55, 0.63)]
        case .drizzle, .rain, .sunShowers, .freezingDrizzle:
            return [rgb(0.20, 0.28, 0.40), rgb(0.31, 0.42, 0.55), rgb(0.45, 0.55, 0.65)]
        case .heavyRain, .freezingRain:
            return [rgb(0.14, 0.20, 0.30), rgb(0.22, 0.31, 0.42), rgb(0.33, 0.43, 0.53)]
        case .snow, .heavySnow, .flurries, .sunFlurries, .blowingSnow, .sleet, .wintryMix:
            return [rgb(0.31, 0.40, 0.51), rgb(0.43, 0.53, 0.63), rgb(0.55, 0.64, 0.72)]
        case .blizzard:
            return [rgb(0.36, 0.44, 0.53), rgb(0.50, 0.58, 0.66), rgb(0.62, 0.69, 0.75)]
        case .hail:
            return [rgb(0.22, 0.28, 0.38), rgb(0.34, 0.41, 0.50), rgb(0.46, 0.53, 0.60)]
        case .isolatedThunderstorms, .scatteredThunderstorms, .thunderstorms,
             .strongStorms, .hurricane, .tropicalStorm:
            return [rgb(0.11, 0.11, 0.20), rgb(0.21, 0.20, 0.34), rgb(0.33, 0.31, 0.45)]
        case .foggy:
            return [rgb(0.32, 0.35, 0.39), rgb(0.43, 0.46, 0.50), rgb(0.54, 0.57, 0.60)]
        case .haze:
            return [rgb(0.42, 0.38, 0.34), rgb(0.56, 0.51, 0.44), rgb(0.68, 0.62, 0.54)]
        case .smoky:
            return [rgb(0.30, 0.28, 0.26), rgb(0.42, 0.39, 0.36), rgb(0.53, 0.50, 0.46)]
        case .blowingDust:
            return [rgb(0.44, 0.34, 0.22), rgb(0.58, 0.46, 0.30), rgb(0.70, 0.58, 0.40)]
        }
    }

    private func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(red: r, green: g, blue: b)
    }
}

/// One drawable layer of a sky.
enum SkyLayer: Hashable {
    enum CloudDensity { case light, medium, heavy }
    enum WindStrength { case gentle, strong, severe }
    enum LightningRate { case rare, occasional, frequent }
    enum AtmosphereKind { case fog, haze, smoke, dust }
    enum PrecipitationKind {
        case drizzle, rain, heavyRain, snow, heavySnow, flurries, sleet, hail
    }

    case sun
    case moon
    case stars
    case clouds(CloudDensity)
    case precipitation(PrecipitationKind)
    case lightning(LightningRate)
    case wind(WindStrength)
    case atmosphere(AtmosphereKind)
    case heatHaze
    case iceCrystals
}
