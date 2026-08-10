import SwiftUI

enum AppTheme {
    /// Accent intentionally stays restrained; the app should feel like graphite on paper,
    /// with iOS accent reserved for interactive state.
    static let accent = Color.accentColor
    static let paper = Color(red: 0.975, green: 0.965, blue: 0.925)
    static let graphite = Color(red: 0.16, green: 0.16, blue: 0.14)
    static let rule = Color.black.opacity(0.10)
    static let faintRule = Color.black.opacity(0.045)

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum CornerRadius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
    }

    enum TouchTarget {
        static let minimum: CGFloat = 44
        static let gameAction: CGFloat = 52
    }
}

struct ScorebookPaperBackground: View {
    var gridSpacing: CGFloat = 24

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(AppTheme.paper))

            var fineGrid = Path()
            stride(from: CGFloat.zero, through: size.width, by: gridSpacing).forEach { x in
                fineGrid.move(to: CGPoint(x: x, y: 0))
                fineGrid.addLine(to: CGPoint(x: x, y: size.height))
            }
            stride(from: CGFloat.zero, through: size.height, by: gridSpacing).forEach { y in
                fineGrid.move(to: CGPoint(x: 0, y: y))
                fineGrid.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(fineGrid, with: .color(AppTheme.faintRule), lineWidth: 0.5)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct ScorebookSheet<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.paper.opacity(0.96))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm)
                    .stroke(AppTheme.rule, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm))
    }
}

extension View {
    func scorebookFormBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(AppTheme.paper)
    }
}
