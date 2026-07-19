import SwiftUI

/// Falling precipitation drawn in three depth layers.
///
/// Depth is what sells rain: the far layer is thin, slow and faint; the near
/// layer is thicker, faster and slightly blurred, so the layers slide past each
/// other (motion parallax). Every particle also gets its own speed and length,
/// since uniform velocity is the giveaway of a fake rain effect.
struct PrecipitationLayer {
    let kind: SkyLayer.PrecipitationKind
    let intensity: Double
    let seed: UInt64

    /// One depth plane: `scale` 0 (far) … 1 (near).
    private struct Depth {
        let scale: Double
        let blur: CGFloat
    }

    private let depths = [
        Depth(scale: 0.45, blur: 0),
        Depth(scale: 0.72, blur: 0.6),
        Depth(scale: 1.0, blur: 1.8),
    ]

    func draw(in canvas: inout GraphicsContext, size: CGSize, time: Double) {
        for (index, depth) in depths.enumerated() {
            var layer = canvas
            if depth.blur > 0 { layer.addFilter(.blur(radius: depth.blur)) }
            drawDepth(depth, index: index, in: &layer, size: size, time: time)
        }
        if isLiquid, intensity > 0.5 {
            drawSplashes(in: &canvas, size: size, time: time)
        }
    }

    // MARK: - Per-depth drawing

    private func drawDepth(_ depth: Depth, index: Int,
                           in canvas: inout GraphicsContext, size: CGSize, time: Double) {
        var random = SeededGenerator(seed: seed &+ UInt64(index &* 977))
        let count = max(3, Int(Double(baseCount) * intensity * (0.45 + depth.scale * 0.55) / 3))

        for _ in 0..<count {
            let phase = Double.random(in: 0...1, using: &random)
            let speedJitter = Double.random(in: 0.75...1.35, using: &random)
            let speed = baseSpeed * depth.scale * speedJitter
            let x0 = CGFloat.random(in: -0.25...1.25, using: &random) * size.width
            let travel = size.height + 60

            let progress = ((time * speed / travel) + phase).truncatingRemainder(dividingBy: 1)
            let y = CGFloat(progress) * travel - 30

            switch kind {
            case .drizzle, .rain, .heavyRain:
                drawStreak(&canvas, random: &random, depth: depth,
                           x: x0 + y * slant, y: y, size: size)
            case .snow, .heavySnow, .flurries:
                drawFlake(&canvas, random: &random, depth: depth,
                          x: x0, y: y, time: time, phase: phase)
            case .sleet:
                // Sleet is a mix: alternate tiny streaks and pellets.
                if Bool.random(using: &random) {
                    drawStreak(&canvas, random: &random, depth: depth,
                               x: x0 + y * slant, y: y, size: size)
                } else {
                    drawPellet(&canvas, random: &random, depth: depth, x: x0, y: y)
                }
            case .hail:
                drawPellet(&canvas, random: &random, depth: depth, x: x0, y: y)
            }
        }
    }

    private func drawStreak(_ canvas: inout GraphicsContext, random: inout SeededGenerator,
                            depth: Depth, x: CGFloat, y: CGFloat, size: CGSize) {
        let length = CGFloat.random(in: lengthRange, using: &random) * depth.scale
        let width = (kind == .heavyRain ? 1.9 : 1.4) * depth.scale
        let opacity = Double.random(in: opacityRange, using: &random) * (0.5 + depth.scale * 0.5)

        var path = Path()
        path.move(to: CGPoint(x: x, y: y))
        path.addLine(to: CGPoint(x: x + length * slant, y: y + length))
        // Tapered: a streak fades out toward its tail rather than being a
        // flat-ended stick.
        canvas.stroke(
            path,
            with: .linearGradient(
                Gradient(colors: [.white.opacity(opacity * 0.15), .white.opacity(opacity)]),
                startPoint: CGPoint(x: x, y: y),
                endPoint: CGPoint(x: x + length * slant, y: y + length)
            ),
            style: StrokeStyle(lineWidth: width, lineCap: .round)
        )
    }

    private func drawFlake(_ canvas: inout GraphicsContext, random: inout SeededGenerator,
                           depth: Depth, x: CGFloat, y: CGFloat, time: Double, phase: Double) {
        let radius = CGFloat.random(in: 1.2...3.2, using: &random) * depth.scale
        let opacity = Double.random(in: 0.45...0.95, using: &random) * (0.55 + depth.scale * 0.45)
        let swayAmp = CGFloat.random(in: 8...26, using: &random) * depth.scale
        let swayRate = Double.random(in: 0.25...0.8, using: &random)
        // Flakes flutter rather than fall straight, each on its own phase.
        let drift = CGFloat(sin(time * swayRate + phase * 6.283)) * swayAmp
        let rect = CGRect(x: x + drift - radius, y: y - radius,
                          width: radius * 2, height: radius * 2)
        canvas.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
    }

    private func drawPellet(_ canvas: inout GraphicsContext, random: inout SeededGenerator,
                            depth: Depth, x: CGFloat, y: CGFloat) {
        let radius = CGFloat.random(in: 1.4...2.6, using: &random) * depth.scale
        let opacity = Double.random(in: 0.6...0.95, using: &random)
        let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
        canvas.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
    }

    /// Short horizontal ticks near the bottom edge, as if drops are landing.
    private func drawSplashes(in canvas: inout GraphicsContext, size: CGSize, time: Double) {
        var random = SeededGenerator(seed: seed &+ 5171)
        let count = max(2, Int(10 * intensity))

        for _ in 0..<count {
            let x = CGFloat.random(in: 0...1, using: &random) * size.width
            let rate = Double.random(in: 1.4...3.0, using: &random)
            let phase = Double.random(in: 0...1, using: &random)
            let cycle = ((time * rate) + phase).truncatingRemainder(dividingBy: 1)
            guard cycle < 0.25 else { continue }

            let life = cycle / 0.25
            let spread = 3 + life * 7
            let opacity = (1 - life) * 0.5
            let y = size.height - 3

            var path = Path()
            path.move(to: CGPoint(x: x - spread, y: y))
            path.addLine(to: CGPoint(x: x + spread, y: y))
            canvas.stroke(path, with: .color(.white.opacity(opacity)),
                          style: StrokeStyle(lineWidth: 1, lineCap: .round))
        }
    }

    // MARK: - Per-kind parameters

    private var isLiquid: Bool {
        kind == .rain || kind == .heavyRain || kind == .drizzle
    }

    private var baseCount: Int {
        switch kind {
        case .drizzle: return 150
        case .rain: return 210
        case .heavyRain: return 330
        case .snow: return 130
        case .heavySnow: return 200
        case .flurries: return 70
        case .sleet: return 170
        case .hail: return 120
        }
    }

    private var baseSpeed: Double {
        switch kind {
        case .drizzle: return 380
        case .rain: return 620
        case .heavyRain: return 820
        case .snow, .flurries: return 60
        case .heavySnow: return 90
        case .sleet: return 400
        case .hail: return 700
        }
    }

    private var slant: CGFloat {
        switch kind {
        case .drizzle: return 0.10
        case .rain: return 0.16
        case .heavyRain: return 0.24
        case .sleet: return 0.20
        default: return 0
        }
    }

    private var lengthRange: ClosedRange<CGFloat> {
        switch kind {
        case .drizzle: return 5...11
        case .rain: return 12...26
        case .heavyRain: return 20...40
        case .sleet: return 6...13
        default: return 8...16
        }
    }

    private var opacityRange: ClosedRange<Double> {
        switch kind {
        case .drizzle: return 0.18...0.4
        case .heavyRain: return 0.35...0.75
        default: return 0.25...0.6
        }
    }
}
