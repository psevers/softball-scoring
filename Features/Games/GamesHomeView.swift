import SwiftUI
import SwiftData

struct GamesHomeView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \Game.gameDate, order: .reverse) private var games: [Game]
    @Query(sort: \Season.startDate, order: .reverse) private var seasons: [Season]
    @Query private var players: [Player]

    @State private var showingNewGame = false

    private var inProgressGames: [Game] { games.filter { $0.status == .inProgress } }
    private var otherGames: [Game] { games.filter { $0.status != .inProgress } }
    private var canCreateGame: Bool { !seasons.isEmpty && players.filter(\.isActive).count >= LineupValidation.requiredDefenderCount }

    var body: some View {
        ZStack {
            ScorebookPaperBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    ScorebookPageHeader(
                        title: "Games",
                        subtitle: "Season scorecards",
                        systemImage: "book.closed"
                    )

                    if games.isEmpty {
                        ScorebookEmptyLedger(
                            systemImage: "sportscourt",
                            title: "No Games Yet",
                            message: canCreateGame
                                ? "Your roster is ready. Create a game and set today's lineup."
                                : "Create a season and add at least nine active players before starting a game."
                        )
                    } else {
                        ScorebookLedger {
                            if !inProgressGames.isEmpty {
                                gameSection(title: "In Progress", games: inProgressGames, emphasis: true)
                            }

                            if !otherGames.isEmpty {
                                gameSection(title: "Games", games: otherGames, emphasis: false)
                            }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
            }
            .accessibilityIdentifier("games.home.ledger")
        }
        .navigationTitle("Games")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
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

    private func gameSection(title: String, games: [Game], emphasis: Bool) -> some View {
        ScorebookPageSection(title) {
            ForEach(games) { game in
                NavigationLink {
                    if emphasis {
                        LiveGameView(game: game)
                    } else {
                        GameSummaryView(game: game)
                    }
                } label: {
                    ScorebookLedgerRow {
                        gameRow(game, emphasis: emphasis)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func gameRow(_ game: Game, emphasis: Bool) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    ScorebookLabel(game.homeAway.rawValue)
                    Spacer()
                    if emphasis {
                        resumeLabel
                    }
                }
                opponentLabel(for: game)
                dateLabel(for: game)
            }
        } else {
            HStack(spacing: AppTheme.Spacing.sm) {
                ScorebookLabel(game.homeAway.rawValue)
                    .frame(width: 44, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    opponentLabel(for: game)
                    dateLabel(for: game)
                }
                Spacer()
                if emphasis {
                    resumeLabel
                }
            }
        }
    }

    private func opponentLabel(for game: Game) -> some View {
        Text(game.homeAway == .home ? "vs \(game.opponentName)" : "@ \(game.opponentName)")
            .font(AppTheme.Typography.playerName)
            .foregroundStyle(AppTheme.graphite)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func dateLabel(for game: Game) -> some View {
        Text(game.gameDate.formatted(date: .abbreviated, time: .shortened))
            .font(AppTheme.Typography.metadata)
            .foregroundStyle(AppTheme.graphite.opacity(0.68))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var resumeLabel: some View {
        Text("Resume →")
            .font(AppTheme.Typography.notation)
            .foregroundStyle(AppTheme.positive)
            .lineLimit(1)
    }
}

#Preview("Games — Empty") {
    NavigationStack { GamesHomeView() }
        .modelContainer(PreviewData.container)
}

#Preview("Games — Ledger") {
    NavigationStack { GamesHomeView() }
        .modelContainer(PreviewData.gamesContainer)
}
