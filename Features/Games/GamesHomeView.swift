import SwiftUI
import SwiftData

struct GamesHomeView: View {
    @Query(sort: \Game.gameDate, order: .reverse) private var games: [Game]
    @Query(sort: \Season.startDate, order: .reverse) private var seasons: [Season]
    @Query private var players: [Player]

    @State private var showingNewGame = false

    private var inProgressGames: [Game] { games.filter { $0.status == .inProgress } }
    private var otherGames: [Game] { games.filter { $0.status != .inProgress } }
    private var canCreateGame: Bool { !seasons.isEmpty && players.filter(\.isActive).count >= LineupValidation.requiredStarterCount }

    var body: some View {
        Group {
            if games.isEmpty {
                EmptyStateView(
                    systemImage: "sportscourt",
                    title: "No Games Yet",
                    message: canCreateGame
                        ? "Your roster is ready. Create a game and set today's lineup."
                        : "Create a season and add at least nine active players before starting a game."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if !inProgressGames.isEmpty {
                        Section("In Progress") {
                            ForEach(inProgressGames) { game in
                                NavigationLink {
                                    LiveGameView(game: game)
                                } label: {
                                    gameRow(game, emphasis: true)
                                }
                            }
                        }
                    }

                    if !otherGames.isEmpty {
                        Section("Games") {
                            ForEach(otherGames) { game in
                                NavigationLink {
                                    GameSummaryView(game: game)
                                } label: {
                                    gameRow(game, emphasis: false)
                                }
                            }
                        }
                    }
                }
            }
        }
        .background(AppTheme.paper)
        .navigationTitle("Games")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingNewGame = true
                } label: {
                    Label("New Game", systemImage: "plus")
                }
                .disabled(!canCreateGame)
                .accessibilityLabel("New Game")
            }
        }
        .sheet(isPresented: $showingNewGame) {
            NewGameFlowView()
        }
    }

    private func gameRow(_ game: Game, emphasis: Bool) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 4) {
                Text(game.homeAway == .home ? "vs \(game.opponentName)" : "@ \(game.opponentName)")
                    .font(emphasis ? .headline : .body)
                Text(game.gameDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if emphasis {
                Text("Resume")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack { GamesHomeView() }
        .modelContainer(PreviewData.container)
}
