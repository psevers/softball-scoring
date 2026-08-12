import SwiftUI

struct StatsHomeView: View {
    var body: some View {
        ZStack {
            ScorebookRuledPaperBackground()

            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                ScorebookPageHeader(
                    title: "Stats",
                    subtitle: "Season scorebook",
                    systemImage: "chart.bar"
                )
                ScorebookEmptyLedger(
                    systemImage: "chart.bar",
                    title: "No Stats Yet",
                    message: "Season statistics will appear after games are scored."
                )
                Spacer(minLength: 0)
            }
            .padding(AppTheme.Spacing.md)
        }
        .navigationTitle("Stats")
        .accessibilityIdentifier("stats.empty.page")
    }
}

#Preview {
    NavigationStack { StatsHomeView() }
}

#Preview("Stats · Accessibility XL") {
    NavigationStack { StatsHomeView() }
        .environment(\.dynamicTypeSize, .accessibility2)
}
