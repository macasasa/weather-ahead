import SwiftUI
import WeatherKit

/// Apple Weather mark + legal link, required by WeatherKit's terms.
struct AttributionFooter: View {
    let provider: WeatherProvider

    @Environment(\.colorScheme) private var colorScheme
    @State private var attribution: WeatherAttribution?

    var body: some View {
        VStack(spacing: 6) {
            if let attribution {
                AsyncImage(url: colorScheme == .dark
                           ? attribution.combinedMarkDarkURL
                           : attribution.combinedMarkLightURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Color.clear
                }
                .frame(height: 14)
                Link("Weather data sources", destination: attribution.legalPageURL)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .task {
            attribution = await provider.attribution
        }
    }
}
