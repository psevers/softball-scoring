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
    @State private var preview: DefensivePitchEditPreview?
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

                    if let preview {
                        Section("Candidate replay") {
                            Text(
                                "Proposed: \(preview.proposedResult.label) · "
                                    + countDescription(proposedState(in: preview))
                            )
                            .accessibilityIdentifier("pitchEdit.proposed")

                            if let invalid = preview.firstInvalidRecord {
                                Label(
                                    "Sequence \(invalid.sequenceNumber): \(invalid.summary)",
                                    systemImage: "exclamationmark.triangle.fill"
                                )
                                .foregroundStyle(AppTheme.destructive)
                            } else {
                                Label(
                                    "Candidate timeline replays cleanly",
                                    systemImage: "checkmark.circle"
                                )
                            }
                        }

                        Section("Preview") {
                            ForEach(preview.snapshot.history.sections) { section in
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
                        .disabled(preview?.canSave != true)
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
            preview = nil
            return
        }
        do {
            preview = try GameEventCorrection.stageDefensivePitchEdit(
                result,
                in: editSession,
                game: game,
                modelContext: modelContext
            )
        } catch {
            preview = nil
            errorMessage = error.localizedDescription
        }
    }

    private func save() {
        guard let preview, preview.canSave else { return }
        do {
            try liveSession.saveDefensivePitchEdit(
                preview,
                game: game,
                modelContext: modelContext
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func proposedState(in preview: DefensivePitchEditPreview) -> GameState {
        preview.snapshot.replay.entries.first(where: {
            $0.recordID == editSession.recordID
        })?.stateAfter ?? preview.snapshot.replay.state
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
    @State private var preview: DefensivePitchDeletionPreview?
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

                    if let preview {
                        Section("Candidate replay") {
                            if let invalid = preview.firstInvalidRecord {
                                Label(
                                    "Sequence \(invalid.sequenceNumber): \(invalid.summary)",
                                    systemImage: "exclamationmark.triangle.fill"
                                )
                                .foregroundStyle(AppTheme.destructive)
                            } else {
                                Label(
                                    "Candidate timeline replays cleanly",
                                    systemImage: "checkmark.circle"
                                )
                            }
                        }

                        Section("Preview") {
                            ForEach(preview.snapshot.history.sections) { section in
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
                        .disabled(preview?.canSave != true)
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
        guard preview == nil else { return }
        do {
            preview = try GameEventCorrection.stageDefensivePitchDeletion(
                deletionSession,
                game: game,
                modelContext: modelContext
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() {
        guard let preview, preview.canSave else { return }
        do {
            try liveSession.saveDefensivePitchDeletion(
                preview,
                game: game,
                modelContext: modelContext
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func countDescription(_ state: GameState) -> String {
        "Count \(state.balls)–\(state.strikes)"
    }
}
