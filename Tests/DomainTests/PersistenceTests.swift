import Foundation
import SwiftData
import Testing
@testable import SoftballScoring

@MainActor
struct PersistenceTests {
    @Test func thirteenPlayerOffensiveOrderReplaysToSameNextBatter() throws {
        let gameID = UUID()
        let lineup = (1...13).map { slot in
            TrackedBatterIdentity(
                playerID: UUID(),
                lineupSlot: slot,
                displayName: "Batter \(slot)",
                jerseyNumber: "\(slot)",
                position: nil
            )
        }
        let records = try lineup.enumerated().map { index, batter in
            try GameEventRecord(
                gameID: gameID,
                sequenceNumber: index + 1,
                body: .offensivePlateAppearance(OffensivePlateAppearanceEvent(
                    batter: batter,
                    battingOrderSize: lineup.count,
                    result: .homeRun,
                    movements: [.init(source: .batter, destination: .home)],
                    rbi: 1,
                    countedRunSources: [.batter],
                    thirdOutClassification: nil
                ))
            )
        }

        let replay = GameEventReplay.replay(
            records: records,
            homeAway: .away,
            startingPitcherID: nil
        )

        #expect(replay.rejectedRecordIDs.isEmpty)
        #expect(replay.state.currentTrackedBatterSlot == 1)
        #expect(replay.state.awayScore == 13)
    }

    @Test func historicalOffensiveEventReplaysWithoutCurrentLineupContext() throws {
        let firstPlayerID = UUID()
        let historicalBatter = TrackedBatterIdentity(
            playerID: firstPlayerID,
            lineupSlot: 1,
            displayName: "Batter One",
            jerseyNumber: "1",
            position: .pitcher
        )
        let record = try GameEventRecord(
            gameID: UUID(),
            sequenceNumber: 1,
            body: .offensivePlateAppearance(OffensivePlateAppearanceEvent(
                batter: historicalBatter,
                battingOrderSize: 2,
                result: .walk,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            ))
        )
        let replay = GameEventReplay.replay(
            records: [record],
            homeAway: .away,
            startingPitcherID: firstPlayerID
        )

        #expect(replay.rejectedRecordIDs.isEmpty)
        #expect(replay.state.currentTrackedBatterSlot == 2)
        #expect(replay.state.firstBaseRunnerPlayerID == firstPlayerID)
    }

    @Test func replayRejectsPlateAppearanceForDifferentBatterAfterPitchSequenceStarts() throws {
        let firstBatter = TrackedBatterIdentity(
            playerID: UUID(),
            lineupSlot: 1,
            displayName: "Original Batter",
            jerseyNumber: "1",
            position: nil
        )
        let replacementIdentity = TrackedBatterIdentity(
            playerID: UUID(),
            lineupSlot: 1,
            displayName: "Different Batter",
            jerseyNumber: "99",
            position: nil
        )
        let gameID = UUID()
        let pitch = try GameEventRecord(
            gameID: gameID,
            sequenceNumber: 1,
            body: .offensivePitch(OffensivePitchEvent(
                batter: firstBatter,
                battingOrderSize: 2,
                result: .calledStrike
            ))
        )
        let plateAppearance = try GameEventRecord(
            gameID: gameID,
            sequenceNumber: 2,
            body: .offensivePlateAppearance(OffensivePlateAppearanceEvent(
                batter: replacementIdentity,
                battingOrderSize: 2,
                result: .strikeout,
                movements: [.init(source: .batter, destination: .out)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            ))
        )

        let replay = GameEventReplay.replay(
            records: [pitch, plateAppearance],
            homeAway: .away,
            startingPitcherID: nil
        )

        #expect(replay.rejectedRecordIDs == [plateAppearance.id])
        #expect(replay.state.strikes == 1)
        #expect(replay.state.currentTrackedBatterSlot == 1)
    }

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
        let playerIDs = (0..<14).map { _ in UUID() }
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
            + Array(repeating: nil, count: 5)

        #expect(storedGame.timeLimitMinutes == 75)
        #expect(storedGame.format == .timeLimit)
        #expect(storedGame.startingPitcherID == playerIDs[0])
        #expect(storedEntries.count == 14)
        #expect(storedEntries.map(\.playerID) == playerIDs)
        #expect(storedEntries.map(\.battingOrder) == Array(1...14))
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

    @Test func coldStoreReloadRestoresOffensiveBatterCountBasesScoreAndProjection() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appending(path: "softball-scoring-cold-reload-\(UUID().uuidString).store")
        let gameID = UUID()
        let first = TrackedBatterIdentity(
            playerID: UUID(),
            lineupSlot: 1,
            displayName: "Batter One",
            jerseyNumber: "1",
            position: nil
        )
        let second = TrackedBatterIdentity(
            playerID: UUID(),
            lineupSlot: 2,
            displayName: "Batter Two",
            jerseyNumber: "2",
            position: nil
        )

        do {
            let writeContainer = try AppModelContainer.make(storeURL: storeURL)
            let context = writeContainer.mainContext
            context.insert(try GameEventRecord(
                gameID: gameID,
                sequenceNumber: 1,
                body: .offensivePlateAppearance(OffensivePlateAppearanceEvent(
                    batter: first,
                    battingOrderSize: 2,
                    result: .homeRun,
                    movements: [.init(source: .batter, destination: .home)],
                    rbi: 1,
                    countedRunSources: [.batter],
                    thirdOutClassification: nil
                ))
            ))
            context.insert(try GameEventRecord(
                gameID: gameID,
                sequenceNumber: 2,
                body: .offensivePlateAppearance(OffensivePlateAppearanceEvent(
                    batter: second,
                    battingOrderSize: 2,
                    result: .walk,
                    movements: [.init(source: .batter, destination: .first)],
                    rbi: 0,
                    countedRunSources: [],
                    thirdOutClassification: nil
                ))
            ))
            context.insert(try GameEventRecord(
                gameID: gameID,
                sequenceNumber: 3,
                body: .offensivePitch(OffensivePitchEvent(
                    batter: first,
                    battingOrderSize: 2,
                    result: .ball
                ))
            ))
            try context.save()
        }

        let readContainer = try AppModelContainer.make(storeURL: storeURL)
        let records = try readContainer.mainContext.fetch(FetchDescriptor<GameEventRecord>())
            .filter { $0.gameID == gameID }
        let replay = GameEventReplay.replay(
            records: records,
            homeAway: .away,
            startingPitcherID: nil
        )
        let projection = BattingStatProjector.project(events: try records.map { try $0.decoded() })

        #expect(replay.rejectedRecordIDs.isEmpty)
        #expect(replay.state.currentTrackedBatterSlot == 1)
        #expect(replay.state.balls == 1)
        #expect(replay.state.firstBaseRunnerPlayerID == second.playerID)
        #expect(replay.state.awayScore == 1)
        #expect(projection[first.playerID]?.homeRuns == 1)
        #expect(projection[first.playerID]?.runs == 1)
        #expect(projection[second.playerID]?.walks == 1)
    }
}

extension PersistenceTests {
    @Test func offensiveRecorderPersistsCurrentTrackedBatterAndReplaysFromStore() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let players = (1...13).map { slot in
            Player(
                firstName: "Batter",
                lastName: "\(slot)",
                jerseyNumber: "\(slot)"
            )
        }
        let game = Game(
            seasonID: UUID(),
            opponentName: "Thunder",
            homeAway: .away,
            status: .inProgress,
            startingPitcherID: players[0].id
        )
        context.insert(game)
        for (index, player) in players.enumerated() {
            context.insert(player)
            context.insert(LineupEntry(
                playerID: player.id,
                battingOrder: index + 1,
                startingPosition: index < 9 ? LineupValidation.regulationDefensivePositions[index] : nil,
                gameID: game.id
            ))
        }
        try context.save()

        try GameEventRecorder.recordOffensivePlateAppearance(
            expectedBatter: TrackedBatterIdentity(
                playerID: players[0].id,
                lineupSlot: 1,
                displayName: "Batter 1",
                jerseyNumber: "1",
                position: .pitcher
            ),
            result: .walk,
            movements: [.init(source: .batter, destination: .first)],
            rbi: 0,
            countedRunSources: [],
            game: game,
            existingRecords: [],
            modelContext: context
        )

        let records = try context.fetch(FetchDescriptor<GameEventRecord>())
        let lineupEntries = try context.fetch(FetchDescriptor<LineupEntry>())
        let storedPlayers = try context.fetch(FetchDescriptor<Player>())
        let battingOrder = try #require(TrackedBattingOrder.resolve(
            gameID: game.id,
            lineupEntries: lineupEntries,
            players: storedPlayers
        ))
        let storedRecord = try #require(records.first)
        let storedEvent = try storedRecord.decoded()
        guard case .offensivePlateAppearance(let plateAppearance) = storedEvent.body else {
            Issue.record("Expected an offensive plate appearance")
            return
        }
        let replay = GameEventReplay.replay(
            records: records,
            homeAway: .away,
            startingPitcherID: game.startingPitcherID
        )

        #expect(battingOrder.count == 13)
        #expect(plateAppearance.batter.playerID == players[0].id)
        #expect(plateAppearance.batter.lineupSlot == 1)
        #expect(plateAppearance.batter.displayName == "Batter 1")
        #expect(replay.rejectedRecordIDs.isEmpty)
        #expect(replay.state.currentTrackedBatterSlot == 2)
        #expect(replay.state.firstBaseRunnerPlayerID == players[0].id)
    }

    @Test func defensivePitchCanBeRecordedAfterOffensivePlateAppearances() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let player = Player(firstName: "Pitcher", lastName: "One", jerseyNumber: "1")
        let game = Game(
            seasonID: UUID(),
            opponentName: "Thunder",
            homeAway: .away,
            status: .inProgress,
            startingPitcherID: player.id
        )
        context.insert(game)
        context.insert(player)
        context.insert(LineupEntry(
            playerID: player.id,
            battingOrder: 1,
            startingPosition: .pitcher,
            gameID: game.id
        ))
        try context.save()

        for _ in 0..<3 {
            try GameEventRecorder.recordOffensivePlateAppearance(
                expectedBatter: TrackedBatterIdentity(
                    playerID: player.id,
                    lineupSlot: 1,
                    displayName: "Pitcher One",
                    jerseyNumber: "1",
                    position: .pitcher
                ),
                result: .strikeout,
                movements: [.init(source: .batter, destination: .out)],
                rbi: 0,
                countedRunSources: [],
                game: game,
                existingRecords: [],
                modelContext: context
            )
        }

        try GameEventRecorder.recordPitch(
            result: .ball,
            game: game,
            existingRecords: [],
            modelContext: context
        )

        let records = try context.fetch(FetchDescriptor<GameEventRecord>())
        let replay = GameEventReplay.replay(
            records: records,
            homeAway: .away,
            startingPitcherID: player.id
        )

        #expect(replay.rejectedRecordIDs.isEmpty)
        #expect(replay.state.half == .bottom)
        #expect(replay.state.balls == 1)
    }

    @Test func recorderRejectsStaleDisplayedBatterBeforeApplyingNextPlateAppearance() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let players = [
            Player(firstName: "Batter", lastName: "One", jerseyNumber: "1"),
            Player(firstName: "Batter", lastName: "Two", jerseyNumber: "2")
        ]
        let game = Game(
            seasonID: UUID(),
            opponentName: "Thunder",
            homeAway: .away,
            status: .inProgress,
            startingPitcherID: players[0].id
        )
        context.insert(game)
        for (index, player) in players.enumerated() {
            context.insert(player)
            context.insert(LineupEntry(
                playerID: player.id,
                battingOrder: index + 1,
                startingPosition: index == 0 ? .pitcher : nil,
                gameID: game.id
            ))
        }
        try context.save()

        let displayedBatter = TrackedBatterIdentity(
            playerID: players[0].id,
            lineupSlot: 1,
            displayName: "Batter One",
            jerseyNumber: "1",
            position: .pitcher
        )
        try GameEventRecorder.recordOffensivePlateAppearance(
            expectedBatter: displayedBatter,
            result: .homeRun,
            movements: [.init(source: .batter, destination: .home)],
            rbi: 1,
            countedRunSources: [.batter],
            game: game,
            existingRecords: [],
            modelContext: context
        )

        do {
            try GameEventRecorder.recordOffensivePlateAppearance(
                expectedBatter: displayedBatter,
                result: .homeRun,
                movements: [.init(source: .batter, destination: .home)],
                rbi: 1,
                countedRunSources: [.batter],
                game: game,
                existingRecords: [],
                modelContext: context
            )
            Issue.record("Expected a stale displayed batter to be rejected")
        } catch GameEventRecorderError.batterMismatch {
            // Expected: the first write advanced the authoritative batting order.
        } catch {
            Issue.record("Expected batterMismatch, got \(error)")
        }

        let records = try context.fetch(FetchDescriptor<GameEventRecord>())
        #expect(records.count == 1)
    }

    @Test func normalOffensivePitchFlowCompletesPlayerAttributedWalkAndStrikeout() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let players = [
            Player(firstName: "Batter", lastName: "One", jerseyNumber: "1"),
            Player(firstName: "Batter", lastName: "Two", jerseyNumber: "2")
        ]
        let game = Game(
            seasonID: UUID(),
            opponentName: "Thunder",
            homeAway: .away,
            status: .inProgress,
            startingPitcherID: players[0].id
        )
        context.insert(game)
        for (index, player) in players.enumerated() {
            context.insert(player)
            context.insert(LineupEntry(
                playerID: player.id,
                battingOrder: index + 1,
                startingPosition: index == 0 ? .pitcher : nil,
                gameID: game.id
            ))
        }
        try context.save()

        let displayedBatter = TrackedBatterIdentity(
            playerID: players[0].id,
            lineupSlot: 1,
            displayName: "Batter One",
            jerseyNumber: "1",
            position: .pitcher
        )
        for _ in 0..<4 {
            try GameEventRecorder.recordOffensivePitch(
                expectedBatter: displayedBatter,
                result: .ball,
                game: game,
                existingRecords: [],
                modelContext: context
            )
        }

        let records = try context.fetch(FetchDescriptor<GameEventRecord>())
        let replay = GameEventReplay.replay(
            records: records,
            homeAway: .away,
            startingPitcherID: players[0].id
        )
        let decoded = try records.map { try $0.decoded() }
        let battingLine = BattingStatProjector.project(events: decoded)[players[0].id]

        #expect(records.count == 4)
        #expect(replay.rejectedRecordIDs.isEmpty)
        #expect(replay.state.currentTrackedBatterSlot == 2)
        #expect(replay.state.firstBaseRunnerPlayerID == players[0].id)
        #expect(replay.state.balls == 0)
        #expect(battingLine?.plateAppearances == 1)
        #expect(battingLine?.walks == 1)

        let secondDisplayedBatter = TrackedBatterIdentity(
            playerID: players[1].id,
            lineupSlot: 2,
            displayName: "Batter Two",
            jerseyNumber: "2",
            position: nil
        )
        for result in [
            OffensivePitchResult.calledStrike,
            .foul,
            .foul,
            .swingingStrike
        ] {
            try GameEventRecorder.recordOffensivePitch(
                expectedBatter: secondDisplayedBatter,
                result: result,
                game: game,
                existingRecords: [],
                modelContext: context
            )
        }

        let completedRecords = try context.fetch(FetchDescriptor<GameEventRecord>())
        let completedReplay = GameEventReplay.replay(
            records: completedRecords,
            homeAway: .away,
            startingPitcherID: players[0].id
        )
        let completedProjection = BattingStatProjector.project(
            events: try completedRecords.map { try $0.decoded() }
        )

        #expect(completedRecords.count == 8)
        #expect(completedReplay.rejectedRecordIDs.isEmpty)
        #expect(completedReplay.state.currentTrackedBatterSlot == 1)
        #expect(completedReplay.state.outs == 1)
        #expect(completedReplay.state.strikes == 0)
        #expect(completedProjection[players[1].id]?.plateAppearances == 1)
        #expect(completedProjection[players[1].id]?.strikeouts == 1)

        try GameEventRecorder.recordOffensiveBaseRunning(
            expectedRunnerID: players[0].id,
            source: .first,
            result: .stolenBase,
            game: game,
            existingRecords: [],
            modelContext: context
        )
        try GameEventRecorder.recordOffensiveBaseRunning(
            expectedRunnerID: players[0].id,
            source: .second,
            result: .caughtStealing,
            game: game,
            existingRecords: [],
            modelContext: context
        )

        let baseRunningRecords = try context.fetch(FetchDescriptor<GameEventRecord>())
        let baseRunningReplay = GameEventReplay.replay(
            records: baseRunningRecords,
            homeAway: .away,
            startingPitcherID: players[0].id
        )
        let baseRunningProjection = BattingStatProjector.project(
            events: try baseRunningRecords.map { try $0.decoded() }
        )

        #expect(baseRunningRecords.count == 10)
        #expect(baseRunningReplay.rejectedRecordIDs.isEmpty)
        #expect(baseRunningReplay.state.trackedBaseRunnerPlayerIDs.allSatisfy { $0 == nil })
        #expect(baseRunningReplay.state.outs == 2)
        #expect(baseRunningProjection[players[0].id]?.stolenBases == 1)
        #expect(baseRunningProjection[players[0].id]?.caughtStealing == 1)
    }

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

    @Test func liveGameSnapshotLoadsOneGameFromFreshAuthoritativeRecords() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let otherGame = makeGame()
        context.insert(game)
        context.insert(otherGame)

        let strike = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 2,
            body: .pitch(.init(
                result: .calledStrike,
                pitcherID: game.startingPitcherID!,
                opponentBatterSlot: 1
            ))
        )
        let ball = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .pitch(.init(
                result: .ball,
                pitcherID: game.startingPitcherID!,
                opponentBatterSlot: 1
            ))
        )
        let unrelated = try GameEventRecord(
            gameID: otherGame.id,
            sequenceNumber: 1,
            body: .pitch(.init(
                result: .ball,
                pitcherID: otherGame.startingPitcherID!,
                opponentBatterSlot: 1
            ))
        )
        context.insert(strike)
        context.insert(unrelated)
        context.insert(ball)
        try context.save()

        let snapshot = try LiveGameSnapshotLoader.load(game: game, modelContext: context)

        #expect(snapshot.records.map(\.id) == [ball.id, strike.id])
        #expect(snapshot.replay.state.balls == 1)
        #expect(snapshot.replay.state.strikes == 1)
        #expect(snapshot.replay.state.pitchCount(for: game.startingPitcherID!).total == 2)
        #expect(snapshot.battingLines.isEmpty)
        #expect(snapshot.history.sections[0].entries[0].components.map(\.sequenceNumber) == [1, 2])
    }

    @Test func liveGameSessionSurfacesMismatchedGameInsteadOfKeepingStaleSnapshot() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let game = makeGame()
        let otherGame = makeGame()
        let session = LiveGameSession(gameID: game.id)

        session.refresh(game: game, modelContext: container.mainContext)
        #expect(session.snapshot != nil)

        session.refresh(game: otherGame, modelContext: container.mainContext)

        #expect(session.snapshot == nil)
        #expect(session.loadError == "The live-game session does not match this game.")
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
