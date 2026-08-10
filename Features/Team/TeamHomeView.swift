import SwiftUI
import SwiftData

struct TeamHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Team.createdAt) private var teams: [Team]
    @Query(sort: [SortDescriptor(\Player.lastName), SortDescriptor(\Player.firstName)]) private var players: [Player]
    @Query(sort: \Season.startDate, order: .reverse) private var seasons: [Season]

    @State private var selectedSection: TeamSection = .roster
    @State private var showingPlayerEditor = false
    @State private var editingPlayer: Player?
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
        .navigationTitle("Team")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if selectedSection == .roster {
                        editingPlayer = nil
                        showingPlayerEditor = true
                    } else {
                        showingSeasonEditor = true
                    }
                } label: {
                    Label(selectedSection == .roster ? "Add Player" : "Add Season", systemImage: "plus")
                }
                .accessibilityIdentifier("team.add")
            }
        }
        .sheet(isPresented: $showingPlayerEditor) {
            PlayerEditorView(player: editingPlayer)
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
                    Image(systemName: "shield.fill")
                        .font(.title2)
                        .frame(width: AppTheme.TouchTarget.minimum, height: AppTheme.TouchTarget.minimum)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Text(team?.displayName ?? "Set Up Your Team")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if let activeSeason {
                            Text("Active season: \(activeSeason.name)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Add a season before your first game")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
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
    }

    @ViewBuilder
    private var rosterContent: some View {
        if players.isEmpty {
            Section {
                EmptyStateView(
                    systemImage: "person.badge.plus",
                    title: "Build Your Roster",
                    message: "Add players now so game setup is fast at the field."
                )
                .frame(maxWidth: .infinity)
            }
        } else {
            Section("Active Roster · \(activePlayers.count)") {
                ForEach(activePlayers) { player in
                    playerRow(player)
                }
            }

            if !inactivePlayers.isEmpty {
                Section("Inactive") {
                    ForEach(inactivePlayers) { player in
                        playerRow(player)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var seasonsContent: some View {
        if seasons.isEmpty {
            Section {
                EmptyStateView(
                    systemImage: "calendar.badge.plus",
                    title: "Create a Season",
                    message: "Games and season statistics will be grouped under the season you choose."
                )
                .frame(maxWidth: .infinity)
            }
        } else {
            Section("Seasons") {
                ForEach(seasons) { season in
                    Button {
                        activate(season)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                                Text(season.name)
                                    .foregroundStyle(.primary)
                                Text(season.dateRangeDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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
            }
        }
    }

    private func playerRow(_ player: Player) -> some View {
        Button {
            editingPlayer = player
            showingPlayerEditor = true
        } label: {
            HStack(spacing: AppTheme.Spacing.sm) {
                Text(player.jerseyNumber.isEmpty ? "—" : "#\(player.jerseyNumber)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(player.displayName)
                        .foregroundStyle(.primary)
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
            Button(player.isActive ? "Deactivate" : "Activate") {
                player.isActive.toggle()
                try? modelContext.save()
            }
            .tint(player.isActive ? .orange : AppTheme.accent)
        }
    }

    private func activate(_ season: Season) {
        SeasonSelection.activate(season, among: seasons)
        try? modelContext.save()
    }
}

private enum TeamSection: String, CaseIterable, Identifiable {
    case roster = "Roster"
    case seasons = "Seasons"
    var id: String { rawValue }
}

#Preview {
    NavigationStack { TeamHomeView() }
        .modelContainer(PreviewData.container)
}
