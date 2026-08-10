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
    @State private var timeLimitMinutes = 75
    @State private var lineup: [LineupDraftEntry] = []
    @State private var startingPitcherID: UUID?
    @State private var saveErrorMessage: String?
    @FocusState private var isTimeLimitFocused: Bool

    private var activePlayers: [Player] { players.filter(\.isActive) }
    private var selectedSeason: Season? { seasons.first { $0.id == seasonID } }
    private var canContinue: Bool {
        !opponentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && selectedSeason != nil
            && (gameFormat != .timeLimit || timeLimitMinutes > 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Game") {
                    TextField("Opponent", text: $opponentName)
                        .textInputAutocapitalization(.words)

                    DatePicker("Date", selection: $gameDate, displayedComponents: [.date, .hourAndMinute])

                    Picker("Home / Away", selection: $homeAway) {
                        ForEach(HomeAway.allCases) { value in
                            Text(value.rawValue).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Season") {
                    if seasons.isEmpty {
                        ContentUnavailableView(
                            "Season Required",
                            systemImage: "calendar.badge.exclamationmark",
                            description: Text("Create a season from Team before starting a game.")
                        )
                    } else {
                        Picker("Season", selection: $seasonID) {
                            Text("Choose Season").tag(UUID?.none)
                            ForEach(seasons) { season in
                                Text(season.name).tag(Optional(season.id))
                            }
                        }
                    }
                }

                Section("Format") {
                    Picker("Game format", selection: $gameFormat) {
                        ForEach(GameFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch gameFormat {
                    case .innings:
                        Stepper("Regulation innings: \(regulationInnings)", value: $regulationInnings, in: 1...12)
                    case .timeLimit:
                        LabeledContent("Time limit") {
                            TextField("Minutes", value: $timeLimitMinutes, format: .number)
                                .keyboardType(.numberPad)
                                .focused($isTimeLimitFocused)
                                .multilineTextAlignment(.trailing)
                                .frame(minWidth: 72)
                            Text("minutes")
                                .foregroundStyle(.secondary)
                        }
                    }
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
                    }
                    .disabled(!canContinue)
                } footer: {
                    Text("Add the full batting order, then assign the nine defensive positions. Batting-only players can remain without a position.")
                }
            }
            .scorebookFormBackground()
            .navigationTitle("New Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isTimeLimitFocused = false }
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
            .onChange(of: gameFormat) { _, newValue in
                if newValue != .timeLimit {
                    isTimeLimitFocused = false
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

struct LineupDraftEntry: Identifiable, Equatable {
    let playerID: UUID
    var position: DefensivePosition?

    var id: UUID { playerID }
}

private struct LineupBuilderView: View {
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
        List {
            Section {
                HStack {
                    Label("Batting Order", systemImage: "person.3.fill")
                    Spacer()
                    Text("\(lineup.count) batters · \(defenderCount) / \(LineupValidation.requiredDefenderCount) fielders")
                        .monospacedDigit()
                        .foregroundStyle(defenderCount == LineupValidation.requiredDefenderCount ? AppTheme.accent : .secondary)
                }
            }

            if !lineup.isEmpty {
                Section("Batting Order") {
                    ForEach(Array(lineup.enumerated()), id: \.element.id) { index, entry in
                        if let player = player(entry.playerID) {
                            lineupRow(number: index + 1, player: player, entry: entry)
                        }
                    }
                    .onMove(perform: moveLineup)
                    .onDelete(perform: removeFromLineup)
                }
            }

            if !availablePlayers.isEmpty {
                Section("Available Players") {
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
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !lineup.isEmpty {
                Section("Starting Pitcher") {
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
                }
            }

            if !canStart {
                Section {
                    EmptyView()
                } footer: {
                    Text("Add at least nine unique batters, assign each regulation defensive position once, and choose the pitcher. Additional batters do not need a position.")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                _ = onStartGame()
            } label: {
                Label("Start Game", systemImage: "play.fill")
                    .frame(maxWidth: .infinity, minHeight: AppTheme.TouchTarget.minimum)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canStart)
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(.bar)
        }
        .scorebookFormBackground()
        .navigationTitle("Set Lineup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
    }

    private func lineupRow(number: Int, player: Player, entry: LineupDraftEntry) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Text("\(number)")
                .font(.headline.monospacedDigit())
                .frame(width: 24, alignment: .leading)

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
                    .font(.subheadline.weight(.semibold))
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
    }

    private func playerIdentity(_ player: Player) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(player.displayName)
                .foregroundStyle(.primary)
            Text(player.jerseyNumber.isEmpty ? "No jersey" : "#\(player.jerseyNumber)")
                .font(.caption)
                .foregroundStyle(.secondary)
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

#Preview {
    NewGameFlowView()
        .modelContainer(PreviewData.container)
}
