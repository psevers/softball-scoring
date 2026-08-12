import SwiftUI
import SwiftData

private enum OffensiveQuickSuggestion {
    case awardedFirstBase
    case strikeout
    case homeRun
}

struct LiveGameView: View {
    let game: Game

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: [SortDescriptor(\Player.lastName), SortDescriptor(\Player.firstName)]) private var players: [Player]
    @Query(sort: \LineupEntry.battingOrder) private var allLineupEntries: [LineupEntry]

    @State private var session: LiveGameSession
    @State private var errorMessage: String?
    @State private var feedbackTick = 0
    @State private var selectedOutcome: BallInPlayOutcome?
    @State private var selectedOffensiveOutcome: BallInPlayOutcome?

    init(game: Game) {
        self.game = game
        _session = State(initialValue: LiveGameSession(gameID: game.id))
    }

    private var gameRecords: [GameEventRecord] { session.snapshot?.records ?? [] }

    private var validatedHomeAway: HomeAway? {
        HomeAway(rawValue: game.homeAwayRawValue)
    }

    private var homeAway: HomeAway {
        validatedHomeAway ?? .away
    }

    private var trackedBattingOrder: [TrackedBatterIdentity]? {
        TrackedBattingOrder.resolve(
            gameID: game.id,
            lineupEntries: allLineupEntries,
            players: players
        )
    }

    private var replay: GameEventReplay.Result {
        session.snapshot?.replay
            ?? GameEventReplay.Result(state: GameState(), rejectedRecordIDs: [])
    }

    private var state: GameState { replay.state }

    private var pitcher: Player? {
        guard let pitcherID = game.startingPitcherID else { return nil }
        return players.first { $0.id == pitcherID }
    }

    private var pitcherCount: PitchCount {
        guard let pitcherID = game.startingPitcherID else { return PitchCount() }
        return state.pitchCount(for: pitcherID)
    }

    private var currentTrackedBatter: TrackedBatterIdentity? {
        guard let trackedBattingOrder,
              (1...trackedBattingOrder.count).contains(state.currentTrackedBatterSlot) else {
            return nil
        }
        return trackedBattingOrder[state.currentTrackedBatterSlot - 1]
    }

    private var battingLines: [UUID: BattingLine] { session.snapshot?.battingLines ?? [:] }

    var body: some View {
        ZStack {
            ScorebookRuledPaperBackground()

            ScrollView {
                ScorebookLedger {
                    atBatCell

                    if validatedHomeAway == nil
                        || !replay.rejectedRecordIDs.isEmpty
                        || session.loadError != nil {
                        historyWarning
                    } else if state.isOpponentBatting(homeAway: homeAway) {
                        defensiveScoringSurface
                    } else if trackedBattingOrder == nil {
                        lineupWarning
                    } else {
                        offensiveScoringSurface
                    }
                }
                .padding(AppTheme.Spacing.md)
            }
            .overlay(alignment: .leading) {
                ScorebookMarginRule()
            }
        }
        .navigationTitle(game.opponentName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    PlayHistoryView(game: game, session: session)
                } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .accessibilityIdentifier("game.history")
            }
        }
        .task {
            session.refresh(game: game, modelContext: modelContext)
        }
        .alert("Scoring Paused", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "The play could not be saved.")
        }
        .sheet(item: $selectedOutcome) { outcome in
            RunnerConfirmationSheet(
                outcome: outcome,
                state: state,
                homeAway: homeAway,
                onCancel: { selectedOutcome = nil },
                onRecord: recordBallInPlay
            )
            .presentationDetents([.large])
            .interactiveDismissDisabled()
        }
        .sheet(item: $selectedOffensiveOutcome) { outcome in
            OffensiveRunnerConfirmationSheet(
                outcome: outcome,
                state: state,
                homeAway: homeAway,
                battingOrder: trackedBattingOrder ?? [],
                onCancel: { selectedOffensiveOutcome = nil },
                onRecord: recordOffensivePlateAppearance
            )
            .presentationDetents([.large])
            .interactiveDismissDisabled()
        }
        .sensoryFeedback(.impact(weight: .light), trigger: feedbackTick)
    }

    private var atBatCell: some View {
        ScorebookPageSection {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    accessibilityAtBatSummary
                        .padding(.vertical, AppTheme.Spacing.md)
                } else {
                    standardAtBatSummary
                        .frame(height: 190, alignment: .top)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(AppTheme.rule)
                    .frame(height: 1)
            }
        }
    }

    private var standardAtBatSummary: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 1) {
                    inningLabel
                    gameStatus
                }
                Spacer(minLength: AppTheme.Spacing.sm)
                compactScore(team: awayTeamName, score: state.awayScore)
                Text("–")
                    .font(.headline)
                    .foregroundStyle(AppTheme.graphite.opacity(0.54))
                compactScore(team: homeTeamName, score: state.homeScore)
            }

            PencilRule()

            HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    liveIdentity
                    compactCountAndOuts
                }
                Spacer(minLength: AppTheme.Spacing.xs)
                diamond
                    .frame(width: 88, height: 88)
            }
        }
        .padding(.vertical, AppTheme.Spacing.sm)
    }

    private var accessibilityAtBatSummary: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(state.half.displayName) \(state.inning)")
                Spacer()
                Text("Us \(trackedTeamScore) · Opp \(opponentScore)")
            }
            .font(.headline)
            .monospacedDigit()
            .foregroundStyle(AppTheme.graphite)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "\(state.half.displayName) of inning \(state.inning). \(awayTeamName) \(state.awayScore), \(homeTeamName) \(state.homeScore)"
            )

            gameStatus

            accessibilityLiveIdentity

            Text("\(state.balls) – \(state.strikes) count · \(state.outs) \(state.outs == 1 ? "out" : "outs") · \(baseStateSummary)")
                .font(.body)
                .monospacedDigit()
                .foregroundStyle(AppTheme.graphite.opacity(0.78))
                .accessibilityLabel("\(state.balls) – \(state.strikes)")
                .accessibilityHint(
                    "\(state.outs) \(state.outs == 1 ? "out" : "outs"), \(baseStateSummary)"
                )
                .accessibilityIdentifier("game.count")
        }
    }

    private var trackedTeamScore: Int {
        homeAway == .home ? state.homeScore : state.awayScore
    }

    private var opponentScore: Int {
        homeAway == .home ? state.awayScore : state.homeScore
    }

    private var awayTeamName: String {
        homeAway == .home ? game.opponentName : "Us"
    }

    private var homeTeamName: String {
        homeAway == .home ? "Us" : game.opponentName
    }

    private var inningLabel: some View {
        Text("\(state.half.displayName) \(state.inning)")
            .font(AppTheme.Typography.notation)
            .foregroundStyle(AppTheme.graphite.opacity(0.78))
            .accessibilityLabel("\(state.half.displayName) of inning \(state.inning)")
    }

    @ViewBuilder
    private var gameStatus: some View {
        if game.format == .timeLimit {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                gameStatusLabel(game.timeStatus(at: context.date) ?? game.formatDescription)
            }
        } else {
            gameStatusLabel(game.formatDescription)
        }
    }

    private func gameStatusLabel(_ status: String) -> some View {
        Text(status)
            .font(dynamicTypeSize.isAccessibilitySize ? .callout : .caption)
            .monospacedDigit()
            .foregroundStyle(AppTheme.graphite.opacity(0.68))
            .accessibilityIdentifier("game.status")
    }

    private func compactScore(team: String, score: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.xs) {
            Text(team)
                .font(AppTheme.Typography.notation)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text("\(score)")
                .font(.system(.title3, design: .monospaced, weight: .bold))
                .monospacedDigit()
        }
        .foregroundStyle(AppTheme.graphite)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var liveIdentity: some View {
        if state.isOpponentBatting(homeAway: homeAway) {
            VStack(alignment: .leading, spacing: 1) {
                Text(pitcher?.displayName ?? "Starting Pitcher")
                    .font(AppTheme.Typography.notation)
                Text("Pitcher · \(pitcherCount.total) pitches · Opponent batter \(state.currentOpponentBatterSlot)")
                    .font(AppTheme.Typography.metadata)
                    .foregroundStyle(AppTheme.graphite.opacity(0.68))
            }
        } else if let batter = currentTrackedBatter {
            VStack(alignment: .leading, spacing: 1) {
                Text(batter.displayName)
                    .font(AppTheme.Typography.notation)
                    .accessibilityIdentifier("offense.currentBatter")
                Text("At bat \(batter.lineupSlot) of \(trackedBattingOrder?.count ?? 0) · \(batterDetails(batter))")
                    .font(AppTheme.Typography.metadata)
                    .foregroundStyle(AppTheme.graphite.opacity(0.68))
            }
        } else {
            Text("Lineup unavailable")
                .font(AppTheme.Typography.notation)
        }
    }

    @ViewBuilder
    private var accessibilityLiveIdentity: some View {
        if state.isOpponentBatting(homeAway: homeAway) {
            Text(pitcher?.displayName ?? "Starting Pitcher")
                .font(.headline)
            Text("Pitching · \(pitcherCount.total) pitches · Opp batter \(state.currentOpponentBatterSlot)")
                .font(.callout)
                .foregroundStyle(AppTheme.graphite.opacity(0.68))
        } else if let batter = currentTrackedBatter {
            Text(batter.displayName)
                .font(.headline)
                .accessibilityIdentifier("offense.currentBatter")
                .accessibilityHint("At bat \(batter.lineupSlot) of \(trackedBattingOrder?.count ?? 0). \(batterDetails(batter))")
        } else {
            Text("Lineup unavailable")
                .font(.headline)
        }
    }

    private var compactCountAndOuts: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Text("\(state.balls) – \(state.strikes)")
                .font(.system(.title3, design: .monospaced, weight: .semibold))
                .monospacedDigit()
                .accessibilityLabel("Count \(state.balls) and \(state.strikes)")
                .accessibilityIdentifier("game.count")

            HStack(spacing: AppTheme.Spacing.xs) {
                ForEach(0..<3, id: \.self) { index in
                    ZStack {
                        Circle()
                            .stroke(AppTheme.graphite.opacity(0.68), lineWidth: 1)
                        Circle()
                            .stroke(AppTheme.graphite.opacity(0.18), lineWidth: 0.7)
                            .offset(x: 1, y: -0.7)
                        if index < state.outs {
                            Circle()
                                .fill(AppTheme.graphite.opacity(0.78))
                                .padding(2)
                        }
                    }
                    .frame(width: 15, height: 15)
                }
            }
            .accessibilityHidden(true)
            Text("\(state.outs) \(state.outs == 1 ? "out" : "outs")")
                .font(AppTheme.Typography.tabularNumber)
        }
        .foregroundStyle(AppTheme.graphite)
    }

    private var baseStateSummary: String {
        let occupied = [
            state.firstBaseRunnerSlot != nil || state.firstBaseRunnerPlayerID != nil ? "1B" : nil,
            state.secondBaseRunnerSlot != nil || state.secondBaseRunnerPlayerID != nil ? "2B" : nil,
            state.thirdBaseRunnerSlot != nil || state.thirdBaseRunnerPlayerID != nil ? "3B" : nil
        ].compactMap { $0 }
        return occupied.isEmpty ? "bases empty" : "on \(occupied.joined(separator: ", "))"
    }

    private var diamond: some View {
        ScorebookDiamondView(
            firstBaseRunner: displayedRunnerSlot(
                opponentSlot: state.firstBaseRunnerSlot,
                trackedPlayerID: state.firstBaseRunnerPlayerID
            ),
            secondBaseRunner: displayedRunnerSlot(
                opponentSlot: state.secondBaseRunnerSlot,
                trackedPlayerID: state.secondBaseRunnerPlayerID
            ),
            thirdBaseRunner: displayedRunnerSlot(
                opponentSlot: state.thirdBaseRunnerSlot,
                trackedPlayerID: state.thirdBaseRunnerPlayerID
            )
        )
    }

    private var defensiveScoringSurface: some View {
        Group {
            if state.isAwaitingBallInPlayResult {
                outcomePad
            } else {
                pitchPad
            }
        }
    }

    private var pitchPad: some View {
        ScorebookPageSection("Pitch") {
            ScorebookLedgerRow {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.sm) {
                    pitchButton(.ball)
                    pitchButton(.calledStrike)
                    pitchButton(.swingingStrike)
                    pitchButton(.foul)
                    pitchButton(.ballInPlay)
                    pitchButton(.hitByPitch)
                }
            }
        }
    }

    private var outcomePad: some View {
        ScorebookPageSection("Ball in play") {
            ScorebookLedgerRow {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    HStack {
                        Text("What happened?")
                            .font(AppTheme.Typography.playerName)
                        Spacer()
                        Image(systemName: "pencil.line")
                            .foregroundStyle(AppTheme.graphite.opacity(0.65))
                    }

                    outcomeSection("HIT", [.single, .double, .triple, .homeRun])
                    outcomeSection("REACHED", [.reachedOnError, .fieldersChoice])
                    outcomeSection(
                        "OUT",
                        [.groundOut, .flyOut, .lineOut, .popOut, .sacrificeBunt, .sacrificeFly, .doublePlay]
                    )

                    Text("The pitch is already counted. Finish this play before scoring the next pitch.")
                        .font(AppTheme.Typography.metadata)
                        .foregroundStyle(AppTheme.graphite.opacity(0.68))
                }
            }
        }
    }

    private func outcomeSection(_ title: String, _ outcomes: [BallInPlayOutcome]) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            ScorebookLabel(title)
            LazyVGrid(columns: outcomeColumns, spacing: AppTheme.Spacing.xs) {
                ForEach(outcomes) { outcome in
                    Button {
                        selectedOutcome = outcome
                    } label: {
                        Text(outcome.shortLabel)
                    }
                    .buttonStyle(ScorebookKeyButtonStyle(role: outcomeRole(outcome)))
                }
            }
        }
    }

    private func pitchButton(_ result: PitchResult) -> some View {
        Button {
            recordPitch(result)
        } label: {
            Text(result.shortLabel)
        }
        .buttonStyle(ScorebookKeyButtonStyle())
        .disabled(!replay.rejectedRecordIDs.isEmpty)
        .accessibilityLabel(result.label)
    }

    private var historyWarning: some View {
        warningSection(
            title: "Scoring locked",
            message: "Saved game data is unreadable. New scoring is disabled to avoid compounding the problem.",
            systemImage: "exclamationmark.triangle.fill"
        )
    }

    private func warningSection(title: String, message: String, systemImage: String) -> some View {
        ScorebookPageSection(title) {
            ScorebookLedgerRow {
                Label(message, systemImage: systemImage)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.destructive)
            }
        }
    }

    private var lineupWarning: some View {
        warningSection(
            title: "Scoring locked",
            message: "The saved lineup is incomplete or unreadable. Offensive scoring is paused to protect player attribution.",
            systemImage: "person.crop.circle.badge.exclamationmark"
        )
    }

    private var offensiveScoringSurface: some View {
        Group {
            if let batter = currentTrackedBatter {
                let line = battingLines[batter.playerID, default: BattingLine()]
                ScorebookPageSection("Pitch") {
                    ScorebookLedgerRow {
                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible())],
                            spacing: AppTheme.Spacing.sm
                        ) {
                            ForEach(OffensivePitchResult.allCases) { result in
                                offensivePitchButton(result)
                            }
                        }
                    }
                }

                let runnerSources = state.occupiedTrackedRunnerSources.filter { $0 != .batter }
                if !runnerSources.isEmpty {
                    ScorebookPageSection("Base running") {
                        ScorebookLedgerRow {
                            VStack(spacing: AppTheme.Spacing.sm) {
                                ForEach(runnerSources, id: \.self) { source in
                                    offensiveBaseRunningRow(source)
                                }
                            }
                        }
                    }
                }

                ScorebookPageSection("Plate appearance") {
                    ScorebookLedgerRow {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            LazyVGrid(
                                columns: [GridItem(.flexible()), GridItem(.flexible())],
                                spacing: AppTheme.Spacing.sm
                            ) {
                                offensiveButton("Walk", result: .walk, suggestion: .awardedFirstBase)
                                offensiveButton("HBP", result: .hitByPitch, suggestion: .awardedFirstBase)
                                offensiveButton("Strikeout", result: .strikeout, suggestion: .strikeout)
                                offensiveButton("Home Run", result: .homeRun, suggestion: .homeRun)
                            }

                            offensiveOutcomeSection("HIT", [.single, .double, .triple, .homeRun])
                            offensiveOutcomeSection("REACHED", [.reachedOnError, .fieldersChoice])
                            offensiveOutcomeSection(
                                "OUT",
                                [.groundOut, .flyOut, .lineOut, .popOut, .sacrificeBunt, .sacrificeFly, .doublePlay]
                            )
                        }
                    }
                }

                ScorebookPageSection("Batting line") {
                    ScorebookLedgerRow {
                        ScorebookStatGrid(stats: battingStats(line))
                    }
                }
                .accessibilityIdentifier("offense.battingLine")
            }
        }
    }

    private func battingStats(_ line: BattingLine) -> [ScorebookStat] {
        [
            .init(id: "pa", label: "PA", value: "\(line.plateAppearances)"),
            .init(id: "ab", label: "AB", value: "\(line.atBats)"),
            .init(id: "r", label: "R", value: "\(line.runs)"),
            .init(id: "h", label: "H", value: "\(line.hits)"),
            .init(id: "2b", label: "2B", value: "\(line.doubles)"),
            .init(id: "3b", label: "3B", value: "\(line.triples)"),
            .init(id: "hr", label: "HR", value: "\(line.homeRuns)"),
            .init(id: "rbi", label: "RBI", value: "\(line.runsBattedIn)"),
            .init(id: "bb", label: "BB", value: "\(line.walks)"),
            .init(id: "hbp", label: "HBP", value: "\(line.hitByPitch)"),
            .init(id: "so", label: "SO", value: "\(line.strikeouts)"),
            .init(id: "sb", label: "SB", value: "\(line.stolenBases)"),
            .init(id: "cs", label: "CS", value: "\(line.caughtStealing)")
        ]
    }

    private func offensiveButton(
        _ label: String,
        result: OffensivePlateAppearanceResult,
        suggestion: OffensiveQuickSuggestion
    ) -> some View {
        Button {
            recordOffensivePlateAppearance(result, suggestion: suggestion)
        } label: {
            Text(label)
        }
        .buttonStyle(ScorebookKeyButtonStyle(
            role: result == .strikeout ? .normal : .positive
        ))
        .disabled(currentTrackedBatter == nil || !replay.rejectedRecordIDs.isEmpty)
    }

    private func offensivePitchButton(_ result: OffensivePitchResult) -> some View {
        Button {
            recordOffensivePitch(result)
        } label: {
            Text(result.shortLabel)
        }
        .buttonStyle(ScorebookKeyButtonStyle())
        .disabled(currentTrackedBatter == nil || !replay.rejectedRecordIDs.isEmpty)
        .accessibilityIdentifier("offense.pitch.\(result.rawValue)")
    }

    private func offensiveBaseRunningRow(_ source: RunnerSource) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text(baseRunningRunnerName(source))
                .font(AppTheme.Typography.playerName)
                .lineLimit(1)
            HStack(spacing: AppTheme.Spacing.sm) {
                Button(baseRunningAdvanceLabel(source)) {
                    recordOffensiveBaseRunning(source: source, result: .stolenBase)
                }
                .buttonStyle(ScorebookKeyButtonStyle(role: .positive))
                .accessibilityIdentifier("offense.baseRunning.\(source.rawValue).stolenBase")

                Button("Caught Stealing") {
                    recordOffensiveBaseRunning(source: source, result: .caughtStealing)
                }
                .buttonStyle(ScorebookKeyButtonStyle(role: .destructive))
                .accessibilityIdentifier("offense.baseRunning.\(source.rawValue).caughtStealing")
            }
        }
        .frame(minHeight: AppTheme.TouchTarget.minimum)
    }

    private func baseRunningRunnerName(_ source: RunnerSource) -> String {
        guard let runnerID = trackedRunnerID(for: source) else { return source.label }
        return trackedBattingOrder?.first(where: { $0.playerID == runnerID })?.displayName ?? source.label
    }

    private func baseRunningAdvanceLabel(_ source: RunnerSource) -> String {
        switch source {
        case .batter: "Advance"
        case .first: "Steal 2B"
        case .second: "Steal 3B"
        case .third: "Steal Home"
        }
    }

    private func trackedRunnerID(for source: RunnerSource) -> UUID? {
        switch source {
        case .batter: nil
        case .first: state.firstBaseRunnerPlayerID
        case .second: state.secondBaseRunnerPlayerID
        case .third: state.thirdBaseRunnerPlayerID
        }
    }

    private func offensiveOutcomeSection(_ title: String, _ outcomes: [BallInPlayOutcome]) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            ScorebookLabel(title)
            LazyVGrid(
                columns: outcomeColumns,
                spacing: AppTheme.Spacing.xs
            ) {
                ForEach(outcomes) { outcome in
                    Button {
                        selectedOffensiveOutcome = outcome
                    } label: {
                        Text(outcome.shortLabel)
                    }
                    .buttonStyle(ScorebookKeyButtonStyle(role: outcomeRole(outcome)))
                }
            }
        }
    }

    private var outcomeColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [
                GridItem(.flexible(), spacing: AppTheme.Spacing.xs),
                GridItem(.flexible(), spacing: AppTheme.Spacing.xs)
            ]
        }
        return [GridItem(.adaptive(minimum: 78), spacing: AppTheme.Spacing.xs)]
    }

    private func outcomeRole(_ outcome: BallInPlayOutcome) -> ScorebookKeyRole {
        switch outcome {
        case .single, .double, .triple, .homeRun:
            .positive
        case .reachedOnError, .fieldersChoice, .groundOut, .flyOut, .lineOut,
             .popOut, .sacrificeBunt, .sacrificeFly, .doublePlay:
            .normal
        }
    }

    private func displayedRunnerSlot(opponentSlot: Int?, trackedPlayerID: UUID?) -> Int? {
        if state.isOpponentBatting(homeAway: homeAway) { return opponentSlot }
        guard let trackedPlayerID else { return nil }
        return trackedBattingOrder?.first(where: { $0.playerID == trackedPlayerID })?.lineupSlot
    }

    private func batterDetails(_ batter: TrackedBatterIdentity) -> String {
        let jersey = batter.jerseyNumber.isEmpty ? nil : "#\(batter.jerseyNumber)"
        let details = [jersey, batter.position?.rawValue].compactMap { $0 }.joined(separator: "  ·  ")
        return details.isEmpty ? "Batting only" : details
    }

    private func recordPitch(_ result: PitchResult) {
        do {
            try session.performRecording(game: game, modelContext: modelContext) {
                try GameEventRecorder.recordPitch(
                    result: result,
                    game: game,
                    existingRecords: gameRecords,
                    modelContext: modelContext
                )
            }
            feedbackTick += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func recordBallInPlay(_ play: BallInPlayEvent) {
        do {
            try session.performRecording(game: game, modelContext: modelContext) {
                try GameEventRecorder.recordBallInPlay(
                    play: play,
                    game: game,
                    existingRecords: gameRecords,
                    modelContext: modelContext
                )
            }
            selectedOutcome = nil
            feedbackTick += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func recordOffensivePlateAppearance(
        _ result: OffensivePlateAppearanceResult,
        suggestion: OffensiveQuickSuggestion
    ) {
        guard let expectedBatter = currentTrackedBatter else {
            errorMessage = GameEventRecorderError.noTrackedBattingOrder.localizedDescription
            return
        }
        let movementSuggestion: OffensiveMovementSuggestion
        switch suggestion {
        case .awardedFirstBase:
            movementSuggestion = OffensiveMovementSuggestions.awardedFirstBase(state: state)
        case .strikeout:
            movementSuggestion = OffensiveMovementSuggestions.strikeout(state: state)
        case .homeRun:
            movementSuggestion = OffensiveMovementSuggestions.homeRun(state: state)
        }

        do {
            try session.performRecording(game: game, modelContext: modelContext) {
                try GameEventRecorder.recordOffensivePlateAppearance(
                    expectedBatter: expectedBatter,
                    result: result,
                    movements: movementSuggestion.movements,
                    rbi: movementSuggestion.rbi,
                    countedRunSources: movementSuggestion.countedRunSources,
                    game: game,
                    existingRecords: gameRecords,
                    modelContext: modelContext
                )
            }
            feedbackTick += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func recordOffensivePitch(_ result: OffensivePitchResult) {
        guard let expectedBatter = currentTrackedBatter else {
            errorMessage = GameEventRecorderError.noTrackedBattingOrder.localizedDescription
            return
        }
        do {
            try session.performRecording(game: game, modelContext: modelContext) {
                try GameEventRecorder.recordOffensivePitch(
                    expectedBatter: expectedBatter,
                    result: result,
                    game: game,
                    existingRecords: gameRecords,
                    modelContext: modelContext
                )
            }
            feedbackTick += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func recordOffensiveBaseRunning(
        source: RunnerSource,
        result: OffensiveBaseRunningResult
    ) {
        guard let expectedRunnerID = trackedRunnerID(for: source) else {
            errorMessage = GameEventRecorderError.invalidOffensivePlateAppearance.localizedDescription
            return
        }
        do {
            try session.performRecording(game: game, modelContext: modelContext) {
                try GameEventRecorder.recordOffensiveBaseRunning(
                    expectedRunnerID: expectedRunnerID,
                    source: source,
                    result: result,
                    game: game,
                    existingRecords: gameRecords,
                    modelContext: modelContext
                )
            }
            feedbackTick += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func recordOffensivePlateAppearance(_ draft: OffensivePlateAppearanceDraft) {
        guard let expectedBatter = currentTrackedBatter else {
            errorMessage = GameEventRecorderError.noTrackedBattingOrder.localizedDescription
            return
        }
        do {
            try session.performRecording(game: game, modelContext: modelContext) {
                try GameEventRecorder.recordOffensivePlateAppearance(
                    expectedBatter: expectedBatter,
                    result: draft.result,
                    movements: draft.movements,
                    rbi: draft.rbi,
                    countedRunSources: draft.countedRunSources,
                    thirdOutClassification: draft.thirdOutClassification,
                    game: game,
                    existingRecords: gameRecords,
                    modelContext: modelContext
                )
            }
            selectedOffensiveOutcome = nil
            feedbackTick += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview("Offense · occupied bases") {
    let fixture = PreviewData.offensiveLiveGame
    NavigationStack {
        LiveGameView(game: fixture.game)
    }
    .modelContainer(fixture.container)
}

#Preview("Defense · runner and out") {
    let fixture = PreviewData.defensiveLiveGame
    NavigationStack {
        LiveGameView(game: fixture.game)
    }
    .modelContainer(fixture.container)
}

#Preview("Scoring locked") {
    let fixture = PreviewData.gatedLiveGame
    NavigationStack {
        LiveGameView(game: fixture.game)
    }
    .modelContainer(fixture.container)
}

#Preview("Offense · Accessibility XL") {
    let fixture = PreviewData.offensiveLiveGame
    NavigationStack {
        LiveGameView(game: fixture.game)
    }
    .environment(\.dynamicTypeSize, .accessibility3)
    .modelContainer(fixture.container)
}
