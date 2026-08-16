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

        let lockedHistoryGame = Game(
            seasonID: season.id,
            opponentName: "UI Locked History Opponent",
            gameDate: Date(timeIntervalSince1970: 1_786_368_400),
            homeAway: .home,
            status: .inProgress,
            startingPitcherID: activePlayers[0].id,
            startedAt: Date(timeIntervalSince1970: 1_786_368_400)
        )
        context.insert(lockedHistoryGame)
        for (index, player) in activePlayers.enumerated() {
            context.insert(LineupEntry(
                playerID: player.id,
                battingOrder: index + 1,
                startingPosition: positions[index],
                gameID: lockedHistoryGame.id
            ))
        }
        context.insert(try GameEventRecord(
            gameID: lockedHistoryGame.id,
            sequenceNumber: 1,
            timestamp: Date(timeIntervalSince1970: 1_786_368_500),
            body: .pitch(.init(
                result: .ball,
                pitcherID: activePlayers[0].id,
                opponentBatterSlot: 1
            ))
        ))
        let unknownRecord = try GameEventRecord(
            gameID: lockedHistoryGame.id,
            sequenceNumber: 2,
            timestamp: Date(timeIntervalSince1970: 1_786_368_600),
            body: .pitch(.init(
                result: .foul,
                pitcherID: activePlayers[0].id,
                opponentBatterSlot: 1
            ))
        )
        unknownRecord.kindRawValue = "future-event"
        context.insert(unknownRecord)

        let chainedRepairGame = Game(
            seasonID: season.id,
            opponentName: "UI Chained Repair Opponent",
            gameDate: Date(timeIntervalSince1970: 1_786_369_000),
            homeAway: .home,
            status: .inProgress,
            startingPitcherID: activePlayers[0].id,
            startedAt: Date(timeIntervalSince1970: 1_786_369_000)
        )
        context.insert(chainedRepairGame)
        for (index, player) in activePlayers.enumerated() {
            context.insert(LineupEntry(
                playerID: player.id,
                battingOrder: index + 1,
                startingPosition: positions[index],
                gameID: chainedRepairGame.id
            ))
        }
        let chainedRecords = try [
            GameEventRecord(
                gameID: chainedRepairGame.id,
                sequenceNumber: 1,
                timestamp: Date(timeIntervalSince1970: 1_786_369_100),
                body: .pitch(.init(
                    result: .ball,
                    pitcherID: activePlayers[0].id,
                    opponentBatterSlot: 1
                ))
            ),
            GameEventRecord(
                gameID: chainedRepairGame.id,
                sequenceNumber: 2,
                timestamp: Date(timeIntervalSince1970: 1_786_369_200),
                body: .pitch(.init(
                    result: .foul,
                    pitcherID: activePlayers[0].id,
                    opponentBatterSlot: 1
                ))
            ),
            GameEventRecord(
                gameID: chainedRepairGame.id,
                sequenceNumber: 3,
                timestamp: Date(timeIntervalSince1970: 1_786_369_300),
                body: .pitch(.init(
                    result: .ball,
                    pitcherID: activePlayers[0].id,
                    opponentBatterSlot: 1
                ))
            ),
            GameEventRecord(
                gameID: chainedRepairGame.id,
                sequenceNumber: 4,
                timestamp: Date(timeIntervalSince1970: 1_786_369_400),
                body: .pitch(.init(
                    result: .ball,
                    pitcherID: activePlayers[0].id,
                    opponentBatterSlot: 1
                ))
            ),
            GameEventRecord(
                gameID: chainedRepairGame.id,
                sequenceNumber: 5,
                timestamp: Date(timeIntervalSince1970: 1_786_369_500),
                body: .pitch(.init(
                    result: .ball,
                    pitcherID: activePlayers[0].id,
                    opponentBatterSlot: 1
                ))
            ),
            GameEventRecord(
                gameID: chainedRepairGame.id,
                sequenceNumber: 6,
                timestamp: Date(timeIntervalSince1970: 1_786_369_600),
                body: .pitch(.init(
                    result: .calledStrike,
                    pitcherID: activePlayers[0].id,
                    opponentBatterSlot: 1
                ))
            ),
            GameEventRecord(
                gameID: chainedRepairGame.id,
                sequenceNumber: 7,
                timestamp: Date(timeIntervalSince1970: 1_786_369_700),
                body: .pitch(.init(
                    result: .foul,
                    pitcherID: activePlayers[0].id,
                    opponentBatterSlot: 2
                ))
            ),
            GameEventRecord(
                gameID: chainedRepairGame.id,
                sequenceNumber: 10,
                timestamp: Date(timeIntervalSince1970: 1_786_370_000),
                body: .pitch(.init(
                    result: .calledStrike,
                    pitcherID: activePlayers[0].id,
                    opponentBatterSlot: 2
                ))
            )
        ]
        chainedRecords[1].kindRawValue = "future-event"
        chainedRecords[6].payload = Data("not-json".utf8)
        chainedRecords.forEach(context.insert)

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

        let runCorrectionGame = Game(
            seasonID: season.id,
            opponentName: "UI Run Correction Opponent",
            gameDate: Date(timeIntervalSince1970: 1_786_822_800),
            homeAway: .home,
            status: .inProgress,
            startingPitcherID: activePlayers[0].id,
            startedAt: Date(timeIntervalSince1970: 1_786_822_800)
        )
        context.insert(runCorrectionGame)
        for (index, player) in activePlayers.enumerated() {
            context.insert(LineupEntry(
                playerID: player.id,
                battingOrder: index + 1,
                startingPosition: positions[index],
                gameID: runCorrectionGame.id
            ))
        }
        let runCorrectionBodies: [GameEventBody] = [
            .pitch(.init(
                result: .ballInPlay,
                pitcherID: activePlayers[0].id,
                opponentBatterSlot: 1
            )),
            .ballInPlay(.init(
                outcome: .single,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                thirdOutRunsCounted: nil
            )),
            .pitch(.init(
                result: .ballInPlay,
                pitcherID: activePlayers[0].id,
                opponentBatterSlot: 2
            )),
            .ballInPlay(.init(
                outcome: .reachedOnError,
                opponentBatterSlot: 2,
                movements: [
                    .init(source: .batter, destination: .first),
                    .init(source: .first, destination: .second)
                ],
                rbi: 0,
                thirdOutRunsCounted: nil
            ))
        ]
        for (index, body) in runCorrectionBodies.enumerated() {
            context.insert(try GameEventRecord(
                gameID: runCorrectionGame.id,
                sequenceNumber: index + 1,
                body: body
            ))
        }

        let thirdOutCorrectionGame = Game(
            seasonID: season.id,
            opponentName: "UI Third Out Correction Opponent",
            gameDate: Date(timeIntervalSince1970: 1_786_823_100),
            homeAway: .home,
            status: .inProgress,
            startingPitcherID: activePlayers[0].id,
            startedAt: Date(timeIntervalSince1970: 1_786_823_100)
        )
        context.insert(thirdOutCorrectionGame)
        for (index, player) in activePlayers.enumerated() {
            context.insert(LineupEntry(
                playerID: player.id,
                battingOrder: index + 1,
                startingPosition: positions[index],
                gameID: thirdOutCorrectionGame.id
            ))
        }
        let thirdOutCorrectionBodies: [GameEventBody] = [
            .pitch(.init(
                result: .ballInPlay,
                pitcherID: activePlayers[0].id,
                opponentBatterSlot: 1
            )),
            .ballInPlay(.init(
                outcome: .triple,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .third)],
                rbi: 0,
                thirdOutRunsCounted: nil
            )),
            .pitch(.init(
                result: .ballInPlay,
                pitcherID: activePlayers[0].id,
                opponentBatterSlot: 2
            )),
            .ballInPlay(.init(
                outcome: .single,
                opponentBatterSlot: 2,
                movements: [
                    .init(source: .batter, destination: .first),
                    .init(source: .third, destination: .third)
                ],
                rbi: 0,
                thirdOutRunsCounted: nil
            )),
            .pitch(.init(
                result: .ballInPlay,
                pitcherID: activePlayers[0].id,
                opponentBatterSlot: 3
            )),
            .ballInPlay(.init(
                outcome: .flyOut,
                opponentBatterSlot: 3,
                movements: [
                    .init(source: .batter, destination: .out),
                    .init(source: .first, destination: .first),
                    .init(source: .third, destination: .third)
                ],
                rbi: 0,
                thirdOutRunsCounted: nil
            )),
            .pitch(.init(
                result: .ballInPlay,
                pitcherID: activePlayers[0].id,
                opponentBatterSlot: 4
            )),
            .ballInPlay(.init(
                outcome: .doublePlay,
                opponentBatterSlot: 4,
                movements: [
                    .init(source: .batter, destination: .out),
                    .init(source: .first, destination: .out),
                    .init(source: .third, destination: .home)
                ],
                rbi: 0,
                thirdOutRunsCounted: 0,
                thirdOutClassification: .forceOrBatterRunner
            ))
        ]
        for (index, body) in thirdOutCorrectionBodies.enumerated() {
            context.insert(try GameEventRecord(
                gameID: thirdOutCorrectionGame.id,
                sequenceNumber: index + 1,
                body: body
            ))
        }

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
