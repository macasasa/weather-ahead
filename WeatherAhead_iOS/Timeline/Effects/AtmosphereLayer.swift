import SwiftUI

/// Fog, haze, smoke and dust: soft horizontal wisps drifting in alternating
/// directions over a tinted full-scene veil.
struct AtmosphereLayer {
    let kind: SkyLayer.AtmosphereKind
    let intensity: Double
    let seed: UInt64

    func draw(in canvas: inout GraphicsContext, size: CGSize, time: Double) {
        // Overall veil — what actually makes it read as fog rather than cloud.
        canvas.fill(Path(CGRect(origin: .zero, size: size)),
                    with: .color(tint.opacity(veilOpacity * intensity)))

        var random = SeededGenerator(seed: seed &+ 3301)
        let bandCount = max(3, Int(6 * intensity))

        for index in 0..<bandCount {
            let y = (Double(index) + 0.5) / Double(bandCount)
            let height = size.height * CGFloat(Double.random(in: 0.16...0.34, using: &random))
            let speed = Double.random(in: 5...16, using: &random)
            let opacity = Double.random(in: 0.08...0.20, using: &random) * intensity
            let phase = Double.random(in: 0...1, using: &random)
            // Alternating drift keeps the bands sliding past each other.
            let forward = index.isMultiple(of: 2)

            let travel = size.width * 1.8
            let progress = ((time * speed / travel) + phase).truncatingRemainder(dividingBy: 1)
            let offset = CGFloat(progress) * travel
            let x = forward ? offset - size.width * 0.4 : size.width * 1.4 - offset

            var wisp = canvas
            wisp.addFilter(.blur(radius: height * 0.5))
            let rect = CGRect(x: x, y: CGFloat(y) * size.height - height / 2,
                              width: size.width * 0.85, height: height)
            wisp.fill(Path(ellipseIn: rect), with: .color(tint.opacity(opacity)))
        }
    }

    private var tint: Color {
        switch kind {
        case .fog: return Color(white: 0.85)
        case .haze: return Color(red: 0.92, green: 0.86, blue: 0.74)
        case .smoke: return Color(red: 0.72, green: 0.69, blue: 0.65)
        case .dust: return Color(red: 0.85, green: 0.72, blue: 0.50)
        }
    }

    private var veilOpacity: Double {
        switch kind {
        case .fog: return 0.30
        case .haze: return 0.18
        case .smoke: return 0.22
        case .dust: return 0.20
        }
    }
}

/// Shimmering heat above the horizon, for `hot`.
struct HeatHazeLayer {
    let intensity: Double

    func draw(in canvas: inout GraphicsContext, size: CGSize, time: Double) {
        let bands = 7
        for index in 0..<bands {
            let t = Double(index) / Double(bands)
            let y = size.height * CGFloat(0.55 + t * 0.45)
            let wobble = sin(time * 1.6 + Double(index) * 0.9) * 3
            let opacity = (0.10 - t * 0.06) * intensity

            var layer = canvas
            layer.addFilter(.blur(radius: 5))
            let rect = CGRect(x: CGFloat(wobble) - 10, y: y,
                              width: size.width + 20, height: size.height * 0.06)
            layer.fill(Path(ellipseIn: rect), with: .color(.white.opacity(max(0, opacity))))
        }
    }
}

/// Sparse glinting ice crystals, for `frigid` and freezing precipitation.
struct IceCrystalsLayer {
    let intensity: Double
    let seed: UInt64

    func draw(in canvas: inout GraphicsContext, size: CGSize, time: Double) {
        var random = SeededGenerator(seed: seed &+ 8123)
        let count = max(6, Int(30 * intensity))

        for _ in 0..<count {
            let x = CGFloat.random(in: 0...1, using: &random) * size.width
            let y = CGFloat.random(in: 0...1, using: &random) * size.height
            let length = CGFloat.random(in: 2...5, using: &random)
            let rate = Double.random(in: 0.8...2.4, using: &random)
            let phase = Double.random(in: 0...6.283, using: &random)
            let glint = max(0, sin(time * rate + phase))
            guard glint > 0.35 else { continue }

            let opacity = (glint - 0.35) / 0.65 * 0.8
            // A four-point sparkle.
            var path = Path()
            path.move(to: CGPoint(x: x - length, y: y))
            path.addLine(to: CGPoint(x: x + length, y: y))
            path.move(to: CGPoint(x: x, y: y - length))
            path.addLine(to: CGPoint(x: x, y: y + length))
            canvas.stroke(path, with: .color(.white.opacity(opacity)),
                          style: StrokeStyle(lineWidth: 1, lineCap: .round))
        }
    }
}
