import SwiftUI

struct UndoLatestActionButton: View {
    let title: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "arrow.uturn.backward")
                .frame(
                    maxWidth: .infinity,
                    minHeight: AppTheme.TouchTarget.minimum,
                    alignment: .leading
                )
        }
        .buttonStyle(.bordered)
        .tint(AppTheme.destructive)
        .accessibilityHint("Opens a confirmation before removing the latest eligible defensive action")
        .accessibilityIdentifier(identifier)
    }
}
