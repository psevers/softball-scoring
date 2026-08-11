#if DEBUG
import SwiftData

@MainActor
enum UITestData {
    static func makeContainer() throws -> ModelContainer {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext

        context.insert(Team(name: "UI Test Team", abbreviation: "UIT"))
        let season = Season(name: "UI Test Season", isActive: true)
        context.insert(season)

        let positions = LineupValidation.regulationDefensivePositions.map(Optional.some)
            + Array<DefensivePosition?>(repeating: nil, count: 5)

        let activePlayers = (1...14).map { index in
            Player(
                firstName: "Player",
                lastName: String(format: "%02d", index),
                jerseyNumber: String(index),
                defaultPosition: positions[index - 1]
            )
        }
        for player in activePlayers {
            context.insert(player)
        }

        context.insert(Player(
            firstName: "Player",
            lastName: "15",
            jerseyNumber: "15",
            isActive: false
        ))

        let liveGame = Game(
            seasonID: season.id,
            opponentName: "UI Opponent",
            homeAway: .away,
            status: .inProgress,
            startingPitcherID: activePlayers[0].id
        )
        context.insert(liveGame)
        for (index, player) in activePlayers.enumerated() {
            context.insert(LineupEntry(
                playerID: player.id,
                battingOrder: index + 1,
                startingPosition: positions[index],
                gameID: liveGame.id
            ))
        }
        try context.save()
        return container
    }
}
#endif
