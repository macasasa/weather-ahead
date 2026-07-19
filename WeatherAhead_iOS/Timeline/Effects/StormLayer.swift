import SwiftUI

/// Lightning: a branching bolt with a localized bloom and a rapid flicker,
/// rather than a flat full-screen white flash.
struct LightningLayer {
    let rate: SkyLayer.LightningRate
    let intensity: Double
    let seed: UInt64

    func draw(in canvas: inout GraphicsContext, size: CGSize, time: Double) {
        let cycle = cycleLength
        let t = time.truncatingRemainder(dividingBy: cycle)
        // Two quick flashes, then dark for the rest of the cycle.
        let strength: Double
        if t < 0.09 { strength = 1 - t / 0.09 }
        else if t > 0.17 && t < 0.27 { strength = 0.75 * (1 - (t - 0.17) / 0.10) }
        else { return }
        guard strength > 0.02 else { return }

        // Each cycle gets its own bolt shape.
        let strikeIndex = UInt64(time / cycle)
        var random = SeededGenerator(seed: seed &+ strikeIndex &* 7919)

        let originX = CGFloat.random(in: 0.2...0.8, using: &random) * size.width
        let bolt = boltPath(from: CGPoint(x: originX, y: 0),
                            to: CGPoint(x: originX + CGFloat.random(in: -0.12...0.12, using: &random) * size.width,
                                        y: size.height * CGFloat.random(in: 0.55...0.95, using: &random)),
                            random: &random, depth: 4)

        // Sky glow around the strike.
        var glow = canvas
        glow.addFilter(.blur(radius: 40))
        glow.fill(
            Path(ellipseIn: CGRect(x: originX - size.width * 0.5, y: -size.height * 0.2,
                                   width: size.width, height: size.height * 0.9)),
            with: .color(.white.opacity(0.35 * strength * intensity))
        )

        // Bolt bloom, then the core stroke.
        var bloom = canvas
        bloom.addFilter(.blur(radius: 6))
        bloom.stroke(bolt, with: .color(Color(red: 0.85, green: 0.9, blue: 1).opacity(0.9 * strength)),
                     style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
        canvas.stroke(bolt, with: .color(.white.opacity(strength)),
                      style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
    }

    /// Recursive midpoint displacement — the classic way to get a jagged bolt
    /// with forks rather than a straight line.
    private func boltPath(from start: CGPoint, to end: CGPoint,
                          random: inout SeededGenerator, depth: Int) -> Path {
        var path = Path()
        var points: [CGPoint] = [start, end]

        for _ in 0..<depth {
            var next: [CGPoint] = [points[0]]
            for index in 0..<(points.count - 1) {
                let a = points[index], b = points[index + 1]
                let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
                let spread = abs(b.y - a.y) * 0.45
                let jitter = CGFloat.random(in: -spread...spread, using: &random)
                next.append(CGPoint(x: mid.x + jitter, y: mid.y))
                next.append(b)
            }
            points = next
        }

        path.addLines(points)

        // A fork branching off partway down.
        if points.count > 4 {
            let forkStart = points[points.count / 2]
            let forkEnd = CGPoint(x: forkStart.x + CGFloat.random(in: -40...40, using: &random),
                                  y: forkStart.y + CGFloat.random(in: 20...60, using: &random))
            var fork = Path()
            fork.move(to: forkStart)
            fork.addLine(to: forkEnd)
            path.addPath(fork)
        }
        return path
    }

    private var cycleLength: Double {
        switch rate {
        case .rare: return 11
        case .occasional: return 6.5
        case .frequent: return 3.5
        }
    }
}

/// Curved gust streaks for breezy / windy / storm conditions.
struct WindLayer {
    let strength: SkyLayer.WindStrength
    let intensity: Double
    let seed: UInt64

    func draw(in canvas: inout GraphicsContext, size: CGSize, time: Double) {
        var random = SeededGenerator(seed: seed &+ 4457)
        let count = max(3, Int(Double(baseCount) * intensity))
        let travel = size.width * 1.5

        for _ in 0..<count {
            let y = CGFloat.random(in: 0.05...0.95, using: &random) * size.height
            let speed = Double.random(in: speedRange, using: &random)
            let phase = Double.random(in: 0...1, using: &random)
            let length = CGFloat.random(in: 40...130, using: &random)
            let opacity = Double.random(in: 0.10...0.28, using: &random)

            let progress = ((time * speed / travel) + phase).truncatingRemainder(dividingBy: 1)
            let x = CGFloat(progress) * travel - size.width * 0.25

            // A shallow arc reads more like moving air than a straight line.
            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addQuadCurve(to: CGPoint(x: x + length, y: y - 6),
                              control: CGPoint(x: x + length * 0.5, y: y - 14))
            canvas.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [.clear, .white.opacity(opacity), .clear]),
                    startPoint: CGPoint(x: x, y: y),
                    endPoint: CGPoint(x: x + length, y: y)),
                style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
            )
        }
    }

    private var baseCount: Int {
        switch strength {
        case .gentle: return 6
        case .strong: return 14
        case .severe: return 24
        }
    }

    private var speedRange: ClosedRange<Double> {
        switch strength {
        case .gentle: return 60...120
        case .strong: return 150...260
        case .severe: return 280...460
        }
    }
}
