import SwiftUI
import SwiftData

struct TeamHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Team.createdAt) private var teams: [Team]
    @Query(sort: [SortDescriptor(\Player.lastName), SortDescriptor(\Player.firstName)]) private var players: [Player]
    @Query(sort: \Season.startDate, order: .reverse) private var seasons: [Season]

    @State private var selectedSection: TeamSection = .roster
    @State private var playerEditorPresentation: PlayerEditorPresentation?
    @State private var showingSeasonEditor = false
    @State private var showingTeamEditor = false

    private var team: Team? { teams.first }
    private var activePlayers: [Player] { players.filter(\.isActive) }
    private var inactivePlayers: [Player] { players.filter { !$0.isActive } }
    private var activeSeason: Season? { seasons.first(where: \.isActive) }

    var body: some View {
        List {
            teamHeader

            Section {
                Picker("Team section", selection: $selectedSection) {
                    ForEach(TeamSection.allCases) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            switch selectedSection {
            case .roster:
                rosterContent
            case .seasons:
                seasonsContent
            }
        }
        .accessibilityIdentifier("team.roster.list")
        .scorebookFormBackground()
        .listStyle(.plain)
        .navigationTitle("Team")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if selectedSection == .roster {
                        playerEditorPresentation = .add
                    } else {
                        showingSeasonEditor = true
                    }
                } label: {
                    Label(selectedSection == .roster ? "Add Player" : "Add Season", systemImage: "plus")
                }
                .accessibilityIdentifier("team.add")
            }
        }
        .sheet(item: $playerEditorPresentation) { presentation in
            PlayerEditorView(player: presentation.player)
        }
        .sheet(isPresented: $showingSeasonEditor) {
            SeasonEditorView(existingSeasons: seasons)
        }
        .sheet(isPresented: $showingTeamEditor) {
            TeamEditorView(team: team)
        }
    }

    @ViewBuilder
    private var teamHeader: some View {
        Section {
            Button {
                showingTeamEditor = true
            } label: {
                HStack(spacing: AppTheme.Spacing.md) {
                    Image(systemName: "shield")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(AppTheme.graphite.opacity(0.78))
                        .frame(width: AppTheme.TouchTarget.minimum, height: AppTheme.TouchTarget.minimum)

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Text(team?.displayName ?? "Set Up Your Team")
                            .font(AppTheme.Typography.teamName)
                            .foregroundStyle(AppTheme.graphite)
                        if let activeSeason {
                            Text("Active season: \(activeSeason.name)")
                                .font(AppTheme.Typography.body)
                                .foregroundStyle(AppTheme.graphite.opacity(0.72))
                        } else {
                            Text("Add a season before your first game")
                                .font(AppTheme.Typography.body)
                                .foregroundStyle(AppTheme.graphite.opacity(0.72))
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
        .scorebookAdministrativeRow()
    }

    @ViewBuilder
    private var rosterContent: some View {
        if players.isEmpty {
            Section {
                ScorebookEmptyLedger(
                    systemImage: "person.badge.plus",
                    title: "Build Your Roster",
                    message: "Add players now so game setup is fast at the field."
                )
                .frame(maxWidth: .infinity)
                .listRowInsets(EdgeInsets())
            }
            .scorebookAdministrativeRow()
        } else {
            Section {
                ForEach(activePlayers) { player in
                    playerRow(player)
                }
            } header: {
                ScorebookLabel("Active Roster · \(activePlayers.count)")
            }
            .scorebookAdministrativeRow()

            if !inactivePlayers.isEmpty {
                Section {
                    ForEach(inactivePlayers) { player in
                        playerRow(player)
                    }
                } header: {
                    ScorebookLabel("Inactive")
                }
                .scorebookAdministrativeRow()
            }
        }
    }

    @ViewBuilder
    private var seasonsContent: some View {
        if seasons.isEmpty {
            Section {
                ScorebookEmptyLedger(
                    systemImage: "calendar.badge.plus",
                    title: "Create a Season",
                    message: "Games and season statistics will be grouped under the season you choose."
                )
                .frame(maxWidth: .infinity)
                .listRowInsets(EdgeInsets())
            }
            .scorebookAdministrativeRow()
        } else {
            Section {
                ForEach(seasons) { season in
                    Button {
                        activate(season)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                                Text(season.name)
                                    .font(AppTheme.Typography.playerName)
                                    .foregroundStyle(AppTheme.graphite)
                                Text(season.dateRangeDescription)
                                    .font(AppTheme.Typography.tabularNumber)
                                    .foregroundStyle(AppTheme.graphite.opacity(0.68))
                            }
                            Spacer()
                            if season.isActive {
                                Label("Active", systemImage: "checkmark.circle.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                ScorebookLabel("Seasons")
            }
            .scorebookAdministrativeRow()
        }
    }

    private func playerRow(_ player: Player) -> some View {
        Button {
            playerEditorPresentation = .edit(player)
        } label: {
            HStack(spacing: AppTheme.Spacing.sm) {
                Text(player.jerseyNumber.isEmpty ? "—" : "#\(player.jerseyNumber)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(player.displayName)
                        .font(AppTheme.Typography.playerName)
                        .foregroundStyle(AppTheme.graphite)
                    HStack(spacing: AppTheme.Spacing.sm) {
                        if let position = player.defaultPosition {
                            Text(position.rawValue)
                        }
                        Text("B: \(player.battingSide.rawValue.prefix(1))")
                        Text("T: \(player.throwingHand.rawValue.prefix(1))")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                if !player.isActive {
                    Text("Inactive")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if player.isActive {
                Button("Deactivate", role: .destructive) {
                    player.isActive = false
                    try? modelContext.save()
                }
                .tint(AppTheme.destructive)
            } else {
                Button("Activate") {
                    player.isActive = true
                    try? modelContext.save()
                }
                .tint(AppTheme.accent)
            }
        }
    }

    private func activate(_ season: Season) {
        SeasonSelection.activate(season, among: seasons)
        try? modelContext.save()
    }
}

private enum PlayerEditorPresentation: Identifiable {
    case add
    case edit(Player)

    var id: String {
        switch self {
        case .add:
            "add"
        case let .edit(player):
            player.id.uuidString
        }
    }

    var player: Player? {
        switch self {
        case .add:
            nil
        case let .edit(player):
            player
        }
    }
}

private enum TeamSection: String, CaseIterable, Identifiable {
    case roster = "Roster"
    case seasons = "Seasons"
    var id: String { rawValue }
}

#Preview {
    NavigationStack { TeamHomeView() }
        .modelContainer(PreviewData.administrativeSurfaces.container)
}

#Preview("Team · Accessibility XL") {
    NavigationStack { TeamHomeView() }
        .modelContainer(PreviewData.administrativeSurfaces.container)
        .environment(\.dynamicTypeSize, .accessibility2)
}
