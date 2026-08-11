import Foundation
import SwiftData

@Model
final class Season {
    @Attribute(.unique) var id: UUID
    var name: String
    var startDate: Date
    var endDate: Date?
    var isActive: Bool
    var createdAt: Date

    var dateRangeDescription: String {
        let calendar = Calendar.current
        let startYear = calendar.component(.year, from: startDate)
        guard let endDate else { return String(startYear) }
        let endYear = calendar.component(.year, from: endDate)
        return startYear == endYear ? String(startYear) : "\(startYear)–\(endYear)"
    }

    init(
        id: UUID = UUID(),
        name: String,
        startDate: Date = .now,
        endDate: Date? = nil,
        isActive: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.isActive = isActive
        self.createdAt = createdAt
    }
}

enum SeasonSelection {
    static func activate(_ selected: Season, among seasons: [Season]) {
        for season in seasons {
            season.isActive = season.id == selected.id
        }
    }
}
