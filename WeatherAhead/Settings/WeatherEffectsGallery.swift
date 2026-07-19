import SwiftUI

/// Every weather condition rendered as a timeline-sized card, so all the
/// animated skies can be reviewed side by side.
struct WeatherEffectsGallery: View {
    /// Skips the first N conditions — used by the `--gallery-offset` debug
    /// launch argument so every condition can be screenshotted.
    var startOffset: Int = 0

    /// Show each condition twice (day + night) where night differs.
    @State private var showNight = false

    private var conditions: [SkyCondition] {
        Array(SkyCondition.allCases.dropFirst(startOffset))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                Picker("Time of day", selection: $showNight) {
                    Text("Day").tag(false)
                    Text("Night").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 4)

                ForEach(conditions, id: \.self) { condition in
                    WeatherEffectCard(condition: condition, isNight: showNight)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .navigationTitle("Weather Effects")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// One gallery card: the same sky composition the timeline cells use.
struct WeatherEffectCard: View {
    let condition: SkyCondition
    let isNight: Bool

    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false

    var body: some View {
        ZStack(alignment: .leading) {
            WeatherScene(condition: condition, isNight: isNight, preset: .cell,
                         isAnimating: isVisible && scenePhase == .active)
            LinearGradient(
                stops: [.init(color: .black.opacity(0.52), location: 0),
                        .init(color: .black.opacity(0.30), location: 0.32),
                        .init(color: .black.opacity(0.28), location: 0.58),
                        .init(color: .black.opacity(0.50), location: 1)],
                startPoint: .leading, endPoint: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                Text(condition.displayName)
                    .font(.title3.weight(.semibold))
                Text(condition.rawValue)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
            .padding(.horizontal, 16)
        }
        .frame(height: 96)
        .clipShape(.rect(cornerRadius: 22))
        .onScrollVisibilityChange(threshold: 0.01) { visible in
            if isVisible != visible { isVisible = visible }
        }
    }
}
