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
    @State private var correction = DefensiveEventCorrectionCoordinator()

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
                        DefensiveEventCorrectionSections(
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
    @State private var correction = DefensiveEventCorrectionCoordinator()

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
                        DefensiveEventCorrectionSections(
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
            let session = try GameEventCorrection.beginDefensiveEventCorrection(
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

    private func proposedState(in correctionSession: DefensiveEventCorrectionSession) -> GameState {
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
    @State private var correction = DefensiveEventCorrectionCoordinator()

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
                        DefensiveEventCorrectionSections(
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
                Button("OK", role: .cancel) { correction.errorMessage = nil }
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

    private func proposedState(in correctionSession: DefensiveEventCorrectionSession) -> GameState {
        correctionSession.snapshot.replay.entries.first(where: {
            $0.recordID == editSession.recordID
        })?.stateAfter ?? correctionSession.snapshot.replay.state
    }

    private func countDescription(_ state: GameState) -> String {
        "Count \(state.balls)–\(state.strikes)"
    }
}

struct DefensivePitchDeletionView: View {
    let game: Game
    let deletionSession: DefensivePitchDeletionSession
    let liveSession: LiveGameSession

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var correction = DefensiveEventCorrectionCoordinator()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section("Pitch") {
                        Text(
                            "\(deletionSession.half.displayName) \(deletionSession.inning) · "
                                + "Opponent batter \(deletionSession.opponentBatterSlot) · "
                                + "Sequence \(deletionSession.sequenceNumber)"
                        )
                        .font(.body.monospacedDigit())
                        Text(
                            "Delete: \(deletionSession.originalResult.label) · "
                                + countDescription(deletionSession.originalStateAfter)
                        )
                        .accessibilityIdentifier("pitchDelete.current")
                    }

                    if let correctionSession = correction.session {
                        DefensiveEventCorrectionSections(
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
                        .frame(
                            maxWidth: .infinity,
                            minHeight: AppTheme.TouchTarget.minimum
                        )
                        .accessibilityIdentifier("pitchDelete.cancel")

                    Button("Save") { save() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: AppTheme.TouchTarget.minimum
                        )
                        .disabled(correction.session?.canSave != true)
                        .accessibilityIdentifier("pitchDelete.save")
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(.bar)
            }
            .navigationTitle("Delete Pitch")
            .navigationBarTitleDisplayMode(.inline)
            .task { stage() }
            .alert("Pitch Deletion Failed", isPresented: Binding(
                get: { correction.errorMessage != nil },
                set: { if !$0 { correction.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { correction.errorMessage = nil }
            } message: {
                Text(
                    correction.errorMessage
                        ?? "The pitch deletion could not be replayed safely."
                )
            }
        }
    }

    private func stage() {
        guard correction.session == nil else { return }
        do {
            let session = try GameEventCorrection.beginDefensiveEventCorrection(
                game: game,
                modelContext: modelContext
            )
            correction.session = try GameEventCorrection.stagePitchDeletion(
                recordID: deletionSession.recordID,
                in: session,
                game: game,
                modelContext: modelContext
            )
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

    private func countDescription(_ state: GameState) -> String {
        "Count \(state.balls)–\(state.strikes)"
    }
}

struct DefensiveLogicalPlayDeletionView: View {
    let game: Game
    let deletionSession: DefensiveLogicalPlayDeletionSession
    let liveSession: LiveGameSession

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var correction = DefensiveEventCorrectionCoordinator()

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
                        DefensiveEventCorrectionSections(
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

private enum DefensiveEventRepairAction {
    case edit(PitchResult)
    case editOffensivePitch(OffensivePitchResult)
    case delete
    case editBallInPlay(BallInPlayEvent)
}

@MainActor
@Observable
private final class DefensiveEventCorrectionCoordinator {
    var session: DefensiveEventCorrectionSession?
    var errorMessage: String?

    func stageRepair(
        recordID: UUID,
        action: DefensiveEventRepairAction,
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
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save(
        liveSession: LiveGameSession,
        game: Game,
        modelContext: ModelContext
    ) -> Bool {
        guard let session, session.canSave else { return false }
        do {
            try liveSession.saveDefensiveEventCorrection(
                session,
                game: game,
                modelContext: modelContext
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

private extension DefensiveEventCorrectionSession {
    func historyEntry(for recordID: UUID) -> PlayHistoryEntry? {
        snapshot.history.sections
            .flatMap(\.entries)
            .first(where: { entry in entry.components.contains { $0.recordID == recordID } })
    }
}

private struct DefensiveEventCorrectionSections: View {
    let correctionSession: DefensiveEventCorrectionSession
    let homeAway: HomeAway?
    let proposedSummary: String?
    let proposedIdentifier: String?
    let stageChange: (DefensiveEventCorrectionProblem, DefensiveEventRepairAction) -> Void

    init(
        correctionSession: DefensiveEventCorrectionSession,
        homeAway: HomeAway?,
        proposedSummary: String? = nil,
        proposedIdentifier: String? = nil,
        stageChange: @escaping (
            DefensiveEventCorrectionProblem,
            DefensiveEventRepairAction
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
                    DefensiveEventCorrectionProblemView(
                        problem: invalid,
                        historyEntry: correctionSession.historyEntry(for: invalid.id),
                        affectedPlay: affectedPlay,
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

private struct DefensiveEventCorrectionProblemView: View {
    private static let editableResults: [PitchResult] = [
        .ball, .calledStrike, .swingingStrike, .foul
    ]
    private static let editableOffensiveResults = OffensivePitchResult.allCases

    let problem: DefensiveEventCorrectionProblem
    let historyEntry: PlayHistoryEntry?
    let affectedPlay: BallInPlayEvent?
    let affectedState: GameState?
    let homeAway: HomeAway?
    let stageChange: (DefensiveEventRepairAction) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedOutcome: BallInPlayOutcome
    @State private var isConfirmingRunners = false

    init(
        problem: DefensiveEventCorrectionProblem,
        historyEntry: PlayHistoryEntry?,
        affectedPlay: BallInPlayEvent?,
        affectedState: GameState?,
        homeAway: HomeAway?,
        stageChange: @escaping (DefensiveEventRepairAction) -> Void
    ) {
        self.problem = problem
        self.historyEntry = historyEntry
        self.affectedPlay = affectedPlay
        self.affectedState = affectedState
        self.homeAway = homeAway
        self.stageChange = stageChange
        _selectedOutcome = State(initialValue: affectedPlay?.outcome ?? .single)
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
                } else if !problem.canEditPitch
                            && !problem.canEditOffensivePitch
                            && !problem.canDeletePitch {
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
    }

    private var correctionOutcomes: [BallInPlayOutcome] {
        affectedState.map(BallInPlayValidator.correctionOutcomes(for:)) ?? []
    }
}
