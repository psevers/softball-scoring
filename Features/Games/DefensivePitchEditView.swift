import Observation
import SwiftData
import SwiftUI

struct DefensiveBallInPlayEditView: View {
    private static let supportedOutcomes: [BallInPlayOutcome] = [
        .single, .double, .triple, .reachedOnError, .fieldersChoice,
        .groundOut, .flyOut, .lineOut, .popOut, .sacrificeBunt
    ]

    let game: Game
    let editSession: DefensiveBallInPlayEditSession
    let liveSession: LiveGameSession

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedOutcome: BallInPlayOutcome
    @State private var isConfirmingRunners = false
    @State private var proposedPlay: BallInPlayEvent?
    @State private var correction = DefensivePitchCorrectionCoordinator()

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
                        ForEach(Self.supportedOutcomes) { outcome in
                            Button {
                                selectedOutcome = outcome
                                proposedPlay = nil
                                correction.session = nil
                            } label: {
                                HStack {
                                    Text(outcome.label)
                                    Spacer()
                                    if outcome == selectedOutcome {
                                        Image(systemName: "checkmark")
                                    }
                                }
                                .frame(minHeight: AppTheme.TouchTarget.minimum)
                            }
                            .accessibilityIdentifier("playEdit.outcome.\(outcome.rawValue)")
                        }

                        Button("Confirm Runner Destinations") {
                            isConfirmingRunners = true
                        }
                        .frame(minHeight: AppTheme.TouchTarget.minimum)
                        .accessibilityIdentifier("playEdit.confirmRunners")
                    }

                    if let proposedPlay, let correctionSession = correction.session {
                        DefensivePitchCorrectionSections(
                            correctionSession: correctionSession,
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
            .sheet(isPresented: $isConfirmingRunners) {
                RunnerConfirmationSheet(
                    outcome: selectedOutcome,
                    state: editSession.stateBefore,
                    homeAway: editSession.homeAway,
                    initialPlay: initialPlay,
                    allowsScoring: false,
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
        let movements = proposedPlay?.outcome == selectedOutcome
            ? proposedPlay?.movements ?? editSession.originalPlay.movements
            : editSession.originalPlay.movements
        return BallInPlayEvent(
            outcome: selectedOutcome,
            opponentBatterSlot: editSession.opponentBatterSlot,
            movements: movements,
            rbi: 0,
            thirdOutRunsCounted: nil
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
        return "\(play.outcome.label) · \(movements)"
    }

    private func stateSummary(_ state: GameState) -> String {
        let bases = [
            state.firstBaseRunnerSlot.map { "1B \($0)" },
            state.secondBaseRunnerSlot.map { "2B \($0)" },
            state.thirdBaseRunnerSlot.map { "3B \($0)" }
        ].compactMap { $0 }.joined(separator: ", ")
        return "Outs \(state.outs) · Bases \(bases.isEmpty ? "empty" : bases) · "
            + "Opponent batter \(state.currentOpponentBatterSlot)"
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
    @State private var correction = DefensivePitchCorrectionCoordinator()

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
                        DefensivePitchCorrectionSections(
                            correctionSession: correctionSession,
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
            let session = try GameEventCorrection.beginDefensivePitchCorrection(
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

    private func proposedState(in correctionSession: DefensivePitchCorrectionSession) -> GameState {
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
    @State private var correction = DefensivePitchCorrectionCoordinator()

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
                        DefensivePitchCorrectionSections(
                            correctionSession: correctionSession,
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
            let session = try GameEventCorrection.beginDefensivePitchCorrection(
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

private enum DefensivePitchRepairAction {
    case edit(PitchResult)
    case delete
}

@MainActor
@Observable
private final class DefensivePitchCorrectionCoordinator {
    var session: DefensivePitchCorrectionSession?
    var errorMessage: String?

    func stageRepair(
        recordID: UUID,
        action: DefensivePitchRepairAction,
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
            case .delete:
                self.session = try GameEventCorrection.stagePitchDeletion(
                    recordID: recordID,
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
            try liveSession.saveDefensivePitchCorrection(
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

private extension DefensivePitchCorrectionSession {
    func historyEntry(for recordID: UUID) -> PlayHistoryEntry? {
        snapshot.history.sections
            .flatMap(\.entries)
            .first(where: { entry in entry.components.contains { $0.recordID == recordID } })
    }
}

private struct DefensivePitchCorrectionSections: View {
    let correctionSession: DefensivePitchCorrectionSession
    let proposedSummary: String?
    let proposedIdentifier: String?
    let stageChange: (DefensivePitchCorrectionProblem, DefensivePitchRepairAction) -> Void

    init(
        correctionSession: DefensivePitchCorrectionSession,
        proposedSummary: String? = nil,
        proposedIdentifier: String? = nil,
        stageChange: @escaping (
            DefensivePitchCorrectionProblem,
            DefensivePitchRepairAction
        ) -> Void
    ) {
        self.correctionSession = correctionSession
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
                    DefensivePitchCorrectionProblemView(
                        problem: invalid,
                        historyEntry: correctionSession.historyEntry(for: invalid.id),
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

private struct DefensivePitchCorrectionProblemView: View {
    private static let editableResults: [PitchResult] = [
        .ball, .calledStrike, .swingingStrike, .foul
    ]

    let problem: DefensivePitchCorrectionProblem
    let historyEntry: PlayHistoryEntry?
    let stageChange: (DefensivePitchRepairAction) -> Void

    @Environment(\.dismiss) private var dismiss

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

                if problem.canDeletePitch {
                    Button(role: .destructive) {
                        stageChange(.delete)
                        dismiss()
                    } label: {
                        Label("Delete Affected Pitch", systemImage: "trash")
                            .frame(minHeight: AppTheme.TouchTarget.minimum)
                    }
                    .accessibilityIdentifier("correction.repair.delete")
                } else {
                    Text("This event does not support another change in this correction session.")
                        .foregroundStyle(AppTheme.graphite.opacity(0.68))
                }
            }
        }
        .navigationTitle("Affected Event")
        .navigationBarTitleDisplayMode(.inline)
    }
}
