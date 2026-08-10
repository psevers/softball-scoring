#if DEBUG
import SwiftData

@MainActor
enum UITestData {
    static func makeContainer() throws -> ModelContainer {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext

        context.insert(Team(name: "UI Test Team", abbreviation: "UIT"))
        context.insert(Season(name: "UI Test Season", isActive: true))

        let positions = LineupValidation.regulationDefensivePositions.map(Optional.some)
            + Array<DefensivePosition?>(repeating: nil, count: 5)

        for index in 1...14 {
            context.insert(Player(
                firstName: "Player",
                lastName: String(format: "%02d", index),
                jerseyNumber: String(index),
                defaultPosition: positions[index - 1]
            ))
        }

        context.insert(Player(
            firstName: "Player",
            lastName: "15",
            jerseyNumber: "15",
            isActive: false
        ))
        try context.save()
        return container
    }
}
#endif
