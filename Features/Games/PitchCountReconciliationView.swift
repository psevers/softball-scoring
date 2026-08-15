import SwiftUI

struct PitchCountReconciliationView: View {
    let session: PitchCountReconciliationSession
    let pitcherName: String
    let onSave: (Int, Int, Int) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var totalAdjustment = 0
    @State private var ballAdjustment = 0
    @State private var strikeAdjustment = 0
    @State private var errorMessage: String?

    private var reconciledCount: PitchCount? {
        session.reconciledCount(
            totalAdjustment: totalAdjustment,
            ballAdjustment: ballAdjustment,
            strikeAdjustment: strikeAdjustment
        )
    }

    private var unclassifiedAdjustment: Int {
        totalAdjustment - ballAdjustment - strikeAdjustment
    }

    private var hasAdjustment: Bool {
        totalAdjustment != 0 || ballAdjustment != 0 || strikeAdjustment != 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Pitcher") {
                    LabeledContent("Player", value: pitcherName)
                    pitchCountRow("Current", count: session.currentCount)
                }

                Section {
                    adjustmentStepper(
                        "Total pitches",
                        value: $totalAdjustment,
                        identifier: "reconciliation.total"
                    )
                    adjustmentStepper(
                        "Balls",
                        value: $ballAdjustment,
                        identifier: "reconciliation.balls"
                    )
                    adjustmentStepper(
                        "Strikes",
                        value: $strikeAdjustment,
                        identifier: "reconciliation.strikes"
                    )
                    LabeledContent("Unclassified", value: signed(unclassifiedAdjustment))
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
                        .disabled(!hasAdjustment || reconciledCount == nil)
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
            LabeledContent(title, value: signed(value.wrappedValue))
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
            try onSave(totalAdjustment, ballAdjustment, strikeAdjustment)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func signed(_ value: Int) -> String {
        value >= 0 ? "+\(value)" : "\(value)"
    }
}
