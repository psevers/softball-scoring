import SwiftData

@MainActor
enum PreviewData {
    static var container: ModelContainer {
        let container = try! AppModelContainer.make(inMemory: true)
        let context = container.mainContext

        let team = Team(name: "Falcons", abbreviation: "FAL")
        let season = Season(name: "2026 Summer", isActive: true)
        context.insert(team)
        context.insert(season)

        let samplePlayers: [(String, String, String, DefensivePosition)] = [
            ("Maya", "Jones", "7", .shortstop),
            ("Avery", "Smith", "12", .centerField),
            ("Riley", "Davis", "23", .catcher),
            ("Jordan", "Miller", "9", .firstBase),
            ("Peyton", "Wilson", "17", .pitcher),
            ("Taylor", "Brown", "3", .secondBase),
            ("Morgan", "Clark", "15", .thirdBase),
            ("Casey", "Lewis", "2", .leftField),
            ("Sydney", "Walker", "21", .rightField),
            ("Quinn", "Hall", "5", .utility)
        ]

        for (index, item) in samplePlayers.enumerated() {
            context.insert(Player(
                firstName: item.0,
                lastName: item.1,
                jerseyNumber: item.2,
                battingSide: index % 3 == 0 ? .left : .right,
                throwingHand: .right,
                defaultPosition: item.3
            ))
        }

        return container
    }
}
