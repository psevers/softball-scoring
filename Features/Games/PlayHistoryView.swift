import SwiftData
import SwiftUI

struct PlayHistoryView: View {
    let game: Game
    let session: LiveGameSession

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isConfirmingUndo = false
    @State private var correctionError: String?

    var body: some View {
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
                        undoLatestPitchButton
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
        .task {
            session.refresh(game: game, modelContext: modelContext)
        }
        .alert(
            "Undo latest pitch?",
            isPresented: $isConfirmingUndo,
            presenting: session.undoCandidate
        ) { candidate in
            Button("Undo \(candidate.result.label)", role: .destructive) {
                undoLatestCountPitch(candidate)
            }
            Button("Cancel", role: .cancel) {}
        } message: { candidate in
            Text(candidate.confirmationDetail)
        }
        .alert("Undo Failed", isPresented: Binding(
            get: { correctionError != nil },
            set: { if !$0 { correctionError = nil } }
        )) {
            Button("OK", role: .cancel) { correctionError = nil }
        } message: {
            Text(correctionError ?? "The pitch could not be removed.")
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
        }
        .tint(entry.isProblem ? AppTheme.destructive : AppTheme.graphite)
        .accessibilityIdentifier("history.entry.\(entry.components.first?.sequenceNumber ?? 0)")
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

    private var undoLatestPitchButton: some View {
        UndoLatestPitchButton(identifier: "history.undoLatestPitch") {
            isConfirmingUndo = true
        }
    }

    private func undoLatestCountPitch(_ candidate: UndoLatestCountPitchCandidate) {
        do {
            try session.undoLatestCountPitch(
                candidate,
                game: game,
                modelContext: modelContext
            )
        } catch {
            session.refresh(game: game, modelContext: modelContext)
            correctionError = error.localizedDescription
        }
    }
}
