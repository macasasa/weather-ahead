import SwiftUI

/// Drifting clouds built from clusters of overlapping soft circles.
///
/// A single blurred ellipse reads as a smudge; real clouds are lumpy, so each
/// cloud here is 5–8 circles of varying radius sharing a baseline. Two or three
/// parallax bands drift at different speeds and scales for depth.
struct CloudLayer {
    let density: SkyLayer.CloudDensity
    let intensity: Double
    let seed: UInt64

    private struct Band {
        let y: Double        // 0…1 of height
        let scale: Double
        let speed: Double
        let opacity: Double
    }

    func draw(in canvas: inout GraphicsContext, size: CGSize, time: Double) {
        for (index, band) in bands.enumerated() {
            var layer = canvas
            layer.addFilter(.blur(radius: CGFloat(6 + band.scale * 10)))
            drawBand(band, index: index, in: &layer, size: size, time: time)
        }
    }

    private func drawBand(_ band: Band, index: Int, in canvas: inout GraphicsContext,
                          size: CGSize, time: Double) {
        var random = SeededGenerator(seed: seed &+ UInt64(index &* 613))
        let cloudCount = max(1, Int(Double(cloudsPerBand) * (0.6 + intensity * 0.4)))
        let travel = size.width * 1.6

        for _ in 0..<cloudCount {
            let phase = Double.random(in: 0...1, using: &random)
            let progress = ((time * band.speed / travel) + phase).truncatingRemainder(dividingBy: 1)
            let originX = CGFloat(progress) * travel - size.width * 0.3
            let originY = CGFloat(band.y + Double.random(in: -0.06...0.06, using: &random)) * size.height
            let cloudWidth = size.width * CGFloat(0.4 + Double.random(in: 0...0.35, using: &random)) * CGFloat(band.scale)
            let opacity = band.opacity * Double.random(in: 0.8...1.15, using: &random)

            drawCloud(&canvas, random: &random, origin: CGPoint(x: originX, y: originY),
                      width: cloudWidth, opacity: opacity)
        }
    }

    /// One lumpy cloud: overlapping circles along a baseline, bigger in the
    /// middle so the silhouette rises to a crown.
    private func drawCloud(_ canvas: inout GraphicsContext, random: inout SeededGenerator,
                           origin: CGPoint, width: CGFloat, opacity: Double) {
        let puffCount = Int.random(in: 5...8, using: &random)
        let baseRadius = width / CGFloat(puffCount) * 1.5

        for index in 0..<puffCount {
            let t = Double(index) / Double(max(1, puffCount - 1))
            // Crown: radius peaks mid-cloud.
            let bulge = 0.55 + 0.45 * sin(t * .pi)
            let radius = baseRadius * CGFloat(bulge) * CGFloat(Double.random(in: 0.8...1.25, using: &random))
            let x = origin.x + CGFloat(t) * width
            let lift = CGFloat(Double.random(in: -0.35...0.1, using: &random)) * radius
            let rect = CGRect(x: x - radius, y: origin.y + lift - radius,
                              width: radius * 2, height: radius * 2)
            canvas.fill(Path(ellipseIn: rect), with: .color(tint.opacity(opacity)))
        }
    }

    private var bands: [Band] {
        switch density {
        case .light:
            return [Band(y: 0.18, scale: 0.7, speed: 9, opacity: 0.16),
                    Band(y: 0.34, scale: 1.0, speed: 15, opacity: 0.12)]
        case .medium:
            return [Band(y: 0.10, scale: 0.65, speed: 7, opacity: 0.22),
                    Band(y: 0.26, scale: 0.9, speed: 13, opacity: 0.20),
                    Band(y: 0.44, scale: 1.15, speed: 20, opacity: 0.15)]
        case .heavy:
            return [Band(y: 0.04, scale: 0.8, speed: 6, opacity: 0.34),
                    Band(y: 0.20, scale: 1.05, speed: 12, opacity: 0.30),
                    Band(y: 0.38, scale: 1.3, speed: 19, opacity: 0.24)]
        }
    }

    private var cloudsPerBand: Int {
        switch density {
        case .light: return 2
        case .medium: return 3
        case .heavy: return 4
        }
    }

    /// Storm clouds read darker; light clouds are bright against the sky.
    private var tint: Color {
        switch density {
        case .light: return .white
        case .medium: return Color(white: 0.92)
        case .heavy: return Color(white: 0.78)
        }
    }
}
