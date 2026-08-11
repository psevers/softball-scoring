import Foundation
import SwiftData

@MainActor
enum PreviewData {
    static var container: ModelContainer {
        makeContainer(playerFixtures: standardPlayers)
    }

    static var longLineupContainer: ModelContainer {
        makeContainer(playerFixtures: standardPlayers + extendedLineupPlayers)
    }

    static func players(in container: ModelContainer) -> [Player] {
        do {
            return try container.mainContext.fetch(FetchDescriptor<Player>(
                sortBy: [SortDescriptor(\Player.createdAt)]
            ))
        } catch {
            preconditionFailure("Unable to load lineup preview players: \(error)")
        }
    }

    static var gamesContainer: ModelContainer {
        let container = container
        let context = container.mainContext
        do {
            guard let season = try context.fetch(FetchDescriptor<Season>()).first else {
                preconditionFailure("Games preview requires the seeded season.")
            }

            context.insert(Game(
                seasonID: season.id,
                opponentName: "Northside Storm",
                gameDate: Date(timeIntervalSince1970: 1_786_562_700),
                homeAway: .home,
                status: .inProgress,
                startedAt: Date(timeIntervalSince1970: 1_786_562_700)
            ))
            context.insert(Game(
                seasonID: season.id,
                opponentName: "Lakeview Lightning",
                gameDate: Date(timeIntervalSince1970: 1_786_210_200),
                homeAway: .away,
                status: .final,
                finalizedAt: Date(timeIntervalSince1970: 1_786_217_400)
            ))
            try context.save()
            return container
        } catch {
            preconditionFailure("Unable to add Games ledger fixtures: \(error)")
        }
    }

    private typealias PlayerFixture = (
        firstName: String,
        lastName: String,
        jerseyNumber: String,
        position: DefensivePosition?
    )

    private static let previewDate = Date(timeIntervalSince1970: 1_785_211_200)

    private static let standardPlayers: [PlayerFixture] = [
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

    private static let extendedLineupPlayers: [PlayerFixture] = [
        ("Jamie", "Reed", "18", nil),
        ("Rowan", "Baker", "24", nil),
        ("Emerson", "Young", "31", nil),
        ("Dakota", "Price", "44", nil)
    ]

    private static func makeContainer(playerFixtures: [PlayerFixture]) -> ModelContainer {
        do {
            let container = try AppModelContainer.make(inMemory: true)
            let context = container.mainContext

            context.insert(Team(
                name: "Falcons",
                abbreviation: "FAL",
                createdAt: previewDate
            ))
            context.insert(Season(
                name: "2026 Summer",
                startDate: previewDate,
                isActive: true,
                createdAt: previewDate
            ))

            for (index, fixture) in playerFixtures.enumerated() {
                context.insert(Player(
                    firstName: fixture.firstName,
                    lastName: fixture.lastName,
                    jerseyNumber: fixture.jerseyNumber,
                    battingSide: index % 3 == 0 ? .left : .right,
                    throwingHand: .right,
                    defaultPosition: fixture.position,
                    createdAt: previewDate.addingTimeInterval(TimeInterval(index))
                ))
            }
            try context.save()
            return container
        } catch {
            preconditionFailure("Unable to build scorebook preview data: \(error)")
        }
    }
}
