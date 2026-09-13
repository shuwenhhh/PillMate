import SwiftUI

/// A compact, elegant sparkle burst for a completed dose.
/// The Canvas keeps the effect light: one warm point, a few soft particles,
/// and short curved trails that fade out within 700ms.
struct DoseCelebrationView: View {
    @State private var progress: CGFloat = 0

    private let particles: [Particle] = [
        .init(kind: .sparkle, angle: -104, distance: 42, size: 5, color: .cream),
        .init(kind: .sparkle, angle: -21, distance: 51, size: 4, color: .lavender),
        .init(kind: .sparkle, angle: 142, distance: 39, size: 5, color: .white),
        .init(kind: .dot, angle: -72, distance: 36, size: 3, color: .white),
        .init(kind: .dot, angle: -43, distance: 48, size: 2, color: .warm),
        .init(kind: .dot, angle: 12, distance: 40, size: 3, color: .cream),
        .init(kind: .dot, angle: 55, distance: 53, size: 2, color: .white),
        .init(kind: .dot, angle: 88, distance: 43, size: 3, color: .warm),
        .init(kind: .dot, angle: 178, distance: 50, size: 2, color: .lavender),
        .init(kind: .dot, angle: 224, distance: 37, size: 3, color: .cream),
        .init(kind: .tinyStar, angle: 202, distance: 52, size: 5, color: .warm)
    ]

    private let trails: [Trail] = [
        .init(angle: -132, length: 37, bend: -7),
        .init(angle: -62, length: 45, bend: 8),
        .init(angle: 28, length: 42, bend: -6),
        .init(angle: 116, length: 34, bend: 7),
        .init(angle: 198, length: 39, bend: -5)
    ]

    var body: some View {
        Canvas(opaque: false, colorMode: .extendedLinear) { context, size in
            drawBurst(in: &context, size: size)
        }
        .frame(width: 168, height: 168)
        .allowsHitTesting(false)
        .onAppear {
            progress = 0
            // Start on the next run-loop turn so the initial light point is
            // rendered before the particles expand outward.
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.70)) {
                    progress = 1
                }
            }
        }
    }

    private func drawBurst(in context: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let particlePhase = min(1, max(0, (progress - 0.10) / 0.48))
        let particleTravel = 1 - pow(1 - particlePhase, 2)
        let particleFade = min(1, max(0, (progress - 0.48) / 0.52))
        let particleOpacity = 1 - particleFade
        let glowPhase = min(1, max(0, progress / 0.62))
        let glowRadius = 20 + 25 * glowPhase
        let glowOpacity = 0.42 * (1 - min(1, max(0, (progress - 0.42) / 0.38)))

        // Subtle central glow: 20px → 45px, then fades.
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 8))
            layer.fill(Path(ellipseIn: CGRect(x: center.x - glowRadius, y: center.y - glowRadius, width: glowRadius * 2, height: glowRadius * 2)), with: .color(Color(red: 1.0, green: 0.88, blue: 0.48).opacity(glowOpacity)))
        }
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 14))
            layer.fill(Path(ellipseIn: CGRect(x: center.x - glowRadius * 0.72, y: center.y - glowRadius * 0.72, width: glowRadius * 1.44, height: glowRadius * 1.44)), with: .color(Color(red: 0.91, green: 0.86, blue: 1.0).opacity(glowOpacity * 0.48)))
        }

        // Delicate curved light trails, intentionally varied and asymmetrical.
        for trail in trails {
            let angle = trail.angle * .pi / 180
            let start = CGPoint(x: center.x + CGFloat(cos(angle)) * 8 * particleTravel, y: center.y + CGFloat(sin(angle)) * 8 * particleTravel)
            let endDistance = trail.length * particleTravel
            let end = CGPoint(x: center.x + CGFloat(cos(angle)) * endDistance, y: center.y + CGFloat(sin(angle)) * endDistance)
            let normal = CGPoint(x: CGFloat(-sin(angle)) * trail.bend, y: CGFloat(cos(angle)) * trail.bend)
            var path = Path()
            path.move(to: start)
            path.addQuadCurve(to: end, control: CGPoint(x: (start.x + end.x) / 2 + normal.x, y: (start.y + end.y) / 2 + normal.y))
            context.stroke(path, with: .color(Color(red: 1.0, green: 0.93, blue: 0.67).opacity(0.58 * particleOpacity)), style: StrokeStyle(lineWidth: 1.25, lineCap: .round))
        }

        for particle in particles {
            let angle = particle.angle * .pi / 180
            let distance = particle.distance * particleTravel
            let point = CGPoint(x: center.x + CGFloat(cos(angle)) * distance, y: center.y + CGFloat(sin(angle)) * distance)
            switch particle.kind {
            case .dot:
                let radius = particle.size / 2
                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: 2.6))
                    layer.opacity = 0.62 * particleOpacity
                    layer.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: particle.size, height: particle.size)), with: .color(particle.color.value))
                }
                context.fill(Path(ellipseIn: CGRect(x: point.x - radius / 2, y: point.y - radius / 2, width: radius, height: radius)), with: .color(particle.color.value.opacity(particleOpacity * 0.96)))
            case .sparkle:
                drawFourPointSparkle(in: &context, center: point, size: particle.size * (1 - particleFade * 0.35), color: particle.color.value, opacity: particleOpacity)
            case .tinyStar:
                drawTinyStar(in: &context, center: point, size: particle.size * (1 - particleFade * 0.35), opacity: particleOpacity)
            }
        }

        // 0–100ms warm-white point, scaling to 1.2 before fading away.
        let pointPhase = min(1, progress / 0.14)
        let pointScale = pointPhase < 1 ? pointPhase * 1.2 : max(0, 1 - (progress - 0.32) / 0.35)
        let pointRadius: CGFloat = 3.0 * pointScale
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 4))
            layer.opacity = Double(max(0, 1 - progress * 1.4))
            layer.fill(Path(ellipseIn: CGRect(x: center.x - pointRadius * 2.5, y: center.y - pointRadius * 2.5, width: pointRadius * 5, height: pointRadius * 5)), with: .color(Color.white.opacity(0.80)))
        }
        context.fill(Path(ellipseIn: CGRect(x: center.x - pointRadius, y: center.y - pointRadius, width: pointRadius * 2, height: pointRadius * 2)), with: .color(Color.white.opacity(Double(max(0, 1 - progress * 1.4)))))
    }

    private func drawFourPointSparkle(in context: inout GraphicsContext, center: CGPoint, size: CGFloat, color: Color, opacity: CGFloat) {
        var path = Path()
        path.move(to: CGPoint(x: center.x, y: center.y - size))
        path.addQuadCurve(to: CGPoint(x: center.x + size, y: center.y), control: CGPoint(x: center.x + size * 0.28, y: center.y - size * 0.15))
        path.addQuadCurve(to: CGPoint(x: center.x, y: center.y + size), control: CGPoint(x: center.x + size * 0.28, y: center.y + size * 0.15))
        path.addQuadCurve(to: CGPoint(x: center.x - size, y: center.y), control: CGPoint(x: center.x - size * 0.28, y: center.y + size * 0.15))
        path.addQuadCurve(to: CGPoint(x: center.x, y: center.y - size), control: CGPoint(x: center.x - size * 0.28, y: center.y - size * 0.15))
        path.closeSubpath()
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 2.2))
            layer.opacity = Double(opacity) * 0.42
            layer.fill(path, with: .color(color))
        }
        context.fill(path, with: .color(color.opacity(Double(opacity) * 0.94)))
    }

    private func drawTinyStar(in context: inout GraphicsContext, center: CGPoint, size: CGFloat, opacity: CGFloat) {
        let path = roundedStarPath(center: center, radius: size)
        context.fill(path, with: .color(Color(red: 1.0, green: 0.90, blue: 0.54).opacity(Double(opacity))))
    }

    private func roundedStarPath(center: CGPoint, radius: CGFloat) -> Path {
        let inner = radius * 0.46
        var points: [CGPoint] = []
        for index in 0..<10 {
            let angle = -Double.pi / 2 + Double(index) * Double.pi / 5
            let r = index.isMultiple(of: 2) ? radius : inner
            points.append(CGPoint(x: center.x + CGFloat(cos(angle)) * r, y: center.y + CGFloat(sin(angle)) * r))
        }
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        var path = Path()
        path.move(to: mid(points[0], points[1]))
        for index in 1...10 {
            let control = points[index % 10]
            path.addQuadCurve(to: mid(control, points[(index + 1) % 10]), control: control)
        }
        path.closeSubpath()
        return path
    }

    private struct Particle {
        enum Kind { case dot, sparkle, tinyStar }
        let kind: Kind
        let angle: Double
        let distance: CGFloat
        let size: CGFloat
        let color: ParticleColor
    }

    private struct Trail {
        let angle: Double
        let length: CGFloat
        let bend: CGFloat
    }

    private enum ParticleColor {
        case white, cream, warm, lavender

        var value: Color {
            switch self {
            case .white: return Color.white
            case .cream: return Color(red: 1.0, green: 0.957, blue: 0.761)
            case .warm: return Color(red: 1.0, green: 0.898, blue: 0.541)
            case .lavender: return Color(red: 0.91, green: 0.867, blue: 1.0)
            }
        }
    }
}
