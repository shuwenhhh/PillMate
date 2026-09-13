import SwiftUI

/// A compact medication-state marker. Pending doses use a light dashed star
/// outline; completed doses become a filled lavender star with a checkmark.
struct DashedStarBadge: View {
    let isCompleted: Bool

    var body: some View {
        ZStack {
            RoundedStarShape()
                .fill(isCompleted ? AppColors.lavenderAccent : .clear)

            RoundedStarShape()
                .stroke(
                    isCompleted ? AppColors.lavenderAccent : Color(red: 0.54, green: 0.47, blue: 0.70),
                    style: StrokeStyle(
                        lineWidth: isCompleted ? 1.4 : 2.0,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: isCompleted ? [] : [4.5, 3.5]
                    )
                )

            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 38, height: 38)
        .shadow(
            color: isCompleted ? AppColors.lavenderAccent.opacity(0.18) : .clear,
            radius: 5,
            y: 2
        )
        .accessibilityLabel(isCompleted ? "Dose completed" : "Dose not completed")
    }
}

private struct RoundedStarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) * 0.47
        let innerRadius = radius * 0.47
        var points: [CGPoint] = []

        for index in 0..<10 {
            let angle = -Double.pi / 2 + Double(index) * Double.pi / 5
            let distance = index.isMultiple(of: 2) ? radius : innerRadius
            points.append(
                CGPoint(
                    x: center.x + CGFloat(cos(angle)) * distance,
                    y: center.y + CGFloat(sin(angle)) * distance
                )
            )
        }

        func midpoint(_ first: CGPoint, _ second: CGPoint) -> CGPoint {
            CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
        }

        var path = Path()
        path.move(to: midpoint(points[0], points[1]))
        for index in 1...10 {
            let control = points[index % 10]
            path.addQuadCurve(
                to: midpoint(control, points[(index + 1) % 10]),
                control: control
            )
        }
        path.closeSubpath()
        return path
    }
}
