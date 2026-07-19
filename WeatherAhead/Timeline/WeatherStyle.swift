import SwiftUI
import UIKit

/// The single source of truth mapping a weather condition (via its SF Symbol
/// name, which already encodes day vs. night) to the colors the glass cards
/// and charts use. Kept deliberately small and deterministic.
enum WeatherStyle {
    enum Group {
        case clearDay, clearNight, cloudy, rain, snow, fog, thunder, wind
    }

    static func group(forSymbol symbol: String) -> Group {
        let s = symbol.lowercased()
        if s.contains("bolt") || s.contains("thunder") { return .thunder }
        if s.contains("snow") || s.contains("sleet") || s.contains("hail") || s.contains("flurries") { return .snow }
        if s.contains("rain") || s.contains("drizzle") { return .rain }
        if s.contains("fog") || s.contains("haze") || s.contains("smoke") { return .fog }
        if s.contains("wind") || s.contains("hurricane") || s.contains("tornado") { return .wind }
        if s.contains("cloud") {
            return isNight(symbol: s) ? .clearNight : .cloudy
        }
        return isNight(symbol: s) ? .clearNight : .clearDay
    }

    static func isNight(symbol: String) -> Bool {
        let s = symbol.lowercased()
        return s.contains("moon") || s.contains("night") || s.contains("stars")
    }

    private nonisolated(unsafe) static var filledSymbolCache: [String: String] = [:]

    /// WeatherKit hands back outline symbols ("cloud.rain"), which render
    /// almost monochrome in `.multicolor`. The `.fill` variants carry the real
    /// palette — yellow sun, blue rain — which is what Apple's Weather shows.
    static func filledSymbol(_ name: String) -> String {
        if let cached = filledSymbolCache[name] { return cached }
        let filled = name.hasSuffix(".fill") ? name : name + ".fill"
        let resolved = UIImage(systemName: filled) != nil ? filled : name
        filledSymbolCache[name] = resolved
        return resolved
    }

    /// A faint tint for `glassEffect(.regular.tint(...))` on cards (~10%).
    static func tint(forSymbol symbol: String) -> Color {
        accent(forSymbol: symbol).opacity(0.12)
    }

    /// A stronger accent for symbols and chart strokes.
    static func accent(forSymbol symbol: String) -> Color {
        switch group(forSymbol: symbol) {
        case .clearDay:   return .orange
        case .clearNight: return .indigo
        case .cloudy:     return .gray
        case .rain:       return .blue
        case .snow:       return .cyan
        case .fog:        return Color(.systemGray)
        case .thunder:    return .purple
        case .wind:       return .teal
        }
    }

    /// A soft two-stop vertical gradient for detail backgrounds, keyed to the
    /// condition and day/night. Muted so text stays legible.
    static func backgroundGradient(forSymbol symbol: String, scheme: ColorScheme) -> LinearGradient {
        let base = accent(forSymbol: symbol)
        let topOpacity = scheme == .dark ? 0.35 : 0.22
        return LinearGradient(
            colors: [base.opacity(topOpacity), base.opacity(0.02)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// A full sky gradient (horizon at the bottom) behind the animated scene.
    /// Deeper and more saturated than `backgroundGradient`, since particles and
    /// glass cards sit on top of it.
    static func skyGradient(forSymbol symbol: String) -> LinearGradient {
        LinearGradient(colors: skyColors(forSymbol: symbol), startPoint: .top, endPoint: .bottom)
    }

    static func skyColors(forSymbol symbol: String) -> [Color] {
        switch group(forSymbol: symbol) {
        case .clearDay:
            return [Color(red: 0.16, green: 0.47, blue: 0.83),
                    Color(red: 0.44, green: 0.72, blue: 0.94),
                    Color(red: 0.73, green: 0.86, blue: 0.96)]
        case .clearNight:
            return [Color(red: 0.04, green: 0.06, blue: 0.20),
                    Color(red: 0.10, green: 0.14, blue: 0.34),
                    Color(red: 0.20, green: 0.24, blue: 0.44)]
        case .cloudy:
            return [Color(red: 0.26, green: 0.33, blue: 0.42),
                    Color(red: 0.37, green: 0.45, blue: 0.54),
                    Color(red: 0.48, green: 0.55, blue: 0.63)]
        case .rain:
            return [Color(red: 0.20, green: 0.28, blue: 0.40),
                    Color(red: 0.31, green: 0.42, blue: 0.55),
                    Color(red: 0.45, green: 0.55, blue: 0.65)]
        case .snow:
            return [Color(red: 0.31, green: 0.40, blue: 0.51),
                    Color(red: 0.43, green: 0.53, blue: 0.63),
                    Color(red: 0.55, green: 0.64, blue: 0.72)]
        case .fog:
            return [Color(red: 0.32, green: 0.35, blue: 0.39),
                    Color(red: 0.43, green: 0.46, blue: 0.50),
                    Color(red: 0.54, green: 0.57, blue: 0.60)]
        case .thunder:
            return [Color(red: 0.13, green: 0.13, blue: 0.24),
                    Color(red: 0.25, green: 0.23, blue: 0.40),
                    Color(red: 0.38, green: 0.36, blue: 0.52)]
        case .wind:
            return [Color(red: 0.24, green: 0.44, blue: 0.48),
                    Color(red: 0.39, green: 0.60, blue: 0.63),
                    Color(red: 0.60, green: 0.76, blue: 0.78)]
        }
    }

}
