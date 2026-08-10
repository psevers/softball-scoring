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
        List {
            Section {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text(game.homeAway == .home ? "vs \(game.opponentName)" : "@ \(game.opponentName)")
                        .font(.title2.bold())
                    Text(game.gameDate.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, AppTheme.Spacing.xs)
            }

            Section("Game") {
                LabeledContent(
                    "Status",
                    value: game.status == .inProgress
                        ? "In Progress"
                        : game.status?.rawValue.capitalized ?? "Unreadable"
                )
                LabeledContent("Season", value: season?.name ?? "Unknown Season")
                LabeledContent("Format", value: "\(game.regulationInnings) innings")
                if let startingPitcher {
                    LabeledContent("Starting Pitcher", value: startingPitcher.displayName)
                }
            }

            Section("Starting Lineup") {
                ForEach(gameLineup) { entry in
                    if let player = player(entry.playerID) {
                        HStack {
                            Text("\(entry.battingOrder)")
                                .font(.headline.monospacedDigit())
                                .frame(width: 28, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(player.displayName)
                                if !player.jerseyNumber.isEmpty {
                                    Text("#\(player.jerseyNumber)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(entry.startingPosition?.rawValue ?? "—")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                VStack(spacing: AppTheme.Spacing.sm) {
                    Label("Ready for Live Scoring", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(AppTheme.accent)
                    Text("Pitch-by-pitch scoring lands in Vertical Slice 3. This persisted game is the state that screen will resume into.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.md)
            }
        }
        .scorebookFormBackground()
        .navigationTitle(game.opponentName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func player(_ id: UUID) -> Player? {
        players.first { $0.id == id }
    }
}
