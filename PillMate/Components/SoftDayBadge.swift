import SwiftUI

/// Borderless, softly scalloped day marker used by the Records calendar.
/// Completed days receive the purple glow and checkmark from the reference UI;
/// incomplete days remain quiet lavender shapes without a hard outline.
struct SoftDayBadge: View {
    let isCompleted: Bool
    var isSelected: Bool = false

    var body: some View {
        Canvas(opaque: false, colorMode: .extendedLinear) { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let path = Self.rosettePath(center: center, radius: min(size.width, size.height) * 0.43)
            let isActive = isCompleted || isSelected

            if isActive {
                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: 7))
                    layer.opacity = isCompleted ? 0.28 : 0.10
                    layer.fill(path, with: .color(AppColors.lavenderAccent))
                }
                context.fill(
                    path,
                    with: .radialGradient(
                        Gradient(colors: [
                            AppColors.lavenderAccent.opacity(isCompleted ? 0.98 : 0.78),
                            Color(red: 0.49, green: 0.36, blue: 0.88).opacity(isCompleted ? 0.96 : 0.70)
                        ]),
                        center: CGPoint(x: center.x - 4, y: center.y - 5),
                        startRadius: 1,
                        endRadius: size.width * 0.48
                    )
                )
            } else {
                context.fill(path, with: .color(AppColors.lavenderMuted.opacity(0.72)))
            }
        }
        .frame(width: 44, height: 44)
        .overlay {
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    private static func rosettePath(center: CGPoint, radius: CGFloat) -> Path {
        let pointCount = 16
        let innerRadius = radius * 0.88
        var points: [CGPoint] = []

        for index in 0..<pointCount {
            let angle = -Double.pi / 2 + Double(index) * 2 * Double.pi / Double(pointCount)
            let distance = index.isMultiple(of: 2) ? radius : innerRadius
            points.append(
                CGPoint(
                    x: center.x + CGFloat(cos(angle)) * distance,
                    y: center.y + CGFloat(sin(angle)) * distance
                )
            )
        }

        func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        }

        var path = Path()
        path.move(to: midpoint(points[0], points[1]))
        for index in 1...pointCount {
            let control = points[index % pointCount]
            path.addQuadCurve(
                to: midpoint(control, points[(index + 1) % pointCount]),
                control: control
            )
        }
        path.closeSubpath()
        return path
    }
}
