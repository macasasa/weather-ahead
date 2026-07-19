import SwiftUI

/// Draws a condition's layers into a single `Canvas`.
///
/// Every layer is analytic: a particle's position comes from the elapsed time
/// plus a seeded generator, so there is no per-frame state to mutate and no
/// timers. `TimelineView` asks for a frame and we place everything directly,
/// which keeps the whole sky to one draw pass — cheap enough to run inside
/// scrolling cells.
struct WeatherParticles: View {
    let layers: [SkyLayer]
    /// 0…1 — scales particle counts (cells use a fraction of the full scene).
    let intensity: Double
    /// Stops the animation (off-screen cells, background, Reduce Motion).
    let isAnimating: Bool
    /// Keeps two cards with the same condition from looking identical.
    let seed: UInt64

    var body: some View {
        TimelineView(.animation(paused: !isAnimating)) { context in
            Canvas { canvas, size in
                let time = isAnimating ? context.date.timeIntervalSinceReferenceDate : 0
                for (index, layer) in layers.enumerated() {
                    draw(layer, index: index, in: &canvas, size: size, time: time)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func draw(_ layer: SkyLayer, index: Int, in canvas: inout GraphicsContext,
                      size: CGSize, time: Double) {
        let layerSeed = seed &+ UInt64(index &* 31)
        switch layer {
        case .sun:
            SunLayer(intensity: intensity).draw(in: &canvas, size: size, time: time)
        case .moon:
            MoonLayer().draw(in: &canvas, size: size, time: time)
        case .stars:
            StarsLayer(intensity: intensity, seed: layerSeed).draw(in: &canvas, size: size, time: time)
        case .clouds(let density):
            CloudLayer(density: density, intensity: intensity, seed: layerSeed)
                .draw(in: &canvas, size: size, time: time)
        case .precipitation(let kind):
            PrecipitationLayer(kind: kind, intensity: intensity, seed: layerSeed)
                .draw(in: &canvas, size: size, time: time)
        case .lightning(let rate):
            LightningLayer(rate: rate, intensity: intensity, seed: layerSeed)
                .draw(in: &canvas, size: size, time: time)
        case .wind(let strength):
            WindLayer(strength: strength, intensity: intensity, seed: layerSeed)
                .draw(in: &canvas, size: size, time: time)
        case .atmosphere(let kind):
            AtmosphereLayer(kind: kind, intensity: intensity, seed: layerSeed)
                .draw(in: &canvas, size: size, time: time)
        case .heatHaze:
            HeatHazeLayer(intensity: intensity).draw(in: &canvas, size: size, time: time)
        case .iceCrystals:
            IceCrystalsLayer(intensity: intensity, seed: layerSeed)
                .draw(in: &canvas, size: size, time: time)
        }
    }
}

/// Deterministic RNG so a given card's particles are stable across redraws
/// (and differ between cards via the seed).
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &* 6364136223846793005 &+ 1442695040888963407
        if state == 0 { state = 0x9E3779B97F4A7C15 }
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
