import Foundation
import SwiftData

@MainActor
enum PreviewData {
    struct LiveGameFixture {
        let container: ModelContainer
        let game: Game
    }

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

    static var offensiveLiveGame: LiveGameFixture {
        makeLiveGameFixture(homeAway: .away, scenario: .offense)
    }

    static var defensiveLiveGame: LiveGameFixture {
        makeLiveGameFixture(homeAway: .home, scenario: .defense)
    }

    static var gatedLiveGame: LiveGameFixture {
        makeLiveGameFixture(homeAway: .away, scenario: .corruptHistory)
    }

    static var runnerConfirmationBattingOrder: [TrackedBatterIdentity] {
        [
            .init(
                playerID: previewID("00000000-0000-0000-0000-000000000001"),
                lineupSlot: 1,
                displayName: "Maya Jones",
                jerseyNumber: "7",
                position: .shortstop
            ),
            .init(
                playerID: previewID("00000000-0000-0000-0000-000000000002"),
                lineupSlot: 2,
                displayName: "Avery Smith",
                jerseyNumber: "12",
                position: .centerField
            ),
            .init(
                playerID: previewID("00000000-0000-0000-0000-000000000003"),
                lineupSlot: 3,
                displayName: "Riley Davis",
                jerseyNumber: "23",
                position: .catcher
            )
        ]
    }

    static var offensiveRunnerConfirmationState: GameState {
        let order = runnerConfirmationBattingOrder
        return GameState(
            outs: 1,
            balls: 1,
            strikes: 1,
            currentTrackedBatterSlot: 3,
            firstBaseRunnerPlayerID: order[0].playerID,
            secondBaseRunnerPlayerID: order[1].playerID
        )
    }

    static var defensiveRunnerConfirmationState: GameState {
        GameState(
            outs: 1,
            balls: 1,
            strikes: 2,
            currentOpponentBatterSlot: 4,
            firstBaseRunnerSlot: 2,
            thirdBaseRunnerSlot: 3
        )
    }

    private typealias PlayerFixture = (
        firstName: String,
        lastName: String,
        jerseyNumber: String,
        position: DefensivePosition?
    )

    private enum LiveGameScenario {
        case offense
        case defense
        case corruptHistory
    }

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

    private static func previewID(_ rawValue: String) -> UUID {
        guard let id = UUID(uuidString: rawValue) else {
            preconditionFailure("Invalid scorebook preview UUID: \(rawValue)")
        }
        return id
    }

    private static func makeLiveGameFixture(
        homeAway: HomeAway,
        scenario: LiveGameScenario
    ) -> LiveGameFixture {
        let container = makeContainer(playerFixtures: standardPlayers)
        let context = container.mainContext

        do {
            guard let season = try context.fetch(FetchDescriptor<Season>()).first else {
                preconditionFailure("Live game preview requires the seeded season.")
            }
            let roster = players(in: container)
            guard roster.count >= 9 else {
                preconditionFailure("Live game preview requires nine roster players.")
            }

            let game = Game(
                seasonID: season.id,
                opponentName: "Northside Storm",
                gameDate: Date(timeIntervalSince1970: 1_786_562_700),
                homeAway: homeAway,
                status: .inProgress,
                startingPitcherID: roster[4].id,
                startedAt: Date(timeIntervalSince1970: 1_786_562_700)
            )
            context.insert(game)

            let positions = LineupValidation.regulationDefensivePositions
            let battingOrder = Array(roster.prefix(9)).enumerated().map { index, player in
                context.insert(LineupEntry(
                    playerID: player.id,
                    battingOrder: index + 1,
                    startingPosition: positions[index],
                    gameID: game.id
                ))
                return TrackedBatterIdentity(
                    playerID: player.id,
                    lineupSlot: index + 1,
                    displayName: player.displayName,
                    jerseyNumber: player.jerseyNumber,
                    position: positions[index]
                )
            }

            switch scenario {
            case .offense:
                try insertOffensivePreviewEvents(
                    battingOrder: battingOrder,
                    gameID: game.id,
                    context: context
                )
            case .defense:
                try insertDefensivePreviewEvents(
                    pitcherID: roster[4].id,
                    gameID: game.id,
                    context: context
                )
            case .corruptHistory:
                let corruptRecord = try GameEventRecord(
                    gameID: game.id,
                    sequenceNumber: 1,
                    body: .offensivePitch(.init(
                        batter: battingOrder[0],
                        battingOrderSize: battingOrder.count,
                        result: .ball
                    ))
                )
                corruptRecord.payload = Data([0x00])
                context.insert(corruptRecord)
            }

            try context.save()
            return LiveGameFixture(container: container, game: game)
        } catch {
            preconditionFailure("Unable to build live game preview data: \(error)")
        }
    }

    private static func insertOffensivePreviewEvents(
        battingOrder: [TrackedBatterIdentity],
        gameID: UUID,
        context: ModelContext
    ) throws {
        var sequence = 1
        for batter in battingOrder {
            context.insert(try GameEventRecord(
                gameID: gameID,
                sequenceNumber: sequence,
                body: .offensivePlateAppearance(.init(
                    batter: batter,
                    battingOrderSize: battingOrder.count,
                    result: .homeRun,
                    movements: [.init(source: .batter, destination: .home)],
                    rbi: 1,
                    countedRunSources: [.batter],
                    thirdOutClassification: nil
                ))
            ))
            sequence += 1
        }

        context.insert(try GameEventRecord(
            gameID: gameID,
            sequenceNumber: sequence,
            body: .offensivePlateAppearance(.init(
                batter: battingOrder[0],
                battingOrderSize: battingOrder.count,
                result: .single,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            ))
        ))
        sequence += 1

        context.insert(try GameEventRecord(
            gameID: gameID,
            sequenceNumber: sequence,
            body: .offensivePlateAppearance(.init(
                batter: battingOrder[1],
                battingOrderSize: battingOrder.count,
                result: .double,
                movements: [
                    .init(source: .batter, destination: .second),
                    .init(source: .first, destination: .third)
                ],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            ))
        ))
        sequence += 1

        for result in [OffensivePitchResult.ball, .calledStrike] {
            context.insert(try GameEventRecord(
                gameID: gameID,
                sequenceNumber: sequence,
                body: .offensivePitch(.init(
                    batter: battingOrder[2],
                    battingOrderSize: battingOrder.count,
                    result: result
                ))
            ))
            sequence += 1
        }
    }

    private static func insertDefensivePreviewEvents(
        pitcherID: UUID,
        gameID: UUID,
        context: ModelContext
    ) throws {
        let bodies: [GameEventBody] = [
            .pitch(.init(result: .ballInPlay, pitcherID: pitcherID, opponentBatterSlot: 1)),
            .ballInPlay(.init(
                outcome: .groundOut,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .out)],
                rbi: 0,
                thirdOutRunsCounted: nil
            )),
            .pitch(.init(result: .ballInPlay, pitcherID: pitcherID, opponentBatterSlot: 2)),
            .ballInPlay(.init(
                outcome: .single,
                opponentBatterSlot: 2,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                thirdOutRunsCounted: nil
            )),
            .pitch(.init(result: .ball, pitcherID: pitcherID, opponentBatterSlot: 3)),
            .pitch(.init(result: .calledStrike, pitcherID: pitcherID, opponentBatterSlot: 3))
        ]

        for (index, body) in bodies.enumerated() {
            context.insert(try GameEventRecord(
                gameID: gameID,
                sequenceNumber: index + 1,
                body: body
            ))
        }
    }
}
