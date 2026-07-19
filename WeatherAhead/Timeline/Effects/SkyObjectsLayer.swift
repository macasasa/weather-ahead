import SwiftUI

/// The sun: a warm disc with a soft bloom and faint rays.
struct SunLayer {
    let intensity: Double

    func draw(in canvas: inout GraphicsContext, size: CGSize, time: Double) {
        let center = CGPoint(x: size.width * 0.78, y: size.height * 0.22)
        let radius = min(size.width, size.height) * 0.10
        // Gentle breathing so it isn't perfectly static.
        let pulse = 1 + 0.04 * sin(time * 0.5)

        // Bloom
        var bloom = canvas
        bloom.addFilter(.blur(radius: radius * 1.6))
        bloom.fill(
            Path(ellipseIn: CGRect(x: center.x - radius * 2.4, y: center.y - radius * 2.4,
                                   width: radius * 4.8, height: radius * 4.8)),
            with: .radialGradient(
                Gradient(colors: [Color(red: 1, green: 0.92, blue: 0.62).opacity(0.55),
                                  .clear]),
                center: center, startRadius: 0, endRadius: radius * 2.4)
        )

        // Rays
        var rays = canvas
        rays.addFilter(.blur(radius: 3))
        for index in 0..<12 {
            let angle = Double(index) / 12 * 2 * .pi + time * 0.05
            let inner = radius * 1.5
            let outer = radius * (2.4 + 0.3 * sin(time * 0.8 + Double(index)))
            var path = Path()
            path.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
            path.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
            rays.stroke(path, with: .color(Color(red: 1, green: 0.95, blue: 0.75).opacity(0.18)),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }

        // Disc
        let r = radius * pulse
        canvas.fill(
            Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
            with: .radialGradient(
                Gradient(colors: [.white, Color(red: 1, green: 0.90, blue: 0.55)]),
                center: center, startRadius: 0, endRadius: r)
        )
    }
}

/// The moon: a pale disc with a soft halo.
struct MoonLayer {
    func draw(in canvas: inout GraphicsContext, size: CGSize, time: Double) {
        let center = CGPoint(x: size.width * 0.80, y: size.height * 0.20)
        let radius = min(size.width, size.height) * 0.075

        var halo = canvas
        halo.addFilter(.blur(radius: radius * 1.4))
        halo.fill(
            Path(ellipseIn: CGRect(x: center.x - radius * 2, y: center.y - radius * 2,
                                   width: radius * 4, height: radius * 4)),
            with: .radialGradient(
                Gradient(colors: [Color(red: 0.85, green: 0.89, blue: 1).opacity(0.4), .clear]),
                center: center, startRadius: 0, endRadius: radius * 2)
        )

        canvas.fill(
            Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                   width: radius * 2, height: radius * 2)),
            with: .color(Color(red: 0.94, green: 0.95, blue: 1).opacity(0.95))
        )
        // A couple of craters for texture.
        for (dx, dy, scale) in [(-0.3, -0.2, 0.22), (0.25, 0.15, 0.16), (-0.1, 0.35, 0.12)] {
            let cr = radius * CGFloat(scale)
            let rect = CGRect(x: center.x + radius * CGFloat(dx) - cr,
                              y: center.y + radius * CGFloat(dy) - cr,
                              width: cr * 2, height: cr * 2)
            canvas.fill(Path(ellipseIn: rect), with: .color(Color(white: 0.82).opacity(0.5)))
        }
    }
}

/// Stars with varied brightness and twinkle, plus a rare shooting star.
struct StarsLayer {
    let intensity: Double
    let seed: UInt64

    func draw(in canvas: inout GraphicsContext, size: CGSize, time: Double) {
        var random = SeededGenerator(seed: seed &+ 991)
        let count = max(20, Int(110 * intensity))

        for _ in 0..<count {
            let x = CGFloat.random(in: 0...1, using: &random) * size.width
            // Denser toward the top, where the sky is darkest.
            let y = CGFloat(pow(Double.random(in: 0...1, using: &random), 1.7)) * size.height
            let radius = CGFloat.random(in: 0.5...1.8, using: &random)
            let base = Double.random(in: 0.3...1.0, using: &random)
            let rate = Double.random(in: 0.5...2.4, using: &random)
            let phase = Double.random(in: 0...6.283, using: &random)

            let twinkle = 0.6 + 0.4 * sin(time * rate + phase)
            let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
            canvas.fill(Path(ellipseIn: rect), with: .color(.white.opacity(base * twinkle)))
        }

        drawShootingStar(in: &canvas, size: size, time: time)
    }

    private func drawShootingStar(in canvas: inout GraphicsContext, size: CGSize, time: Double) {
        // One streak every ~9s, lasting a fraction of a second.
        let cycle = 9.0
        let t = time.truncatingRemainder(dividingBy: cycle)
        guard t < 0.55 else { return }

        let life = t / 0.55
        let startX = size.width * 0.15
        let startY = size.height * 0.10
        let dx = size.width * 0.55 * CGFloat(life)
        let dy = size.height * 0.35 * CGFloat(life)
        let tail: CGFloat = 42

        var path = Path()
        path.move(to: CGPoint(x: startX + dx, y: startY + dy))
        path.addLine(to: CGPoint(x: startX + dx - tail * 0.85, y: startY + dy - tail * 0.5))

        let fade = (1 - life) * 0.9
        canvas.stroke(
            path,
            with: .linearGradient(
                Gradient(colors: [.white.opacity(fade), .clear]),
                startPoint: CGPoint(x: startX + dx, y: startY + dy),
                endPoint: CGPoint(x: startX + dx - tail * 0.85, y: startY + dy - tail * 0.5)),
            style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
        )
    }
}
