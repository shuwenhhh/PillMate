import Foundation
import SwiftUI

/// Reusable star asset. The character artwork lives in Assets.xcassets so the
/// same round HappyStar image is used for settled stars and the falling star.
struct Star: View {
    let size: CGFloat
    var style: MedicationStarStyle = .defaultStyle

    var body: some View {
        Image(style.assetName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

/// The jar shell is intentionally separate from the star so the star can be
/// animated through the opening without being baked into the jar image. The
/// supplied GlassJar artwork is used for both passes: a quiet rear refraction
/// and a brighter front highlight pass around the animated stars.
struct GlassJar: View {
    enum Layer: Equatable { case back, front }

    let layer: Layer

    var body: some View {
        Image("GlassJar")
            .resizable()
            // The processed asset is tightly cropped to the jar. Stretching
            // into this local canvas keeps all star coordinates aligned with
            // the existing Today-page layout while retaining the artwork.
            .frame(width: GlassStarRenderer.canvasSize.width,
                   height: GlassStarRenderer.canvasSize.height)
            .opacity(layer == .back ? 0.34 : 0.94)
            .allowsHitTesting(false)
    }
}

/// Composition of the separate glass and star layers, with a falling-star
/// animation triggered whenever `collected` increases.
struct GlassStarJar: View {
    let starStyles: [MedicationStarStyle]
    let total: Int

    private var collected: Int { starStyles.count }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedStars: [AnimatedStar] = []
    @State private var movingStarIDs: Set<UUID> = []
    @State private var previousCollected: Int?

    var body: some View {
        GeometryReader { geometry in
            let metrics = JarMetrics(in: geometry.size)

            // The clock owns every frame. This is the same local-coordinate
            // choreography as StarJarDemo.swift, scaled together with the jar
            // so no screen or global coordinates are involved.
            TimelineView(.animation(paused: movingStarIDs.isEmpty)) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate

                ZStack(alignment: .topLeading) {
                    // Layer 1: rear glass/refraction.
                    GlassJar(layer: .back)
                        .scaleEffect(metrics.scale)

                    ForEach(animatedStars) { star in
                        let elapsed = star.instant ? 10 : now - star.start
                        let pose = JarMotion.pose(slot: star.slot,
                                                  elapsed: elapsed,
                                                  instant: star.instant)
                        renderedStar(pose: pose,
                                     style: star.style,
                                     elapsed: elapsed,
                                     metrics: metrics)
                    }

                    // Layer 3: front glass/highlights. The star is never
                    // clipped by the interior while falling through the mouth.
                    GlassJar(layer: .front)
                        .scaleEffect(metrics.scale)
                }
                .frame(width: GlassStarRenderer.canvasSize.width,
                       height: GlassStarRenderer.canvasSize.height)
                .transaction { $0.animation = nil }
            }
            .frame(width: GlassStarRenderer.canvasSize.width,
                   height: GlassStarRenderer.canvasSize.height)
        }
        .frame(width: GlassStarRenderer.canvasSize.width, height: GlassStarRenderer.canvasSize.height)
        .accessibilityLabel("Medication reward jar")
        .accessibilityValue("\(collected) of \(total) doses collected")
        .onAppear {
            guard animatedStars.isEmpty else { return }
            previousCollected = collected
            // Existing records appear settled; only a newly completed task
            // receives the falling choreography.
            animatedStars = Array(starStyles.prefix(JarMotion.capacity)).enumerated().map { index, style in
                AnimatedStar(
                    slot: index,
                    style: style,
                    start: 0,
                    instant: true
                )
            }
        }
        .onChange(of: starStyles) { oldStyles, newStyles in
            let old = previousCollected ?? oldStyles.count
            let new = newStyles.count
            previousCollected = new

            if new == old, newStyles != oldStyles {
                movingStarIDs.removeAll()
                animatedStars = Array(newStyles.prefix(JarMotion.capacity)).enumerated().map { index, style in
                    AnimatedStar(slot: index, style: style, start: 0, instant: true)
                }
                return
            }

            if new < old {
                // A dose can be unticked from the middle of the schedule, so
                // rebuild the settled stars instead of assuming the last slot
                // was the one removed.
                movingStarIDs.removeAll()
                animatedStars = Array(newStyles.prefix(JarMotion.capacity)).enumerated().map { index, style in
                    AnimatedStar(slot: index, style: style, start: 0, instant: true)
                }
                return
            }

            let added = min(new, JarMotion.capacity) - min(max(old, 0), JarMotion.capacity)
            guard added > 0 else { return }
            let newlyCompletedStyles = addedStyles(from: oldStyles, to: newStyles)
            let start = Date().timeIntervalSinceReferenceDate
            for offset in 0..<added {
                let slot = min(max(old, 0), JarMotion.capacity) + offset
                let star = AnimatedStar(
                    slot: slot,
                    style: newlyCompletedStyles.indices.contains(offset)
                        ? newlyCompletedStyles[offset]
                        : .defaultStyle,
                    start: start + Double(offset) * 0.08,
                    instant: reduceMotion
                )
                animatedStars.append(star)

                guard !reduceMotion else { continue }
                movingStarIDs.insert(star.id)
                let id = star.id
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5 + Double(offset) * 0.08) {
                    movingStarIDs.remove(id)
                }
            }
        }
    }

    private func addedStyles(
        from oldStyles: [MedicationStarStyle],
        to newStyles: [MedicationStarStyle]
    ) -> [MedicationStarStyle] {
        var remainingOldCounts: [MedicationStarStyle: Int] = [:]
        for style in oldStyles {
            remainingOldCounts[style, default: 0] += 1
        }

        return newStyles.filter { style in
            guard let remaining = remainingOldCounts[style], remaining > 0 else {
                return true
            }
            remainingOldCounts[style] = remaining - 1
            return false
        }
    }

    private func renderedStar(pose: JarMotion.Pose,
                              style: MedicationStarStyle,
                              elapsed: Double,
                              metrics: JarMetrics) -> some View {
        let point = metrics.point(x: pose.center.x, y: pose.center.y)
        let diameter = pose.diameter * metrics.scale
        let impact = JarMotion.impactProgress(slot: pose.slot, elapsed: elapsed)
        let index = Int(abs(pose.center.x + pose.center.y))

        return ZStack {
            // A quiet warm landing glow is calculated from the same timeline;
            // it never introduces a second implicit animation.
            if impact > 0 {
                Ellipse()
                    .fill(style.accentColor
                        .opacity(Double(0.16 * impact)))
                    .frame(width: diameter * 2.5, height: diameter * 0.50)
                    .blur(radius: diameter * 0.28)
                    .offset(y: diameter * 0.34)
            }

            ForEach(0..<4, id: \.self) { trailIndex in
                let phase = CGFloat(trailIndex + 1) / 5
                let particleColor: Color = trailIndex.isMultiple(of: 2)
                    ? .white
                    : style.accentColor.opacity(0.72)
                let particleDiameter = max(1.3, diameter * (0.06 + phase * 0.02))
                let particleOpacity = JarMotion.trailOpacity(slot: pose.slot,
                                                               elapsed: elapsed,
                                                               particle: trailIndex)
                Circle()
                    .fill(particleColor)
                    .frame(width: particleDiameter, height: particleDiameter)
                    .blur(radius: max(0.5, diameter * 0.025))
                    .opacity(Double(particleOpacity))
                    .offset(x: CGFloat(sin(Double(index + trailIndex) * 1.7)) * diameter * 0.30,
                            y: diameter * (-0.75 + phase * 0.30))
            }

            Star(size: diameter, style: style)
                .blur(radius: diameter * 0.18)
                .opacity(0.18)
            Star(size: diameter, style: style)
        }
        .frame(width: diameter, height: diameter)
        .scaleEffect(x: pose.scaleX, y: pose.scaleY, anchor: .bottom)
        .rotationEffect(.degrees(pose.angle))
        .position(point)
    }
}

private struct AnimatedStar: Identifiable {
    let id = UUID()
    let slot: Int
    let style: MedicationStarStyle
    let start: TimeInterval
    let instant: Bool
}

/// Choreography copied from StarJarDemo.swift. Its 320×440 design space is
/// scaled into the component's 280×380 local canvas by JarMotion.pose.
private enum JarMotion {
    static let designWidth: CGFloat = 320
    static let designHeight: CGFloat = 440
    static let renderWidth: CGFloat = 280
    static let renderHeight: CGFloat = 380
    // The jar is rendered at a compact scale on Today. 106 design points
    // resolves to roughly one third of the visible jar width, so settled and
    // falling stars keep the same generous, readable presence.
    static let diameter: CGFloat = 106
    static let gravity = 1800.0
    static let startY = 34.0
    static let releaseY = 198.0
    static let capacity = 20
    static let designMouthY: CGFloat = 104
    static let renderMouthY: CGFloat = 8
    static let renderFloorY: CGFloat = 358
    static let yMotionScale = (renderFloorY - renderMouthY) / (402 - designMouthY)

    struct Pose {
        let center: CGPoint
        let angle: Double
        let scaleX: CGFloat
        let scaleY: CGFloat
        let diameter: CGFloat
        let slot: Int
    }

    static func target(slot: Int) -> CGPoint {
        let columns: [CGFloat] = [160, 122, 198, 84, 236]
        return CGPoint(x: columns[slot % columns.count],
                       y: 370 - CGFloat(slot / columns.count) * 40)
    }

    static func pose(slot: Int, elapsed: Double, instant: Bool) -> Pose {
        let end = target(slot: slot)
        let fallTime = sqrt(2 * (Double(end.y) - startY) / gravity)
        let releaseTime = sqrt(2 * (releaseY - startY) / gravity)
        let t = instant ? 10 : max(0, elapsed)
        let finalAngle = Double((slot * 7) % 19) - 9
        var x = Double(end.x)
        var y = Double(end.y)
        var angle = finalAngle
        var squash = 0.0

        if t < fallTime {
            y = startY + 0.5 * gravity * t * t
            let denominator = max(0.001, fallTime - releaseTime)
            let u = min(1, max(0, (t - releaseTime) / denominator))
            let smooth = u * u * (3 - 2 * u)
            x = 160 + (Double(end.x) - 160) * smooth
            angle = -12 + (finalAngle + 12) * t / fallTime
        } else {
            var b = t - fallTime
            for bounceHeight in [12.0, 3.0] {
                let speed = sqrt(2 * gravity * bounceHeight)
                let duration = 2 * speed / gravity
                if b < duration {
                    y = Double(end.y) - speed * b + 0.5 * gravity * b * b
                    angle += 3 * sin(.pi * b / duration)
                    break
                }
                b -= duration
            }
            let impactAge = t - fallTime
            if impactAge < 0.10 {
                squash = 0.08 * sin(.pi * impactAge / 0.10)
            }
        }

        let xScale = renderWidth / designWidth
        // The supplied PNG is tightly cropped at the rim, while the demo's
        // 320×440 canvas leaves space above the mouth. Map the motion around
        // the rim/floor anchors so the launch is visible above the glass and
        // the final center still rests on the asset's inner base.
        let mappedY = renderMouthY + (CGFloat(y) - designMouthY) * yMotionScale
        return Pose(center: CGPoint(x: CGFloat(x) * xScale,
                                     y: mappedY),
                    angle: angle,
                    scaleX: CGFloat(1 + squash),
                    scaleY: CGFloat(1 - squash),
                    diameter: diameter * xScale,
                    slot: slot)
    }

    static func impactProgress(slot: Int, elapsed: Double) -> CGFloat {
        let end = target(slot: slot)
        let fallTime = sqrt(2 * (Double(end.y) - startY) / gravity)
        let value = min(1, max(0, (elapsed - fallTime) / 0.42))
        return CGFloat(sin(value * .pi))
    }

    static func trailOpacity(slot: Int, elapsed: Double, particle: Int) -> CGFloat {
        let end = target(slot: slot)
        let fallTime = sqrt(2 * (Double(end.y) - startY) / gravity)
        let progress = min(1, max(0, elapsed / fallTime))
        let delay = CGFloat(particle) * 0.08
        return max(0, min(1, (progress - delay) * 3.5)) * CGFloat(1 - min(1, elapsed / (fallTime + 0.10)))
    }
}

/// Backwards-compatible name for existing Today-page call sites.
typealias StarJarView = GlassStarJar

private struct JarMetrics {
    let size: CGSize
    let scale: CGFloat
    let origin: CGPoint

    init(in size: CGSize) {
        self.size = size
        self.scale = min(size.width / GlassStarRenderer.canvasSize.width, size.height / GlassStarRenderer.canvasSize.height)
        self.origin = CGPoint(
            x: (size.width - GlassStarRenderer.canvasSize.width * scale) / 2,
            y: (size.height - GlassStarRenderer.canvasSize.height * scale) / 2
        )
    }

    var center: CGPoint { CGPoint(x: size.width / 2, y: size.height / 2) }

    func point(x: CGFloat, y: CGFloat) -> CGPoint {
        CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
    }
}

private enum GlassStarRenderer {
    static let canvasSize = CGSize(width: 280, height: 380)
}
