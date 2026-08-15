import Observation
import SwiftData
import SwiftUI

struct DefensiveBallInPlayEditView: View {
    let game: Game
    let editSession: DefensiveBallInPlayEditSession
    let liveSession: LiveGameSession

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedOutcome: BallInPlayOutcome
    @State private var isConfirmingRunners = false
    @State private var proposedPlay: BallInPlayEvent?
    @State private var correction = GameEventCorrectionCoordinator()

    init(
        game: Game,
        editSession: DefensiveBallInPlayEditSession,
        liveSession: LiveGameSession
    ) {
        self.game = game
        self.editSession = editSession
        self.liveSession = liveSession
        _selectedOutcome = State(initialValue: editSession.originalPlay.outcome)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section("Completed play") {
                        Text(
                            "\(editSession.half.displayName) \(editSession.inning) · "
                                + "Opponent batter \(editSession.opponentBatterSlot) · "
                                + "Result sequence \(editSession.sequenceNumber)"
                        )
                        .font(.body.monospacedDigit())
                        Text("Ball In Play pitch · Sequence \(editSession.precedingPitchSequenceNumber) · Counted")
                            .font(.body.monospacedDigit())
                            .accessibilityIdentifier("playEdit.countedPitch")
                        Text("Current: \(playSummary(editSession.originalPlay))")
                            .accessibilityIdentifier("playEdit.current")
                    }

                    Section("Correct result") {
                        Picker("Result", selection: $selectedOutcome) {
                            ForEach(BallInPlayValidator.correctionOutcomes(for: editSession.stateBefore)) { outcome in
                                Text(outcome.label).tag(outcome)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(minHeight: AppTheme.TouchTarget.minimum)
                        .accessibilityIdentifier("playEdit.outcomePicker")
                        .accessibilityValue(selectedOutcome.label)

                        Button("Confirm Runner Destinations") {
                            isConfirmingRunners = true
                        }
                        .frame(minHeight: AppTheme.TouchTarget.minimum)
                        .accessibilityIdentifier("playEdit.confirmRunners")
                    }

                    if let proposedPlay, let correctionSession = correction.session {
                        GameEventCorrectionSections(
                            correctionSession: correctionSession,
                            homeAway: HomeAway(rawValue: game.homeAwayRawValue),
                            proposedSummary: "Proposed: \(playSummary(proposedPlay)) · "
                                + stateSummary(correctionSession.snapshot.replay.state),
                            proposedIdentifier: "playEdit.proposed",
                            stageChange: { problem, action in
                                correction.stageRepair(
                                    recordID: problem.id,
                                    action: action,
                                    game: game,
                                    modelContext: modelContext
                                )
                            }
                        )
                    }
                }

                Divider()
                HStack(spacing: AppTheme.Spacing.sm) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, minHeight: AppTheme.TouchTarget.minimum)
                        .accessibilityIdentifier("playEdit.cancel")

                    Button("Save") { save() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, minHeight: AppTheme.TouchTarget.minimum)
                        .disabled(correction.session?.canSave != true)
                        .accessibilityIdentifier("playEdit.save")
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(.bar)
            }
            .navigationTitle("Edit Play")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: selectedOutcome) { _, _ in
                proposedPlay = nil
                correction.session = nil
            }
            .sheet(isPresented: $isConfirmingRunners) {
                RunnerConfirmationSheet(
                    outcome: selectedOutcome,
                    state: editSession.stateBefore,
                    homeAway: editSession.homeAway,
                    initialPlay: initialPlay,
                    allowsScoring: true,
                    title: "Confirm Correction",
                    confirmationTitle: "Preview",
                    onCancel: { isConfirmingRunners = false },
                    onRecord: stage
                )
            }
            .alert("Play Edit Failed", isPresented: Binding(
                get: { correction.errorMessage != nil },
                set: { if !$0 { correction.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { correction.errorMessage = nil }
            } message: {
                Text(correction.errorMessage ?? "The proposed play could not be replayed safely.")
            }
        }
    }

    private var initialPlay: BallInPlayEvent {
        let sourcePlay = proposedPlay?.outcome == selectedOutcome
            ? proposedPlay ?? editSession.originalPlay
            : editSession.originalPlay
        return BallInPlayEvent(
            outcome: selectedOutcome,
            opponentBatterSlot: editSession.opponentBatterSlot,
            movements: sourcePlay.movements,
            rbi: sourcePlay.rbi,
            thirdOutRunsCounted: sourcePlay.thirdOutRunsCounted,
            thirdOutClassification: sourcePlay.thirdOutClassification
        )
    }

    private func stage(_ play: BallInPlayEvent) {
        do {
            let preview = try GameEventCorrection.stageDefensiveBallInPlayEdit(
                play,
                in: editSession,
                game: game,
                modelContext: modelContext
            )
            proposedPlay = play
            correction.session = preview.correctionSession
            isConfirmingRunners = false
        } catch {
            correction.errorMessage = error.localizedDescription
        }
    }

    private func save() {
        if correction.save(
            liveSession: liveSession,
            game: game,
            modelContext: modelContext
        ) {
            dismiss()
        }
    }

    private func playSummary(_ play: BallInPlayEvent) -> String {
        let movements = play.movements
            .map { "\($0.source.baseLabel) to \($0.destination.label)" }
            .joined(separator: "; ")
        let homeTouches = play.movements.filter { $0.destination == .home }.count
        let outsOnPlay = play.movements.filter { $0.destination == .out }.count
        let runs = editSession.stateBefore.outs + outsOnPlay == 3
            ? play.thirdOutRunsCounted ?? 0
            : homeTouches
        let scoring = homeTouches > 0
            ? " · \(runs) \(runs == 1 ? "run" : "runs") · \(play.rbi) RBI"
            : ""
        let thirdOut = switch play.thirdOutClassification {
        case .forceOrBatterRunner: " · Force / batter-runner third out"
        case .timingPlay: " · Timing play third out"
        case nil: ""
        }
        return "\(play.outcome.label) · \(movements)\(scoring)\(thirdOut)"
    }

    private func stateSummary(_ state: GameState) -> String {
        let homeAway = HomeAway(rawValue: game.homeAwayRawValue)
        let opponentScore = homeAway == .home ? state.awayScore : state.homeScore
        let trackedScore = homeAway == .home ? state.homeScore : state.awayScore
        let pitchTotal = game.startingPitcherID.map { state.pitchCount(for: $0).total } ?? 0
        let bases = [
            state.firstBaseRunnerSlot.map { "1B \($0)" },
            state.secondBaseRunnerSlot.map { "2B \($0)" },
            state.thirdBaseRunnerSlot.map { "3B \($0)" }
        ].compactMap { $0 }.joined(separator: ", ")
        return "\(state.half.displayName) \(state.inning) · "
            + "Score \(opponentScore)–\(trackedScore) · Pitcher \(pitchTotal) pitches · "
            + "Count \(state.balls)–\(state.strikes) · Outs \(state.outs) · "
            + "Bases \(bases.isEmpty ? "empty" : bases) · "
            + "Opponent batter \(state.currentOpponentBatterSlot) · "
            + "Tracked batter \(state.currentTrackedBatterSlot)"
    }
}

struct OffensivePlateAppearanceEditView: View {
    let game: Game
    let editSession: OffensivePlateAppearanceEditSession
    let liveSession: LiveGameSession

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedResult: OffensivePlateAppearanceResult
    @State private var isConfirmingRunners = false
    @State private var proposedPlateAppearance: OffensivePlateAppearanceEvent?
    @State private var correction = GameEventCorrectionCoordinator()

    init(
        game: Game,
        editSession: OffensivePlateAppearanceEditSession,
        liveSession: LiveGameSession
    ) {
        self.game = game
        self.editSession = editSession
        self.liveSession = liveSession
        _selectedResult = State(initialValue: editSession.originalPlateAppearance.result)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section("Completed plate appearance") {
                        Text(
                            "\(editSession.half.displayName) \(editSession.inning) · "
                                + "\(editSession.batter.displayName) · Batting slot "
                                + "\(editSession.batter.lineupSlot) of "
                                + "\(editSession.battingOrderSize) · Sequence "
                                + "\(editSession.sequenceNumber)"
                        )
                        .font(.body.monospacedDigit())
                        Text(
                            "Current: \(summary(editSession.originalPlateAppearance)) · "
                                + stateSummary(editSession.originalStateAfter) + " · "
                                + battingLineSummary(editSession.originalBattingLine) + " · "
                                + battingAttributionSummary(editSession.originalBattingLines)
                        )
                            .accessibilityIdentifier("trackedPlayEdit.current")
                    }

                    Section("Correct result") {
                        Picker("Result", selection: $selectedResult) {
                            ForEach(
                                OffensivePlateAppearanceValidator.correctionResults(
                                    for: editSession.stateBefore
                                ),
                                id: \.self
                            ) { result in
                                Text(result.label).tag(result)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(minHeight: AppTheme.TouchTarget.minimum)
                        .accessibilityIdentifier("trackedPlayEdit.resultPicker")
                        .accessibilityValue(selectedResult.label)

                        Button("Confirm Runner Destinations") {
                            isConfirmingRunners = true
                        }
                        .frame(minHeight: AppTheme.TouchTarget.minimum)
                        .accessibilityIdentifier("trackedPlayEdit.confirmRunners")
                    }

                    if let proposedPlateAppearance, let correctionSession = correction.session {
                        GameEventCorrectionSections(
                            correctionSession: correctionSession,
                            homeAway: editSession.homeAway,
                            proposedSummary: "Proposed: \(summary(proposedPlateAppearance)) · "
                                + stateSummary(correctionSession.snapshot.replay.state) + " · "
                                + battingLineSummary(correctionSession.snapshot.battingLines[
                                    editSession.batter.playerID,
                                    default: BattingLine()
                                ]) + " · "
                                + battingAttributionSummary(correctionSession.snapshot.battingLines),
                            proposedIdentifier: "trackedPlayEdit.proposed",
                            stageChange: { problem, action in
                                correction.stageRepair(
                                    recordID: problem.id,
                                    action: action,
                                    game: game,
                                    modelContext: modelContext
                                )
                            }
                        )
                    }
                }

                Divider()
                HStack(spacing: AppTheme.Spacing.sm) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, minHeight: AppTheme.TouchTarget.minimum)
                        .accessibilityIdentifier("trackedPlayEdit.cancel")

                    Button("Save") { save() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, minHeight: AppTheme.TouchTarget.minimum)
                        .disabled(correction.session?.canSave != true)
                        .accessibilityIdentifier("trackedPlayEdit.save")
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(.bar)
            }
            .navigationTitle("Edit Tracked Play")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: selectedResult) { _, _ in
                proposedPlateAppearance = nil
                correction.session = nil
            }
            .sheet(isPresented: $isConfirmingRunners) {
                OffensiveRunnerConfirmationSheet(
                    result: selectedResult,
                    state: editSession.stateBefore,
                    homeAway: editSession.homeAway,
                    battingOrder: editSession.runnerIdentities.values.sorted {
                        $0.lineupSlot < $1.lineupSlot
                    },
                    batter: editSession.batter,
                    battingOrderSize: editSession.battingOrderSize,
                    initialDraft: initialDraft,
                    allowsScoring: true,
                    title: "Confirm Correction",
                    confirmationTitle: "Preview",
                    onCancel: { isConfirmingRunners = false },
                    onRecord: stage
                )
            }
            .alert("Play Edit Failed", isPresented: Binding(
                get: { correction.errorMessage != nil },
                set: { if !$0 { correction.errorMessage = nil } }
            )) {
                if correction.requiresReopen {
                    Button("Return to Play History") {
                        correction.errorMessage = nil
                        dismiss()
                    }
                    .accessibilityIdentifier("trackedPlayEdit.reopen")
                } else {
                    Button("OK", role: .cancel) { correction.errorMessage = nil }
                }
            } message: {
                Text(
                    correction.errorMessage
                        ?? "The proposed plate appearance could not be replayed safely."
                )
            }
        }
    }

    private var initialDraft: OffensivePlateAppearanceDraft {
        let source = proposedPlateAppearance ?? editSession.originalPlateAppearance
        return OffensivePlateAppearanceDraft(
            result: selectedResult,
            movements: source.movements,
            rbi: source.rbi,
            countedRunSources: source.countedRunSources,
            thirdOutClassification: source.thirdOutClassification
        )
    }

    private func stage(_ draft: OffensivePlateAppearanceDraft) {
        let plateAppearance = OffensivePlateAppearanceEvent(
            batter: editSession.batter,
            battingOrderSize: editSession.battingOrderSize,
            result: draft.result,
            movements: draft.movements,
            rbi: draft.rbi,
            countedRunSources: draft.countedRunSources,
            thirdOutClassification: draft.thirdOutClassification
        )
        do {
            correction.session = try GameEventCorrection.stageOffensivePlateAppearanceEdit(
                plateAppearance,
                in: editSession,
                game: game,
                modelContext: modelContext
            )
            proposedPlateAppearance = plateAppearance
            isConfirmingRunners = false
        } catch {
            correction.session = nil
            correction.present(error)
        }
    }

    private func save() {
        if correction.save(
            liveSession: liveSession,
            game: game,
            modelContext: modelContext
        ) {
            dismiss()
        }
    }

    private func summary(_ plateAppearance: OffensivePlateAppearanceEvent) -> String {
        let movements = plateAppearance.movements
            .map { "\($0.source.baseLabel) to \($0.destination.label)" }
            .joined(separator: "; ")
        let runs = plateAppearance.countedRunSources.count
        let scoring = runs > 0
            ? " · \(runs) \(runs == 1 ? "run" : "runs") · \(plateAppearance.rbi) RBI"
            : ""
        let thirdOut = switch plateAppearance.thirdOutClassification {
        case .forceOrBatterRunner: " · Force / batter-runner third out"
        case .timingPlay: " · Timing play third out"
        case nil: ""
        }
        return "\(plateAppearance.result.label) · \(movements)\(scoring)\(thirdOut)"
    }

    private func stateSummary(_ state: GameState) -> String {
        let trackedScore = editSession.homeAway == .home ? state.homeScore : state.awayScore
        let opponentScore = editSession.homeAway == .home ? state.awayScore : state.homeScore
        let bases = [
            state.firstBaseRunnerPlayerID.map { _ in "1B occupied" },
            state.secondBaseRunnerPlayerID.map { _ in "2B occupied" },
            state.thirdBaseRunnerPlayerID.map { _ in "3B occupied" }
        ].compactMap { $0 }.joined(separator: ", ")
        return "\(state.half.displayName) \(state.inning) · "
            + "Score \(opponentScore)–\(trackedScore) · Outs \(state.outs) · "
            + "Bases \(bases.isEmpty ? "empty" : bases) · "
            + "Tracked batter \(state.currentTrackedBatterSlot)"
    }

    private func battingLineSummary(_ line: BattingLine) -> String {
        "Batting PA \(line.plateAppearances) · AB \(line.atBats) · H \(line.hits)"
    }

    private func battingAttributionSummary(_ lines: [UUID: BattingLine]) -> String {
        let participants = Dictionary(
            editSession.runnerIdentities.values.map { ($0.playerID, $0) },
            uniquingKeysWith: { first, _ in first }
        ).values.sorted { $0.lineupSlot < $1.lineupSlot }
        let summaries = participants.map { identity in
            let line = lines[identity.playerID, default: BattingLine()]
            return "\(identity.displayName) R \(line.runs) RBI \(line.runsBattedIn)"
        }
        return "Attribution \(summaries.joined(separator: "; "))"
    }
}

struct OffensiveBaseRunningEditView: View {
    let game: Game
    let editSession: OffensiveBaseRunningEditSession
    let liveSession: LiveGameSession

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedRunnerID: UUID
    @State private var selectedResult: OffensiveBaseRunningResult
    @State private var proposedEvent: OffensiveBaseRunningEvent?
    @State private var correction = GameEventCorrectionCoordinator()

    init(
        game: Game,
        editSession: OffensiveBaseRunningEditSession,
        liveSession: LiveGameSession
    ) {
        self.game = game
        self.editSession = editSession
        self.liveSession = liveSession
        _selectedRunnerID = State(initialValue: editSession.runner.playerID)
        _selectedResult = State(initialValue: editSession.originalEvent.result)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section("Base-running attempt") {
                        Text(
                            "\(editSession.half.displayName) \(editSession.inning) · Sequence "
                                + "\(editSession.sequenceNumber)"
                        )
                        .font(.body.monospacedDigit())
                        Text(
                            "Active batter slot \(editSession.stateBefore.currentTrackedBatterSlot) · "
                                + "Count \(editSession.stateBefore.balls)–"
                                + "\(editSession.stateBefore.strikes) · Outs "
                                + "\(editSession.stateBefore.outs)"
                        )
                        .font(.body.monospacedDigit())
                        Text(
                            "Current: \(editSession.runner.displayName) · "
                                + eventSummary(editSession.originalEvent) + " · "
                                + stateSummary(editSession.originalStateAfter) + " · "
                                + battingLineSummary(
                                    editSession.originalBattingLines[
                                        editSession.runner.playerID,
                                        default: BattingLine()
                                    ]
                                )
                        )
                        .accessibilityIdentifier("trackedBaseRunningEdit.current")
                    }

                    Section("Correct attempt") {
                        Picker("Runner", selection: $selectedRunnerID) {
                            ForEach(editSession.eligibleRunners) { runner in
                                Text(
                                    "\(runner.identity.displayName) · "
                                        + "slot \(runner.identity.lineupSlot) of "
                                        + "\(runner.battingOrderSize) · "
                                        + runner.source.baseLabel
                                )
                                .tag(runner.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(minHeight: AppTheme.TouchTarget.minimum)
                        .accessibilityIdentifier("trackedBaseRunningEdit.runnerPicker")

                        Picker("Result", selection: $selectedResult) {
                            ForEach(OffensiveBaseRunningResult.allCases) { result in
                                Text(result.shortLabel).tag(result)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(minHeight: AppTheme.TouchTarget.minimum)
                        .accessibilityIdentifier("trackedBaseRunningEdit.resultPicker")

                        Button("Preview Correction") { stage() }
                            .frame(minHeight: AppTheme.TouchTarget.minimum)
                            .accessibilityIdentifier("trackedBaseRunningEdit.preview")
                    }

                    if let proposedEvent, let correctionSession = correction.session {
                        let runner = selectedRunner
                        GameEventCorrectionSections(
                            correctionSession: correctionSession,
                            homeAway: HomeAway(rawValue: game.homeAwayRawValue),
                            proposedSummary: "Proposed: \(runner?.identity.displayName ?? "Runner") · "
                                + eventSummary(proposedEvent) + " · "
                                + stateSummary(proposedState(in: correctionSession)) + " · "
                                + battingLineSummary(
                                    correctionSession.snapshot.battingLines[
                                        proposedEvent.runnerID,
                                        default: BattingLine()
                                    ]
                                ),
                            proposedIdentifier: "trackedBaseRunningEdit.proposed",
                            stageChange: { problem, action in
                                correction.stageRepair(
                                    recordID: problem.id,
                                    action: action,
                                    game: game,
                                    modelContext: modelContext
                                )
                            }
                        )
                    }
                }
                .onChange(of: selectedRunnerID) { _, _ in clearPreview() }
                .onChange(of: selectedResult) { _, _ in clearPreview() }

                Divider()
                HStack(spacing: AppTheme.Spacing.sm) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, minHeight: AppTheme.TouchTarget.minimum)
                        .accessibilityIdentifier("trackedBaseRunningEdit.cancel")

                    Button("Save") { save() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, minHeight: AppTheme.TouchTarget.minimum)
                        .disabled(correction.session?.canSave != true)
                        .accessibilityIdentifier("trackedBaseRunningEdit.save")
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(.bar)
            }
            .navigationTitle("Edit Base Running")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Base-Running Edit Failed", isPresented: Binding(
                get: { correction.errorMessage != nil },
                set: { if !$0 { correction.errorMessage = nil } }
            )) {
                if correction.requiresReopen {
                    Button("Return to Play History") {
                        correction.errorMessage = nil
                        dismiss()
                    }
                    .accessibilityIdentifier("trackedBaseRunningEdit.reopen")
                } else {
                    Button("OK", role: .cancel) { correction.errorMessage = nil }
                }
            } message: {
                Text(
                    correction.errorMessage
                        ?? "The proposed base-running attempt could not be replayed safely."
                )
            }
        }
    }

    private var selectedRunner: OffensiveBaseRunningRunner? {
        editSession.eligibleRunners.first(where: { $0.id == selectedRunnerID })
    }

    private func stage() {
        guard let selectedRunner,
              let destination = baseRunningDestination(
                  source: selectedRunner.source,
                  result: selectedResult
              ) else {
            correction.errorMessage = "The selected runner cannot make that base-running attempt."
            return
        }
        let event = OffensiveBaseRunningEvent(
            runnerID: selectedRunner.id,
            source: selectedRunner.source,
            destination: destination,
            result: selectedResult
        )
        do {
            correction.session = try GameEventCorrection.stageOffensiveBaseRunningEdit(
                event,
                in: editSession,
                game: game,
                modelContext: modelContext
            )
            proposedEvent = event
        } catch {
            correction.session = nil
            correction.present(error)
        }
    }

    private func clearPreview() {
        proposedEvent = nil
        correction.session = nil
    }

    private func save() {
        if correction.save(
            liveSession: liveSession,
            game: game,
            modelContext: modelContext
        ) {
            dismiss()
        }
    }

    private func proposedState(in correctionSession: GameEventCorrectionSession) -> GameState {
        correctionSession.snapshot.replay.entries.first(where: {
            $0.recordID == editSession.recordID
        })?.stateAfter ?? correctionSession.snapshot.replay.state
    }

    private func eventSummary(_ event: OffensiveBaseRunningEvent) -> String {
        "\(event.result.shortLabel) · \(event.source.baseLabel) to \(event.destination.label)"
    }

    private func stateSummary(_ state: GameState) -> String {
        let bases = [
            state.firstBaseRunnerPlayerID.map { _ in "1B occupied" },
            state.secondBaseRunnerPlayerID.map { _ in "2B occupied" },
            state.thirdBaseRunnerPlayerID.map { _ in "3B occupied" }
        ].compactMap { $0 }.joined(separator: ", ")
        let homeAway = HomeAway(rawValue: game.homeAwayRawValue)
        let trackedScore = homeAway == .home ? state.homeScore : state.awayScore
        return "Score \(trackedScore) · Outs \(state.outs) · "
            + "Bases \(bases.isEmpty ? "empty" : bases) · "
            + "Batter \(state.currentTrackedBatterSlot) · "
            + "Count \(state.balls)–\(state.strikes)"
    }

    private func battingLineSummary(_ line: BattingLine) -> String {
        "R \(line.runs) · RBI \(line.runsBattedIn) · "
            + "SB \(line.stolenBases) · CS \(line.caughtStealing)"
    }
}

private func baseRunningDestination(
    source: RunnerSource,
    result: OffensiveBaseRunningResult
) -> RunnerDestination? {
    if result == .caughtStealing { return .out }
    return switch source {
    case .first: .second
    case .second: .third
    case .third: .home
    case .batter: nil
    }
}

struct DefensivePitchEditView: View {
    private static let supportedResults: [PitchResult] = [
        .ball, .calledStrike, .swingingStrike, .foul
    ]

    let game: Game
    let editSession: DefensivePitchEditSession
    let liveSession: LiveGameSession

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedResult: PitchResult
    @State private var correction = GameEventCorrectionCoordinator()

    init(
        game: Game,
        editSession: DefensivePitchEditSession,
        liveSession: LiveGameSession
    ) {
        self.game = game
        self.editSession = editSession
        self.liveSession = liveSession
        _selectedResult = State(initialValue: editSession.originalResult)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section("Pitch") {
                        Text(
                            "\(editSession.half.displayName) \(editSession.inning) · "
                                + "Opponent batter \(editSession.opponentBatterSlot) · "
                                + "Sequence \(editSession.sequenceNumber)"
                        )
                        .font(.body.monospacedDigit())
                        Text(
                            "Current: \(editSession.originalResult.label) · "
                                + countDescription(editSession.originalStateAfter)
                        )
                        .accessibilityIdentifier("pitchEdit.current")
                    }

                    Section("Correct result") {
                        ForEach(Self.supportedResults) { result in
                            Button {
                                select(result)
                            } label: {
                                HStack {
                                    Text(result.label)
                                    Spacer()
                                    if result == selectedResult {
                                        Image(systemName: "checkmark")
                                    }
                                }
                                .frame(minHeight: AppTheme.TouchTarget.minimum)
                            }
                            .accessibilityIdentifier("pitchEdit.result.\(result.rawValue)")
                        }
                    }

                    if let correctionSession = correction.session {
                        GameEventCorrectionSections(
                            correctionSession: correctionSession,
                            homeAway: HomeAway(rawValue: game.homeAwayRawValue),
                            proposedSummary: "Proposed: \(selectedResult.label) · "
                                + countDescription(proposedState(in: correctionSession)),
                            proposedIdentifier: "pitchEdit.proposed",
                            stageChange: { problem, action in
                                correction.stageRepair(
                                    recordID: problem.id,
                                    action: action,
                                    game: game,
                                    modelContext: modelContext
                                )
                            }
                        )
                    }
                }

                Divider()
                HStack(spacing: AppTheme.Spacing.sm) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: AppTheme.TouchTarget.minimum
                        )
                        .accessibilityIdentifier("pitchEdit.cancel")

                    Button("Save") { save() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: AppTheme.TouchTarget.minimum
                        )
                        .disabled(correction.session?.canSave != true)
                        .accessibilityIdentifier("pitchEdit.save")
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(.bar)
            }
            .navigationTitle("Edit Pitch")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Pitch Edit Failed", isPresented: Binding(
                get: { correction.errorMessage != nil },
                set: { if !$0 { correction.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { correction.errorMessage = nil }
            } message: {
                Text(
                    correction.errorMessage
                        ?? "The proposed pitch could not be replayed safely."
                )
            }
        }
    }

    private func select(_ result: PitchResult) {
        selectedResult = result
        guard result != editSession.originalResult else {
            correction.session = nil
            return
        }
        do {
            let session = try GameEventCorrection.beginGameEventCorrection(
                game: game,
                modelContext: modelContext
            )
            correction.session = try GameEventCorrection.stagePitchEdit(
                recordID: editSession.recordID,
                result: result,
                in: session,
                game: game,
                modelContext: modelContext
            )
        } catch {
            correction.session = nil
            correction.errorMessage = error.localizedDescription
        }
    }

    private func save() {
        if correction.save(
            liveSession: liveSession,
            game: game,
            modelContext: modelContext
        ) {
            dismiss()
        }
    }

    private func proposedState(in correctionSession: GameEventCorrectionSession) -> GameState {
        correctionSession.snapshot.replay.entries.first(where: {
            $0.recordID == editSession.recordID
        })?.stateAfter ?? correctionSession.snapshot.replay.state
    }

    private func countDescription(_ state: GameState) -> String {
        "Count \(state.balls)–\(state.strikes)"
    }
}

struct OffensivePitchEditView: View {
    let game: Game
    let editSession: OffensivePitchEditSession
    let liveSession: LiveGameSession

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedResult: OffensivePitchResult
    @State private var correction = GameEventCorrectionCoordinator()

    init(
        game: Game,
        editSession: OffensivePitchEditSession,
        liveSession: LiveGameSession
    ) {
        self.game = game
        self.editSession = editSession
        self.liveSession = liveSession
        _selectedResult = State(initialValue: editSession.originalResult)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section("Pitch") {
                        Text(
                            "\(editSession.half.displayName) \(editSession.inning) · "
                                + "\(editSession.batter.displayName) · Batting slot "
                                + "\(editSession.batter.lineupSlot) of "
                                + "\(editSession.battingOrderSize) · Sequence "
                                + "\(editSession.sequenceNumber)"
                        )
                        .font(.body.monospacedDigit())
                        Text(
                            "Current: \(editSession.originalResult.label) · "
                                + countDescription(editSession.originalStateAfter)
                        )
                        .accessibilityIdentifier("trackedPitchEdit.current")
                    }

                    Section("Correct result") {
                        ForEach(OffensivePitchResult.allCases) { result in
                            Button {
                                select(result)
                            } label: {
                                HStack {
                                    Text(result.label)
                                    Spacer()
                                    if result == selectedResult {
                                        Image(systemName: "checkmark")
                                    }
                                }
                                .frame(minHeight: AppTheme.TouchTarget.minimum)
                            }
                            .accessibilityIdentifier("trackedPitchEdit.result.\(result.rawValue)")
                        }
                    }

                    if let correctionSession = correction.session {
                        GameEventCorrectionSections(
                            correctionSession: correctionSession,
                            homeAway: HomeAway(rawValue: game.homeAwayRawValue),
                            proposedSummary: "Proposed: \(selectedResult.label) · "
                                + countDescription(proposedState(in: correctionSession)),
                            proposedIdentifier: "trackedPitchEdit.proposed",
                            stageChange: { problem, action in
                                correction.stageRepair(
                                    recordID: problem.id,
                                    action: action,
                                    game: game,
                                    modelContext: modelContext
                                )
                            }
                        )
                    }
                }

                Divider()
                HStack(spacing: AppTheme.Spacing.sm) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, minHeight: AppTheme.TouchTarget.minimum)
                        .accessibilityIdentifier("trackedPitchEdit.cancel")

                    Button("Save") { save() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, minHeight: AppTheme.TouchTarget.minimum)
                        .disabled(correction.session?.canSave != true)
                        .accessibilityIdentifier("trackedPitchEdit.save")
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(.bar)
            }
            .navigationTitle("Edit Tracked Pitch")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Pitch Edit Failed", isPresented: Binding(
                get: { correction.errorMessage != nil },
                set: { if !$0 { correction.errorMessage = nil } }
            )) {
                if correction.requiresReopen {
                    Button("Return to Play History") {
                        correction.errorMessage = nil
                        dismiss()
                    }
                    .accessibilityIdentifier("trackedPitchEdit.reopen")
                } else {
                    Button("OK", role: .cancel) { correction.errorMessage = nil }
                }
            } message: {
                Text(correction.errorMessage ?? "The proposed pitch could not be replayed safely.")
            }
        }
    }

    private func select(_ result: OffensivePitchResult) {
        selectedResult = result
        guard result != editSession.originalResult else {
            correction.session = nil
            return
        }
        do {
            correction.session = try GameEventCorrection.stageOffensivePitchEdit(
                result,
                in: editSession,
                game: game,
                modelContext: modelContext
            )
        } catch {
            correction.session = nil
            correction.present(error)
        }
    }

    private func save() {
        if correction.save(
            liveSession: liveSession,
            game: game,
            modelContext: modelContext
        ) {
            dismiss()
        }
    }

    private func proposedState(in correctionSession: GameEventCorrectionSession) -> GameState {
        correctionSession.snapshot.replay.entries.first(where: {
            $0.recordID == editSession.recordID
        })?.stateAfter ?? correctionSession.snapshot.replay.state
    }

    private func countDescription(_ state: GameState) -> String {
        "Count \(state.balls)–\(state.strikes)"
    }
}

struct OffensivePitchDeletionView: View {
    let game: Game
    let deletionSession: OffensivePitchDeletionSession
    let liveSession: LiveGameSession

    var body: some View {
        PitchDeletionView(
            game: game,
            liveSession: liveSession,
            navigationTitle: "Delete Tracked Pitch",
            eventContext: "\(deletionSession.half.displayName) \(deletionSession.inning) · "
                + "\(deletionSession.batter.displayName) · Batting slot "
                + "\(deletionSession.batter.lineupSlot) of "
                + "\(deletionSession.battingOrderSize) · Sequence "
                + "\(deletionSession.sequenceNumber)",
            deletionSummary: "Delete: \(deletionSession.originalResult.label) · "
                + countDescription(deletionSession.originalStateAfter),
            accessibilityPrefix: "trackedPitchDelete",
            fallbackError: "The tracked pitch deletion could not be replayed safely."
        ) { modelContext in
            try GameEventCorrection.stageOffensivePitchDeletion(
                deletionSession,
                game: game,
                modelContext: modelContext
            )
        }
    }

    private func countDescription(_ state: GameState) -> String {
        "Count \(state.balls)–\(state.strikes)"
    }
}

struct DefensivePitchDeletionView: View {
    let game: Game
    let deletionSession: DefensivePitchDeletionSession
    let liveSession: LiveGameSession

    var body: some View {
        PitchDeletionView(
            game: game,
            liveSession: liveSession,
            navigationTitle: "Delete Pitch",
            eventContext: "\(deletionSession.half.displayName) \(deletionSession.inning) · "
                + "Opponent batter \(deletionSession.opponentBatterSlot) · "
                + "Sequence \(deletionSession.sequenceNumber)",
            deletionSummary: "Delete: \(deletionSession.originalResult.label) · "
                + countDescription(deletionSession.originalStateAfter),
            accessibilityPrefix: "pitchDelete",
            fallbackError: "The pitch deletion could not be replayed safely."
        ) { modelContext in
            let session = try GameEventCorrection.beginGameEventCorrection(
                game: game,
                modelContext: modelContext
            )
            return try GameEventCorrection.stagePitchDeletion(
                recordID: deletionSession.recordID,
                in: session,
                game: game,
                modelContext: modelContext
            )
        }
    }

    private func countDescription(_ state: GameState) -> String {
        "Count \(state.balls)–\(state.strikes)"
    }
}

private struct PitchDeletionView: View {
    let game: Game
    let liveSession: LiveGameSession
    let navigationTitle: String
    let eventContext: String
    let deletionSummary: String
    let accessibilityPrefix: String
    let fallbackError: String
    let stageDeletion: (ModelContext) throws -> GameEventCorrectionSession

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var correction = GameEventCorrectionCoordinator()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section("Pitch") {
                        Text(eventContext)
                            .font(.body.monospacedDigit())
                        Text(deletionSummary)
                            .accessibilityIdentifier("\(accessibilityPrefix).current")
                    }

                    if let correctionSession = correction.session {
                        GameEventCorrectionSections(
                            correctionSession: correctionSession,
                            homeAway: HomeAway(rawValue: game.homeAwayRawValue),
                            stageChange: { problem, action in
                                correction.stageRepair(
                                    recordID: problem.id,
                                    action: action,
                                    game: game,
                                    modelContext: modelContext
                                )
                            }
                        )
                    } else if correction.errorMessage == nil {
                        Section("Candidate replay") {
                            ProgressView("Replaying complete history…")
                        }
                    }
                }

                Divider()
                HStack(spacing: AppTheme.Spacing.sm) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, minHeight: AppTheme.TouchTarget.minimum)
                        .accessibilityIdentifier("\(accessibilityPrefix).cancel")

                    Button("Save") { save() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, minHeight: AppTheme.TouchTarget.minimum)
                        .disabled(correction.session?.canSave != true)
                        .accessibilityIdentifier("\(accessibilityPrefix).save")
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(.bar)
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .task { stage() }
            .alert("Pitch Deletion Failed", isPresented: Binding(
                get: { correction.errorMessage != nil },
                set: { if !$0 { correction.errorMessage = nil } }
            )) {
                if correction.requiresReopen {
                    Button("Return to Play History") {
                        correction.errorMessage = nil
                        dismiss()
                    }
                    .accessibilityIdentifier("\(accessibilityPrefix).reopen")
                } else {
                    Button("OK", role: .cancel) { correction.errorMessage = nil }
                }
            } message: {
                Text(correction.errorMessage ?? fallbackError)
            }
        }
    }

    private func stage() {
        guard correction.session == nil else { return }
        do {
            correction.session = try stageDeletion(modelContext)
        } catch {
            correction.present(error)
        }
    }

    private func save() {
        if correction.save(
            liveSession: liveSession,
            game: game,
            modelContext: modelContext
        ) {
            dismiss()
        }
    }
}

struct DefensiveLogicalPlayDeletionView: View {
    let game: Game
    let deletionSession: DefensiveLogicalPlayDeletionSession
    let liveSession: LiveGameSession

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var correction = GameEventCorrectionCoordinator()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section("Completed play records") {
                        Text(
                            "\(deletionSession.half.displayName) \(deletionSession.inning) · "
                                + "Opponent batter \(deletionSession.opponentBatterSlot)"
                        )
                        .font(.body.monospacedDigit())
                        ForEach(deletionSession.components) { component in
                            Text("Sequence \(component.sequenceNumber) · \(component.summary)")
                                .font(.body.monospacedDigit())
                                .accessibilityIdentifier(
                                    "logicalPlayDelete.component.\(component.sequenceNumber)"
                                )
                        }
                    }

                    if let correctionSession = correction.session {
                        GameEventCorrectionSections(
                            correctionSession: correctionSession,
                            homeAway: HomeAway(rawValue: game.homeAwayRawValue),
                            stageChange: { problem, action in
                                correction.stageRepair(
                                    recordID: problem.id,
                                    action: action,
                                    game: game,
                                    modelContext: modelContext
                                )
                            }
                        )
                    } else if correction.errorMessage == nil {
                        Section("Candidate replay") {
                            ProgressView("Replaying complete history…")
                        }
                    }
                }

                Divider()
                HStack(spacing: AppTheme.Spacing.sm) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, minHeight: AppTheme.TouchTarget.minimum)
                        .accessibilityIdentifier("logicalPlayDelete.cancel")

                    Button("Save") { save() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, minHeight: AppTheme.TouchTarget.minimum)
                        .disabled(correction.session?.canSave != true)
                        .accessibilityIdentifier("logicalPlayDelete.save")
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(.bar)
            }
            .navigationTitle("Delete Completed Play")
            .navigationBarTitleDisplayMode(.inline)
            .task { stage() }
            .alert("Play Deletion Failed", isPresented: Binding(
                get: { correction.errorMessage != nil },
                set: { if !$0 { correction.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { correction.errorMessage = nil }
            } message: {
                Text(
                    correction.errorMessage
                        ?? "The completed play deletion could not be replayed safely."
                )
            }
        }
    }

    private func stage() {
        guard correction.session == nil else { return }
        do {
            let preview = try GameEventCorrection.stageDefensiveLogicalPlayDeletion(
                deletionSession,
                game: game,
                modelContext: modelContext
            )
            correction.session = preview.correctionSession
        } catch {
            correction.errorMessage = error.localizedDescription
        }
    }

    private func save() {
        if correction.save(
            liveSession: liveSession,
            game: game,
            modelContext: modelContext
        ) {
            dismiss()
        }
    }
}

private enum GameEventRepairAction {
    case edit(PitchResult)
    case editOffensivePitch(OffensivePitchResult)
    case deleteOffensivePitch
    case delete
    case editBallInPlay(BallInPlayEvent)
    case editOffensiveBaseRunning(OffensiveBaseRunningEvent)
    case editOffensivePlateAppearance(OffensivePlateAppearanceEvent)
}

@MainActor
@Observable
private final class GameEventCorrectionCoordinator {
    var session: GameEventCorrectionSession?
    var errorMessage: String?
    var requiresReopen = false

    func present(_ error: Error) {
        if let correctionError = error as? GameEventCorrectionError,
           case .staleTimeline = correctionError {
            requiresReopen = true
        } else {
            requiresReopen = false
        }
        errorMessage = error.localizedDescription
    }

    func stageRepair(
        recordID: UUID,
        action: GameEventRepairAction,
        game: Game,
        modelContext: ModelContext
    ) {
        guard let session else { return }
        do {
            switch action {
            case .edit(let result):
                self.session = try GameEventCorrection.stagePitchEdit(
                    recordID: recordID,
                    result: result,
                    in: session,
                    game: game,
                    modelContext: modelContext
                )
            case .editOffensivePitch(let result):
                self.session = try GameEventCorrection.stageOffensivePitchEdit(
                    recordID: recordID,
                    result: result,
                    in: session,
                    game: game,
                    modelContext: modelContext
                )
            case .deleteOffensivePitch:
                self.session = try GameEventCorrection.stageOffensivePitchDeletion(
                    recordID: recordID,
                    in: session,
                    game: game,
                    modelContext: modelContext
                )
            case .delete:
                self.session = try GameEventCorrection.stagePitchDeletion(
                    recordID: recordID,
                    in: session,
                    game: game,
                    modelContext: modelContext
                )
            case .editBallInPlay(let play):
                self.session = try GameEventCorrection.stageBallInPlayEdit(
                    recordID: recordID,
                    play: play,
                    in: session,
                    game: game,
                    modelContext: modelContext
                )
            case .editOffensiveBaseRunning(let event):
                self.session = try GameEventCorrection.stageOffensiveBaseRunningEdit(
                    recordID: recordID,
                    event: event,
                    in: session,
                    game: game,
                    modelContext: modelContext
                )
            case .editOffensivePlateAppearance(let plateAppearance):
                self.session = try GameEventCorrection.stageOffensivePlateAppearanceEdit(
                    recordID: recordID,
                    plateAppearance: plateAppearance,
                    in: session,
                    game: game,
                    modelContext: modelContext
                )
            }
        } catch {
            present(error)
        }
    }

    func save(
        liveSession: LiveGameSession,
        game: Game,
        modelContext: ModelContext
    ) -> Bool {
        guard let session, session.canSave else { return false }
        do {
            try liveSession.saveGameEventCorrection(
                session,
                game: game,
                modelContext: modelContext
            )
            return true
        } catch {
            present(error)
            return false
        }
    }
}

private extension GameEventCorrectionSession {
    func historyEntry(for recordID: UUID) -> PlayHistoryEntry? {
        snapshot.history.sections
            .flatMap(\.entries)
            .first(where: { entry in entry.components.contains { $0.recordID == recordID } })
    }
}

private struct GameEventCorrectionSections: View {
    let correctionSession: GameEventCorrectionSession
    let homeAway: HomeAway?
    let proposedSummary: String?
    let proposedIdentifier: String?
    let stageChange: (GameEventCorrectionProblem, GameEventRepairAction) -> Void

    init(
        correctionSession: GameEventCorrectionSession,
        homeAway: HomeAway?,
        proposedSummary: String? = nil,
        proposedIdentifier: String? = nil,
        stageChange: @escaping (
            GameEventCorrectionProblem,
            GameEventRepairAction
        ) -> Void
    ) {
        self.correctionSession = correctionSession
        self.homeAway = homeAway
        self.proposedSummary = proposedSummary
        self.proposedIdentifier = proposedIdentifier
        self.stageChange = stageChange
    }

    var body: some View {
        Section("Candidate replay") {
            if let proposedSummary {
                Text(proposedSummary)
                    .accessibilityIdentifier(proposedIdentifier ?? "correction.proposed")
            }

            if let invalid = correctionSession.firstInvalidRecord {
                NavigationLink {
                    let affectedEntry = correctionSession.snapshot.replay.entries.first(where: {
                        $0.recordID == invalid.id
                    })
                    let affectedPlay: BallInPlayEvent? = if case .ballInPlay(let play) = affectedEntry?.body {
                        play
                    } else {
                        nil
                    }
                    let affectedPlateAppearance: OffensivePlateAppearanceEvent? =
                        if case .offensivePlateAppearance(let plateAppearance) = affectedEntry?.body {
                            plateAppearance
                        } else {
                            nil
                        }
                    let affectedBaseRunning: OffensiveBaseRunningEvent? =
                        if case .offensiveBaseRunning(let event) = affectedEntry?.body {
                            event
                        } else {
                            nil
                        }
                    GameEventCorrectionProblemView(
                        problem: invalid,
                        historyEntry: correctionSession.historyEntry(for: invalid.id),
                        affectedPlay: affectedPlay,
                        affectedBaseRunning: affectedBaseRunning,
                        affectedPlateAppearance: affectedPlateAppearance,
                        affectedState: affectedEntry?.stateBefore,
                        homeAway: homeAway,
                        stageChange: { stageChange(invalid, $0) }
                    )
                } label: {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Label(
                            "Sequence \(invalid.sequenceNumber): \(invalid.context)",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        Text(invalid.explanation)
                            .font(.caption)
                    }
                    .foregroundStyle(AppTheme.destructive)
                }
                .accessibilityIdentifier("correction.problem.\(invalid.sequenceNumber)")
            } else {
                Label(
                    "Candidate timeline replays cleanly",
                    systemImage: "checkmark.circle"
                )
            }
        }

        Section("Staged changes") {
            ForEach(correctionSession.stagedLogicalPlayDeletions) { deletion in
                Text(deletion.summary)
                    .font(.body.monospacedDigit())
                    .accessibilityIdentifier(
                        "correction.logicalPlayChange.\(deletion.resultSequenceNumber)"
                    )
            }
            ForEach(correctionSession.stagedBallInPlayChanges) { change in
                Text(change.summary)
                    .font(.body.monospacedDigit())
                    .accessibilityIdentifier("correction.change.\(change.sequenceNumber)")
            }
            ForEach(correctionSession.stagedChanges) { change in
                Text(change.summary)
                    .font(.body.monospacedDigit())
                    .accessibilityIdentifier("correction.change.\(change.sequenceNumber)")
            }
            ForEach(correctionSession.stagedOffensivePitchChanges) { change in
                Text(change.summary)
                    .font(.body.monospacedDigit())
                    .accessibilityIdentifier("correction.change.\(change.sequenceNumber)")
            }
            ForEach(correctionSession.stagedOffensiveBaseRunningChanges) { change in
                Text(change.summary)
                    .font(.body.monospacedDigit())
                    .accessibilityIdentifier("correction.change.\(change.sequenceNumber)")
            }
            if !correctionSession.stagedOffensivePlateAppearanceChanges.isEmpty {
                ForEach(correctionSession.stagedOffensivePlateAppearanceChanges) { change in
                    Text(change.summary)
                        .font(.body.monospacedDigit())
                        .accessibilityIdentifier("correction.change.\(change.sequenceNumber)")
                }
            }
        }

        Section("Preview") {
            ForEach(correctionSession.snapshot.history.sections) { section in
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text(section.title)
                        .font(.caption.bold())
                    ForEach(section.entries) { entry in
                        Text("\(entry.actor): \(entry.summary)")
                            .font(.body)
                    }
                }
            }
        }
    }
}

private struct GameEventCorrectionProblemView: View {
    private static let editableResults: [PitchResult] = [
        .ball, .calledStrike, .swingingStrike, .foul
    ]
    private static let editableOffensiveResults = OffensivePitchResult.allCases

    let problem: GameEventCorrectionProblem
    let historyEntry: PlayHistoryEntry?
    let affectedPlay: BallInPlayEvent?
    let affectedBaseRunning: OffensiveBaseRunningEvent?
    let affectedPlateAppearance: OffensivePlateAppearanceEvent?
    let affectedState: GameState?
    let homeAway: HomeAway?
    let stageChange: (GameEventRepairAction) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedOutcome: BallInPlayOutcome
    @State private var selectedPlateAppearanceResult: OffensivePlateAppearanceResult
    @State private var selectedBaseRunningRunnerID: UUID
    @State private var selectedBaseRunningResult: OffensiveBaseRunningResult
    @State private var baseRunningRepairError: String?
    @State private var isConfirmingRunners = false
    @State private var isConfirmingPlateAppearanceRunners = false

    init(
        problem: GameEventCorrectionProblem,
        historyEntry: PlayHistoryEntry?,
        affectedPlay: BallInPlayEvent?,
        affectedBaseRunning: OffensiveBaseRunningEvent?,
        affectedPlateAppearance: OffensivePlateAppearanceEvent?,
        affectedState: GameState?,
        homeAway: HomeAway?,
        stageChange: @escaping (GameEventRepairAction) -> Void
    ) {
        self.problem = problem
        self.historyEntry = historyEntry
        self.affectedPlay = affectedPlay
        self.affectedBaseRunning = affectedBaseRunning
        self.affectedPlateAppearance = affectedPlateAppearance
        self.affectedState = affectedState
        self.homeAway = homeAway
        self.stageChange = stageChange
        _selectedOutcome = State(initialValue: affectedPlay?.outcome ?? .single)
        _selectedPlateAppearanceResult = State(
            initialValue: affectedPlateAppearance?.result ?? .single
        )
        _selectedBaseRunningRunnerID = State(
            initialValue: problem.offensiveBaseRunningRunners.first(where: {
                $0.id == affectedBaseRunning?.runnerID
            })?.id
                ?? problem.offensiveBaseRunningRunners.first?.id
                ?? affectedBaseRunning?.runnerID
                ?? UUID()
        )
        _selectedBaseRunningResult = State(
            initialValue: affectedBaseRunning?.result ?? .stolenBase
        )
    }

    var body: some View {
        Form {
            Section("Replay problem") {
                Text("Sequence \(problem.sequenceNumber)")
                    .font(.headline.monospacedDigit())
                Text(problem.context)
                    .font(.body.monospacedDigit())
                Text(problem.explanation)
                    .foregroundStyle(AppTheme.destructive)
            }

            if let historyEntry {
                Section("Affected history entry") {
                    Text(historyEntry.actor)
                        .font(AppTheme.Typography.playerName)
                    Text(historyEntry.summary)
                        .font(.body.bold())
                    Text(historyEntry.detail)
                        .font(.caption.monospacedDigit())
                }
            }

            Section("Stage another change") {
                if problem.canEditPitch {
                    Menu {
                        ForEach(Self.editableResults) { result in
                            Button(result.label) {
                                stageChange(.edit(result))
                                dismiss()
                            }
                            .accessibilityIdentifier("correction.repair.edit.\(result.rawValue)")
                        }
                    } label: {
                        Label("Edit Affected Pitch", systemImage: "pencil")
                            .frame(minHeight: AppTheme.TouchTarget.minimum)
                    }
                }

                if problem.canEditOffensivePitch {
                    Menu {
                        ForEach(Self.editableOffensiveResults) { result in
                            Button(result.label) {
                                stageChange(.editOffensivePitch(result))
                                dismiss()
                            }
                            .accessibilityIdentifier(
                                "correction.repair.editTracked.\(result.rawValue)"
                            )
                        }
                    } label: {
                        Label("Edit Affected Tracked Pitch", systemImage: "pencil")
                            .frame(minHeight: AppTheme.TouchTarget.minimum)
                    }
                }

                if problem.canDeletePitch {
                    Button(role: .destructive) {
                        stageChange(.delete)
                        dismiss()
                    } label: {
                        Label("Delete Affected Pitch", systemImage: "trash")
                            .frame(minHeight: AppTheme.TouchTarget.minimum)
                    }
                    .accessibilityIdentifier("correction.repair.delete")
                }

                if problem.canDeleteOffensivePitch {
                    Button(role: .destructive) {
                        stageChange(.deleteOffensivePitch)
                        dismiss()
                    } label: {
                        Label("Delete Affected Tracked Pitch", systemImage: "trash")
                            .frame(minHeight: AppTheme.TouchTarget.minimum)
                    }
                    .accessibilityIdentifier("correction.repair.deleteTracked")
                }

                if problem.canEditBallInPlay,
                   affectedPlay != nil,
                   affectedState != nil,
                   homeAway != nil {
                    Picker("Correct result", selection: $selectedOutcome) {
                        ForEach(correctionOutcomes) { outcome in
                            Text(outcome.label).tag(outcome)
                        }
                    }

                    Button("Confirm Runner Destinations") {
                        isConfirmingRunners = true
                    }
                    .frame(minHeight: AppTheme.TouchTarget.minimum)
                    .accessibilityIdentifier("correction.repair.play")
                }

                if problem.canEditOffensivePlateAppearance,
                   let affectedState,
                   affectedPlateAppearance != nil,
                   homeAway != nil {
                    Picker("Correct tracked result", selection: $selectedPlateAppearanceResult) {
                        ForEach(
                            OffensivePlateAppearanceValidator.correctionResults(for: affectedState),
                            id: \.self
                        ) { result in
                            Text(result.label).tag(result)
                        }
                    }

                    Button("Confirm Tracked Runner Destinations") {
                        isConfirmingPlateAppearanceRunners = true
                    }
                    .frame(minHeight: AppTheme.TouchTarget.minimum)
                    .accessibilityIdentifier("correction.repair.trackedPlay")
                }

                if problem.canEditOffensiveBaseRunning,
                   !problem.offensiveBaseRunningRunners.isEmpty {
                    Picker("Correct runner", selection: $selectedBaseRunningRunnerID) {
                        ForEach(problem.offensiveBaseRunningRunners) { runner in
                            Text(
                                "\(runner.identity.displayName) · "
                                    + "slot \(runner.identity.lineupSlot) · "
                                    + runner.source.baseLabel
                            )
                            .tag(runner.id)
                        }
                    }

                    Picker("Correct base-running result", selection: $selectedBaseRunningResult) {
                        ForEach(OffensiveBaseRunningResult.allCases) { result in
                            Text(result.shortLabel).tag(result)
                        }
                    }

                    Button("Stage Base-Running Repair") {
                        stageBaseRunningRepair()
                    }
                    .frame(minHeight: AppTheme.TouchTarget.minimum)
                    .accessibilityIdentifier("correction.repair.trackedBaseRunning")

                    if let baseRunningRepairError {
                        Text(baseRunningRepairError)
                            .foregroundStyle(AppTheme.destructive)
                            .accessibilityIdentifier("correction.repair.trackedBaseRunningError")
                    }
                }

                if !problem.canEditPitch
                            && !problem.canEditOffensivePitch
                            && !problem.canDeleteOffensivePitch
                            && !problem.canDeletePitch
                            && !problem.canEditBallInPlay
                            && !problem.canEditOffensiveBaseRunning
                            && !problem.canEditOffensivePlateAppearance {
                    Text("This event does not support another change in this correction session.")
                        .foregroundStyle(AppTheme.graphite.opacity(0.68))
                }
            }
        }
        .navigationTitle("Affected Event")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isConfirmingRunners) {
            if let affectedPlay, let affectedState, let homeAway {
                RunnerConfirmationSheet(
                    outcome: selectedOutcome,
                    state: affectedState,
                    homeAway: homeAway,
                    initialPlay: affectedPlay.outcome == selectedOutcome ? affectedPlay : nil,
                    allowsScoring: true,
                    title: "Repair Affected Play",
                    confirmationTitle: "Stage Repair",
                    onCancel: { isConfirmingRunners = false },
                    onRecord: { play in
                        stageChange(.editBallInPlay(play))
                        isConfirmingRunners = false
                        dismiss()
                    }
                )
            }
        }
        .sheet(isPresented: $isConfirmingPlateAppearanceRunners) {
            if let affectedPlateAppearance, let affectedState, let homeAway {
                OffensiveRunnerConfirmationSheet(
                    result: selectedPlateAppearanceResult,
                    state: affectedState,
                    homeAway: homeAway,
                    battingOrder: problem.offensiveRunnerIdentities,
                    batter: affectedPlateAppearance.batter,
                    battingOrderSize: affectedPlateAppearance.battingOrderSize,
                    initialDraft: OffensivePlateAppearanceDraft(
                        result: selectedPlateAppearanceResult,
                        movements: affectedPlateAppearance.movements,
                        rbi: affectedPlateAppearance.rbi,
                        countedRunSources: affectedPlateAppearance.countedRunSources,
                        thirdOutClassification: affectedPlateAppearance.thirdOutClassification
                    ),
                    allowsScoring: true,
                    title: "Repair Affected Tracked Play",
                    confirmationTitle: "Stage Repair",
                    onCancel: { isConfirmingPlateAppearanceRunners = false },
                    onRecord: { draft in
                        stageChange(.editOffensivePlateAppearance(.init(
                            batter: affectedPlateAppearance.batter,
                            battingOrderSize: affectedPlateAppearance.battingOrderSize,
                            result: draft.result,
                            movements: draft.movements,
                            rbi: draft.rbi,
                            countedRunSources: draft.countedRunSources,
                            thirdOutClassification: draft.thirdOutClassification
                        )))
                        isConfirmingPlateAppearanceRunners = false
                        dismiss()
                    }
                )
            }
        }
    }

    private var correctionOutcomes: [BallInPlayOutcome] {
        affectedState.map(BallInPlayValidator.correctionOutcomes(for:)) ?? []
    }

    private func stageBaseRunningRepair() {
        guard let runner = problem.offensiveBaseRunningRunners.first(where: {
            $0.id == selectedBaseRunningRunnerID
        }) else {
            baseRunningRepairError = "Choose a runner who occupied a base at this event."
            return
        }
        guard let destination = baseRunningDestination(
            source: runner.source,
            result: selectedBaseRunningResult
        ) else {
            baseRunningRepairError = "The selected runner cannot make that base-running attempt."
            return
        }
        baseRunningRepairError = nil
        stageChange(.editOffensiveBaseRunning(.init(
            runnerID: runner.id,
            source: runner.source,
            destination: destination,
            result: selectedBaseRunningResult
        )))
        dismiss()
    }
}
