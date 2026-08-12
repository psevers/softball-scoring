import SwiftUI
import UIKit

enum AppTheme {
    /// Accent intentionally stays restrained; the app should feel like graphite on paper,
    /// with iOS accent reserved for interactive state.
    static let accent = Color(red: 0.24, green: 0.40, blue: 0.28)
    static let positive = Color(red: 0.24, green: 0.40, blue: 0.28)
    static let destructive = Color(red: 0.64, green: 0.16, blue: 0.14)
    static let paper = Color(red: 0.975, green: 0.965, blue: 0.925)
    static let graphite = Color(red: 0.16, green: 0.16, blue: 0.14)
    static let rule = Color(red: 0.34, green: 0.32, blue: 0.26).opacity(0.24)
    static let faintRule = Color(red: 0.34, green: 0.32, blue: 0.26).opacity(0.075)

    enum Typography {
        static let expressiveFontName = "PatrickHand-Regular"
        static let expressiveFontIsAvailable = UIFont(
            name: expressiveFontName,
            size: UIFont.labelFontSize
        ) != nil

        static var pageTitle: Font {
            expressive(size: 34, relativeTo: .largeTitle, fallbackDesign: .serif, weight: .semibold)
        }

        static var teamName: Font {
            expressive(size: 25, relativeTo: .title2, fallbackDesign: .serif, weight: .semibold)
        }

        static var playerName: Font {
            expressive(size: 22, relativeTo: .title3, fallbackDesign: .rounded, weight: .medium)
        }

        static var notation: Font {
            expressive(size: 19, relativeTo: .body, fallbackDesign: .rounded, weight: .medium)
        }

        static var actionLabel: Font {
            expressive(size: 19, relativeTo: .headline, fallbackDesign: .rounded, weight: .semibold)
        }

        static let fieldLabel = Font.system(.caption, design: .rounded, weight: .semibold)
        static let body = Font.body
        static let metadata = Font.caption
        static let tabularNumber = Font.system(.body, design: .monospaced).monospacedDigit()
        static let score = Font.system(.largeTitle, design: .monospaced, weight: .bold).monospacedDigit()

        private static func expressive(
            size: CGFloat,
            relativeTo textStyle: Font.TextStyle,
            fallbackDesign: Font.Design,
            weight: Font.Weight
        ) -> Font {
            guard expressiveFontIsAvailable else {
                return .system(textStyle, design: fallbackDesign, weight: weight)
            }
            return .custom(expressiveFontName, size: size, relativeTo: textStyle)
        }
    }

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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        titleIcon
                        titleText
                    }
                    subtitleText
                }
            } else {
                HStack(spacing: AppTheme.Spacing.sm) {
                    titleIcon

                    VStack(alignment: .leading, spacing: 1) {
                        titleText
                        subtitleText
                    }
                }
            }
            PencilRule()
        }
        .accessibilityElement(children: .combine)
    }

    private var titleIcon: some View {
        Image(systemName: systemImage)
            .font(.title2)
            .foregroundStyle(AppTheme.graphite.opacity(0.78))
    }

    private var titleText: some View {
        Text(title)
            .font(AppTheme.Typography.pageTitle)
            .foregroundStyle(AppTheme.graphite)
    }

    private var subtitleText: some View {
        Text(subtitle)
            .font(AppTheme.Typography.metadata.italic())
            .foregroundStyle(AppTheme.graphite.opacity(0.68))
    }
}

struct ScorebookLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(AppTheme.Typography.fieldLabel)
            .tracking(1.1)
            .foregroundStyle(AppTheme.graphite.opacity(0.68))
    }
}

struct ScorebookMarginRule: View {
    var body: some View {
        Rectangle()
            .fill(Color.red.opacity(0.10))
            .frame(width: 0.75)
            .padding(.leading, AppTheme.Spacing.lg)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}

struct ScorebookPageSection<Content: View>: View {
    let title: String?
    @ViewBuilder let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                ScorebookLabel(title)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.vertical, AppTheme.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.graphite.opacity(0.035))
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(AppTheme.rule)
                            .frame(height: 1)
                    }
            }
            content
        }
        .background(AppTheme.paper.opacity(0.97))
    }
}

struct ScorebookLedger<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .background(AppTheme.paper.opacity(0.97))
        .overlay {
            Rectangle()
                .stroke(AppTheme.rule, lineWidth: 1)
        }
    }
}

struct ScorebookLedgerRow<Content: View>: View {
    @ScaledMetric(relativeTo: .body) private var verticalPadding = 10
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity, minHeight: AppTheme.TouchTarget.minimum, alignment: .leading)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(AppTheme.rule)
                    .frame(height: 1)
            }
    }
}

struct ScorebookStat: Identifiable {
    let id: String
    let label: String
    let value: String
}

struct ScorebookStatGrid: View {
    let stats: [ScorebookStat]

    @ScaledMetric(relativeTo: .body) private var minimumColumnWidth = 56.0

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: minimumColumnWidth), spacing: 0, alignment: .leading)]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 0) {
            ForEach(stats) { stat in
                VStack(alignment: .leading, spacing: 2) {
                    ScorebookLabel(stat.label)
                        .accessibilityIdentifier("scorebook.stat.\(stat.id).label")
                    Text(stat.value)
                        .font(AppTheme.Typography.tabularNumber)
                        .foregroundStyle(AppTheme.graphite)
                        .accessibilityIdentifier("scorebook.stat.\(stat.id).value")
                }
                .padding(AppTheme.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay {
                    Rectangle()
                        .stroke(AppTheme.rule, lineWidth: 0.5)
                }
            }
        }
    }
}

enum ScorebookKeyRole {
    case normal
    case selected
    case positive
    case destructive
    case invalid
}

struct ScorebookKeyButtonStyle: ButtonStyle {
    let role: ScorebookKeyRole

    init(role: ScorebookKeyRole = .normal) {
        self.role = role
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.actionLabel)
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity, minHeight: AppTheme.TouchTarget.gameAction)
            .padding(.horizontal, AppTheme.Spacing.sm)
            .background(configuration.isPressed ? pressedBackgroundColor : backgroundColor)
            .overlay {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(strokeColor.opacity(configuration.isPressed ? 0.82 : 0.56), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }

    private var foregroundColor: Color {
        switch role {
        case .normal:
            AppTheme.graphite
        case .selected, .positive:
            AppTheme.positive
        case .destructive, .invalid:
            AppTheme.destructive
        }
    }

    private var backgroundColor: Color {
        switch role {
        case .normal:
            AppTheme.paper
        case .selected:
            AppTheme.positive.opacity(0.16)
        case .positive:
            AppTheme.positive.opacity(0.08)
        case .destructive, .invalid:
            AppTheme.destructive.opacity(0.08)
        }
    }

    private var strokeColor: Color {
        switch role {
        case .normal:
            AppTheme.graphite
        case .selected, .positive:
            AppTheme.positive
        case .destructive, .invalid:
            AppTheme.destructive
        }
    }

    private var pressedBackgroundColor: Color {
        switch role {
        case .normal:
            AppTheme.graphite.opacity(0.08)
        case .selected:
            AppTheme.positive.opacity(0.24)
        case .positive:
            AppTheme.positive.opacity(0.16)
        case .destructive, .invalid:
            AppTheme.destructive.opacity(0.16)
        }
    }
}

struct ScorebookEmptyLedger: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        ScorebookLedger {
            ScorebookPageSection("Scorecard") {
                ScorebookLedgerRow {
                    HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                        Image(systemName: systemImage)
                            .font(.title2)
                            .foregroundStyle(AppTheme.graphite.opacity(0.72))
                            .frame(width: AppTheme.TouchTarget.minimum, height: AppTheme.TouchTarget.minimum)

                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            Text(title)
                                .font(AppTheme.Typography.teamName)
                                .foregroundStyle(AppTheme.graphite)
                            Text(message)
                                .font(AppTheme.Typography.body)
                                .foregroundStyle(AppTheme.graphite.opacity(0.74))
                        }
                    }
                }
            }
        }
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

    func scorebookAdministrativeRow() -> some View {
        listRowBackground(AppTheme.paper.opacity(0.94))
            .listRowSeparatorTint(AppTheme.rule)
    }
}
