import SwiftData
import SwiftUI

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
    @State private var correctionSession: DefensivePitchCorrectionSession?
    @State private var errorMessage: String?

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

                    if let correctionSession {
                        DefensivePitchCorrectionSections(
                            correctionSession: correctionSession,
                            proposedSummary: "Proposed: \(selectedResult.label) · "
                                + countDescription(proposedState(in: correctionSession)),
                            proposedIdentifier: "pitchEdit.proposed"
                        ) { problem in
                            repairView(for: problem, in: correctionSession)
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
                        .accessibilityIdentifier("pitchEdit.cancel")

                    Button("Save") { save() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: AppTheme.TouchTarget.minimum
                        )
                        .disabled(correctionSession?.canSave != true)
                        .accessibilityIdentifier("pitchEdit.save")
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(.bar)
            }
            .navigationTitle("Edit Pitch")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Pitch Edit Failed", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "The proposed pitch could not be replayed safely.")
            }
        }
    }

    private func select(_ result: PitchResult) {
        selectedResult = result
        guard result != editSession.originalResult else {
            correctionSession = nil
            return
        }
        do {
            let session = try GameEventCorrection.beginDefensivePitchCorrection(
                game: game,
                modelContext: modelContext
            )
            correctionSession = try GameEventCorrection.stagePitchEdit(
                recordID: editSession.recordID,
                result: result,
                in: session,
                game: game,
                modelContext: modelContext
            )
        } catch {
            correctionSession = nil
            errorMessage = error.localizedDescription
        }
    }

    private func save() {
        guard let correctionSession, correctionSession.canSave else { return }
        do {
            try liveSession.saveDefensivePitchCorrection(
                correctionSession,
                game: game,
                modelContext: modelContext
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func proposedState(in correctionSession: DefensivePitchCorrectionSession) -> GameState {
        correctionSession.snapshot.replay.entries.first(where: {
            $0.recordID == editSession.recordID
        })?.stateAfter ?? correctionSession.snapshot.replay.state
    }

    private func repairView(
        for problem: DefensivePitchCorrectionProblem,
        in correctionSession: DefensivePitchCorrectionSession
    ) -> some View {
        DefensivePitchCorrectionProblemView(
            problem: problem,
            historyEntry: correctionSession.historyEntry(for: problem.id),
            stageChange: { stageRepair(recordID: problem.id, action: $0) }
        )
    }

    private func stageRepair(recordID: UUID, action: DefensivePitchRepairAction) {
        guard let correctionSession else { return }
        do {
            switch action {
            case .edit(let result):
                self.correctionSession = try GameEventCorrection.stagePitchEdit(
                    recordID: recordID,
                    result: result,
                    in: correctionSession,
                    game: game,
                    modelContext: modelContext
                )
            case .delete:
                self.correctionSession = try GameEventCorrection.stagePitchDeletion(
                    recordID: recordID,
                    in: correctionSession,
                    game: game,
                    modelContext: modelContext
                )
            }
        } catch {
            errorMessage = error.localizedDescription
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

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var correctionSession: DefensivePitchCorrectionSession?
    @State private var errorMessage: String?

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

                    if let correctionSession {
                        DefensivePitchCorrectionSections(
                            correctionSession: correctionSession
                        ) { problem in
                            repairView(for: problem, in: correctionSession)
                        }
                    } else if errorMessage == nil {
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
                        .disabled(correctionSession?.canSave != true)
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
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "The pitch deletion could not be replayed safely.")
            }
        }
    }

    private func stage() {
        guard correctionSession == nil else { return }
        do {
            let session = try GameEventCorrection.beginDefensivePitchCorrection(
                game: game,
                modelContext: modelContext
            )
            correctionSession = try GameEventCorrection.stagePitchDeletion(
                recordID: deletionSession.recordID,
                in: session,
                game: game,
                modelContext: modelContext
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() {
        guard let correctionSession, correctionSession.canSave else { return }
        do {
            try liveSession.saveDefensivePitchCorrection(
                correctionSession,
                game: game,
                modelContext: modelContext
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func repairView(
        for problem: DefensivePitchCorrectionProblem,
        in correctionSession: DefensivePitchCorrectionSession
    ) -> some View {
        DefensivePitchCorrectionProblemView(
            problem: problem,
            historyEntry: correctionSession.historyEntry(for: problem.id),
            stageChange: { stageRepair(recordID: problem.id, action: $0) }
        )
    }

    private func stageRepair(recordID: UUID, action: DefensivePitchRepairAction) {
        guard let correctionSession else { return }
        do {
            switch action {
            case .edit(let result):
                self.correctionSession = try GameEventCorrection.stagePitchEdit(
                    recordID: recordID,
                    result: result,
                    in: correctionSession,
                    game: game,
                    modelContext: modelContext
                )
            case .delete:
                self.correctionSession = try GameEventCorrection.stagePitchDeletion(
                    recordID: recordID,
                    in: correctionSession,
                    game: game,
                    modelContext: modelContext
                )
            }
        } catch {
            errorMessage = error.localizedDescription
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

private extension DefensivePitchCorrectionSession {
    func historyEntry(for recordID: UUID) -> PlayHistoryEntry? {
        snapshot.history.sections
            .flatMap(\.entries)
            .first(where: { entry in entry.components.contains { $0.recordID == recordID } })
    }
}

private struct DefensivePitchCorrectionSections<ProblemDestination: View>: View {
    let correctionSession: DefensivePitchCorrectionSession
    let proposedSummary: String?
    let proposedIdentifier: String?
    let problemDestination: (DefensivePitchCorrectionProblem) -> ProblemDestination

    init(
        correctionSession: DefensivePitchCorrectionSession,
        proposedSummary: String? = nil,
        proposedIdentifier: String? = nil,
        @ViewBuilder problemDestination: @escaping (DefensivePitchCorrectionProblem) -> ProblemDestination
    ) {
        self.correctionSession = correctionSession
        self.proposedSummary = proposedSummary
        self.proposedIdentifier = proposedIdentifier
        self.problemDestination = problemDestination
    }

    var body: some View {
        Section("Candidate replay") {
            if let proposedSummary {
                Text(proposedSummary)
                    .accessibilityIdentifier(proposedIdentifier ?? "correction.proposed")
            }

            if let invalid = correctionSession.firstInvalidRecord {
                NavigationLink {
                    problemDestination(invalid)
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
