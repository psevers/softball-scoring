import SwiftUI
import SwiftData

struct TeamEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let team: Team?

    @State private var name: String
    @State private var abbreviation: String

    init(team: Team?) {
        self.team = team
        _name = State(initialValue: team?.name ?? "")
        _abbreviation = State(initialValue: team?.abbreviation ?? "")
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Team") {
                    TextField("Team name", text: $name)
                    TextField("Abbreviation", text: $abbreviation)
                        .textInputAutocapitalization(.characters)
                }
            }
            .scorebookFormBackground()
            .navigationTitle(team == nil ? "Set Up Team" : "Edit Team")
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
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAbbreviation = abbreviation.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if let team {
            team.name = cleanName
            team.abbreviation = cleanAbbreviation
        } else {
            modelContext.insert(Team(name: cleanName, abbreviation: cleanAbbreviation))
        }
        try? modelContext.save()
        dismiss()
    }
}
