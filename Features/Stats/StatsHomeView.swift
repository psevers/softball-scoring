import SwiftUI

struct StatsHomeView: View {
    var body: some View {
        EmptyStateView(
            systemImage: "chart.bar",
            title: "No Stats Yet",
            message: "Season statistics will appear after games are scored."
        )
        .navigationTitle("Stats")
    }
}

#Preview {
    NavigationStack { StatsHomeView() }
}
