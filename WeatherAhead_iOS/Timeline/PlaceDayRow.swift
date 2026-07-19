import SwiftUI

/// One place on one day, styled after the native Weather list cell: place +
/// country and condition on the left, a large temperature on the right, all on
/// a Liquid Glass card faintly tinted by the condition.
struct PlaceDayRow: View {
    let entry: PlaceDay

    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false

    /// Cells with a real forecast get the animated sky; other states keep the
    /// quiet glass treatment so they read as "no weather here yet".
    private var sceneSummary: DailySummary? {
        if case .ready(let summary) = entry.weather { return summary }
        return nil
    }

    private var sceneSymbol: String? { sceneSummary?.symbolName }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            leadingSymbol
            textColumn
            Spacer(minLength: 8)
            trailing
                .foregroundStyle(textStyle)
                .shadow(color: textShadow, radius: 3, y: 1)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { cardBackground }
        .clipShape(.rect(cornerRadius: 22))
        .contentShape(.rect(cornerRadius: 22))
        .onScrollVisibilityChange(threshold: 0.01) { visible in
            // Guard: assigning every frame trips SwiftUI's
            // "tried to update multiple times per frame" warning.
            if isVisible != visible { isVisible = visible }
        }
    }

    /// The text block. The white tint and shadow are applied here rather than
    /// to the whole row so the multicolor weather symbol keeps its own colors.
    private var textColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.placeName)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(secondaryStyle)
                    .lineLimit(1)
            }
            if let condition = conditionText {
                Text(condition)
                    .font(.caption)
                    .foregroundStyle(secondaryStyle)
                    .lineLimit(1)
            }
        }
        .layoutPriority(1)
        .foregroundStyle(textStyle)
        .shadow(color: textShadow, radius: 3, y: 1)
    }

    private var textStyle: AnyShapeStyle {
        sceneSymbol == nil ? AnyShapeStyle(.primary) : AnyShapeStyle(.white)
    }

    private var textShadow: Color {
        sceneSymbol == nil ? .clear : .black.opacity(0.45)
    }

    @ViewBuilder
    private var cardBackground: some View {
        if let summary = sceneSummary {
            ZStack {
                WeatherScene(conditionCode: summary.conditionCode,
                             symbolName: summary.symbolName, preset: .cell,
                             isAnimating: isVisible && scenePhase == .active)
                // Text sits at both ends of the card, so darken the edges and
                // leave the middle clear — the sky stays vivid where nothing
                // overlaps it, and white text keeps its contrast where it does.
                LinearGradient(
                    stops: [.init(color: .black.opacity(0.52), location: 0),
                            .init(color: .black.opacity(0.30), location: 0.32),
                            .init(color: .black.opacity(0.28), location: 0.58),
                            .init(color: .black.opacity(0.50), location: 1)],
                    startPoint: .leading, endPoint: .trailing)
            }
        } else {
            Color.clear.glassEffect(.regular.tint(tintColor), in: .rect(cornerRadius: 22))
        }
    }

    private var secondaryStyle: AnyShapeStyle {
        // Near-white over the sky: plain `.secondary` measured as low as
        // 2.5:1 against the lighter cloudy gradients.
        sceneSymbol == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.white.opacity(0.95))
    }

    // MARK: - Pieces

    private var leadingSymbol: some View {
        Image(systemName: WeatherStyle.filledSymbol(symbolName))
            .symbolRenderingMode(.multicolor)
            .font(.system(size: 30))
            .frame(width: 44, height: 40)
            .shadow(color: sceneSymbol == nil ? .clear : .black.opacity(0.35), radius: 4, y: 1)
    }

    @ViewBuilder
    private var trailing: some View {
        switch entry.weather {
        case .loading:
            ProgressView().controlSize(.small)
        case .ready(let summary):
            VStack(alignment: .trailing, spacing: 2) {
                Text(TemperatureText.degrees(celsius: dominantTemp(summary)))
                    .font(.system(size: 36, weight: .thin))
                    .monospacedDigit()
                Text("H:\(TemperatureText.degrees(celsius: summary.highCelsius))  L:\(TemperatureText.degrees(celsius: summary.lowCelsius))")
                    .font(.caption)
                    .foregroundStyle(secondaryStyle)
                    .monospacedDigit()
            }
        case .seasonal(let seasonal, _):
            Text("~\(TemperatureText.degrees(celsius: seasonal.averageHighCelsius)) / \(TemperatureText.degrees(celsius: seasonal.averageLowCelsius))")
                .font(.title3.weight(.medium))
                .monospacedDigit()
        case .unavailable:
            Image(systemName: "questionmark.circle")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Derived text

    private var subtitle: String? {
        if entry.kind == .currentLocation {
            return String(localized: "Where you are right now")
        }
        return entry.country
    }

    private var conditionText: String? {
        switch entry.weather {
        case .ready(let summary): return summary.conditionDescription
        case .seasonal(let seasonal, .beyondForecastRange): return seasonalLabel(month: seasonal.month)
        case .seasonal(_, .forecastUnavailable): return String(localized: "Forecast unavailable")
        case .loading, .unavailable: return nil
        }
    }

    private var symbolName: String {
        switch entry.weather {
        case .ready(let summary): return summary.symbolName
        case .seasonal(_, .beyondForecastRange): return "calendar"
        case .seasonal(_, .forecastUnavailable): return "arrow.clockwise"
        case .loading: return "clock.arrow.circlepath"
        case .unavailable: return "questionmark.circle"
        }
    }

    private var tintColor: Color {
        switch entry.weather {
        case .ready(let summary): return WeatherStyle.tint(forSymbol: summary.symbolName)
        case .seasonal: return Color.secondary.opacity(0.08)
        case .loading, .unavailable: return Color.secondary.opacity(0.06)
        }
    }

    /// For today, show the day's high as the headline number (we don't have a
    /// single "current" temp in the daily summary); otherwise the high too.
    private func dominantTemp(_ summary: DailySummary) -> Double {
        summary.highCelsius
    }

    private func seasonalLabel(month: Int) -> String {
        String(localized: "Typical for \(monthName(month))")
    }

    private func monthName(_ month: Int) -> String {
        let symbols = Calendar.current.monthSymbols
        guard month >= 1, month <= symbols.count else { return "" }
        return symbols[month - 1]
    }
}
