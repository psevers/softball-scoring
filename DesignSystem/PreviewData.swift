import Foundation
import SwiftData

@MainActor
enum PreviewData {
    static var container: ModelContainer {
        do {
            let container = try AppModelContainer.make(inMemory: true)
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
            try context.save()
            return container
        } catch {
            preconditionFailure("Unable to build scorebook preview data: \(error)")
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
}
