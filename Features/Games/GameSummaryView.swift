import SwiftUI
import SwiftData

struct GameSummaryView: View {
    let game: Game

    @Query(sort: [SortDescriptor(\Player.lastName), SortDescriptor(\Player.firstName)]) private var players: [Player]
    @Query(sort: \Season.startDate, order: .reverse) private var seasons: [Season]
    @Query(sort: \LineupEntry.battingOrder) private var lineupEntries: [LineupEntry]

    private var season: Season? { seasons.first { $0.id == game.seasonID } }
    private var gameLineup: [LineupEntry] { lineupEntries.filter { $0.gameID == game.id } }
    private var startingPitcher: Player? {
        guard let id = game.startingPitcherID else { return nil }
        return player(id)
    }

    var body: some View {
        ZStack {
            ScorebookRuledPaperBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    ScorebookPageHeader(
                        title: game.homeAway == .home ? "vs \(game.opponentName)" : "@ \(game.opponentName)",
                        subtitle: game.gameDate.formatted(date: .abbreviated, time: .shortened),
                        systemImage: "book.closed"
                    )

                    ScorebookLedger {
                        ScorebookPageSection("Game") {
                            summaryRow("Status", value: statusDescription)
                            summaryRow("Season", value: season?.name ?? "Unknown Season")
                            summaryRow("Format", value: game.formatDescription, style: .tabular)
                            if let startingPitcher {
                                summaryRow(
                                    "Starting Pitcher",
                                    value: startingPitcher.displayName,
                                    style: .playerName
                                )
                            }
                        }

                        ScorebookPageSection("Starting Lineup") {
                            ForEach(gameLineup) { entry in
                                if let player = player(entry.playerID) {
                                    ScorebookLedgerRow {
                                        HStack(spacing: AppTheme.Spacing.sm) {
                                            Text("\(entry.battingOrder)")
                                                .font(AppTheme.Typography.tabularNumber.weight(.semibold))
                                                .frame(width: 28, alignment: .leading)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(player.displayName)
                                                    .font(AppTheme.Typography.playerName)
                                                    .foregroundStyle(AppTheme.graphite)
                                                if !player.jerseyNumber.isEmpty {
                                                    Text("#\(player.jerseyNumber)")
                                                        .font(AppTheme.Typography.tabularNumber)
                                                        .foregroundStyle(AppTheme.graphite.opacity(0.68))
                                                }
                                            }
                                            Spacer()
                                            Text(entry.startingPosition?.rawValue ?? "—")
                                                .font(AppTheme.Typography.tabularNumber.weight(.semibold))
                                                .foregroundStyle(AppTheme.graphite.opacity(0.72))
                                        }
                                    }
                                }
                            }
                        }

                        ScorebookPageSection("Scorebook") {
                            ScorebookLedgerRow {
                                Label(
                                    game.status == .final ? "Game Complete" : "Saved for Live Scoring",
                                    systemImage: "checkmark.circle.fill"
                                )
                                .font(AppTheme.Typography.body.weight(.semibold))
                                .foregroundStyle(AppTheme.positive)
                            }
                        }
                    }
                }
                .padding(AppTheme.Spacing.md)
            }
            .overlay(alignment: .leading) { ScorebookMarginRule() }
        }
        .navigationTitle(game.opponentName)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("game.summary.page")
    }

    private var statusDescription: String {
        game.status == .inProgress
            ? "In Progress"
            : game.status?.rawValue.capitalized ?? "Unreadable"
    }

    private func summaryRow(
        _ label: String,
        value: String,
        style: SummaryValueStyle = .body
    ) -> some View {
        ScorebookLedgerRow {
            LabeledContent {
                Text(value)
                    .font(style.font)
                    .foregroundStyle(AppTheme.graphite)
            } label: {
                ScorebookLabel(label)
            }
        }
    }

    private func player(_ id: UUID) -> Player? {
        players.first { $0.id == id }
    }
}

private enum SummaryValueStyle {
    case body
    case playerName
    case tabular

    var font: Font {
        switch self {
        case .body:
            AppTheme.Typography.body
        case .playerName:
            AppTheme.Typography.playerName
        case .tabular:
            AppTheme.Typography.tabularNumber
        }
    }
}

#Preview("Game summary") {
    let fixture = PreviewData.administrativeSurfaces
    NavigationStack { GameSummaryView(game: fixture.game) }
        .modelContainer(fixture.container)
}

#Preview("Game summary · Accessibility XL") {
    let fixture = PreviewData.administrativeSurfaces
    NavigationStack { GameSummaryView(game: fixture.game) }
        .modelContainer(fixture.container)
        .environment(\.dynamicTypeSize, .accessibility2)
}
