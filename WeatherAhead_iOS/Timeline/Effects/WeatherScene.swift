import SwiftUI

/// An animated sky for a weather condition: gradient + layered procedural
/// effects. Used full-bleed on the detail screen and, at lower intensity,
/// behind timeline cells.
struct WeatherScene: View {
    enum Preset {
        /// Behind a list cell.
        case cell
        /// Full-screen detail background.
        case full

        var intensity: Double {
            switch self {
            case .cell: return 0.55
            case .full: return 1.0
            }
        }
    }

    let condition: SkyCondition
    let isNight: Bool
    var preset: Preset = .full
    /// Set false to freeze the scene (off-screen cells, inactive scene phase).
    var isAnimating: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Convenience for callers that only have a summary's symbol + code.
    init(conditionCode: String, symbolName: String, preset: Preset = .full, isAnimating: Bool = true) {
        self.condition = SkyCondition.from(code: conditionCode, symbolName: symbolName)
        self.isNight = WeatherStyle.isNight(symbol: symbolName)
        self.preset = preset
        self.isAnimating = isAnimating
    }

    init(condition: SkyCondition, isNight: Bool, preset: Preset = .full, isAnimating: Bool = true) {
        self.condition = condition
        self.isNight = isNight
        self.preset = preset
        self.isAnimating = isAnimating
    }

    private var seed: UInt64 {
        UInt64(abs(condition.rawValue.hashValue % 100_000)) &+ 7
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: condition.skyColors(isNight: isNight),
                           startPoint: .top, endPoint: .bottom)
            WeatherParticles(
                layers: condition.layers(isNight: isNight),
                intensity: preset.intensity * condition.severity,
                isAnimating: isAnimating && !reduceMotion,
                seed: seed
            )
        }
        .drawingGroup()
        .allowsHitTesting(false)
    }
}
