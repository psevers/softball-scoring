import SwiftUI
import SwiftData

struct SeasonEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let existingSeasons: [Season]

    @State private var name = ""
    @State private var startDate = Date.now
    @State private var hasEndDate = false
    @State private var endDate = Date.now
    @State private var makeActive = true

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (!hasEndDate || endDate >= startDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, e.g. 2026 Summer", text: $name)
                    DatePicker("Starts", selection: $startDate, displayedComponents: .date)
                    Toggle("Set end date", isOn: $hasEndDate.animation())
                    if hasEndDate {
                        DatePicker("Ends", selection: $endDate, in: startDate..., displayedComponents: .date)
                    }
                } header: {
                    ScorebookLabel("Season")
                }
                .scorebookAdministrativeRow()

                Section {
                    Toggle("Make active season", isOn: $makeActive)
                } footer: {
                    Text("New games will default to the active season. Only one season can be active at a time.")
                }
                .scorebookAdministrativeRow()
            }
            .scorebookFormBackground()
            .navigationTitle("New Season")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        let season = Season(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            isActive: makeActive
        )
        modelContext.insert(season)
        if makeActive {
            SeasonSelection.activate(season, among: existingSeasons + [season])
        }
        try? modelContext.save()
        dismiss()
    }
}

#Preview("Season editor") {
    SeasonEditorView(existingSeasons: [])
        .modelContainer(PreviewData.administrativeSurfaces.container)
}

#Preview("Season editor · Accessibility XL") {
    SeasonEditorView(existingSeasons: [])
        .modelContainer(PreviewData.administrativeSurfaces.container)
        .environment(\.dynamicTypeSize, .accessibility2)
}
