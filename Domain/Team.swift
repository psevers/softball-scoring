import Foundation
import SwiftData

@Model
final class Team {
    @Attribute(.unique) var id: UUID
    var name: String
    var abbreviation: String
    var createdAt: Date

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "My Team" : trimmed
    }

    init(
        id: UUID = UUID(),
        name: String,
        abbreviation: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.abbreviation = abbreviation
        self.createdAt = createdAt
    }
}
