import SwiftUI

struct UndoLatestPitchButton: View {
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Undo Latest Pitch", systemImage: "arrow.uturn.backward")
                .frame(
                    maxWidth: .infinity,
                    minHeight: AppTheme.TouchTarget.minimum,
                    alignment: .leading
                )
        }
        .buttonStyle(.bordered)
        .tint(AppTheme.destructive)
        .accessibilityHint("Opens a confirmation before removing the latest eligible defensive pitch")
        .accessibilityIdentifier(identifier)
    }
}
