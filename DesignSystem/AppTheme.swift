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

struct ScorebookRuledPaperBackground: View {
    var lineSpacing: CGFloat = 28

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(AppTheme.paper))

            var rules = Path()
            stride(from: lineSpacing, through: size.height, by: lineSpacing).forEach { y in
                rules.move(to: CGPoint(x: 0, y: y))
                rules.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(rules, with: .color(AppTheme.rule.opacity(0.65)), lineWidth: 0.5)

            var margin = Path()
            margin.move(to: CGPoint(x: AppTheme.Spacing.lg, y: 0))
            margin.addLine(to: CGPoint(x: AppTheme.Spacing.lg, y: size.height))
            context.stroke(margin, with: .color(Color.red.opacity(0.10)), lineWidth: 0.75)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct PencilRule: View {
    var body: some View {
        Canvas { context, size in
            var upper = Path()
            upper.move(to: CGPoint(x: 0, y: size.height * 0.38))
            upper.addLine(to: CGPoint(x: size.width, y: size.height * 0.50))
            context.stroke(upper, with: .color(AppTheme.graphite.opacity(0.48)), lineWidth: 0.8)

            var lower = Path()
            lower.move(to: CGPoint(x: 2, y: size.height * 0.68))
            lower.addLine(to: CGPoint(x: size.width - 3, y: size.height * 0.60))
            context.stroke(lower, with: .color(AppTheme.graphite.opacity(0.18)), lineWidth: 0.6)
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

struct ScorebookPageHeader: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(AppTheme.graphite.opacity(0.78))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(.title3, design: .serif, weight: .semibold))
                        .foregroundStyle(AppTheme.graphite)
                    Text(subtitle)
                        .font(.caption.italic())
                        .foregroundStyle(AppTheme.graphite.opacity(0.68))
                }
            }
            PencilRule()
        }
        .accessibilityElement(children: .combine)
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
            .background { ScorebookRuledPaperBackground() }
    }
}
