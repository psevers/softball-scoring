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
    @Query(sort: \GameEventRecord.sequenceNumber) private var allEventRecords: [GameEventRecord]
    @Query(sort: [SortDescriptor(\Player.lastName), SortDescriptor(\Player.firstName)]) private var players: [Player]
    @Query(sort: \LineupEntry.battingOrder) private var allLineupEntries: [LineupEntry]

    @State private var errorMessage: String?
    @State private var feedbackTick = 0
    @State private var selectedOutcome: BallInPlayOutcome?
    @State private var selectedOffensiveOutcome: BallInPlayOutcome?

    private var gameRecords: [GameEventRecord] {
        allEventRecords.filter { $0.gameID == game.id }
    }

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
        guard let validatedHomeAway else {
            return GameEventReplay.Result(state: GameState(), rejectedRecordIDs: [])
        }
        return GameEventReplay.replay(
            records: gameRecords,
            homeAway: validatedHomeAway,
            startingPitcherID: game.startingPitcherID
        )
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

    private var battingProjection: Result<[UUID: BattingLine], Error> {
        Result {
            BattingStatProjector.project(events: try gameRecords.map { try $0.decoded() })
        }
    }

    private var battingLines: [UUID: BattingLine] {
        switch battingProjection {
        case .success(let lines): lines
        case .failure: [:]
        }
    }

    private var hasBattingProjectionError: Bool {
        if case .failure = battingProjection { return true }
        return false
    }

    var body: some View {
        ZStack {
            ScorebookPaperBackground(gridSpacing: 22)

            ScrollView {
                VStack(spacing: AppTheme.Spacing.md) {
                    scoreHeader
                    inningCard

                    if validatedHomeAway == nil
                        || !replay.rejectedRecordIDs.isEmpty
                        || hasBattingProjectionError {
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
        }
        .navigationTitle(game.opponentName)
        .navigationBarTitleDisplayMode(.inline)
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

    private var scoreHeader: some View {
        ScorebookSheet {
            VStack(spacing: AppTheme.Spacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(homeAway == .home ? game.opponentName.uppercased() : "US")
                            .font(.caption.weight(.semibold))
                        Text("\(state.awayScore)")
                            .font(.system(size: 32, weight: .semibold, design: .serif).monospacedDigit())
                    }
                    Spacer()
                    Text("\(state.half.displayName.uppercased()) \(state.inning)")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.graphite.opacity(0.8))
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(homeAway == .home ? "US" : game.opponentName.uppercased())
                            .font(.caption.weight(.semibold))
                        Text("\(state.homeScore)")
                            .font(.system(size: 32, weight: .semibold, design: .serif).monospacedDigit())
                    }
                }

                Rectangle().fill(AppTheme.rule).frame(height: 1)

                HStack {
                    Text(homeAway == .home ? "Opponent is away" : "Opponent is home")
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        if game.format == .timeLimit {
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                Text(game.timeStatus(at: context.date) ?? game.formatDescription)
                            }
                        } else {
                            Text(game.formatDescription)
                        }
                        Text(game.gameDate.formatted(date: .abbreviated, time: .omitted))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var inningCard: some View {
        ScorebookSheet {
            HStack(spacing: AppTheme.Spacing.lg) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("OUTS")
                        .font(.caption2.weight(.bold))
                        .tracking(1.2)
                    HStack(spacing: AppTheme.Spacing.sm) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(index < state.outs ? AppTheme.graphite : Color.clear)
                                .overlay(Circle().stroke(AppTheme.graphite.opacity(0.7), lineWidth: 1))
                                .frame(width: 15, height: 15)
                        }
                    }

                    Text("COUNT")
                        .font(.caption2.weight(.bold))
                        .tracking(1.2)
                        .padding(.top, AppTheme.Spacing.xs)
                    Text("\(state.balls) – \(state.strikes)")
                        .font(.title2.bold().monospacedDigit())
                        .accessibilityIdentifier("game.count")
                }

                Spacer()

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
                .frame(width: 128, height: 128)
            }
        }
    }

    private var defensiveScoringSurface: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ScorebookSheet {
                VStack(spacing: AppTheme.Spacing.sm) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("PITCHER")
                                .font(.caption2.weight(.bold))
                                .tracking(1.2)
                            Text(pitcher?.displayName ?? "Starting Pitcher")
                                .font(.headline)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("PITCHES")
                                .font(.caption2.weight(.bold))
                                .tracking(1.2)
                            Text("\(pitcherCount.total)")
                                .font(.title2.bold().monospacedDigit())
                        }
                    }

                    Rectangle().fill(AppTheme.rule).frame(height: 1)

                    HStack {
                        Text("Opponent Batter \(state.currentOpponentBatterSlot)")
                            .font(.headline)
                        Spacer()
                        Text("B \(pitcherCount.balls)  ·  S \(pitcherCount.strikes)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if state.isAwaitingBallInPlayResult {
                outcomePad
            } else {
                pitchPad
            }
        }
    }

    private var pitchPad: some View {
        ScorebookSheet {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("PITCH")
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)

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
        ScorebookSheet {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("BALL IN PLAY")
                            .font(.caption2.weight(.bold))
                            .tracking(1.2)
                        Text("What happened?")
                            .font(.headline)
                    }
                    Spacer()
                    Image(systemName: "pencil.line")
                        .foregroundStyle(AppTheme.graphite.opacity(0.65))
                }

                outcomeSection("HIT", [.single, .double, .triple, .homeRun])
                outcomeSection("REACHED", [.reachedOnError, .fieldersChoice])
                outcomeSection("OUT", [.groundOut, .flyOut, .lineOut, .popOut, .sacrificeBunt, .sacrificeFly, .doublePlay])

                Text("The pitch is already counted. Finish this play before scoring the next pitch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func outcomeSection(_ title: String, _ outcomes: [BallInPlayOutcome]) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: AppTheme.Spacing.xs)], spacing: AppTheme.Spacing.xs) {
                ForEach(outcomes) { outcome in
                    Button {
                        selectedOutcome = outcome
                    } label: {
                        Text(outcome.shortLabel)
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: AppTheme.TouchTarget.gameAction)
                            .foregroundStyle(AppTheme.graphite)
                            .background(AppTheme.paper)
                            .overlay {
                                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm)
                                    .stroke(AppTheme.graphite.opacity(0.5), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func pitchButton(_ result: PitchResult) -> some View {
        Button {
            recordPitch(result)
        } label: {
            Text(result.shortLabel)
                .font(.headline)
                .foregroundStyle(AppTheme.graphite)
                .frame(maxWidth: .infinity, minHeight: AppTheme.TouchTarget.gameAction)
                .background(AppTheme.paper)
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm)
                        .stroke(AppTheme.graphite.opacity(0.55), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(!replay.rejectedRecordIDs.isEmpty)
        .accessibilityLabel(result.label)
    }

    private var historyWarning: some View {
        ScorebookSheet {
            Label(
                "Saved game data is unreadable. New scoring is disabled to avoid compounding the problem.",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.subheadline)
        }
    }

    private var lineupWarning: some View {
        ScorebookSheet {
            Label(
                "The saved lineup is incomplete or unreadable. Offensive scoring is paused to protect player attribution.",
                systemImage: "person.crop.circle.badge.exclamationmark"
            )
            .font(.subheadline)
        }
    }

    private var offensiveScoringSurface: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            if let batter = currentTrackedBatter {
                let line = battingLines[batter.playerID, default: BattingLine()]
                ScorebookSheet {
                    VStack(spacing: AppTheme.Spacing.sm) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("AT BAT · \(batter.lineupSlot) OF \(trackedBattingOrder?.count ?? 0)")
                                    .font(.caption2.weight(.bold))
                                    .tracking(1.2)
                                Text(batter.displayName)
                                    .font(.title3.weight(.semibold))
                                    .accessibilityIdentifier("offense.currentBatter")
                                Text(batterDetails(batter))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "pencil.and.outline")
                                .font(.title2)
                                .foregroundStyle(AppTheme.graphite.opacity(0.7))
                        }

                        Rectangle().fill(AppTheme.rule).frame(height: 1)

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible()), count: 5),
                            spacing: AppTheme.Spacing.sm
                        ) {
                            battingStat("PA", line.plateAppearances)
                            battingStat("AB", line.atBats)
                            battingStat("R", line.runs)
                            battingStat("H", line.hits)
                            battingStat("2B", line.doubles)
                            battingStat("3B", line.triples)
                            battingStat("HR", line.homeRuns)
                            battingStat("RBI", line.runsBattedIn)
                            battingStat("BB", line.walks)
                            battingStat("HBP", line.hitByPitch)
                            battingStat("SO", line.strikeouts)
                            battingStat("SB", line.stolenBases)
                            battingStat("CS", line.caughtStealing)
                        }
                    }
                }

                ScorebookSheet {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        Text("PITCH")
                            .font(.caption2.weight(.bold))
                            .tracking(1.2)

                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible())],
                            spacing: AppTheme.Spacing.sm
                        ) {
                            ForEach(OffensivePitchResult.allCases) { result in
                                offensivePitchButton(result)
                            }
                        }

                        let runnerSources = state.occupiedTrackedRunnerSources.filter { $0 != .batter }
                        if !runnerSources.isEmpty {
                            Rectangle().fill(AppTheme.rule).frame(height: 1)
                            Text("BASE RUNNING")
                                .font(.caption2.weight(.bold))
                                .tracking(1.2)
                            ForEach(runnerSources, id: \.self) { source in
                                offensiveBaseRunningRow(source)
                            }
                        }

                        Rectangle().fill(AppTheme.rule).frame(height: 1)

                        Text("PLATE APPEARANCE")
                            .font(.caption2.weight(.bold))
                            .tracking(1.2)

                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible())],
                            spacing: AppTheme.Spacing.sm
                        ) {
                            offensiveButton("Walk", result: .walk, suggestion: .awardedFirstBase)
                            offensiveButton("HBP", result: .hitByPitch, suggestion: .awardedFirstBase)
                            offensiveButton("Strikeout", result: .strikeout, suggestion: .strikeout)
                            offensiveButton("Home Run", result: .homeRun, suggestion: .homeRun)
                        }

                        Rectangle().fill(AppTheme.rule).frame(height: 1)
                        offensiveOutcomeSection("HIT", [.single, .double, .triple, .homeRun])
                        offensiveOutcomeSection("REACHED", [.reachedOnError, .fieldersChoice])
                        offensiveOutcomeSection(
                            "OUT",
                            [.groundOut, .flyOut, .lineOut, .popOut, .sacrificeBunt, .sacrificeFly, .doublePlay]
                        )
                    }
                }
            }
        }
    }

    private func battingStat(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.headline.monospacedDigit())
        }
        .frame(maxWidth: .infinity)
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
                .font(.headline)
                .foregroundStyle(AppTheme.graphite)
                .frame(maxWidth: .infinity, minHeight: AppTheme.TouchTarget.gameAction)
                .background(AppTheme.paper)
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm)
                        .stroke(AppTheme.graphite.opacity(0.55), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(currentTrackedBatter == nil || !replay.rejectedRecordIDs.isEmpty)
    }

    private func offensivePitchButton(_ result: OffensivePitchResult) -> some View {
        Button {
            recordOffensivePitch(result)
        } label: {
            Text(result.shortLabel)
                .font(.headline)
                .foregroundStyle(AppTheme.graphite)
                .frame(maxWidth: .infinity, minHeight: AppTheme.TouchTarget.gameAction)
                .background(AppTheme.paper)
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm)
                        .stroke(AppTheme.graphite.opacity(0.55), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(currentTrackedBatter == nil || !replay.rejectedRecordIDs.isEmpty)
        .accessibilityIdentifier("offense.pitch.\(result.rawValue)")
    }

    private func offensiveBaseRunningRow(_ source: RunnerSource) -> some View {
        HStack {
            Text(baseRunningRunnerName(source))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Spacer()
            Button(baseRunningAdvanceLabel(source)) {
                recordOffensiveBaseRunning(source: source, result: .stolenBase)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("offense.baseRunning.\(source.rawValue).stolenBase")

            Button("CS") {
                recordOffensiveBaseRunning(source: source, result: .caughtStealing)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("offense.baseRunning.\(source.rawValue).caughtStealing")
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
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 78), spacing: AppTheme.Spacing.xs)],
                spacing: AppTheme.Spacing.xs
            ) {
                ForEach(outcomes) { outcome in
                    Button {
                        selectedOffensiveOutcome = outcome
                    } label: {
                        Text(outcome.shortLabel)
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: AppTheme.TouchTarget.gameAction)
                            .foregroundStyle(AppTheme.graphite)
                            .background(AppTheme.paper)
                            .overlay {
                                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm)
                                    .stroke(AppTheme.graphite.opacity(0.5), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
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
            try GameEventRecorder.recordPitch(
                result: result,
                game: game,
                existingRecords: gameRecords,
                modelContext: modelContext
            )
            feedbackTick += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func recordBallInPlay(_ play: BallInPlayEvent) {
        do {
            try GameEventRecorder.recordBallInPlay(
                play: play,
                game: game,
                existingRecords: gameRecords,
                modelContext: modelContext
            )
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
            try GameEventRecorder.recordOffensivePitch(
                expectedBatter: expectedBatter,
                result: result,
                game: game,
                existingRecords: gameRecords,
                modelContext: modelContext
            )
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
            try GameEventRecorder.recordOffensiveBaseRunning(
                expectedRunnerID: expectedRunnerID,
                source: source,
                result: result,
                game: game,
                existingRecords: gameRecords,
                modelContext: modelContext
            )
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
            selectedOffensiveOutcome = nil
            feedbackTick += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        Text("Create a game in preview data to exercise LiveGameView")
    }
    .modelContainer(PreviewData.container)
}
