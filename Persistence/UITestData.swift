#if DEBUG
import Foundation
import SwiftData

@MainActor
enum UITestData {
    static func makeContainer(storeURL: URL? = nil) throws -> ModelContainer {
        let container = try AppModelContainer.make(
            inMemory: storeURL == nil,
            storeURL: storeURL
        )
        let context = container.mainContext
        if storeURL != nil,
           try !context.fetch(FetchDescriptor<Team>()).isEmpty {
            return container
        }

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
            gameDate: Date(timeIntervalSince1970: 1_786_562_700),
            homeAway: .away,
            status: .inProgress,
            startingPitcherID: activePlayers[0].id,
            startedAt: Date(timeIntervalSince1970: 1_786_562_700)
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

        let defensiveGame = Game(
            seasonID: season.id,
            opponentName: "UI Defense Opponent",
            gameDate: Date(timeIntervalSince1970: 1_786_476_300),
            homeAway: .home,
            status: .inProgress,
            startingPitcherID: activePlayers[0].id,
            startedAt: Date(timeIntervalSince1970: 1_786_476_300)
        )
        context.insert(defensiveGame)
        for (index, player) in activePlayers.enumerated() {
            context.insert(LineupEntry(
                playerID: player.id,
                battingOrder: index + 1,
                startingPosition: positions[index],
                gameID: defensiveGame.id
            ))
        }

        let pitchEditGame = Game(
            seasonID: season.id,
            opponentName: "UI Pitch Edit Opponent",
            gameDate: Date(timeIntervalSince1970: 1_786_433_100),
            homeAway: .home,
            status: .inProgress,
            startingPitcherID: activePlayers[0].id,
            startedAt: Date(timeIntervalSince1970: 1_786_433_100)
        )
        context.insert(pitchEditGame)
        for (index, player) in activePlayers.enumerated() {
            context.insert(LineupEntry(
                playerID: player.id,
                battingOrder: index + 1,
                startingPosition: positions[index],
                gameID: pitchEditGame.id
            ))
        }
        context.insert(try GameEventRecord(
            gameID: pitchEditGame.id,
            sequenceNumber: 1,
            body: .pitch(.init(
                result: .ball,
                pitcherID: activePlayers[0].id,
                opponentBatterSlot: 1
            ))
        ))
        context.insert(try GameEventRecord(
            gameID: pitchEditGame.id,
            sequenceNumber: 2,
            body: .pitch(.init(
                result: .calledStrike,
                pitcherID: activePlayers[0].id,
                opponentBatterSlot: 1
            ))
        ))

        let multiCorrectionGame = Game(
            seasonID: season.id,
            opponentName: "UI Multi Correction Opponent",
            gameDate: Date(timeIntervalSince1970: 1_786_411_500),
            homeAway: .home,
            status: .inProgress,
            startingPitcherID: activePlayers[0].id,
            startedAt: Date(timeIntervalSince1970: 1_786_411_500)
        )
        context.insert(multiCorrectionGame)
        for (index, player) in activePlayers.enumerated() {
            context.insert(LineupEntry(
                playerID: player.id,
                battingOrder: index + 1,
                startingPosition: positions[index],
                gameID: multiCorrectionGame.id
            ))
        }
        for sequence in 1...5 {
            context.insert(try GameEventRecord(
                gameID: multiCorrectionGame.id,
                sequenceNumber: sequence,
                body: .pitch(.init(
                    result: sequence <= 4 ? .ball : .calledStrike,
                    pitcherID: activePlayers[0].id,
                    opponentBatterSlot: sequence <= 4 ? 1 : 2
                ))
            ))
        }

        let historyGame = Game(
            seasonID: season.id,
            opponentName: "UI History Opponent",
            gameDate: Date(timeIntervalSince1970: 1_786_390_000),
            homeAway: .home,
            status: .inProgress,
            startingPitcherID: activePlayers[0].id,
            startedAt: Date(timeIntervalSince1970: 1_786_390_000)
        )
        context.insert(historyGame)
        for (index, player) in activePlayers.enumerated() {
            context.insert(LineupEntry(
                playerID: player.id,
                battingOrder: index + 1,
                startingPosition: positions[index],
                gameID: historyGame.id
            ))
        }
        context.insert(try GameEventRecord(
            gameID: historyGame.id,
            sequenceNumber: 1,
            body: .pitch(.init(
                result: .ballInPlay,
                pitcherID: activePlayers[0].id,
                opponentBatterSlot: 1
            ))
        ))
        context.insert(try GameEventRecord(
            gameID: historyGame.id,
            sequenceNumber: 2,
            body: .ballInPlay(.init(
                outcome: .single,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                thirdOutRunsCounted: nil
            ))
        ))
        context.insert(try GameEventRecord(
            gameID: historyGame.id,
            sequenceNumber: 3,
            body: .pitch(.init(
                result: .ballInPlay,
                pitcherID: activePlayers[0].id,
                opponentBatterSlot: 2
            ))
        ))

        let ballInPlayUndoGame = Game(
            seasonID: season.id,
            opponentName: "UI Ball In Play Undo Opponent",
            gameDate: Date(timeIntervalSince1970: 1_786_346_800),
            homeAway: .home,
            status: .inProgress,
            startingPitcherID: activePlayers[0].id,
            startedAt: Date(timeIntervalSince1970: 1_786_346_800)
        )
        context.insert(ballInPlayUndoGame)
        for (index, player) in activePlayers.enumerated() {
            context.insert(LineupEntry(
                playerID: player.id,
                battingOrder: index + 1,
                startingPosition: positions[index],
                gameID: ballInPlayUndoGame.id
            ))
        }
        context.insert(try GameEventRecord(
            gameID: ballInPlayUndoGame.id,
            sequenceNumber: 1,
            body: .pitch(.init(
                result: .ballInPlay,
                pitcherID: activePlayers[0].id,
                opponentBatterSlot: 1
            ))
        ))
        context.insert(try GameEventRecord(
            gameID: ballInPlayUndoGame.id,
            sequenceNumber: 2,
            body: .ballInPlay(.init(
                outcome: .single,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                thirdOutRunsCounted: nil
            ))
        ))

        let undoGame = Game(
            seasonID: season.id,
            opponentName: "UI Undo Opponent",
            gameDate: Date(timeIntervalSince1970: 1_786_303_600),
            homeAway: .home,
            status: .inProgress,
            startingPitcherID: activePlayers[0].id,
            startedAt: Date(timeIntervalSince1970: 1_786_303_600)
        )
        context.insert(undoGame)
        for (index, player) in activePlayers.enumerated() {
            context.insert(LineupEntry(
                playerID: player.id,
                battingOrder: index + 1,
                startingPosition: positions[index],
                gameID: undoGame.id
            ))
        }
        for sequence in 1...4 {
            context.insert(try GameEventRecord(
                gameID: undoGame.id,
                sequenceNumber: sequence,
                body: .pitch(.init(
                    result: .ball,
                    pitcherID: activePlayers[0].id,
                    opponentBatterSlot: 1
                ))
            ))
        }

        let strikeoutUndoGame = Game(
            seasonID: season.id,
            opponentName: "UI Strikeout Undo Opponent",
            gameDate: Date(timeIntervalSince1970: 1_786_260_400),
            homeAway: .home,
            status: .inProgress,
            startingPitcherID: activePlayers[0].id,
            startedAt: Date(timeIntervalSince1970: 1_786_260_400)
        )
        context.insert(strikeoutUndoGame)
        for (index, player) in activePlayers.enumerated() {
            context.insert(LineupEntry(
                playerID: player.id,
                battingOrder: index + 1,
                startingPosition: positions[index],
                gameID: strikeoutUndoGame.id
            ))
        }
        for sequence in 1...9 {
            context.insert(try GameEventRecord(
                gameID: strikeoutUndoGame.id,
                sequenceNumber: sequence,
                body: .pitch(.init(
                    result: .calledStrike,
                    pitcherID: activePlayers[0].id,
                    opponentBatterSlot: ((sequence - 1) / 3) + 1
                ))
            ))
        }

        let summaryGame = Game(
            seasonID: season.id,
            opponentName: "UI Summary Opponent",
            gameDate: Date(timeIntervalSince1970: 1_786_210_200),
            homeAway: .home,
            status: .final,
            startingPitcherID: activePlayers[0].id,
            startedAt: Date(timeIntervalSince1970: 1_786_210_200),
            finalizedAt: Date(timeIntervalSince1970: 1_786_217_400)
        )
        context.insert(summaryGame)
        for (index, player) in activePlayers.enumerated() {
            context.insert(LineupEntry(
                playerID: player.id,
                battingOrder: index + 1,
                startingPosition: positions[index],
                gameID: summaryGame.id
            ))
        }
        try context.save()
        return container
    }
}
#endif
