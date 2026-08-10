import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                GamesHomeView()
            }
            .tabItem {
                Label("Games", systemImage: "sportscourt")
            }

            NavigationStack {
                StatsHomeView()
            }
            .tabItem {
                Label("Stats", systemImage: "chart.bar")
            }

            NavigationStack {
                TeamHomeView()
            }
            .tabItem {
                Label("Team", systemImage: "person.3")
            }
        }
        .tint(AppTheme.accent)
    }
}

#Preview {
    RootTabView()
}
