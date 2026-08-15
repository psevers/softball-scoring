import SwiftUI

struct PitchCountReconciliationView: View {
    let session: PitchCountReconciliationSession
    let pitcherName: String
    let onSave: (PitchCountAdjustment, UUID?) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var adjustment = PitchCountAdjustment()
    @State private var relatedPlayRecordID: UUID?
    @State private var errorMessage: String?

    init(
        session: PitchCountReconciliationSession,
        pitcherName: String,
        onSave: @escaping (PitchCountAdjustment, UUID?) throws -> Void
    ) {
        self.session = session
        self.pitcherName = pitcherName
        self.onSave = onSave
        _relatedPlayRecordID = State(initialValue: nil)
    }

    private var reconciledCount: PitchCount? {
        session.reconciledCount(adjustment: adjustment)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Pitcher") {
                    LabeledContent("Player", value: pitcherName)
                    pitchCountRow("Current", count: session.currentCount)
                }

                Section {
                    Picker("Completed play", selection: $relatedPlayRecordID) {
                        Text("No related play").tag(UUID?.none)
                        ForEach(session.completedDefensivePlays) { play in
                            Text(play.summary).tag(Optional(play.recordID))
                        }
                    }
                    .accessibilityIdentifier("reconciliation.relatedPlay")
                } header: {
                    Text("Related defensive play")
                } footer: {
                    Text(
                        "Choose the completed plate appearance whose omitted pitches "
                            + "this adjustment explains."
                    )
                }

                Section {
                    adjustmentStepper(
                        "Total pitches",
                        value: $adjustment.total,
                        identifier: "reconciliation.total"
                    )
                    adjustmentStepper(
                        "Balls",
                        value: $adjustment.balls,
                        identifier: "reconciliation.balls"
                    )
                    adjustmentStepper(
                        "Strikes",
                        value: $adjustment.strikes,
                        identifier: "reconciliation.strikes"
                    )
                    LabeledContent(
                        "Unclassified",
                        value: signedPitchAdjustment(adjustment.unclassified)
                    )
                        .monospacedDigit()
                        .accessibilityIdentifier("reconciliation.unclassified")
                } header: {
                    Text("Signed adjustments")
                } footer: {
                    Text("Unclassified pitches include HBP or pitches whose result was not recorded.")
                }

                Section("Resulting totals") {
                    if let reconciledCount {
                        pitchCountRow("Adjusted", count: reconciledCount)
                    } else {
                        Label(
                            "The adjustment would produce negative or contradictory totals.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(AppTheme.destructive)
                        .accessibilityIdentifier("reconciliation.invalid")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.paper)
            .navigationTitle("Reconcile Pitch Total")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(adjustment.isEmpty || reconciledCount == nil)
                        .accessibilityIdentifier("reconciliation.save")
                }
            }
            .alert("Reconciliation Failed", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "The pitch-total adjustment could not be saved.")
            }
        }
        .interactiveDismissDisabled()
    }

    private func adjustmentStepper(
        _ title: String,
        value: Binding<Int>,
        identifier: String
    ) -> some View {
        Stepper(value: value) {
            LabeledContent(title, value: signedPitchAdjustment(value.wrappedValue))
                .monospacedDigit()
        }
        .accessibilityIdentifier(identifier)
    }

    private func pitchCountRow(_ title: String, count: PitchCount) -> some View {
        LabeledContent(
            title,
            value: "\(count.total) total · \(count.balls) balls · "
                + "\(count.strikes) strikes · \(count.unclassified) unclassified"
        )
        .monospacedDigit()
    }

    private func save() {
        do {
            try onSave(adjustment, relatedPlayRecordID)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
