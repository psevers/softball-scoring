import SwiftUI
import SwiftData

struct PlayerEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let player: Player?

    @State private var firstName: String
    @State private var lastName: String
    @State private var jerseyNumber: String
    @State private var battingSide: BattingSide
    @State private var throwingHand: ThrowingHand
    @State private var defaultPosition: DefensivePosition?
    @State private var isActive: Bool

    init(player: Player?) {
        self.player = player
        _firstName = State(initialValue: player?.firstName ?? "")
        _lastName = State(initialValue: player?.lastName ?? "")
        _jerseyNumber = State(initialValue: player?.jerseyNumber ?? "")
        _battingSide = State(initialValue: player?.battingSide ?? .right)
        _throwingHand = State(initialValue: player?.throwingHand ?? .right)
        _defaultPosition = State(initialValue: player?.defaultPosition)
        _isActive = State(initialValue: player?.isActive ?? true)
    }

    private var canSave: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Player") {
                    TextField("First name", text: $firstName)
                        .textContentType(.givenName)
                    TextField("Last name", text: $lastName)
                        .textContentType(.familyName)
                    TextField("Jersey number", text: $jerseyNumber)
                        .keyboardType(.numbersAndPunctuation)
                }

                Section("Defaults") {
                    Picker("Bats", selection: $battingSide) {
                        ForEach(BattingSide.allCases) { side in
                            Text(side.rawValue).tag(side)
                        }
                    }
                    Picker("Throws", selection: $throwingHand) {
                        ForEach(ThrowingHand.allCases) { hand in
                            Text(hand.rawValue).tag(hand)
                        }
                    }
                    Picker("Position", selection: $defaultPosition) {
                        Text("None").tag(DefensivePosition?.none)
                        ForEach(DefensivePosition.allCases) { position in
                            Text(position.rawValue).tag(Optional(position))
                        }
                    }
                }

                if player != nil {
                    Section {
                        Toggle("Active roster", isOn: $isActive)
                    } footer: {
                        Text("Inactive players stay in historical games and can be reactivated later.")
                    }
                }
            }
            .scorebookFormBackground()
            .navigationTitle(player == nil ? "Add Player" : "Edit Player")
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
        let cleanFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNumber = jerseyNumber.trimmingCharacters(in: .whitespacesAndNewlines)

        if let player {
            player.firstName = cleanFirstName
            player.lastName = cleanLastName
            player.jerseyNumber = cleanNumber
            player.battingSide = battingSide
            player.throwingHand = throwingHand
            player.defaultPosition = defaultPosition
            player.isActive = isActive
        } else {
            modelContext.insert(Player(
                firstName: cleanFirstName,
                lastName: cleanLastName,
                jerseyNumber: cleanNumber,
                battingSide: battingSide,
                throwingHand: throwingHand,
                defaultPosition: defaultPosition,
                isActive: true
            ))
        }

        try? modelContext.save()
        dismiss()
    }
}
