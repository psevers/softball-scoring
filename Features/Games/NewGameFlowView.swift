import SwiftUI
import SwiftData

struct NewGameFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Season.startDate, order: .reverse) private var seasons: [Season]
    @Query(sort: [SortDescriptor(\Player.lastName), SortDescriptor(\Player.firstName)]) private var players: [Player]

    @State private var opponentName = ""
    @State private var gameDate = Date.now
    @State private var homeAway: HomeAway = .away
    @State private var seasonID: UUID?
    @State private var gameFormat: GameFormat = .innings
    @State private var regulationInnings = 7
    @State private var timeLimitMinutes = GameSetupValidation.defaultTimeLimitMinutes
    @State private var lineup: [LineupDraftEntry] = []
    @State private var startingPitcherID: UUID?
    @State private var saveErrorMessage: String?

    init(
        initialOpponentName: String = "",
        initialGameDate: Date = .now,
        initialHomeAway: HomeAway = .away,
        initialGameFormat: GameFormat = .innings,
        initialTimeLimitMinutes: Int = GameSetupValidation.defaultTimeLimitMinutes
    ) {
        _opponentName = State(initialValue: initialOpponentName)
        _gameDate = State(initialValue: initialGameDate)
        _homeAway = State(initialValue: initialHomeAway)
        _gameFormat = State(initialValue: initialGameFormat)
        _timeLimitMinutes = State(initialValue: initialTimeLimitMinutes)
    }

    private var activePlayers: [Player] { players.filter(\.isActive) }
    private var selectedSeason: Season? { seasons.first { $0.id == seasonID } }
    private var canContinue: Bool {
        GameSetupValidation.canContinue(
            opponentName: opponentName,
            seasonID: selectedSeason?.id,
            format: gameFormat,
            timeLimitMinutes: timeLimitMinutes
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScorebookPageHeader(
                        title: "Game Card",
                        subtitle: "Set the matchup, format, and batting order",
                        systemImage: "pencil.and.scribble"
                    )
                    .padding(.vertical, AppTheme.Spacing.sm)
                    .scorebookListRow()
                }

                Section {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        ScorebookLabel("Opponent")
                        TextField("Opponent", text: $opponentName)
                            .font(AppTheme.Typography.body)
                            .textInputAutocapitalization(.words)
                    }
                    .scorebookListRow(verticalPadding: AppTheme.Spacing.sm)

                    DatePicker("Date", selection: $gameDate, displayedComponents: [.date, .hourAndMinute])
                        .font(AppTheme.Typography.body)
                        .scorebookListRow()

                    Picker("Home / Away", selection: $homeAway) {
                        ForEach(HomeAway.allCases) { value in
                            Text(value.rawValue).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .scorebookListRow(verticalPadding: AppTheme.Spacing.sm)
                } header: {
                    ScorebookListSectionHeader("Game")
                }

                Section {
                    if seasons.isEmpty {
                        ContentUnavailableView(
                            "Season Required",
                            systemImage: "calendar.badge.exclamationmark",
                            description: Text("Create a season from Team before starting a game.")
                        )
                        .scorebookListRow(verticalPadding: AppTheme.Spacing.sm)
                    } else {
                        Picker("Season", selection: $seasonID) {
                            Text("Choose Season").tag(UUID?.none)
                            ForEach(seasons) { season in
                                Text(season.name).tag(Optional(season.id))
                            }
                        }
                        .font(AppTheme.Typography.body)
                        .scorebookListRow()
                    }
                } header: {
                    ScorebookListSectionHeader("Season")
                }

                Section {
                    Picker("Game format", selection: $gameFormat) {
                        ForEach(GameFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .scorebookListRow(verticalPadding: AppTheme.Spacing.sm)

                    switch gameFormat {
                    case .innings:
                        Stepper("Regulation innings: \(regulationInnings)", value: $regulationInnings, in: 1...12)
                            .font(AppTheme.Typography.body)
                            .scorebookListRow()
                    case .timeLimit:
                        ScorebookDurationPicker(minutes: $timeLimitMinutes)
                            .scorebookListRow(verticalPadding: AppTheme.Spacing.sm)
                    }
                } header: {
                    ScorebookListSectionHeader("Format")
                }

                Section {
                    NavigationLink {
                        LineupBuilderView(
                            players: activePlayers,
                            lineup: $lineup,
                            startingPitcherID: $startingPitcherID,
                            onStartGame: saveAndStartGame
                        )
                    } label: {
                        Label("Set Lineup", systemImage: "list.number")
                            .font(AppTheme.Typography.actionLabel)
                            .foregroundStyle(canContinue ? AppTheme.accent : AppTheme.graphite.opacity(0.48))
                    }
                    .disabled(!canContinue)
                    .scorebookListRow(verticalPadding: AppTheme.Spacing.xs)
                } footer: {
                    Text("Add the full batting order, then assign the nine defensive positions. Batting-only players can remain without a position.")
                        .font(AppTheme.Typography.metadata)
                        .foregroundStyle(AppTheme.graphite.opacity(0.68))
                        .textCase(nil)
                }
            }
            .listStyle(.plain)
            .listSectionSpacing(0)
            .accessibilityIdentifier("game.setup.form")
            .scorebookFormBackground()
            .overlay(alignment: .leading) { ScorebookMarginRule() }
            .navigationTitle("New Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Could Not Start Game", isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { saveErrorMessage = nil }
            } message: {
                Text(saveErrorMessage ?? "The game could not be saved.")
            }
            .onAppear {
                if seasonID == nil {
                    seasonID = seasons.first(where: \.isActive)?.id ?? seasons.first?.id
                }
            }
        }
    }

    @discardableResult
    private func saveAndStartGame() -> Bool {
        guard let seasonID,
              LineupValidation.canStart(
                entries: lineup.map { .init(playerID: $0.playerID, position: $0.position) },
                startingPitcherID: startingPitcherID
              ) else { return false }

        let game = Game(
            seasonID: seasonID,
            opponentName: opponentName.trimmingCharacters(in: .whitespacesAndNewlines),
            gameDate: gameDate,
            homeAway: homeAway,
            regulationInnings: regulationInnings,
            timeLimitMinutes: gameFormat == .timeLimit ? timeLimitMinutes : nil,
            status: .inProgress,
            startingPitcherID: startingPitcherID,
            startedAt: .now
        )
        modelContext.insert(game)

        for (index, draft) in lineup.enumerated() {
            let entry = LineupEntry(
                playerID: draft.playerID,
                battingOrder: index + 1,
                startingPosition: draft.position,
                gameID: game.id
            )
            modelContext.insert(entry)
        }

        do {
            try modelContext.save()
            dismiss()
            return true
        } catch {
            modelContext.rollback()
            saveErrorMessage = error.localizedDescription
            return false
        }
    }
}

private struct ScorebookDurationPicker: View {
    @Binding var minutes: Int
    @ScaledMetric(relativeTo: .body) private var wheelHeight: CGFloat = 128

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Label("Time Limit", systemImage: "timer")
                    .font(AppTheme.Typography.notation)
                    .foregroundStyle(AppTheme.graphite)

                Spacer()

                Text("\(minutes)")
                    .font(AppTheme.Typography.score)
                    .foregroundStyle(AppTheme.graphite)
                Text("MIN")
                    .font(AppTheme.Typography.fieldLabel)
                    .foregroundStyle(AppTheme.graphite.opacity(0.62))
            }

            PencilRule()

            Picker("Time limit", selection: $minutes) {
                ForEach(GameSetupValidation.timeLimitOptions, id: \.self) { option in
                    Text("\(option) minutes").tag(option)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: min(wheelHeight, 180))
            .clipped()
            .accessibilityIdentifier("game.timeLimit.picker")

            Text("The timer is a reminder; it never finalizes the game automatically.")
                .font(AppTheme.Typography.metadata.italic())
                .foregroundStyle(AppTheme.graphite.opacity(0.66))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, AppTheme.Spacing.xs)
    }
}

struct LineupDraftEntry: Identifiable, Equatable {
    let playerID: UUID
    var position: DefensivePosition?

    var id: UUID { playerID }
}

private struct LineupBuilderView: View {
    @ScaledMetric(relativeTo: .body) private var orderColumnWidth: CGFloat = 32

    let players: [Player]
    @Binding var lineup: [LineupDraftEntry]
    @Binding var startingPitcherID: UUID?
    let onStartGame: () -> Bool

    private var selectedIDs: Set<UUID> { Set(lineup.map(\.playerID)) }
    private var availablePlayers: [Player] { players.filter { !selectedIDs.contains($0.id) } }
    private var defenderCount: Int { lineup.compactMap(\.position).count }
    private var canStart: Bool {
        LineupValidation.canStart(
            entries: lineup.map { .init(playerID: $0.playerID, position: $0.position) },
            startingPitcherID: startingPitcherID
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        ScorebookPageHeader(
                            title: "Lineup Card",
                            subtitle: "Batting order and nine defensive assignments",
                            systemImage: "list.number"
                        )

                        Text("\(lineup.count) batters · \(defenderCount) / \(LineupValidation.requiredDefenderCount) fielders")
                            .font(AppTheme.Typography.tabularNumber)
                            .foregroundStyle(
                                defenderCount == LineupValidation.requiredDefenderCount
                                    ? AppTheme.positive
                                    : AppTheme.graphite.opacity(0.68)
                            )
                            .accessibilityIdentifier("lineup.summary")
                    }
                    .padding(.vertical, AppTheme.Spacing.sm)
                    .scorebookListRow()
                }

                if !lineup.isEmpty {
                    Section {
                        ForEach(Array(lineup.enumerated()), id: \.element.id) { index, entry in
                            if let player = player(entry.playerID) {
                                lineupRow(number: index + 1, player: player, entry: entry)
                                    .scorebookListRow(verticalPadding: AppTheme.Spacing.xs)
                            }
                        }
                        .onMove(perform: moveLineup)
                        .onDelete(perform: removeFromLineup)
                    } header: {
                        ScorebookListSectionHeader("Batting Order")
                    }
                }

                if !availablePlayers.isEmpty {
                    Section {
                        ForEach(availablePlayers) { player in
                            Button {
                                addToLineup(player)
                            } label: {
                                HStack {
                                    playerIdentity(player)
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(AppTheme.accent)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("lineup.add.\(player.displayName)")
                            .scorebookListRow(verticalPadding: AppTheme.Spacing.xs)
                        }
                    } header: {
                        ScorebookListSectionHeader("Available Players")
                    }
                }

                if !lineup.isEmpty {
                    Section {
                        Picker("Pitcher", selection: Binding(
                            get: { startingPitcherID },
                            set: { setStartingPitcher($0) }
                        )) {
                            Text("Choose Pitcher").tag(UUID?.none)
                            ForEach(lineup, id: \.id) { entry in
                                if let player = player(entry.playerID) {
                                    Text(player.displayName).tag(Optional(player.id))
                                }
                            }
                        }
                        .accessibilityIdentifier("lineup.pitcher")
                        .font(AppTheme.Typography.body)
                        .scorebookListRow()
                    } header: {
                        ScorebookListSectionHeader("Starting Pitcher")
                    }
                }

                if !canStart {
                    Section {
                        Text("Add at least nine unique batters, assign each regulation defensive position once, and choose the pitcher. Additional batters do not need a position.")
                            .font(AppTheme.Typography.metadata)
                            .foregroundStyle(AppTheme.graphite.opacity(0.68))
                            .scorebookListRow(verticalPadding: AppTheme.Spacing.sm)
                    }
                }
            }
            .listStyle(.plain)
            .listSectionSpacing(0)
            .accessibilityIdentifier("lineup.list")
            .scorebookFormBackground()
            .overlay(alignment: .leading) { ScorebookMarginRule() }

            Rectangle()
                .fill(AppTheme.rule)
                .frame(height: 1)

            Button {
                _ = onStartGame()
            } label: {
                Label("Start Game", systemImage: "play.fill")
                    .frame(maxWidth: .infinity, minHeight: AppTheme.TouchTarget.minimum)
            }
            .buttonStyle(ScorebookKeyButtonStyle(role: .positive))
            .disabled(!canStart)
            .opacity(canStart ? 1 : 0.46)
            .accessibilityValue("\(lineup.count) batters, \(defenderCount) of \(LineupValidation.requiredDefenderCount) fielders")
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(AppTheme.paper)
        }
        .navigationTitle("Set Lineup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
    }

    private func lineupRow(number: Int, player: Player, entry: LineupDraftEntry) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Text("\(number)")
                .font(AppTheme.Typography.tabularNumber)
                .foregroundStyle(AppTheme.graphite.opacity(0.72))
                .frame(width: orderColumnWidth, alignment: .leading)

            playerIdentity(player)

            Spacer()

            Menu {
                ForEach(LineupValidation.regulationDefensivePositions) { position in
                    Button(position.rawValue) {
                        setPosition(position, for: entry.playerID)
                    }
                }
                Button("Clear Position", role: .destructive) {
                    setPosition(nil, for: entry.playerID)
                }
            } label: {
                Text(entry.position?.rawValue ?? "Pos")
                    .font(AppTheme.Typography.tabularNumber)
                    .foregroundStyle(entry.position == nil ? AppTheme.graphite.opacity(0.58) : AppTheme.accent)
                    .padding(.horizontal, AppTheme.Spacing.sm)
                    .frame(minWidth: 44, minHeight: 44)
                    .overlay {
                        Rectangle()
                            .stroke(entry.position == nil ? AppTheme.rule : AppTheme.accent.opacity(0.58), lineWidth: 1)
                    }
            }
        }
    }

    private func playerIdentity(_ player: Player) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(player.displayName)
                .font(AppTheme.Typography.playerName)
                .foregroundStyle(AppTheme.graphite)
            Text(player.jerseyNumber.isEmpty ? "No jersey" : "#\(player.jerseyNumber)")
                .font(AppTheme.Typography.tabularNumber)
                .foregroundStyle(AppTheme.graphite.opacity(0.62))
        }
    }

    private func player(_ id: UUID) -> Player? {
        players.first { $0.id == id }
    }

    private func addToLineup(_ player: Player) {
        lineup.append(LineupDraftEntry(playerID: player.id, position: player.defaultPosition))
        if player.defaultPosition == .pitcher && startingPitcherID == nil {
            startingPitcherID = player.id
        }
    }

    private func removeFromLineup(at offsets: IndexSet) {
        let removedIDs = offsets.map { lineup[$0].playerID }
        lineup.remove(atOffsets: offsets)
        if let startingPitcherID, removedIDs.contains(startingPitcherID) {
            self.startingPitcherID = nil
        }
    }

    private func moveLineup(from source: IndexSet, to destination: Int) {
        lineup.move(fromOffsets: source, toOffset: destination)
    }

    private func setPosition(_ position: DefensivePosition?, for playerID: UUID) {
        guard let index = lineup.firstIndex(where: { $0.playerID == playerID }) else { return }
        lineup[index].position = position
        if position == .pitcher {
            for otherIndex in lineup.indices where lineup[otherIndex].playerID != playerID && lineup[otherIndex].position == .pitcher {
                lineup[otherIndex].position = nil
            }
            startingPitcherID = playerID
        } else if startingPitcherID == playerID {
            startingPitcherID = nil
        }
    }

    private func setStartingPitcher(_ playerID: UUID?) {
        startingPitcherID = playerID
        guard let playerID else { return }

        for index in lineup.indices {
            if lineup[index].position == .pitcher && lineup[index].playerID != playerID {
                lineup[index].position = nil
            }
        }
        if let index = lineup.firstIndex(where: { $0.playerID == playerID }) {
            lineup[index].position = .pitcher
        }
    }
}

private struct ScorebookListSectionHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(AppTheme.Typography.notation)
            .textCase(nil)
            .foregroundStyle(AppTheme.graphite.opacity(0.78))
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.paper)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(AppTheme.rule)
                    .frame(height: 1)
            }
    }
}

private extension View {
    func scorebookListRow(verticalPadding: CGFloat = 0) -> some View {
        listRowInsets(EdgeInsets(
            top: verticalPadding,
            leading: AppTheme.Spacing.md,
            bottom: verticalPadding,
            trailing: AppTheme.Spacing.md
        ))
        .listRowBackground(AppTheme.paper.opacity(0.97))
        .listRowSeparator(.visible)
        .listRowSeparatorTint(AppTheme.rule)
    }
}

private struct LongLineupPreview: View {
    let players: [Player]
    @State private var lineup: [LineupDraftEntry]
    @State private var startingPitcherID: UUID?

    init(players: [Player]) {
        self.players = players
        let regulationPositions = Set(LineupValidation.regulationDefensivePositions)
        _lineup = State(initialValue: players.map { player in
            LineupDraftEntry(
                playerID: player.id,
                position: player.defaultPosition.flatMap {
                    regulationPositions.contains($0) ? $0 : nil
                }
            )
        })
        _startingPitcherID = State(initialValue: players.first {
            $0.defaultPosition == .pitcher
        }?.id)
    }

    var body: some View {
        NavigationStack {
            LineupBuilderView(
                players: players,
                lineup: $lineup,
                startingPitcherID: $startingPitcherID,
                onStartGame: { true }
            )
        }
    }
}

#Preview("New Game — Time Limit") {
    NewGameFlowView(
        initialOpponentName: "Northside Storm",
        initialGameDate: Date(timeIntervalSince1970: 1_786_562_700),
        initialHomeAway: .home,
        initialGameFormat: .timeLimit,
        initialTimeLimitMinutes: 75
    )
    .modelContainer(PreviewData.longLineupContainer)
}

#Preview("Lineup — Fourteen Batters") {
    let container = PreviewData.longLineupContainer
    LongLineupPreview(players: PreviewData.players(in: container))
        .modelContainer(container)
}
