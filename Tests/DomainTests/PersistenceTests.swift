import Foundation
import SwiftData
import Testing
@testable import SoftballScoring

@MainActor
struct PersistenceTests {
    @Test func gameAndLineupPersistInContainer() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let season = Season(name: "Summer", isActive: true)
        let player = Player(firstName: "Peyton", lastName: "Wilson")
        context.insert(season)
        context.insert(player)

        let game = Game(
            seasonID: season.id,
            opponentName: "Thunder",
            status: .inProgress,
            startingPitcherID: player.id
        )
        context.insert(game)
        context.insert(LineupEntry(
            playerID: player.id,
            battingOrder: 1,
            startingPosition: .pitcher,
            gameID: game.id
        ))
        try context.save()

        let games = try context.fetch(FetchDescriptor<Game>())
        let entries = try context.fetch(FetchDescriptor<LineupEntry>())

        #expect(games.count == 1)
        #expect(games.first?.opponentName == "Thunder")
        #expect(entries.count == 1)
        #expect(entries.first?.gameID == game.id)
    }

    @Test func timedGameAndContinuousBattingOrderPersistInContainer() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let playerIDs = (0..<13).map { _ in UUID() }
        let game = Game(
            seasonID: UUID(),
            opponentName: "Lightning",
            timeLimitMinutes: 75,
            status: .inProgress,
            startingPitcherID: playerIDs[0]
        )
        context.insert(game)

        for (index, playerID) in playerIDs.enumerated() {
            context.insert(LineupEntry(
                playerID: playerID,
                battingOrder: index + 1,
                startingPosition: index < 9 ? LineupValidation.regulationDefensivePositions[index] : nil,
                gameID: game.id
            ))
        }
        try context.save()

        let reloadContext = ModelContext(container)
        let storedGame = try #require(reloadContext.fetch(FetchDescriptor<Game>()).first)
        let storedEntries = try reloadContext.fetch(FetchDescriptor<LineupEntry>())
            .filter { $0.gameID == game.id }
            .sorted { $0.battingOrder < $1.battingOrder }
        let expectedPositions: [DefensivePosition?] = LineupValidation.regulationDefensivePositions.map(Optional.some)
            + Array(repeating: nil, count: 4)

        #expect(storedGame.timeLimitMinutes == 75)
        #expect(storedGame.format == .timeLimit)
        #expect(storedGame.startingPitcherID == playerIDs[0])
        #expect(storedEntries.count == 13)
        #expect(storedEntries.map(\.playerID) == playerIDs)
        #expect(storedEntries.map(\.battingOrder) == Array(1...13))
        #expect(storedEntries.map(\.startingPosition) == expectedPositions)
    }

    @Test func inningsBasedFormatPersistsThroughFreshContext() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let game = Game(
            seasonID: UUID(),
            opponentName: "Lightning",
            regulationInnings: 7
        )
        container.mainContext.insert(game)
        try container.mainContext.save()

        let reloadContext = ModelContext(container)
        let storedGame = try #require(reloadContext.fetch(FetchDescriptor<Game>()).first)

        #expect(storedGame.format == .innings)
        #expect(storedGame.regulationInnings == 7)
        #expect(storedGame.timeLimitMinutes == nil)
    }
}

extension PersistenceTests {
    @Test func pitchEventPersistsAndReplaysIntoCount() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let pitcherID = UUID()
        let gameID = UUID()

        let record = try GameEventRecord(
            gameID: gameID,
            sequenceNumber: 1,
            timestamp: Date(timeIntervalSince1970: 1),
            body: .pitch(PitchEvent(result: .ball, pitcherID: pitcherID, opponentBatterSlot: 1))
        )
        context.insert(record)
        try context.save()

        let records = try context.fetch(FetchDescriptor<GameEventRecord>())
        let replay = GameEventReplay.replay(
            records: records,
            homeAway: .home,
            startingPitcherID: pitcherID
        )

        #expect(replay.rejectedRecordIDs.isEmpty)
        #expect(replay.state.balls == 1)
        #expect(replay.state.pitchCount(for: pitcherID).total == 1)
    }

    @Test func replayRejectsDuplicateSequenceNumber() throws {
        let pitcherID = UUID()
        let gameID = UUID()
        let first = try GameEventRecord(
            gameID: gameID,
            sequenceNumber: 1,
            timestamp: Date(timeIntervalSince1970: 1),
            body: .pitch(PitchEvent(result: .ball, pitcherID: pitcherID, opponentBatterSlot: 1))
        )
        let duplicate = try GameEventRecord(
            gameID: gameID,
            sequenceNumber: 1,
            timestamp: Date(timeIntervalSince1970: 2),
            body: .pitch(PitchEvent(result: .calledStrike, pitcherID: pitcherID, opponentBatterSlot: 1))
        )

        let replay = GameEventReplay.replay(
            records: [first, duplicate],
            homeAway: .home,
            startingPitcherID: pitcherID
        )

        #expect(replay.rejectedRecordIDs == [duplicate.id])
        #expect(replay.state.balls == 1)
        #expect(replay.state.strikes == 0)
    }

    @Test func replayRejectsPitchAttributedToWrongPitcher() throws {
        let expectedPitcherID = UUID()
        let wrongPitcherID = UUID()
        let record = try GameEventRecord(
            gameID: UUID(),
            sequenceNumber: 1,
            body: .pitch(PitchEvent(result: .ball, pitcherID: wrongPitcherID, opponentBatterSlot: 1))
        )

        let replay = GameEventReplay.replay(
            records: [record],
            homeAway: .home,
            startingPitcherID: expectedPitcherID
        )

        #expect(replay.rejectedRecordIDs == [record.id])
        #expect(replay.state == GameState())
    }

    @Test func replayRestoresPendingBallInPlayState() throws {
        let pitcherID = UUID()
        let record = try GameEventRecord(
            gameID: UUID(),
            sequenceNumber: 1,
            body: .pitch(PitchEvent(result: .ballInPlay, pitcherID: pitcherID, opponentBatterSlot: 1))
        )

        let replay = GameEventReplay.replay(
            records: [record],
            homeAway: .home,
            startingPitcherID: pitcherID
        )

        #expect(replay.rejectedRecordIDs.isEmpty)
        #expect(replay.state.isAwaitingBallInPlayResult)
        #expect(replay.state.pitchCount(for: pitcherID).total == 1)
    }

    @Test func replayRestoresCompletedBallInPlayState() throws {
        let pitcherID = UUID()
        let gameID = UUID()
        let pitch = try GameEventRecord(
            gameID: gameID,
            sequenceNumber: 1,
            body: .pitch(PitchEvent(result: .ballInPlay, pitcherID: pitcherID, opponentBatterSlot: 1))
        )
        let play = try GameEventRecord(
            gameID: gameID,
            sequenceNumber: 2,
            body: .ballInPlay(BallInPlayEvent(
                outcome: .single,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                thirdOutRunsCounted: nil
            ))
        )

        let replay = GameEventReplay.replay(
            records: [play, pitch],
            homeAway: .home,
            startingPitcherID: pitcherID
        )

        #expect(replay.rejectedRecordIDs.isEmpty)
        #expect(!replay.state.isAwaitingBallInPlayResult)
        #expect(replay.state.firstBaseRunnerSlot == 1)
        #expect(replay.state.currentOpponentBatterSlot == 2)
        #expect(replay.state.pitchCount(for: pitcherID).total == 1)
    }

    @Test func thirdOutTimingRunSurvivesPersistedReplay() throws {
        let pitcherID = UUID()
        let gameID = UUID()
        var sequence = 0
        func record(_ body: GameEventBody) throws -> GameEventRecord {
            sequence += 1
            return try GameEventRecord(gameID: gameID, sequenceNumber: sequence, body: body)
        }
        func pitch(_ result: PitchResult, batter: Int) throws -> GameEventRecord {
            try record(.pitch(PitchEvent(result: result, pitcherID: pitcherID, opponentBatterSlot: batter)))
        }
        func play(
            _ outcome: BallInPlayOutcome,
            batter: Int,
            movements: [RunnerMovementEvent],
            rbi: Int = 0,
            countedRuns: Int? = nil
        ) throws -> GameEventRecord {
            try record(.ballInPlay(BallInPlayEvent(
                outcome: outcome,
                opponentBatterSlot: batter,
                movements: movements,
                rbi: rbi,
                thirdOutRunsCounted: countedRuns,
                thirdOutClassification: countedRuns == nil ? nil : .timingPlay
            )))
        }

        let records = try [
            pitch(.ballInPlay, batter: 1),
            play(.triple, batter: 1, movements: [.init(source: .batter, destination: .third)]),
            pitch(.ballInPlay, batter: 2),
            play(.single, batter: 2, movements: [
                .init(source: .batter, destination: .first),
                .init(source: .third, destination: .third)
            ]),
            pitch(.ballInPlay, batter: 3),
            play(.single, batter: 3, movements: [
                .init(source: .batter, destination: .out),
                .init(source: .first, destination: .second),
                .init(source: .third, destination: .third)
            ]),
            pitch(.calledStrike, batter: 4),
            pitch(.calledStrike, batter: 4),
            pitch(.calledStrike, batter: 4),
            pitch(.ballInPlay, batter: 5),
            play(.single, batter: 5, movements: [
                .init(source: .batter, destination: .first),
                .init(source: .second, destination: .out),
                .init(source: .third, destination: .home)
            ], rbi: 1, countedRuns: 1)
        ]

        let replay = GameEventReplay.replay(
            records: records.reversed(),
            homeAway: .home,
            startingPitcherID: pitcherID
        )

        #expect(replay.rejectedRecordIDs.isEmpty)
        #expect(replay.state.awayScore == 1)
        #expect(replay.state.half == .bottom)
        #expect(replay.state.outs == 0)
        #expect(replay.state.baseRunnerSlots.allSatisfy { $0 == nil })
        #expect(replay.state.currentOpponentBatterSlot == 6)
        #expect(replay.state.pitchCount(for: pitcherID).total == 7)
    }

    @Test func recorderRejectsWrongGameAndMalformedHistory() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let game = makeGame()
        let wrongGameRecord = try GameEventRecord(
            gameID: UUID(),
            sequenceNumber: 1,
            body: .pitch(PitchEvent(result: .ball, pitcherID: game.startingPitcherID!, opponentBatterSlot: 1))
        )

        #expect(throws: GameEventRecorderError.self) {
            try GameEventRecorder.recordPitch(
                result: .ball,
                game: game,
                existingRecords: [wrongGameRecord],
                modelContext: container.mainContext
            )
        }


        let phantom = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .pitch(PitchEvent(result: .ball, pitcherID: game.startingPitcherID!, opponentBatterSlot: 1))
        )
        #expect(throws: GameEventRecorderError.self) {
            try GameEventRecorder.recordPitch(
                result: .calledStrike,
                game: game,
                existingRecords: [phantom],
                modelContext: container.mainContext
            )
        }

        let malformed = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .pitch(PitchEvent(result: .ball, pitcherID: game.startingPitcherID!, opponentBatterSlot: 1))
        )
        malformed.kindRawValue = "unknown"
        container.mainContext.insert(malformed)
        try container.mainContext.save()
        #expect(throws: GameEventRecorderError.self) {
            try GameEventRecorder.recordPitch(
                result: .ball,
                game: game,
                existingRecords: [malformed],
                modelContext: container.mainContext
            )
        }
    }

    @Test func recorderAssignsNextSequenceAndSaves() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let game = makeGame()
        let existing = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 7,
            body: .pitch(PitchEvent(result: .ball, pitcherID: game.startingPitcherID!, opponentBatterSlot: 1))
        )
        container.mainContext.insert(existing)
        try container.mainContext.save()

        try GameEventRecorder.recordPitch(
            result: .calledStrike,
            game: game,
            existingRecords: [existing],
            modelContext: container.mainContext
        )

        let saved = try container.mainContext.fetch(FetchDescriptor<GameEventRecord>())
        #expect(saved.count == 2)
        let appended = saved.first { $0.sequenceNumber == 8 }
        #expect(try appended?.decoded().body == .pitch(PitchEvent(
            result: .calledStrike,
            pitcherID: game.startingPitcherID!,
            opponentBatterSlot: 1
        )))
    }

    @Test func repeatedRecorderCallsUseAuthoritativeStoredSequence() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let game = makeGame()
        let staleSnapshot: [GameEventRecord] = []

        try GameEventRecorder.recordPitch(
            result: .ball,
            game: game,
            existingRecords: staleSnapshot,
            modelContext: container.mainContext
        )
        try GameEventRecorder.recordPitch(
            result: .calledStrike,
            game: game,
            existingRecords: staleSnapshot,
            modelContext: container.mainContext
        )

        let records = try container.mainContext.fetch(FetchDescriptor<GameEventRecord>())
        #expect(records.map(\.sequenceNumber).sorted() == [1, 2])
        let replay = GameEventReplay.replay(
            records: records,
            homeAway: .home,
            startingPitcherID: game.startingPitcherID
        )
        #expect(replay.rejectedRecordIDs.isEmpty)
        #expect(replay.state.balls == 1)
        #expect(replay.state.strikes == 1)
    }

    @Test func recorderRollsBackInsertionWhenSaveFails() throws {
        struct ForcedSaveError: Error {}

        let container = try AppModelContainer.make(inMemory: true)
        let game = makeGame()

        #expect(throws: ForcedSaveError.self) {
            try GameEventRecorder.recordPitch(
                result: .ball,
                game: game,
                existingRecords: [],
                modelContext: container.mainContext,
                save: { _ in throw ForcedSaveError() }
            )
        }

        let records = try container.mainContext.fetch(FetchDescriptor<GameEventRecord>())
        #expect(records.isEmpty)
    }

    @Test func recorderRejectsInvalidDurableHomeAwayValue() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let game = makeGame()
        game.homeAwayRawValue = "sideways"

        #expect(throws: GameEventRecorderError.self) {
            try GameEventRecorder.recordPitch(
                result: .ball,
                game: game,
                existingRecords: [],
                modelContext: container.mainContext
            )
        }

        let records = try container.mainContext.fetch(FetchDescriptor<GameEventRecord>())
        #expect(records.isEmpty)
    }

    private func makeGame() -> Game {
        Game(
            seasonID: UUID(),
            opponentName: "Thunder",
            homeAway: .home,
            status: .inProgress,
            startingPitcherID: UUID()
        )
    }
}
