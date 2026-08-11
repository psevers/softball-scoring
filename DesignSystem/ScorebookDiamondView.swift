import SwiftUI

struct ScorebookDiamondView: View {
    let firstBaseRunner: Int?
    let secondBaseRunner: Int?
    let thirdBaseRunner: Int?

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = side * 0.31
            let home = CGPoint(x: center.x, y: center.y + radius)
            let first = CGPoint(x: center.x + radius, y: center.y)
            let second = CGPoint(x: center.x, y: center.y - radius)
            let third = CGPoint(x: center.x - radius, y: center.y)

            ZStack {
                Path { path in
                    path.move(to: home)
                    path.addLine(to: first)
                    path.addLine(to: second)
                    path.addLine(to: third)
                    path.closeSubpath()
                }
                .stroke(AppTheme.graphite.opacity(0.72), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))

                base(at: home, runner: nil, label: "H")
                base(at: first, runner: firstBaseRunner, label: "1")
                base(at: second, runner: secondBaseRunner, label: "2")
                base(at: third, runner: thirdBaseRunner, label: "3")
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private func base(at point: CGPoint, runner: Int?, label: String) -> some View {
        ZStack {
            Rectangle()
                .fill(runner == nil ? AppTheme.paper : AppTheme.graphite.opacity(0.82))
                .overlay(Rectangle().stroke(AppTheme.graphite.opacity(0.72), lineWidth: 1))
                .frame(width: 18, height: 18)
                .rotationEffect(.degrees(45))

            if let runner {
                Text("\(runner)")
                    .font(.caption2.bold().monospacedDigit())
                    .foregroundStyle(AppTheme.paper)
            } else if label == "H" {
                Text("")
            }
        }
        .position(point)
    }

    private var accessibilityDescription: String {
        let first = firstBaseRunner.map { "runner \($0)" } ?? "empty"
        let second = secondBaseRunner.map { "runner \($0)" } ?? "empty"
        let third = thirdBaseRunner.map { "runner \($0)" } ?? "empty"
        return "Bases. First \(first), second \(second), third \(third)."
    }
}
