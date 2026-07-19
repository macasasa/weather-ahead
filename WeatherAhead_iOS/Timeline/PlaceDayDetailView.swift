import SwiftUI
import WeatherKit

/// Full weather for one place on one day, styled after the native Weather
/// "Conditions" screen: a temperature chart, hourly strip, precipitation
/// chart, and a grid of detail tiles — all on condition-tinted glass.
struct PlaceDayDetailView: View {
    let entry: PlaceDay
    let provider: WeatherProvider

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var hours: [HourSummary]?
    @State private var alerts: [WeatherAlert] = []
    @State private var chartMode: TemperatureChart.Mode = .actual
    /// State resolved by this screen when pushed with a still-loading entry.
    @State private var resolvedWeather: WeatherState?

    private var weather: WeatherState {
        resolvedWeather ?? entry.weather
    }

    /// True when the animated sky is behind the content, so the whole screen
    /// switches to dark-scheme semantics (light text, dark-tuned glass).
    private var hasScene: Bool {
        if case .ready = weather { return true }
        return false
    }

    private var accent: Color {
        if case .ready(let summary) = weather {
            return WeatherStyle.accent(forSymbol: summary.symbolName)
        }
        return .secondary
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !alerts.isEmpty {
                    ForEach(Array(alerts.enumerated()), id: \.offset) { _, alert in
                        AlertCard(alert: alert)
                    }
                }

                switch weather {
                case .ready(let summary):
                    header(summary)
                    temperatureCard
                    hourlyStrip
                    precipitationCard
                    DetailGrid(summary: summary, sampleHour: representativeHour)
                case .seasonal(let seasonal, let reason):
                    SeasonalCard(seasonal: seasonal, reason: reason, placeName: entry.placeName)
                case .loading:
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
                case .unavailable:
                    unavailable
                }

                AttributionFooter(provider: provider)
            }
            .padding(.horizontal)
        }
        .background {
            if case .ready(let summary) = weather {
                ZStack {
                    WeatherScene(conditionCode: summary.conditionCode,
                                 symbolName: summary.symbolName, preset: .full,
                                 isAnimating: scenePhase == .active)
                    // Darkens the sky just enough for the glass cards and
                    // white text to stay readable over bright conditions.
                    LinearGradient(colors: [.black.opacity(0.25), .black.opacity(0.45)],
                                   startPoint: .top, endPoint: .bottom)
                }
                .ignoresSafeArea()
            }
        }
        .colorScheme(hasScene ? .dark : colorScheme)
        // The nav bar sits over the dark sky, so its labels need light colors.
        .toolbarColorScheme(hasScene ? .dark : nil, for: .navigationBar)
        .navigationTitle(entry.placeName)
        .navigationSubtitle(subtitleText)
        .task {
            // If pushed while the day's state was still loading, resolve it
            // here rather than spinning forever on a frozen value.
            if case .loading = weather, let coordinate = entry.coordinate {
                let states = await provider.summaries(for: coordinate.rounded, days: [entry.day])
                if let state = states[entry.day] {
                    resolvedWeather = state
                }
            }
            if case .ready = weather, let coordinate = entry.coordinate {
                hours = provider.cachedHourly(for: coordinate, day: entry.day)
                async let fetchedHours = provider.hourly(for: coordinate, day: entry.day)
                if Calendar.current.isDateInToday(entry.day) {
                    async let fetchedAlerts = provider.alerts(for: coordinate)
                    alerts = await fetchedAlerts
                }
                if let resolved = await fetchedHours { hours = resolved }
            }
        }
    }

    // MARK: - Header

    private func header(_ summary: DailySummary) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: WeatherStyle.filledSymbol(summary.symbolName))
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 56))
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.conditionDescription)
                    .font(.title2.weight(.semibold))
                Text("H:\(TemperatureText.degrees(celsius: summary.highCelsius))  L:\(TemperatureText.degrees(celsius: summary.lowCelsius))")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                if let feels = representativeHour?.apparentTemperatureCelsius {
                    Text("Feels like \(TemperatureText.degrees(celsius: feels))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    // MARK: - Temperature card

    private var temperatureCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Temperature", systemImage: "thermometer.medium")
                    .font(.headline)
                Spacer()
                Picker("Mode", selection: $chartMode) {
                    Text("Actual").tag(TemperatureChart.Mode.actual)
                    Text("Feels Like").tag(TemperatureChart.Mode.feelsLike)
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            if let hours, !hours.isEmpty {
                TemperatureChart(hours: hours, mode: chartMode, accent: accent)
            } else {
                ChartSkeleton(height: 200)
            }
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    // MARK: - Hourly strip

    private var hourlyStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Hour by hour", systemImage: "clock")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(hours ?? HourSummary.placeholders) { hour in
                        VStack(spacing: 6) {
                            Text(hour.date, format: .dateTime.hour())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Image(systemName: WeatherStyle.filledSymbol(hour.symbolName))
                                .symbolRenderingMode(.multicolor)
                                .font(.body)
                            Text(TemperatureText.degrees(celsius: hour.temperatureCelsius))
                                .font(.caption.weight(.semibold))
                                .monospacedDigit()
                            if hour.precipitationChance >= 0.2 {
                                Text(hour.precipitationChance, format: .percent.precision(.fractionLength(0)))
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                            } else {
                                Text(verbatim: " ").font(.caption2)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .redacted(reason: hours == nil ? .placeholder : [])
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    // MARK: - Precipitation card

    @ViewBuilder
    private var precipitationCard: some View {
        if let hours, !hours.isEmpty, hours.contains(where: { $0.precipitationChance > 0.05 }) {
            VStack(alignment: .leading, spacing: 10) {
                Label("Chance of precipitation", systemImage: "drop")
                    .font(.headline)
                PrecipitationChart(hours: hours)
            }
            .padding(16)
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
        }
    }

    private var unavailable: some View {
        ContentUnavailableView {
            Label("No weather data", systemImage: "questionmark.circle")
        } description: {
            if entry.coordinate == nil {
                Text("This place couldn't be located precisely enough to fetch its weather.")
            } else {
                Text("The weather couldn't be loaded right now. It'll be retried automatically.")
            }
        }
    }

    // MARK: - Helpers

    /// The hour that best represents the day for point-in-time metrics: the
    /// current hour for today, otherwise local midday.
    private var representativeHour: HourSummary? {
        guard let hours, !hours.isEmpty else { return nil }
        let calendar = Calendar.current
        if calendar.isDateInToday(entry.day) {
            return hours.min { abs($0.date.timeIntervalSinceNow) < abs($1.date.timeIntervalSinceNow) }
        }
        return hours.min {
            abs(calendar.component(.hour, from: $0.date) - 13) < abs(calendar.component(.hour, from: $1.date) - 13)
        }
    }

    private var subtitleText: Text {
        Text(entry.day, format: .dateTime.weekday(.wide).day().month(.wide))
    }
}

// MARK: - Detail tile grid

private struct DetailGrid: View {
    let summary: DailySummary
    let sampleHour: HourSummary?

    private struct Metric: Identifiable {
        let id = UUID()
        let icon: String
        let title: LocalizedStringKey
        let value: String
        var detail: String?
    }

    /// Two independent masonry columns: every tile keeps identical internal
    /// padding and vertical spacing; the columns just end at different heights.
    var body: some View {
        let metrics = allMetrics
        HStack(alignment: .top, spacing: 12) {
            column(of: metrics.enumerated().filter { $0.offset.isMultiple(of: 2) }.map(\.element))
            column(of: metrics.enumerated().filter { !$0.offset.isMultiple(of: 2) }.map(\.element))
        }
    }

    private func column(of metrics: [Metric]) -> some View {
        VStack(spacing: 12) {
            ForEach(metrics) { metric in
                MetricTile(icon: metric.icon, title: metric.title,
                           value: metric.value, detail: metric.detail)
            }
        }
    }

    private var allMetrics: [Metric] {
        var metrics: [Metric] = []
        if let hour = sampleHour {
            metrics.append(Metric(icon: "thermometer.variable", title: "Feels like",
                                  value: TemperatureText.degrees(celsius: hour.apparentTemperatureCelsius)))
        }
        metrics.append(Metric(icon: "humidity", title: "Humidity", value: humidityText))
        if let hour = sampleHour {
            metrics.append(Metric(icon: "drop.degreesign", title: "Dew point",
                                  value: TemperatureText.degrees(celsius: hour.dewPointCelsius)))
        }
        metrics.append(Metric(icon: "wind", title: "Wind", value: windText, detail: summary.windCompass))
        if let gust = summary.windGustKph {
            metrics.append(Metric(icon: "wind.circle", title: "Gusts", value: speedText(gust)))
        }
        if let hour = sampleHour {
            metrics.append(Metric(icon: "gauge.with.dots.needle.bottom.50percent", title: "Pressure",
                                  value: pressureText(hour.pressureHectopascals), detail: hour.pressureTrend))
            metrics.append(Metric(icon: "eye", title: "Visibility", value: visibilityText(hour.visibilityKm)))
            metrics.append(Metric(icon: "cloud", title: "Cloud cover",
                                  value: hour.cloudCover.formatted(.percent.precision(.fractionLength(0)))))
        }
        metrics.append(Metric(icon: "sun.max", title: "UV index",
                              value: "\(summary.maxUVIndex)", detail: summary.uvCategory))
        if summary.precipitationAmountMm > 0 {
            metrics.append(Metric(icon: "cloud.rain", title: "Precipitation",
                                  value: lengthText(mm: summary.precipitationAmountMm), detail: summary.precipitationType))
        }
        if summary.snowfallCm > 0 {
            metrics.append(Metric(icon: "snowflake", title: "Snowfall", value: snowText(cm: summary.snowfallCm)))
        }
        if let sunrise = summary.sunrise {
            metrics.append(Metric(icon: "sunrise", title: "Sunrise",
                                  value: sunrise.formatted(date: .omitted, time: .shortened)))
        }
        if let sunset = summary.sunset {
            metrics.append(Metric(icon: "sunset", title: "Sunset",
                                  value: sunset.formatted(date: .omitted, time: .shortened)))
        }
        if let symbol = summary.moonPhaseSymbol, let text = summary.moonPhaseText {
            metrics.append(Metric(icon: symbol, title: "Moon", value: text))
        }
        return metrics
    }

    private var humidityText: String {
        if let maxH = summary.maxHumidity {
            return maxH.formatted(.percent.precision(.fractionLength(0)))
        }
        return "—"
    }
    private var windText: String { speedText(summary.windKph) }
    private func speedText(_ kph: Double) -> String {
        Measurement(value: kph, unit: UnitSpeed.kilometersPerHour)
            .formatted(.measurement(width: .abbreviated, usage: .general,
                                    numberFormatStyle: .number.precision(.fractionLength(0))))
    }
    private func pressureText(_ hPa: Double) -> String {
        // `.asProvided` keeps hPa; the default auto-converts to pascals ("101 196 Pa").
        Measurement(value: hPa, unit: UnitPressure.hectopascals)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided,
                                    numberFormatStyle: .number.precision(.fractionLength(0))))
    }
    private func visibilityText(_ km: Double) -> String {
        Measurement(value: km, unit: UnitLength.kilometers)
            .formatted(.measurement(width: .abbreviated, usage: .road,
                                    numberFormatStyle: .number.precision(.fractionLength(0))))
    }
    private func lengthText(mm: Double) -> String {
        Measurement(value: mm, unit: UnitLength.millimeters)
            .formatted(.measurement(width: .abbreviated, numberFormatStyle: .number.precision(.fractionLength(1))))
    }
    private func snowText(cm: Double) -> String {
        Measurement(value: cm, unit: UnitLength.centimeters)
            .formatted(.measurement(width: .abbreviated, numberFormatStyle: .number.precision(.fractionLength(1))))
    }
}

private struct MetricTile: View {
    let icon: String
    let title: LocalizedStringKey
    let value: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
            Text(value)
                .font(.title3.weight(.medium))
                .monospacedDigit()
            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }
}

// MARK: - Seasonal / alerts / skeleton

private struct SeasonalCard: View {
    let seasonal: SeasonalSummary
    let reason: WeatherState.SeasonalReason
    let placeName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Typical for \(monthName)",
                  systemImage: reason == .beyondForecastRange ? "calendar" : "arrow.clockwise")
                .font(.title3.weight(.semibold))
            HStack(spacing: 24) {
                stat(title: "Avg high", value: TemperatureText.degrees(celsius: seasonal.averageHighCelsius))
                stat(title: "Avg low", value: TemperatureText.degrees(celsius: seasonal.averageLowCelsius))
                stat(title: "Rain / month", value: rainText)
            }
            Text(explanation)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassEffect(.regular.tint(Color.secondary.opacity(0.1)), in: .rect(cornerRadius: 20))
        .padding(.top, 8)
    }

    private func stat(title: LocalizedStringKey, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title2.weight(.semibold)).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var explanation: String {
        switch reason {
        case .beyondForecastRange:
            String(localized: "This far ahead there's no forecast yet, so this shows the typical climate for \(placeName) in \(monthName). The real forecast appears automatically as the date gets closer.")
        case .forecastUnavailable:
            String(localized: "The forecast for this day couldn't be loaded right now, so this shows the typical climate for \(placeName) in \(monthName). It'll keep retrying automatically.")
        }
    }

    private var rainText: String {
        Measurement(value: seasonal.averagePrecipitationAmountMm, unit: UnitLength.millimeters)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided,
                                    numberFormatStyle: .number.precision(.fractionLength(0))))
    }

    private var monthName: String {
        let symbols = Calendar.current.monthSymbols
        guard seasonal.month >= 1, seasonal.month <= symbols.count else { return "" }
        return symbols[seasonal.month - 1]
    }
}

private struct AlertCard: View {
    let alert: WeatherAlert

    var body: some View {
        Link(destination: alert.detailsURL) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(severityColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(alert.summary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(alert.source)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
            .padding(16)
            .glassEffect(.regular.tint(severityColor.opacity(0.18)), in: .rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private var severityColor: Color {
        switch alert.severity {
        case .extreme, .severe: return .red
        case .moderate: return .orange
        case .minor: return .yellow
        default: return .gray
        }
    }
}

private struct ChartSkeleton: View {
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.secondary.opacity(0.12))
            .frame(height: height)
            .overlay { ProgressView() }
    }
}

private extension HourSummary {
    /// Placeholder hours for the redacted loading state of the hourly strip.
    static var placeholders: [HourSummary] {
        (0..<8).map { i in
            HourSummary(date: Date(timeIntervalSinceNow: Double(i) * 3600),
                        symbolName: "cloud.sun", conditionCode: "partlyCloudy",
                        temperatureCelsius: 18,
                        apparentTemperatureCelsius: 18, precipitationChance: 0,
                        precipitationAmountMm: 0, humidity: 0.5, dewPointCelsius: 10,
                        pressureHectopascals: 1013, pressureTrend: "steady", cloudCover: 0.3,
                        visibilityKm: 10, windKph: 8, windGustKph: nil, uvIndex: 2, isDaylight: true)
        }
    }
}
