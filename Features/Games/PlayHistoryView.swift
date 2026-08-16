import SwiftData
import SwiftUI

struct PlayHistoryView: View {
    let game: Game
    let session: LiveGameSession

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query private var players: [Player]
    @State private var isConfirmingUndo = false
    @State private var correctionError: String?
    @State private var pitchEditSession: DefensivePitchEditSession?
    @State private var offensivePitchEditSession: OffensivePitchEditSession?
    @State private var offensiveBaseRunningEditSession: OffensiveBaseRunningEditSession?
    @State private var offensivePlateAppearanceEditSession: OffensivePlateAppearanceEditSession?
    @State private var ballInPlayEditSession: DefensiveBallInPlayEditSession?
    @State private var pendingPitchDeletionSession: DefensivePitchDeletionSession?
    @State private var pitchDeletionSession: DefensivePitchDeletionSession?
    @State private var pendingOffensivePitchDeletionSession: OffensivePitchDeletionSession?
    @State private var offensivePitchDeletionSession: OffensivePitchDeletionSession?
    @State private var pendingLogicalPlayDeletionSession: DefensiveLogicalPlayDeletionSession?
    @State private var logicalPlayDeletionSession: DefensiveLogicalPlayDeletionSession?
    @State private var pendingOffensiveLogicalPlayDeletionSession: OffensiveLogicalPlayDeletionSession?
    @State private var offensiveLogicalPlayDeletionSession: OffensiveLogicalPlayDeletionSession?
    @State private var pendingUnreadableRecordDeletionSession: UnreadableRecordDeletionSession?
    @State private var unreadableRecordDeletionSession: UnreadableRecordDeletionSession?
    @State private var pitchCountReconciliationSession: PitchCountReconciliationSession?

    var body: some View {
        presentedHistoryPage
    }

    private var historyPage: some View {
        ZStack {
            ScorebookRuledPaperBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    ScorebookPageHeader(
                        title: "Play History",
                        subtitle: "Authoritative scorebook timeline",
                        systemImage: "clock.arrow.circlepath"
                    )

                    if session.undoCandidate != nil {
                        undoLatestActionButton
                    }

                    historyContent
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
            }
            .accessibilityIdentifier("history.page")
            .overlay(alignment: .leading) {
                ScorebookMarginRule()
            }
        }
        .navigationTitle("Play History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    beginPitchCountReconciliation()
                } label: {
                    Label("Reconcile Pitches", systemImage: "plusminus.circle")
                }
                .accessibilityIdentifier("history.reconcilePitches")
            }
        }
        .task {
            session.refresh(game: game, modelContext: modelContext)
        }
    }

    private var undoAlertedHistoryPage: some View {
        historyPage
        .alert(
            session.undoCandidate?.confirmationTitle ?? "Undo latest action?",
            isPresented: $isConfirmingUndo,
            presenting: session.undoCandidate
        ) { candidate in
            Button("Undo \(candidate.action.label)", role: .destructive) {
                undoLatestAction(candidate)
            }
            Button("Cancel", role: .cancel) {}
        } message: { candidate in
            Text(candidate.confirmationDetail)
        }
        .alert("Correction Failed", isPresented: Binding(
            get: { correctionError != nil },
            set: { if !$0 { correctionError = nil } }
        )) {
            Button("OK", role: .cancel) { correctionError = nil }
        } message: {
            Text(correctionError ?? "The scorebook correction could not be completed.")
        }
    }

    private var pitchAlertedHistoryPage: some View {
        undoAlertedHistoryPage
        .alert(
            pendingPitchDeletionSession?.confirmationTitle ?? "Delete pitch?",
            isPresented: Binding(
                get: { pendingPitchDeletionSession != nil },
                set: { if !$0 { pendingPitchDeletionSession = nil } }
            ),
            presenting: pendingPitchDeletionSession
        ) { deletionSession in
            Button("Preview Deletion", role: .destructive) {
                pitchDeletionSession = deletionSession
                pendingPitchDeletionSession = nil
            }
            Button("Cancel", role: .cancel) {
                pendingPitchDeletionSession = nil
            }
        } message: { deletionSession in
            Text(deletionSession.confirmationDetail)
        }
        .alert(
            pendingOffensivePitchDeletionSession?.confirmationTitle ?? "Delete tracked pitch?",
            isPresented: Binding(
                get: { pendingOffensivePitchDeletionSession != nil },
                set: { if !$0 { pendingOffensivePitchDeletionSession = nil } }
            ),
            presenting: pendingOffensivePitchDeletionSession
        ) { deletionSession in
            Button("Preview Deletion", role: .destructive) {
                offensivePitchDeletionSession = deletionSession
                pendingOffensivePitchDeletionSession = nil
            }
            Button("Cancel", role: .cancel) {
                pendingOffensivePitchDeletionSession = nil
            }
        } message: { deletionSession in
            Text(deletionSession.confirmationDetail)
        }
    }

    private var alertedHistoryPage: some View {
        pitchAlertedHistoryPage
        .alert(
            pendingLogicalPlayDeletionSession?.confirmationTitle ?? "Delete completed play?",
            isPresented: Binding(
                get: { pendingLogicalPlayDeletionSession != nil },
                set: { if !$0 { pendingLogicalPlayDeletionSession = nil } }
            ),
            presenting: pendingLogicalPlayDeletionSession
        ) { deletionSession in
            Button("Preview Deletion", role: .destructive) {
                logicalPlayDeletionSession = deletionSession
                pendingLogicalPlayDeletionSession = nil
            }
            Button("Cancel", role: .cancel) {
                pendingLogicalPlayDeletionSession = nil
            }
        } message: { deletionSession in
            Text(deletionSession.confirmationDetail)
        }
        .alert(
            pendingOffensiveLogicalPlayDeletionSession?.confirmationTitle
                ?? "Delete completed tracked play?",
            isPresented: Binding(
                get: { pendingOffensiveLogicalPlayDeletionSession != nil },
                set: { if !$0 { pendingOffensiveLogicalPlayDeletionSession = nil } }
            ),
            presenting: pendingOffensiveLogicalPlayDeletionSession
        ) { deletionSession in
            Button("Preview Deletion", role: .destructive) {
                offensiveLogicalPlayDeletionSession = deletionSession
                pendingOffensiveLogicalPlayDeletionSession = nil
            }
            Button("Cancel", role: .cancel) {
                pendingOffensiveLogicalPlayDeletionSession = nil
            }
        } message: { deletionSession in
            Text(deletionSession.confirmationDetail)
        }
        .alert(
            pendingUnreadableRecordDeletionSession?.confirmationTitle
                ?? "Delete unreadable event?",
            isPresented: Binding(
                get: { pendingUnreadableRecordDeletionSession != nil },
                set: { if !$0 { pendingUnreadableRecordDeletionSession = nil } }
            ),
            presenting: pendingUnreadableRecordDeletionSession
        ) { deletionSession in
            Button("Preview Deletion", role: .destructive) {
                unreadableRecordDeletionSession = deletionSession
                pendingUnreadableRecordDeletionSession = nil
            }
            Button("Cancel", role: .cancel) {
                pendingUnreadableRecordDeletionSession = nil
            }
        } message: { deletionSession in
            Text(deletionSession.confirmationDetail)
        }
    }

    private var presentedHistoryPage: some View {
        alertedHistoryPage
        .sheet(item: $pitchEditSession) { editSession in
            DefensivePitchEditView(
                game: game,
                editSession: editSession,
                liveSession: session
            )
        }
        .sheet(item: $offensivePitchEditSession) { editSession in
            OffensivePitchEditView(
                game: game,
                editSession: editSession,
                liveSession: session
            )
        }
        .sheet(item: $offensiveBaseRunningEditSession) { editSession in
            OffensiveBaseRunningEditView(
                game: game,
                editSession: editSession,
                liveSession: session
            )
        }
        .sheet(item: $offensivePlateAppearanceEditSession) { editSession in
            OffensivePlateAppearanceEditView(
                game: game,
                editSession: editSession,
                liveSession: session
            )
        }
        .sheet(item: $ballInPlayEditSession) { editSession in
            DefensiveBallInPlayEditView(
                game: game,
                editSession: editSession,
                liveSession: session
            )
        }
        .sheet(item: $pitchDeletionSession) { deletionSession in
            DefensivePitchDeletionView(
                game: game,
                deletionSession: deletionSession,
                liveSession: session
            )
        }
        .sheet(item: $offensivePitchDeletionSession) { deletionSession in
            OffensivePitchDeletionView(
                game: game,
                deletionSession: deletionSession,
                liveSession: session
            )
        }
        .sheet(item: $logicalPlayDeletionSession) { deletionSession in
            DefensiveLogicalPlayDeletionView(
                game: game,
                deletionSession: deletionSession,
                liveSession: session
            )
        }
        .sheet(item: $offensiveLogicalPlayDeletionSession) { deletionSession in
            OffensiveLogicalPlayDeletionView(
                game: game,
                deletionSession: deletionSession,
                liveSession: session
            )
        }
        .sheet(item: $unreadableRecordDeletionSession) { deletionSession in
            UnreadableRecordDeletionView(
                game: game,
                deletionSession: deletionSession,
                liveSession: session
            )
        }
        .sheet(item: $pitchCountReconciliationSession) { reconciliationSession in
            PitchCountReconciliationView(
                session: reconciliationSession,
                pitcherName: players.first(where: {
                    $0.id == reconciliationSession.pitcherID
                })?.displayName ?? "Starting Pitcher"
            ) { adjustment, relatedPlayRecordID in
                try session.savePitchCountReconciliation(
                    adjustment: adjustment,
                    relatedPlayRecordID: relatedPlayRecordID,
                    session: reconciliationSession,
                    game: game,
                    modelContext: modelContext
                )
            }
        }
    }

    @ViewBuilder
    private var historyContent: some View {
        if let error = session.loadError {
            ScorebookLedger {
                ScorebookPageSection("History unavailable") {
                    ScorebookLedgerRow {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.body)
                            .foregroundStyle(AppTheme.destructive)
                    }
                }
            }
        } else if let snapshot = session.snapshot {
            if snapshot.history.sections.isEmpty {
                ScorebookEmptyLedger(
                    systemImage: "book.pages",
                    title: "No Plays Yet",
                    message: "Recorded pitches and plays will appear here."
                )
            } else {
                ScorebookLedger {
                    ForEach(snapshot.history.sections) { section in
                        ScorebookPageSection(section.title) {
                            ForEach(section.entries) { entry in
                                ScorebookLedgerRow {
                                    historyEntry(entry)
                                }
                            }
                        }
                    }
                }
            }
        } else {
            ProgressView("Loading history…")
                .frame(maxWidth: .infinity, minHeight: 120)
        }
    }

    private func historyEntry(_ entry: PlayHistoryEntry) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                ForEach(entry.components) { component in
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
                            Text("\(component.sequenceNumber)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(AppTheme.graphite.opacity(0.54))
                                .frame(minWidth: 24, alignment: .trailing)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(component.summary)
                                    .font(component.isPitch ? .body : AppTheme.Typography.notation)
                                    .foregroundStyle(componentColor(entry))
                                Text(component.detail)
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(AppTheme.graphite.opacity(0.68))
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: AppTheme.TouchTarget.minimum, alignment: .leading)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(
                            "Event \(component.sequenceNumber). \(component.accessibilityDescription)"
                        )

                        if let result = component.editableDefensivePitchResult {
                            Button {
                                beginPitchEdit(recordID: component.recordID)
                            } label: {
                                Label("Edit Pitch", systemImage: "pencil")
                                    .frame(minHeight: AppTheme.TouchTarget.minimum)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel(
                                "Edit \(result.label) pitch, sequence \(component.sequenceNumber)"
                            )
                            .accessibilityIdentifier("history.editPitch.\(component.sequenceNumber)")
                        }

                        if let result = component.editableOffensivePitchResult {
                            Button {
                                beginOffensivePitchEdit(recordID: component.recordID)
                            } label: {
                                Label("Edit Pitch", systemImage: "pencil")
                                    .frame(minHeight: AppTheme.TouchTarget.minimum)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel(
                                "Edit \(entry.actor) \(result.label) pitch, sequence "
                                    + "\(component.sequenceNumber)"
                            )
                            .accessibilityIdentifier(
                                "history.editTrackedPitch.\(component.sequenceNumber)"
                            )

                            Button(role: .destructive) {
                                beginOffensivePitchDeletion(recordID: component.recordID)
                            } label: {
                                Label("Delete Pitch", systemImage: "trash")
                                    .frame(minHeight: AppTheme.TouchTarget.minimum)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel(
                                "Delete \(entry.actor) \(result.label) pitch, sequence "
                                    + "\(component.sequenceNumber)"
                            )
                            .accessibilityIdentifier(
                                "history.deleteTrackedPitch.\(component.sequenceNumber)"
                            )
                        }

                        if let event = component.editableOffensiveBaseRunningEvent {
                            Button {
                                beginOffensiveBaseRunningEdit(recordID: component.recordID)
                            } label: {
                                Label("Edit Base Running", systemImage: "figure.run")
                                    .frame(minHeight: AppTheme.TouchTarget.minimum)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel(
                                "Edit \(entry.actor) \(event.result.shortLabel), sequence "
                                    + "\(component.sequenceNumber)"
                            )
                            .accessibilityIdentifier(
                                "history.editTrackedBaseRunning.\(component.sequenceNumber)"
                            )
                        }

                        if let result = component.editableOffensivePlateAppearanceResult {
                            Button {
                                beginOffensivePlateAppearanceEdit(recordID: component.recordID)
                            } label: {
                                Label("Edit Play", systemImage: "square.and.pencil")
                                    .frame(minHeight: AppTheme.TouchTarget.minimum)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel(
                                "Edit \(entry.actor) \(result.label) result, sequence "
                                    + "\(component.sequenceNumber)"
                            )
                            .accessibilityIdentifier(
                                "history.editTrackedPlay.\(component.sequenceNumber)"
                            )
                        }

                        if let result = component.defensivePitchResult {
                            Button(role: .destructive) {
                                beginPitchDeletion(recordID: component.recordID)
                            } label: {
                                Label("Delete Pitch", systemImage: "trash")
                                    .frame(minHeight: AppTheme.TouchTarget.minimum)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel(
                                "Delete \(result.label) pitch, sequence \(component.sequenceNumber)"
                            )
                            .accessibilityIdentifier("history.deletePitch.\(component.sequenceNumber)")
                        }

                        if let outcome = component.editableDefensiveBallInPlayOutcome {
                            Button {
                                beginBallInPlayEdit(recordID: component.recordID)
                            } label: {
                                Label("Edit Play", systemImage: "square.and.pencil")
                                    .frame(minHeight: AppTheme.TouchTarget.minimum)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel(
                                "Edit \(outcome.label) result, sequence \(component.sequenceNumber)"
                            )
                            .accessibilityIdentifier("history.editPlay.\(component.sequenceNumber)")
                        }

                        if component.allowsUnreadableDeletion {
                            Button(role: .destructive) {
                                beginUnreadableRecordDeletion(recordID: component.recordID)
                            } label: {
                                Label("Delete Unreadable Event", systemImage: "trash")
                                    .frame(minHeight: AppTheme.TouchTarget.minimum)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel(
                                "Delete \(component.summary.lowercased()), sequence "
                                    + "\(component.sequenceNumber)"
                            )
                            .accessibilityIdentifier(
                                "history.deleteUnreadable.\(component.sequenceNumber)"
                            )
                        }
                    }
                }

                if let resultRecordID = entry.deletableDefensiveLogicalPlayResultRecordID,
                   let pitchSequence = entry.components.last(where: {
                       $0.defensivePitchResult == .ballInPlay
                   })?.sequenceNumber,
                   let resultSequence = entry.components.first(where: {
                       $0.recordID == resultRecordID
                   })?.sequenceNumber {
                    Button(role: .destructive) {
                        beginLogicalPlayDeletion(resultRecordID: resultRecordID)
                    } label: {
                        Label("Delete Completed Play", systemImage: "trash.slash")
                            .frame(minHeight: AppTheme.TouchTarget.minimum)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel(
                        "Delete Completed Play, sequences \(pitchSequence) and \(resultSequence)"
                    )
                    .accessibilityIdentifier("history.deleteCompletedPlay.\(resultSequence)")
                }

                if let resultRecordID = entry.deletableOffensiveLogicalPlayResultRecordID,
                   let resultSequence = entry.components.first(where: {
                       $0.recordID == resultRecordID
                   })?.sequenceNumber {
                    Button(role: .destructive) {
                        beginOffensiveLogicalPlayDeletion(resultRecordID: resultRecordID)
                    } label: {
                        Label("Delete Completed Play", systemImage: "trash.slash")
                            .frame(minHeight: AppTheme.TouchTarget.minimum)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel(
                        "Delete Completed Tracked Play, terminal sequence \(resultSequence)"
                    )
                    .accessibilityIdentifier(
                        "history.deleteTrackedCompletedPlay.\(resultSequence)"
                    )
                }
            }
            .padding(.top, AppTheme.Spacing.sm)
        } label: {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        actorLabel(entry)
                        summaryLabel(entry)
                        detailLabel(entry)
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.md) {
                        VStack(alignment: .leading, spacing: 2) {
                            actorLabel(entry)
                            Text(entry.actorContext)
                                .font(AppTheme.Typography.metadata)
                                .foregroundStyle(AppTheme.graphite.opacity(0.62))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .trailing, spacing: 2) {
                            summaryLabel(entry)
                            detailLabel(entry)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: AppTheme.TouchTarget.minimum, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(entry.accessibilityDescription)
            .accessibilityHint("Expands the component pitches and play records")
            .accessibilityIdentifier("history.entry.\(entry.components.first?.sequenceNumber ?? 0)")
        }
        .tint(entry.isProblem ? AppTheme.destructive : AppTheme.graphite)
    }

    private func actorLabel(_ entry: PlayHistoryEntry) -> some View {
        Text(entry.actor)
            .font(entry.isProblem ? .headline : AppTheme.Typography.playerName)
            .foregroundStyle(componentColor(entry))
    }

    private func summaryLabel(_ entry: PlayHistoryEntry) -> some View {
        Text(entry.summary)
            .font(entry.isProblem ? .body.bold() : AppTheme.Typography.notation)
            .foregroundStyle(componentColor(entry))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func detailLabel(_ entry: PlayHistoryEntry) -> some View {
        Text(entry.detail)
            .font(AppTheme.Typography.metadata)
            .monospacedDigit()
            .foregroundStyle(AppTheme.graphite.opacity(0.68))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func componentColor(_ entry: PlayHistoryEntry) -> Color {
        entry.isProblem ? AppTheme.destructive : AppTheme.graphite
    }

    private var undoLatestActionButton: some View {
        UndoLatestActionButton(
            title: session.undoCandidate?.action.buttonTitle ?? "Undo Latest Action",
            identifier: "history.undoLatestAction"
        ) {
            isConfirmingUndo = true
        }
    }

    private func undoLatestAction(_ candidate: UndoLatestActionCandidate) {
        do {
            try session.undoLatestAction(
                candidate,
                game: game,
                modelContext: modelContext
            )
        } catch {
            session.refresh(game: game, modelContext: modelContext)
            correctionError = error.localizedDescription
        }
    }

    private func beginPitchEdit(recordID: UUID) {
        do {
            pitchEditSession = try GameEventCorrection.prepareDefensivePitchEdit(
                recordID: recordID,
                game: game,
                modelContext: modelContext
            )
        } catch {
            session.refresh(game: game, modelContext: modelContext)
            correctionError = error.localizedDescription
        }
    }

    private func beginOffensivePitchEdit(recordID: UUID) {
        do {
            offensivePitchEditSession = try GameEventCorrection.prepareOffensivePitchEdit(
                recordID: recordID,
                game: game,
                modelContext: modelContext
            )
        } catch {
            session.refresh(game: game, modelContext: modelContext)
            correctionError = error.localizedDescription
        }
    }

    private func beginOffensiveBaseRunningEdit(recordID: UUID) {
        do {
            offensiveBaseRunningEditSession = try GameEventCorrection
                .prepareOffensiveBaseRunningEdit(
                    recordID: recordID,
                    game: game,
                    modelContext: modelContext
                )
        } catch {
            session.refresh(game: game, modelContext: modelContext)
            correctionError = error.localizedDescription
        }
    }

    private func beginOffensivePlateAppearanceEdit(recordID: UUID) {
        do {
            offensivePlateAppearanceEditSession = try GameEventCorrection
                .prepareOffensivePlateAppearanceEdit(
                    recordID: recordID,
                    game: game,
                    modelContext: modelContext
                )
        } catch {
            session.refresh(game: game, modelContext: modelContext)
            correctionError = error.localizedDescription
        }
    }

    private func beginPitchDeletion(recordID: UUID) {
        do {
            pendingPitchDeletionSession = try GameEventCorrection.prepareDefensivePitchDeletion(
                recordID: recordID,
                game: game,
                modelContext: modelContext
            )
        } catch {
            session.refresh(game: game, modelContext: modelContext)
            correctionError = error.localizedDescription
        }
    }

    private func beginOffensivePitchDeletion(recordID: UUID) {
        do {
            pendingOffensivePitchDeletionSession = try GameEventCorrection
                .prepareOffensivePitchDeletion(
                    recordID: recordID,
                    game: game,
                    modelContext: modelContext
                )
        } catch {
            session.refresh(game: game, modelContext: modelContext)
            correctionError = error.localizedDescription
        }
    }

    private func beginBallInPlayEdit(recordID: UUID) {
        do {
            ballInPlayEditSession = try GameEventCorrection.prepareDefensiveBallInPlayEdit(
                recordID: recordID,
                game: game,
                modelContext: modelContext
            )
        } catch {
            session.refresh(game: game, modelContext: modelContext)
            correctionError = error.localizedDescription
        }
    }

    private func beginLogicalPlayDeletion(resultRecordID: UUID) {
        do {
            pendingLogicalPlayDeletionSession = try GameEventCorrection
                .prepareDefensiveLogicalPlayDeletion(
                    resultRecordID: resultRecordID,
                    game: game,
                    modelContext: modelContext
                )
        } catch {
            session.refresh(game: game, modelContext: modelContext)
            correctionError = error.localizedDescription
        }
    }

    private func beginOffensiveLogicalPlayDeletion(resultRecordID: UUID) {
        do {
            pendingOffensiveLogicalPlayDeletionSession = try GameEventCorrection
                .prepareOffensiveLogicalPlayDeletion(
                    resultRecordID: resultRecordID,
                    game: game,
                    modelContext: modelContext
                )
        } catch {
            session.refresh(game: game, modelContext: modelContext)
            correctionError = error.localizedDescription
        }
    }

    private func beginPitchCountReconciliation() {
        do {
            pitchCountReconciliationSession = try GameEventCorrection
                .preparePitchCountReconciliation(
                    game: game,
                    modelContext: modelContext
                )
        } catch {
            session.refresh(game: game, modelContext: modelContext)
            correctionError = error.localizedDescription
        }
    }

    private func beginUnreadableRecordDeletion(recordID: UUID) {
        do {
            pendingUnreadableRecordDeletionSession = try GameEventCorrection
                .prepareUnreadableRecordDeletion(
                    recordID: recordID,
                    game: game,
                    modelContext: modelContext
                )
        } catch {
            session.refresh(game: game, modelContext: modelContext)
            correctionError = error.localizedDescription
        }
    }
}
