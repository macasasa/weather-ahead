import SwiftUI

/// One trip beyond the forecast window: place, date range, and typical
/// seasonal temperatures on a glass card matching PlaceDayRow's look.
struct TripRow: View {
    let trip: TripSpan

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: symbolName)
                .font(.system(size: 26))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(trip.placeName)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let titles = eventTitlesText {
                    Text(titles)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            // Without this the HStack compresses the text column before the
            // spacer, truncating the subtitle while free space remains.
            .layoutPriority(1)
            Spacer(minLength: 8)
            trailing
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(Color.secondary.opacity(0.07)), in: .rect(cornerRadius: 22))
        .contentShape(.rect(cornerRadius: 22))
    }

    @ViewBuilder
    private var trailing: some View {
        switch trip.weather {
        case .loading:
            ProgressView().controlSize(.small)
        case .ready(let summary):
            // A trip card that already has a real forecast (rare edge while
            // the window rolls over) shows it plainly.
            Text("\(TemperatureText.degrees(celsius: summary.highCelsius)) / \(TemperatureText.degrees(celsius: summary.lowCelsius))")
                .font(.title3.weight(.medium))
                .monospacedDigit()
        case .seasonal(let seasonal, _):
            VStack(alignment: .trailing, spacing: 2) {
                Text("~\(TemperatureText.degrees(celsius: seasonal.averageHighCelsius)) / \(TemperatureText.degrees(celsius: seasonal.averageLowCelsius))")
                    .font(.title3.weight(.medium))
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
                Text("typical")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        case .unavailable:
            Image(systemName: "questionmark.circle")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }

    private var symbolName: String {
        if case .seasonal(_, .forecastUnavailable) = trip.weather {
            return "arrow.clockwise"
        }
        return "calendar"
    }

    private var subtitle: String {
        var text = dateRangeText
        if let country = trip.country {
            text += " · \(country)"
        }
        return text
    }

    private var dateRangeText: String {
        if trip.isSingleDay {
            return trip.startDay.formatted(.dateTime.day().month(.abbreviated))
        }
        // Same-month ranges compact to "16–18 Aug" so the country still fits.
        if Calendar.current.isDate(trip.startDay, equalTo: trip.endDay, toGranularity: .month) {
            return "\(trip.startDay.formatted(.dateTime.day()))–\(trip.endDay.formatted(.dateTime.day().month(.abbreviated)))"
        }
        return "\(trip.startDay.formatted(.dateTime.day().month(.abbreviated))) – \(trip.endDay.formatted(.dateTime.day().month(.abbreviated)))"
    }

    private var eventTitlesText: String? {
        let titles = trip.eventTitles.joined(separator: ", ")
        return titles.isEmpty ? nil : titles
    }
}
