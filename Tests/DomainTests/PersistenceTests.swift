import Foundation
import SwiftData
import Testing
@testable import SoftballScoring

private struct TrackedPlateAppearanceUndoScenario: Sendable {
    let result: OffensivePlateAppearanceResult
    let movements: [RunnerMovementEvent]
    let rbi: Int
    let countedRunSources: [RunnerSource]
}

private let trackedPlateAppearanceUndoScenarios: [TrackedPlateAppearanceUndoScenario] = [
    .init(
        result: .walk,
        movements: [
            .init(source: .first, destination: .second),
            .init(source: .batter, destination: .first)
        ],
        rbi: 0,
        countedRunSources: []
    ),
    .init(
        result: .hitByPitch,
        movements: [
            .init(source: .first, destination: .second),
            .init(source: .batter, destination: .first)
        ],
        rbi: 0,
        countedRunSources: []
    ),
    .init(
        result: .strikeout,
        movements: [
            .init(source: .first, destination: .first),
            .init(source: .batter, destination: .out)
        ],
        rbi: 0,
        countedRunSources: []
    ),
    .init(
        result: .double,
        movements: [
            .init(source: .first, destination: .home),
            .init(source: .batter, destination: .second)
        ],
        rbi: 1,
        countedRunSources: [.first]
    ),
    .init(
        result: .reachedOnError,
        movements: [
            .init(source: .first, destination: .second),
            .init(source: .batter, destination: .first)
        ],
        rbi: 0,
        countedRunSources: []
    ),
    .init(
        result: .homeRun,
        movements: [
            .init(source: .first, destination: .home),
            .init(source: .batter, destination: .home)
        ],
        rbi: 2,
        countedRunSources: [.first, .batter]
    ),
    .init(
        result: .sacrificeFly,
        movements: [
            .init(source: .first, destination: .home),
            .init(source: .batter, destination: .out)
        ],
        rbi: 1,
        countedRunSources: [.first]
    ),
    .init(
        result: .flyOut,
        movements: [
            .init(source: .first, destination: .first),
            .init(source: .batter, destination: .out)
        ],
        rbi: 0,
        countedRunSources: []
    ),
    .init(
        result: .doublePlay,
        movements: [
            .init(source: .first, destination: .out),
            .init(source: .batter, destination: .out)
        ],
        rbi: 0,
        countedRunSources: []
    )
]

private struct DefensivePitchEditScenario: Sendable {
    let precedingResults: [PitchResult]
    let originalResult: PitchResult
    let proposedResult: PitchResult
    let expectedBalls: Int
    let expectedStrikes: Int
    let expectedBatterSlot: Int
    let expectedOuts: Int
}

private let defensivePitchEditScenarios: [DefensivePitchEditScenario] = [
    .init(
        precedingResults: [.ball, .ball, .ball, .calledStrike],
        originalResult: .foul,
        proposedResult: .ball,
        expectedBalls: 0,
        expectedStrikes: 0,
        expectedBatterSlot: 2,
        expectedOuts: 0
    ),
    .init(
        precedingResults: [.ball, .calledStrike, .swingingStrike],
        originalResult: .foul,
        proposedResult: .calledStrike,
        expectedBalls: 0,
        expectedStrikes: 0,
        expectedBatterSlot: 2,
        expectedOuts: 1
    ),
    .init(
        precedingResults: [.ball, .calledStrike, .swingingStrike],
        originalResult: .foul,
        proposedResult: .swingingStrike,
        expectedBalls: 0,
        expectedStrikes: 0,
        expectedBatterSlot: 2,
        expectedOuts: 1
    ),
    .init(
        precedingResults: [.ball, .ball, .ball, .calledStrike],
        originalResult: .calledStrike,
        proposedResult: .foul,
        expectedBalls: 3,
        expectedStrikes: 2,
        expectedBatterSlot: 1,
        expectedOuts: 0
    )
]

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
        let projection = try BattingStatProjector.project(events: try records.map { try $0.decoded() })

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
        let battingLine = try BattingStatProjector.project(events: decoded)[players[0].id]

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
        let completedProjection = try BattingStatProjector.project(
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
        let baseRunningProjection = try BattingStatProjector.project(
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

    @Test func undoLatestDefensiveCountPitchRestoresReplayDerivedState() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = game.startingPitcherID!
        let records = try [PitchResult.ball, .calledStrike, .foul].enumerated().map { index, result in
            try GameEventRecord(
                gameID: game.id,
                sequenceNumber: index + 1,
                body: .pitch(.init(
                    result: result,
                    pitcherID: pitcherID,
                    opponentBatterSlot: 1
                ))
            )
        }
        records.forEach(context.insert)
        try context.save()

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )
        let snapshot = try GameEventCorrection.undoLatestAction(
            candidate,
            game: game,
            modelContext: context
        )

        #expect(candidate.sequenceNumber == 3)
        #expect(candidate.inning == 1)
        #expect(candidate.half == .top)
        #expect(candidate.opponentBatterSlot == 1)
        #expect(candidate.action == .pitch(.foul))
        #expect(snapshot.records.map(\.id) == Array(records.dropLast()).map(\.id))
        #expect(snapshot.replay.state.balls == 1)
        #expect(snapshot.replay.state.strikes == 1)
        #expect(snapshot.replay.state.pitchCount(for: pitcherID) == PitchCount(total: 2, balls: 1, strikes: 1))
    }

    @Test func undoLatestTrackedTeamCountPitchRestoresEventTimeBatterCountAndProjection() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let batter = makeTrackedBatter()
        let records = try seedOffensivePitches(
            [.ball, .calledStrike],
            game: game,
            batter: batter,
            modelContext: context
        )
        let before = try LiveGameSnapshotLoader.load(game: game, modelContext: context)

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )
        let restored = try GameEventCorrection.undoLatestAction(
            candidate,
            game: game,
            modelContext: context
        )

        #expect(candidate.action == .offensivePitch(.calledStrike))
        #expect(candidate.actor == .trackedBatter(batter, battingOrderSize: 10))
        #expect(candidate.confirmationDetail.contains("Avery Stone"))
        #expect(candidate.confirmationDetail.contains("batting slot 1 of 10"))
        #expect(candidate.confirmationDetail.contains("sequence 2: Called Strike"))
        #expect(restored.records.map(\.id) == [records[0].id])
        #expect(restored.records.map(\.sequenceNumber) == [1])
        #expect(restored.replay.state.balls == 1)
        #expect(restored.replay.state.strikes == 0)
        #expect(restored.replay.state.currentTrackedBatterSlot == 1)
        #expect(restored.replay.state.offensiveCountContext == OffensiveCountContext(
            batter: batter,
            battingOrderSize: 10
        ))
        #expect(restored.battingLines == before.battingLines)
        #expect(restored.battingLines.isEmpty)
    }

    @Test(arguments: OffensivePitchResult.allCases)
    func undoRestoresPriorOffensiveCountForEveryNonTerminalTrackedTeamPitch(
        _ result: OffensivePitchResult
    ) throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let batter = makeTrackedBatter()
        let priorResults: [OffensivePitchResult]
        let expectedBalls: Int
        let expectedStrikes: Int
        switch result {
        case .ball:
            priorResults = [.calledStrike]
            expectedBalls = 0
            expectedStrikes = 1
        case .calledStrike, .swingingStrike:
            priorResults = [.ball]
            expectedBalls = 1
            expectedStrikes = 0
        case .foul:
            priorResults = [.calledStrike, .swingingStrike]
            expectedBalls = 0
            expectedStrikes = 2
        }
        let records = try seedOffensivePitches(
            priorResults + [result],
            game: game,
            batter: batter,
            modelContext: context
        )

        let restored = try GameEventCorrection.undoLatestAction(
            GameEventCorrection.prepareUndoLatestAction(game: game, modelContext: context),
            game: game,
            modelContext: context
        )

        #expect(restored.records.map(\.id) == Array(records.dropLast()).map(\.id))
        #expect(restored.replay.state.balls == expectedBalls)
        #expect(restored.replay.state.strikes == expectedStrikes)
        #expect(restored.replay.state.pitchCountsByPitcher.isEmpty)
        #expect(restored.replay.state.offensiveCountContext == OffensiveCountContext(
            batter: batter,
            battingOrderSize: 10
        ))
        #expect(restored.battingLines.isEmpty)
    }

    @Test func cancellingTrackedTeamPitchUndoLeavesOriginalTimelineUnchanged() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let records = try seedOffensivePitches(
            [.ball, .foul],
            game: game,
            batter: makeTrackedBatter(),
            modelContext: context
        )
        let before = try LiveGameSnapshotLoader.load(game: game, modelContext: context)

        _ = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        let after = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(after.records.map(\.id) == records.map(\.id))
        #expect(after.records.map(\.sequenceNumber) == [1, 2])
        #expect(after.replay.state == before.replay.state)
        #expect(after.battingLines == before.battingLines)
    }

    @Test func staleTrackedBatterIdentityRejectsUndoAndPreservesOriginalTimeline() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let replacement = makeTrackedBatter(
            displayName: "Jordan Lee",
            jerseyNumber: "12",
            position: .centerField
        )
        let records = try seedOffensivePitches(
            [.ball, .foul],
            game: game,
            batter: makeTrackedBatter(),
            modelContext: context
        )
        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        records[1].payload = try GameEventCodec.encode(.offensivePitch(.init(
            batter: replacement,
            battingOrderSize: 10,
            result: .foul
        ))).payload
        try context.save()

        #expect(throws: GameEventCorrectionError.staleTimeline) {
            _ = try GameEventCorrection.undoLatestAction(
                candidate,
                game: game,
                modelContext: context
            )
        }
        let stored = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>())
            .sorted { $0.sequenceNumber < $1.sequenceNumber }
        #expect(stored.map(\.id) == records.map(\.id))
        #expect(stored.map(\.sequenceNumber) == [1, 2])
        #expect(try stored[1].decoded().body == .offensivePitch(.init(
            batter: replacement,
            battingOrderSize: 10,
            result: .foul
        )))
    }

    @Test func mismatchedTrackedBatterCandidateReplayFailsWithoutChangingHistory() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let firstBatter = makeTrackedBatter()
        let differentBatter = makeTrackedBatter(
            displayName: "Jordan Lee",
            jerseyNumber: "12",
            position: .centerField
        )
        let records = try [firstBatter, differentBatter].enumerated().map { index, batter in
            try GameEventRecord(
                gameID: game.id,
                sequenceNumber: index + 1,
                body: .offensivePitch(.init(
                    batter: batter,
                    battingOrderSize: 10,
                    result: index == 0 ? .ball : .foul
                ))
            )
        }
        records.forEach(context.insert)
        try context.save()

        #expect(throws: GameEventCorrectionError.invalidTimeline) {
            _ = try GameEventCorrection.prepareUndoLatestAction(
                game: game,
                modelContext: context
            )
        }
        let stored = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>())
            .sorted { $0.sequenceNumber < $1.sequenceNumber }
        #expect(stored.map(\.id) == records.map(\.id))
        #expect(stored.map(\.sequenceNumber) == [1, 2])
    }

    @Test func failedTrackedTeamPitchUndoSaveRollsBackOriginalTimeline() throws {
        struct ForcedSaveError: Error {}

        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let records = try seedOffensivePitches(
            [.ball, .foul],
            game: game,
            batter: makeTrackedBatter(),
            modelContext: context
        )
        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        #expect(throws: ForcedSaveError.self) {
            _ = try GameEventCorrection.undoLatestAction(
                candidate,
                game: game,
                modelContext: context,
                save: { _ in throw ForcedSaveError() }
            )
        }
        let stored = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>())
            .sorted { $0.sequenceNumber < $1.sequenceNumber }
        #expect(stored.map(\.id) == records.map(\.id))
        #expect(stored.map(\.sequenceNumber) == [1, 2])
        #expect(try stored.map { try $0.decoded().body } == records.map { try $0.decoded().body })
    }

    @Test func trackedTeamPitchUndoSurvivesFreshContextAndColdStoreReload() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appending(path: "softball-scoring-offensive-pitch-undo-\(UUID().uuidString).store")
        let gameID = UUID()
        let batter = makeTrackedBatter()
        var expectedState: GameState?
        var expectedRecordIDs: [UUID] = []

        do {
            let container = try AppModelContainer.make(storeURL: storeURL)
            let context = container.mainContext
            let game = makeOffensiveGame(id: gameID)
            context.insert(game)
            let records = try seedOffensivePitches(
                [.ball, .calledStrike, .foul],
                game: game,
                batter: batter,
                modelContext: context
            )

            let restored = try GameEventCorrection.undoLatestAction(
                GameEventCorrection.prepareUndoLatestAction(game: game, modelContext: context),
                game: game,
                modelContext: context
            )
            expectedState = restored.replay.state
            expectedRecordIDs = Array(records.dropLast()).map(\.id)

            let freshContext = ModelContext(container)
            let freshGame = try #require(freshContext.fetch(FetchDescriptor<Game>()).first)
            let fresh = try LiveGameSnapshotLoader.load(game: freshGame, modelContext: freshContext)
            #expect(fresh.replay.state == expectedState)
            #expect(fresh.records.map(\.id) == expectedRecordIDs)
            #expect(fresh.replay.state.balls == 1)
            #expect(fresh.replay.state.strikes == 1)
            #expect(fresh.replay.state.offensiveCountContext == OffensiveCountContext(
                batter: batter,
                battingOrderSize: 10
            ))
        }

        let reloadedContainer = try AppModelContainer.make(storeURL: storeURL)
        let reloadedContext = ModelContext(reloadedContainer)
        let reloadedGame = try #require(reloadedContext.fetch(FetchDescriptor<Game>()).first)
        let reloaded = try LiveGameSnapshotLoader.load(
            game: reloadedGame,
            modelContext: reloadedContext
        )
        #expect(reloaded.replay.state == expectedState)
        #expect(reloaded.records.map(\.id) == expectedRecordIDs)
        #expect(reloaded.replay.state.offensiveCountContext == OffensiveCountContext(
            batter: batter,
            battingOrderSize: 10
        ))
    }

    @Test func scoringAfterTrackedTeamPitchUndoPreservesSurvivorsAndUsesAuthoritativeSequence() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let player = Player(
            firstName: "Avery",
            lastName: "Stone",
            jerseyNumber: "8",
            defaultPosition: .shortstop
        )
        let game = makeOffensiveGame()
        let batter = makeTrackedBatter(playerID: player.id)
        context.insert(player)
        context.insert(LineupEntry(
            playerID: player.id,
            battingOrder: 1,
            startingPosition: .shortstop,
            gameID: game.id
        ))
        let records = try seedOffensivePitches(
            [.ball, .calledStrike, .foul],
            sequences: [1, 3, 6],
            game: game,
            batter: batter,
            battingOrderSize: 1,
            modelContext: context
        )

        let restored = try GameEventCorrection.undoLatestAction(
            GameEventCorrection.prepareUndoLatestAction(game: game, modelContext: context),
            game: game,
            modelContext: context
        )
        try GameEventRecorder.recordOffensivePitch(
            expectedBatter: batter,
            result: .swingingStrike,
            game: game,
            existingRecords: restored.records,
            modelContext: context
        )

        let stored = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>())
            .filter { $0.gameID == game.id }
            .sorted { $0.sequenceNumber < $1.sequenceNumber }
        #expect(stored.map(\.sequenceNumber) == [1, 3, 4])
        #expect(stored.prefix(2).map(\.id) == records.prefix(2).map(\.id))
        #expect(stored.prefix(2).map(\.timestamp) == records.prefix(2).map(\.timestamp))
        #expect(!stored.contains { $0.id == records[2].id })
        #expect(try stored.last?.decoded().body == .offensivePitch(.init(
            batter: batter,
            battingOrderSize: 1,
            result: .swingingStrike
        )))
    }

    @Test func undoLatestTrackedTeamPlateAppearanceRestoresCountBasesBatterAndBattingProjection() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let batter = makeTrackedBatter()
        let pitches = try seedOffensivePitches(
            [.ball, .calledStrike],
            game: game,
            batter: batter,
            modelContext: context
        )
        let plateAppearance = OffensivePlateAppearanceEvent(
            batter: batter,
            battingOrderSize: 10,
            result: .single,
            movements: [.init(source: .batter, destination: .first)],
            rbi: 0,
            countedRunSources: [],
            thirdOutClassification: nil
        )
        let completedRecord = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 3,
            body: .offensivePlateAppearance(plateAppearance)
        )
        context.insert(completedRecord)
        try context.save()

        let completed = try LiveGameSnapshotLoader.load(game: game, modelContext: context)
        #expect(completed.replay.state.currentTrackedBatterSlot == 2)
        #expect(completed.replay.state.firstBaseRunnerPlayerID == batter.playerID)
        #expect(completed.battingLines[batter.playerID] == BattingLine(
            plateAppearances: 1,
            atBats: 1,
            hits: 1
        ))

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )
        let restored = try GameEventCorrection.undoLatestAction(
            candidate,
            game: game,
            modelContext: context
        )

        #expect(candidate.actor == .trackedBatter(batter, battingOrderSize: 10))
        #expect(candidate.action.buttonTitle == "Undo Latest Play")
        #expect(candidate.confirmationTitle == "Undo latest plate appearance?")
        #expect(candidate.confirmationDetail.contains("Avery Stone"))
        #expect(candidate.confirmationDetail.contains("sequence 3: Single"))
        #expect(candidate.confirmationDetail.contains("Runner movements: Batter to 1B"))
        #expect(candidate.confirmationDetail.contains("Runs: 0. RBI: 0"))
        #expect(restored.records.map(\.id) == pitches.map(\.id))
        #expect(restored.replay.state.balls == 1)
        #expect(restored.replay.state.strikes == 1)
        #expect(restored.replay.state.currentTrackedBatterSlot == 1)
        #expect(restored.replay.state.firstBaseRunnerPlayerID == nil)
        #expect(restored.replay.state.offensiveCountContext == OffensiveCountContext(
            batter: batter,
            battingOrderSize: 10
        ))
        #expect(restored.battingLines.isEmpty)
    }

    @Test(arguments: trackedPlateAppearanceUndoScenarios)
    fileprivate func undoTrackedTeamPlateAppearanceRestoresExactPrePlaySnapshot(
        _ scenario: TrackedPlateAppearanceUndoScenario
    ) throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let runner = makeTrackedBatter(displayName: "Riley North")
        let batter = makeTrackedBatter(
            displayName: "Morgan Field",
            jerseyNumber: "21",
            position: .leftField,
            lineupSlot: 2
        )
        let baselineRecords: [GameEventRecord] = try [
            .init(
                gameID: game.id,
                sequenceNumber: 1,
                body: .offensivePlateAppearance(.init(
                    batter: runner,
                    battingOrderSize: 10,
                    result: .walk,
                    movements: [.init(source: .batter, destination: .first)],
                    rbi: 0,
                    countedRunSources: [],
                    thirdOutClassification: nil
                ))
            ),
            .init(
                gameID: game.id,
                sequenceNumber: 2,
                body: .offensivePitch(.init(
                    batter: batter,
                    battingOrderSize: 10,
                    result: .ball
                ))
            ),
            .init(
                gameID: game.id,
                sequenceNumber: 3,
                body: .offensivePitch(.init(
                    batter: batter,
                    battingOrderSize: 10,
                    result: .calledStrike
                ))
            )
        ]
        baselineRecords.forEach(context.insert)
        try context.save()
        let baseline = try LiveGameSnapshotLoader.load(game: game, modelContext: context)

        let completedRecord = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 4,
            body: .offensivePlateAppearance(.init(
                batter: batter,
                battingOrderSize: 10,
                result: scenario.result,
                movements: scenario.movements,
                rbi: scenario.rbi,
                countedRunSources: scenario.countedRunSources,
                thirdOutClassification: nil
            ))
        )
        context.insert(completedRecord)
        try context.save()
        let completed = try LiveGameSnapshotLoader.load(game: game, modelContext: context)
        #expect(completed.replay.rejectedRecordIDs.isEmpty)
        #expect(completed.battingLines != baseline.battingLines)

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )
        let restored = try GameEventCorrection.undoLatestAction(
            candidate,
            game: game,
            modelContext: context
        )

        #expect(candidate.confirmationDetail.contains("sequence 4: \(scenario.result.label)"))
        #expect(candidate.confirmationDetail.contains("Runs: \(scenario.countedRunSources.count)"))
        #expect(candidate.confirmationDetail.contains("RBI: \(scenario.rbi)"))
        #expect(restored.records.map(\.id) == baselineRecords.map(\.id))
        #expect(restored.replay.state == baseline.replay.state)
        #expect(restored.battingLines == baseline.battingLines)
        #expect(restored.history == baseline.history)
    }

    @Test func trackedTeamPlateAppearanceUndoKeepsEventTimeIdentityWhenCurrentPlayerMetadataDiffers() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let playerID = UUID()
        let historicalBatter = makeTrackedBatter(
            playerID: playerID,
            displayName: "Historical Name",
            jerseyNumber: "8",
            position: .shortstop
        )
        context.insert(Player(
            id: playerID,
            firstName: "Current",
            lastName: "Name",
            jerseyNumber: "99",
            defaultPosition: .centerField
        ))
        context.insert(LineupEntry(
            playerID: playerID,
            battingOrder: 1,
            startingPosition: .centerField,
            gameID: game.id
        ))
        let record = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .offensivePlateAppearance(.init(
                batter: historicalBatter,
                battingOrderSize: 10,
                result: .walk,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            ))
        )
        context.insert(record)
        try context.save()

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        #expect(candidate.actor == .trackedBatter(historicalBatter, battingOrderSize: 10))
        #expect(candidate.confirmationDetail.contains("Historical Name"))
        #expect(!candidate.confirmationDetail.contains("Current Name"))
    }

    @Test func cancellingOrFailingTrackedTeamPlateAppearanceUndoPreservesRecordAndBattingLine() throws {
        struct ForcedSaveError: Error {}

        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let batter = makeTrackedBatter()
        let record = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .offensivePlateAppearance(.init(
                batter: batter,
                battingOrderSize: 10,
                result: .homeRun,
                movements: [.init(source: .batter, destination: .home)],
                rbi: 1,
                countedRunSources: [.batter],
                thirdOutClassification: nil
            ))
        )
        context.insert(record)
        try context.save()
        let before = try LiveGameSnapshotLoader.load(game: game, modelContext: context)
        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        let afterCancel = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(afterCancel.records.map(\.id) == [record.id])
        #expect(afterCancel.battingLines == before.battingLines)

        #expect(throws: ForcedSaveError.self) {
            _ = try GameEventCorrection.undoLatestAction(
                candidate,
                game: game,
                modelContext: context,
                save: { _ in throw ForcedSaveError() }
            )
        }
        let afterFailure = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(afterFailure.records.map(\.id) == [record.id])
        #expect(afterFailure.replay.state == before.replay.state)
        #expect(afterFailure.battingLines == before.battingLines)
    }

    @Test func staleTrackedTeamPlateAppearanceUndoPreservesTheNewerCompletedPlay() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let batter = makeTrackedBatter()
        let record = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .offensivePlateAppearance(.init(
                batter: batter,
                battingOrderSize: 10,
                result: .single,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            ))
        )
        context.insert(record)
        try context.save()
        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        record.payload = try GameEventCodec.encode(.offensivePlateAppearance(.init(
            batter: batter,
            battingOrderSize: 10,
            result: .homeRun,
            movements: [.init(source: .batter, destination: .home)],
            rbi: 1,
            countedRunSources: [.batter],
            thirdOutClassification: nil
        ))).payload
        try context.save()

        #expect(throws: GameEventCorrectionError.staleTimeline) {
            _ = try GameEventCorrection.undoLatestAction(
                candidate,
                game: game,
                modelContext: context
            )
        }
        let after = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(after.records.map(\.id) == [record.id])
        #expect(after.battingLines[batter.playerID]?.homeRuns == 1)
        #expect(after.battingLines[batter.playerID]?.runs == 1)
    }

    @Test func invalidTrackedTeamCandidateReplayPreservesCompletedPlayAndProjection() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let batter = makeTrackedBatter()
        let mismatchedBatter = makeTrackedBatter(displayName: "Different Batter")
        let records = try [
            GameEventRecord(
                gameID: game.id,
                sequenceNumber: 1,
                body: .offensivePitch(.init(
                    batter: mismatchedBatter,
                    battingOrderSize: 10,
                    result: .ball
                ))
            ),
            GameEventRecord(
                gameID: game.id,
                sequenceNumber: 2,
                body: .offensivePlateAppearance(.init(
                    batter: batter,
                    battingOrderSize: 10,
                    result: .single,
                    movements: [.init(source: .batter, destination: .first)],
                    rbi: 0,
                    countedRunSources: [],
                    thirdOutClassification: nil
                ))
            )
        ]
        records.forEach(context.insert)
        try context.save()
        let before = try LiveGameSnapshotLoader.load(game: game, modelContext: context)
        #expect(!before.replay.rejectedRecordIDs.isEmpty)

        #expect(throws: GameEventCorrectionError.invalidTimeline) {
            _ = try GameEventCorrection.prepareUndoLatestAction(
                game: game,
                modelContext: context
            )
        }
        let after = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(after.records.map(\.id) == records.map(\.id))
        #expect(after.replay.state == before.replay.state)
        #expect(after.battingLines == before.battingLines)
    }

    @Test func failedTrackedTeamCandidateProjectionPreservesCompletedPlayAndBattingLine() throws {
        struct ForcedProjectionError: Error {}

        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let batter = makeTrackedBatter()
        let record = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .offensivePlateAppearance(.init(
                batter: batter,
                battingOrderSize: 10,
                result: .homeRun,
                movements: [.init(source: .batter, destination: .home)],
                rbi: 1,
                countedRunSources: [.batter],
                thirdOutClassification: nil
            ))
        )
        context.insert(record)
        try context.save()
        let before = try LiveGameSnapshotLoader.load(game: game, modelContext: context)
        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        #expect(throws: ForcedProjectionError.self) {
            _ = try GameEventCorrection.undoLatestAction(
                candidate,
                game: game,
                modelContext: context,
                projectBattingLines: { _ in throw ForcedProjectionError() }
            )
        }
        let after = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(after.records.map(\.id) == [record.id])
        #expect(after.replay.state == before.replay.state)
        #expect(after.battingLines == before.battingLines)
    }

    @Test func trackedTeamPlateAppearanceUndoSurvivesFreshContextAndColdStoreReload() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appending(path: "softball-scoring-plate-appearance-undo-\(UUID().uuidString).store")
        let gameID = UUID()
        let batter = makeTrackedBatter()
        var expectedState: GameState?
        var expectedHistory: PlayHistory?

        do {
            let container = try AppModelContainer.make(storeURL: storeURL)
            let context = container.mainContext
            let game = makeOffensiveGame(id: gameID)
            context.insert(game)
            let records = try [
                GameEventRecord(
                    gameID: game.id,
                    sequenceNumber: 1,
                    body: .offensivePitch(.init(
                        batter: batter,
                        battingOrderSize: 10,
                        result: .ball
                    ))
                ),
                GameEventRecord(
                    gameID: game.id,
                    sequenceNumber: 2,
                    body: .offensivePlateAppearance(.init(
                        batter: batter,
                        battingOrderSize: 10,
                        result: .homeRun,
                        movements: [.init(source: .batter, destination: .home)],
                        rbi: 1,
                        countedRunSources: [.batter],
                        thirdOutClassification: nil
                    ))
                )
            ]
            records.forEach(context.insert)
            try context.save()

            let restored = try GameEventCorrection.undoLatestAction(
                GameEventCorrection.prepareUndoLatestAction(game: game, modelContext: context),
                game: game,
                modelContext: context
            )
            expectedState = restored.replay.state
            expectedHistory = restored.history
            #expect(restored.records.map(\.id) == [records[0].id])
            #expect(restored.replay.state.balls == 1)
            #expect(restored.replay.state.currentTrackedBatterSlot == 1)
            #expect(restored.battingLines.isEmpty)

            let freshContext = ModelContext(container)
            let freshGame = try #require(freshContext.fetch(FetchDescriptor<Game>()).first)
            let fresh = try LiveGameSnapshotLoader.load(game: freshGame, modelContext: freshContext)
            #expect(fresh.replay.state == expectedState)
            #expect(fresh.history == expectedHistory)
            #expect(fresh.battingLines.isEmpty)
        }

        let reloadedContainer = try AppModelContainer.make(storeURL: storeURL)
        let reloadedContext = ModelContext(reloadedContainer)
        let reloadedGame = try #require(reloadedContext.fetch(FetchDescriptor<Game>()).first)
        let reloaded = try LiveGameSnapshotLoader.load(
            game: reloadedGame,
            modelContext: reloadedContext
        )
        #expect(reloaded.replay.state == expectedState)
        #expect(reloaded.history == expectedHistory)
        #expect(reloaded.battingLines.isEmpty)
    }

    @Test func undoTrackedTeamThirdOutRestoresPriorHalfInningAndTwoOutBattingProjection() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let batters = (1...3).map { slot in
            makeTrackedBatter(
                displayName: "Batter \(slot)",
                jerseyNumber: "\(slot)",
                lineupSlot: slot
            )
        }
        let records = try batters.enumerated().map { index, batter in
            try GameEventRecord(
                gameID: game.id,
                sequenceNumber: index + 1,
                body: .offensivePlateAppearance(.init(
                    batter: batter,
                    battingOrderSize: 10,
                    result: .strikeout,
                    movements: [.init(source: .batter, destination: .out)],
                    rbi: 0,
                    countedRunSources: [],
                    thirdOutClassification: nil
                ))
            )
        }
        records.forEach(context.insert)
        try context.save()
        let completed = try LiveGameSnapshotLoader.load(game: game, modelContext: context)
        #expect(completed.replay.state.half == .bottom)
        #expect(completed.replay.state.outs == 0)

        let restored = try GameEventCorrection.undoLatestAction(
            GameEventCorrection.prepareUndoLatestAction(game: game, modelContext: context),
            game: game,
            modelContext: context
        )

        #expect(restored.records.map(\.id) == Array(records.dropLast()).map(\.id))
        #expect(restored.replay.state.inning == 1)
        #expect(restored.replay.state.half == .top)
        #expect(restored.replay.state.outs == 2)
        #expect(restored.replay.state.currentTrackedBatterSlot == 3)
        #expect(restored.replay.state.balls == 0)
        #expect(restored.replay.state.strikes == 0)
        #expect(restored.battingLines[batters[0].playerID]?.strikeouts == 1)
        #expect(restored.battingLines[batters[1].playerID]?.strikeouts == 1)
        #expect(restored.battingLines[batters[2].playerID] == nil)
    }

    @Test func undoLatestStolenBaseRestoresRunnerCountBatterAndBattingProjection() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let runner = makeTrackedBatter()
        let activeBatter = makeTrackedBatter(
            displayName: "Jordan Lee",
            jerseyNumber: "12",
            position: .centerField,
            lineupSlot: 2
        )
        let records = try [
            GameEventBody.offensivePlateAppearance(.init(
                batter: runner,
                battingOrderSize: 10,
                result: .single,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensivePitch(.init(
                batter: activeBatter,
                battingOrderSize: 10,
                result: .ball
            )),
            .offensiveBaseRunning(.init(
                runnerID: runner.playerID,
                source: .first,
                destination: .second,
                result: .stolenBase
            ))
        ].enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )
        let restored = try GameEventCorrection.undoLatestAction(
            candidate,
            game: game,
            modelContext: context
        )

        #expect(candidate.action == .offensiveBaseRunning(.init(
            runnerID: runner.playerID,
            source: .first,
            destination: .second,
            result: .stolenBase
        )))
        #expect(candidate.actor == .trackedBatter(runner, battingOrderSize: 10))
        #expect(candidate.confirmationDetail.contains("Avery Stone"))
        #expect(candidate.confirmationDetail.contains("sequence 3: SB · 1B to 2B"))
        #expect(restored.records.map(\.id) == Array(records.dropLast()).map(\.id))
        #expect(restored.replay.state.firstBaseRunnerPlayerID == runner.playerID)
        #expect(restored.replay.state.secondBaseRunnerPlayerID == nil)
        #expect(restored.replay.state.currentTrackedBatterSlot == 2)
        #expect(restored.replay.state.balls == 1)
        #expect(restored.replay.state.strikes == 0)
        #expect(restored.replay.state.offensiveCountContext == OffensiveCountContext(
            batter: activeBatter,
            battingOrderSize: 10
        ))
        #expect(restored.battingLines[runner.playerID]?.plateAppearances == 1)
        #expect(restored.battingLines[runner.playerID]?.hits == 1)
        #expect(restored.battingLines[runner.playerID]?.stolenBases == 0)
        #expect(restored.battingLines[runner.playerID]?.caughtStealing == 0)
    }

    @Test func acceptedDuplicatePlayerIDHistoryUsesSourceBaseProvenanceForUndoConfirmation() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let originatingRunner = makeTrackedBatter()
        let laterSnapshot = makeTrackedBatter(
            playerID: originatingRunner.playerID,
            displayName: "Later Snapshot",
            jerseyNumber: "12",
            position: .centerField,
            lineupSlot: 2
        )
        let records = try [
            GameEventBody.offensivePlateAppearance(.init(
                batter: originatingRunner,
                battingOrderSize: 10,
                result: .single,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensivePlateAppearance(.init(
                batter: laterSnapshot,
                battingOrderSize: 10,
                result: .double,
                movements: [
                    .init(source: .batter, destination: .second),
                    .init(source: .first, destination: .third)
                ],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensiveBaseRunning(.init(
                runnerID: originatingRunner.playerID,
                source: .third,
                destination: .home,
                result: .stolenBase
            ))
        ].enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        #expect(candidate.actor == .trackedBatter(originatingRunner, battingOrderSize: 10))
        #expect(candidate.confirmationDetail.contains("Avery Stone"))
        #expect(!candidate.confirmationDetail.contains("Later Snapshot"))
    }

    @Test func acceptedSameIDReplacementUsesNewSourceBaseProvenanceForUndoConfirmation() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let earlierRunner = makeTrackedBatter()
        let replacementRunner = makeTrackedBatter(
            playerID: earlierRunner.playerID,
            displayName: "Replacement Snapshot",
            jerseyNumber: "12",
            position: .centerField,
            lineupSlot: 2
        )
        let records = try [
            GameEventBody.offensivePlateAppearance(.init(
                batter: earlierRunner,
                battingOrderSize: 10,
                result: .single,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensivePlateAppearance(.init(
                batter: replacementRunner,
                battingOrderSize: 10,
                result: .single,
                movements: [
                    .init(source: .batter, destination: .first),
                    .init(source: .first, destination: .third)
                ],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensiveBaseRunning(.init(
                runnerID: replacementRunner.playerID,
                source: .first,
                destination: .second,
                result: .stolenBase
            ))
        ].enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        #expect(candidate.actor == .trackedBatter(replacementRunner, battingOrderSize: 10))
        #expect(candidate.confirmationDetail.contains("Replacement Snapshot"))
        #expect(!candidate.confirmationDetail.contains("Avery Stone"))
    }

    @Test func consecutiveStealsTraceUndoConfirmationBackToOriginatingPlateAppearance() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let runner = makeTrackedBatter()
        let records = try [
            GameEventBody.offensivePlateAppearance(.init(
                batter: runner,
                battingOrderSize: 10,
                result: .single,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensiveBaseRunning(.init(
                runnerID: runner.playerID,
                source: .first,
                destination: .second,
                result: .stolenBase
            )),
            .offensiveBaseRunning(.init(
                runnerID: runner.playerID,
                source: .second,
                destination: .third,
                result: .stolenBase
            ))
        ].enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        #expect(candidate.actor == .trackedBatter(runner, battingOrderSize: 10))
        #expect(candidate.confirmationDetail.contains("sequence 3: SB · 2B to 3B"))
    }

    @Test func undoStealOfHomeRemovesRunAndSBWhileRestoringRunnerToThird() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let runner = makeTrackedBatter()
        let activeBatter = makeTrackedBatter(
            displayName: "Jordan Lee",
            jerseyNumber: "12",
            position: .centerField,
            lineupSlot: 2
        )
        let records = try [
            GameEventBody.offensivePlateAppearance(.init(
                batter: runner,
                battingOrderSize: 10,
                result: .triple,
                movements: [.init(source: .batter, destination: .third)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensivePitch(.init(
                batter: activeBatter,
                battingOrderSize: 10,
                result: .calledStrike
            )),
            .offensiveBaseRunning(.init(
                runnerID: runner.playerID,
                source: .third,
                destination: .home,
                result: .stolenBase
            ))
        ].enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()
        let before = try LiveGameSnapshotLoader.load(game: game, modelContext: context)
        #expect(before.replay.state.awayScore == 1)
        #expect(before.battingLines[runner.playerID]?.runs == 1)
        #expect(before.battingLines[runner.playerID]?.stolenBases == 1)

        let restored = try GameEventCorrection.undoLatestAction(
            GameEventCorrection.prepareUndoLatestAction(game: game, modelContext: context),
            game: game,
            modelContext: context
        )

        #expect(restored.replay.state.awayScore == 0)
        #expect(restored.replay.state.thirdBaseRunnerPlayerID == runner.playerID)
        #expect(restored.replay.state.currentTrackedBatterSlot == 2)
        #expect(restored.replay.state.strikes == 1)
        #expect(restored.battingLines[runner.playerID]?.runs == 0)
        #expect(restored.battingLines[runner.playerID]?.triples == 1)
        #expect(restored.battingLines[runner.playerID]?.stolenBases == 0)
    }

    @Test func undoThirdOutCaughtStealingRestoresPriorHalfRunnerOutsAndActiveBatter() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let batters = (1...4).map { slot in
            makeTrackedBatter(
                displayName: "Player \(slot)",
                jerseyNumber: "\(slot)",
                position: .shortstop,
                lineupSlot: slot
            )
        }
        let records = try [
            GameEventBody.offensivePlateAppearance(.init(
                batter: batters[0],
                battingOrderSize: 10,
                result: .strikeout,
                movements: [.init(source: .batter, destination: .out)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensivePlateAppearance(.init(
                batter: batters[1],
                battingOrderSize: 10,
                result: .strikeout,
                movements: [.init(source: .batter, destination: .out)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensivePlateAppearance(.init(
                batter: batters[2],
                battingOrderSize: 10,
                result: .single,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensivePitch(.init(
                batter: batters[3],
                battingOrderSize: 10,
                result: .calledStrike
            )),
            .offensiveBaseRunning(.init(
                runnerID: batters[2].playerID,
                source: .first,
                destination: .out,
                result: .caughtStealing
            ))
        ].enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()
        let before = try LiveGameSnapshotLoader.load(game: game, modelContext: context)
        #expect(before.replay.state.half == .bottom)
        #expect(before.battingLines[batters[2].playerID]?.caughtStealing == 1)

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )
        let restored = try GameEventCorrection.undoLatestAction(
            candidate,
            game: game,
            modelContext: context
        )

        #expect(candidate.actor == .trackedBatter(batters[2], battingOrderSize: 10))
        #expect(candidate.confirmationTitle == "Undo latest caught stealing?")
        #expect(candidate.confirmationDetail.contains("sequence 5: CS · 1B to Out"))
        #expect(restored.replay.state.inning == 1)
        #expect(restored.replay.state.half == .top)
        #expect(restored.replay.state.outs == 2)
        #expect(restored.replay.state.firstBaseRunnerPlayerID == batters[2].playerID)
        #expect(restored.replay.state.currentTrackedBatterSlot == 4)
        #expect(restored.replay.state.strikes == 1)
        #expect(restored.replay.state.offensiveCountContext == OffensiveCountContext(
            batter: batters[3],
            battingOrderSize: 10
        ))
        #expect(restored.battingLines[batters[2].playerID]?.hits == 1)
        #expect(restored.battingLines[batters[2].playerID]?.caughtStealing == 0)
    }

    @Test func wrongRunnerBaseRunningHistoryCannotBecomeAnUndoCandidate() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let runner = makeTrackedBatter()
        let records = try [
            GameEventBody.offensivePlateAppearance(.init(
                batter: runner,
                battingOrderSize: 10,
                result: .single,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensiveBaseRunning(.init(
                runnerID: UUID(),
                source: .first,
                destination: .second,
                result: .stolenBase
            ))
        ].enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()

        #expect(throws: GameEventCorrectionError.invalidTimeline) {
            _ = try GameEventCorrection.prepareUndoLatestAction(
                game: game,
                modelContext: context
            )
        }
        let stored = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>())
            .sorted { $0.sequenceNumber < $1.sequenceNumber }
        #expect(stored.map(\.id) == records.map(\.id))
        #expect(stored.map(\.sequenceNumber) == [1, 2])
    }

    @Test func staleStolenBaseUndoPreservesNewerHistory() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let seeded = try seedStolenBaseUndoTimeline(game: game, modelContext: context)
        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        seeded.records[0].timestamp = seeded.records[0].timestamp.addingTimeInterval(1)
        try context.save()

        #expect(throws: GameEventCorrectionError.staleTimeline) {
            _ = try GameEventCorrection.undoLatestAction(
                candidate,
                game: game,
                modelContext: context
            )
        }
        let stored = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(stored.records.map(\.id) == seeded.records.map(\.id))
        #expect(stored.replay.state.secondBaseRunnerPlayerID == seeded.runner.playerID)
        #expect(stored.battingLines[seeded.runner.playerID]?.stolenBases == 1)
    }

    @Test func failedStolenBaseProjectionOrSaveLeavesTimelineAndAttributionUnchanged() throws {
        struct ForcedProjectionError: Error {}
        struct ForcedSaveError: Error {}

        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeOffensiveGame()
        let seeded = try seedStolenBaseUndoTimeline(game: game, modelContext: context)
        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        #expect(throws: ForcedProjectionError.self) {
            _ = try GameEventCorrection.undoLatestAction(
                candidate,
                game: game,
                modelContext: context,
                projectBattingLines: { _ in throw ForcedProjectionError() }
            )
        }
        #expect(throws: ForcedSaveError.self) {
            _ = try GameEventCorrection.undoLatestAction(
                candidate,
                game: game,
                modelContext: context,
                save: { _ in throw ForcedSaveError() }
            )
        }

        let stored = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(stored.records.map(\.id) == seeded.records.map(\.id))
        #expect(stored.replay.state.secondBaseRunnerPlayerID == seeded.runner.playerID)
        #expect(stored.battingLines[seeded.runner.playerID]?.stolenBases == 1)
    }

    @Test func stolenBaseUndoSurvivesFreshContextAndColdStoreReload() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appending(path: "softball-scoring-base-running-undo-\(UUID().uuidString).store")
        let gameID = UUID()
        var expectedState: GameState?
        var expectedLines: [UUID: BattingLine] = [:]
        var expectedRecordIDs: [UUID] = []

        do {
            let container = try AppModelContainer.make(storeURL: storeURL)
            let context = container.mainContext
            let game = makeOffensiveGame(id: gameID)
            context.insert(game)
            let seeded = try seedStolenBaseUndoTimeline(game: game, modelContext: context)
            let restored = try GameEventCorrection.undoLatestAction(
                GameEventCorrection.prepareUndoLatestAction(game: game, modelContext: context),
                game: game,
                modelContext: context
            )
            expectedState = restored.replay.state
            expectedLines = restored.battingLines
            expectedRecordIDs = Array(seeded.records.dropLast()).map(\.id)

            let freshContext = ModelContext(container)
            let freshGame = try #require(freshContext.fetch(FetchDescriptor<Game>()).first)
            let fresh = try LiveGameSnapshotLoader.load(game: freshGame, modelContext: freshContext)
            #expect(fresh.replay.state == expectedState)
            #expect(fresh.battingLines == expectedLines)
            #expect(fresh.records.map(\.id) == expectedRecordIDs)
            #expect(fresh.replay.state.firstBaseRunnerPlayerID == seeded.runner.playerID)
        }

        let reloadedContainer = try AppModelContainer.make(storeURL: storeURL)
        let reloadedContext = ModelContext(reloadedContainer)
        let reloadedGame = try #require(reloadedContext.fetch(FetchDescriptor<Game>()).first)
        let reloaded = try LiveGameSnapshotLoader.load(
            game: reloadedGame,
            modelContext: reloadedContext
        )
        #expect(reloaded.replay.state == expectedState)
        #expect(reloaded.battingLines == expectedLines)
        #expect(reloaded.records.map(\.id) == expectedRecordIDs)
    }

    @Test func undoLatestBallInPlayResultPreservesCountedPitchAndRestoresPendingState() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = game.startingPitcherID!
        let pitch = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .pitch(.init(
                result: .ballInPlay,
                pitcherID: pitcherID,
                opponentBatterSlot: 1
            ))
        )
        let result = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 2,
            body: .ballInPlay(.init(
                outcome: .single,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                thirdOutRunsCounted: nil
            ))
        )
        context.insert(pitch)
        context.insert(result)
        try context.save()

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )
        let restored = try GameEventCorrection.undoLatestAction(
            candidate,
            game: game,
            modelContext: context
        )

        #expect(candidate.action == .ballInPlayResult(.single))
        #expect(candidate.precedingBallInPlayPitchSequenceNumber == 1)
        #expect(candidate.confirmationTitle == "Undo latest result?")
        #expect(candidate.confirmationDetail.contains("Only the completed Single result will be removed"))
        #expect(candidate.confirmationDetail.contains("Ball In Play pitch at sequence 1 will remain counted"))
        #expect(restored.records.map(\.id) == [pitch.id])
        #expect(restored.replay.state.isAwaitingBallInPlayResult)
        #expect(restored.replay.state.currentOpponentBatterSlot == 1)
        #expect(restored.replay.state.baseRunnerSlots == [nil, nil, nil])
        #expect(restored.replay.state.outs == 0)
        #expect(restored.replay.state.awayScore == 0)
        #expect(restored.replay.state.pitchCount(for: pitcherID) == PitchCount(total: 1, balls: 0, strikes: 1))
    }

    @Test(arguments: [
        BallInPlayOutcome.single,
        .double,
        .homeRun,
        .groundOut
    ])
    func undoBallInPlayResultRestoresPreResultStateForHitsHomeRunAndOrdinaryOut(
        _ outcome: BallInPlayOutcome
    ) throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = game.startingPitcherID!
        let destination: RunnerDestination = switch outcome {
        case .single: .first
        case .double: .second
        case .homeRun: .home
        case .groundOut: .out
        default: try #require(nil)
        }
        let bodies: [GameEventBody] = [
            .pitch(.init(result: .ballInPlay, pitcherID: pitcherID, opponentBatterSlot: 1)),
            .ballInPlay(.init(
                outcome: outcome,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: destination)],
                rbi: outcome == .homeRun ? 1 : 0,
                thirdOutRunsCounted: nil
            ))
        ]
        let records = try bodies.enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()

        let expected = try LiveGameSnapshotLoader.makeSnapshot(
            game: game,
            records: [records[0]]
        )
        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )
        let restored = try GameEventCorrection.undoLatestAction(
            candidate,
            game: game,
            modelContext: context
        )

        #expect(candidate.action == .ballInPlayResult(outcome))
        #expect(restored.records.map(\.id) == [records[0].id])
        #expect(restored.replay.state == expected.replay.state)
        #expect(restored.replay.state.isAwaitingBallInPlayResult)
        #expect(restored.replay.state.pitchCount(for: pitcherID) == PitchCount(total: 1, balls: 0, strikes: 1))
    }

    @Test func undoMultiOutBallInPlayResultRestoresRunnerOutsAndPendingBatter() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = game.startingPitcherID!
        let bodies = twoConsecutiveSingles(pitcherID: pitcherID).prefix(2) + [
            .pitch(.init(result: .ballInPlay, pitcherID: pitcherID, opponentBatterSlot: 2)),
            .ballInPlay(.init(
                outcome: .doublePlay,
                opponentBatterSlot: 2,
                movements: [
                    .init(source: .first, destination: .out),
                    .init(source: .batter, destination: .out)
                ],
                rbi: 0,
                thirdOutRunsCounted: nil
            ))
        ]
        let records = try bodies.enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()

        let restored = try GameEventCorrection.undoLatestAction(
            GameEventCorrection.prepareUndoLatestAction(game: game, modelContext: context),
            game: game,
            modelContext: context
        )

        #expect(restored.replay.state.outs == 0)
        #expect(restored.replay.state.currentOpponentBatterSlot == 2)
        #expect(restored.replay.state.firstBaseRunnerSlot == 1)
        #expect(restored.replay.state.isAwaitingBallInPlayResult)
        #expect(restored.replay.state.pitchCount(for: pitcherID) == PitchCount(total: 2, balls: 0, strikes: 2))
    }

    @Test func undoThirdOutBallInPlayResultRestoresPriorHalfInningAndTwoOutState() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = game.startingPitcherID!
        let bodies = (1...3).flatMap { slot in
            [
                GameEventBody.pitch(.init(
                    result: .ballInPlay,
                    pitcherID: pitcherID,
                    opponentBatterSlot: slot
                )),
                .ballInPlay(.init(
                    outcome: .groundOut,
                    opponentBatterSlot: slot,
                    movements: [.init(source: .batter, destination: .out)],
                    rbi: 0,
                    thirdOutRunsCounted: nil
                ))
            ]
        }
        let records = try bodies.enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()

        let completed = try LiveGameSnapshotLoader.load(game: game, modelContext: context)
        #expect(completed.replay.state.half == .bottom)
        let restored = try GameEventCorrection.undoLatestAction(
            GameEventCorrection.prepareUndoLatestAction(game: game, modelContext: context),
            game: game,
            modelContext: context
        )

        #expect(restored.replay.state.half == .top)
        #expect(restored.replay.state.inning == 1)
        #expect(restored.replay.state.outs == 2)
        #expect(restored.replay.state.currentOpponentBatterSlot == 3)
        #expect(restored.replay.state.isAwaitingBallInPlayResult)
        #expect(restored.replay.state.pitchCount(for: pitcherID) == PitchCount(total: 3, balls: 0, strikes: 3))
    }

    @Test func undoBallFourRestoresCountBatterForcedRunnersScoreAndPitcherTotals() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = game.startingPitcherID!
        let bodies = twoConsecutiveSingles(pitcherID: pitcherID) + [
            .pitch(.init(result: .ballInPlay, pitcherID: pitcherID, opponentBatterSlot: 3)),
            .ballInPlay(.init(
                outcome: .single,
                opponentBatterSlot: 3,
                movements: [
                    .init(source: .second, destination: .third),
                    .init(source: .first, destination: .second),
                    .init(source: .batter, destination: .first)
                ],
                rbi: 0,
                thirdOutRunsCounted: nil
            )),
            .pitch(.init(result: .ball, pitcherID: pitcherID, opponentBatterSlot: 4)),
            .pitch(.init(result: .ball, pitcherID: pitcherID, opponentBatterSlot: 4)),
            .pitch(.init(result: .ball, pitcherID: pitcherID, opponentBatterSlot: 4)),
            .pitch(.init(result: .ball, pitcherID: pitcherID, opponentBatterSlot: 4))
        ]
        let records = try bodies.enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()

        let completed = try LiveGameSnapshotLoader.load(game: game, modelContext: context)
        #expect(completed.replay.state.currentOpponentBatterSlot == 5)
        #expect(completed.replay.state.awayScore == 1)
        #expect(completed.replay.state.firstBaseRunnerSlot == 4)
        #expect(completed.replay.state.secondBaseRunnerSlot == 3)
        #expect(completed.replay.state.thirdBaseRunnerSlot == 2)

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )
        let restored = try GameEventCorrection.undoLatestAction(
            candidate,
            game: game,
            modelContext: context
        )

        #expect(candidate.action == .pitch(.ball))
        #expect(candidate.opponentBatterSlot == 4)
        #expect(candidate.confirmationDetail.contains("completed the plate appearance for opponent batting slot 4"))
        #expect(restored.records.map(\.id) == Array(records.dropLast()).map(\.id))
        #expect(restored.replay.state.balls == 3)
        #expect(restored.replay.state.strikes == 0)
        #expect(restored.replay.state.currentOpponentBatterSlot == 4)
        #expect(restored.replay.state.awayScore == 0)
        #expect(restored.replay.state.firstBaseRunnerSlot == 3)
        #expect(restored.replay.state.secondBaseRunnerSlot == 2)
        #expect(restored.replay.state.thirdBaseRunnerSlot == 1)
        #expect(restored.replay.state.pitchCount(for: pitcherID) == PitchCount(total: 6, balls: 3, strikes: 3))
    }

    @Test func undoHitByPitchRemovesAwardedBaseAndEveryForcedMovement() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = game.startingPitcherID!
        let bodies = twoConsecutiveSingles(pitcherID: pitcherID) + [
            .pitch(.init(result: .hitByPitch, pitcherID: pitcherID, opponentBatterSlot: 3))
        ]
        let records = try bodies.enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(context.insert)
        try context.save()

        let completed = try LiveGameSnapshotLoader.load(game: game, modelContext: context)
        #expect(completed.replay.state.currentOpponentBatterSlot == 4)
        #expect(completed.replay.state.firstBaseRunnerSlot == 3)
        #expect(completed.replay.state.secondBaseRunnerSlot == 2)
        #expect(completed.replay.state.thirdBaseRunnerSlot == 1)

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )
        let restored = try GameEventCorrection.undoLatestAction(
            candidate,
            game: game,
            modelContext: context
        )

        #expect(candidate.action == .pitch(.hitByPitch))
        #expect(candidate.completedPlateAppearance)
        #expect(restored.records.map(\.id) == Array(records.dropLast()).map(\.id))
        #expect(restored.replay.state.currentOpponentBatterSlot == 3)
        #expect(restored.replay.state.firstBaseRunnerSlot == 2)
        #expect(restored.replay.state.secondBaseRunnerSlot == 1)
        #expect(restored.replay.state.thirdBaseRunnerSlot == nil)
        #expect(restored.replay.state.pitchCount(for: pitcherID) == PitchCount(total: 2, balls: 0, strikes: 2))
    }

    @Test(arguments: [PitchResult.calledStrike, .swingingStrike])
    func undoStrikeThreeRestoresTwoStrikeCountOutsBatterAndHalfInning(
        _ strikeResult: PitchResult
    ) throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = game.startingPitcherID!
        let records = try (1...9).map { sequence in
            let batterSlot = ((sequence - 1) / 3) + 1
            return try GameEventRecord(
                gameID: game.id,
                sequenceNumber: sequence,
                body: .pitch(.init(
                    result: strikeResult,
                    pitcherID: pitcherID,
                    opponentBatterSlot: batterSlot
                ))
            )
        }
        records.forEach(context.insert)
        try context.save()

        let completed = try LiveGameSnapshotLoader.load(game: game, modelContext: context)
        #expect(completed.replay.state.inning == 1)
        #expect(completed.replay.state.half == .bottom)
        #expect(completed.replay.state.outs == 0)
        #expect(completed.replay.state.currentOpponentBatterSlot == 4)

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )
        let restored = try GameEventCorrection.undoLatestAction(
            candidate,
            game: game,
            modelContext: context
        )

        #expect(candidate.action == .pitch(strikeResult))
        #expect(candidate.opponentBatterSlot == 3)
        #expect(candidate.completedPlateAppearance)
        #expect(restored.records.map(\.id) == Array(records.dropLast()).map(\.id))
        #expect(restored.replay.state.inning == 1)
        #expect(restored.replay.state.half == .top)
        #expect(restored.replay.state.outs == 2)
        #expect(restored.replay.state.balls == 0)
        #expect(restored.replay.state.strikes == 2)
        #expect(restored.replay.state.currentOpponentBatterSlot == 3)
        #expect(restored.replay.state.pitchCount(for: pitcherID) == PitchCount(total: 8, balls: 0, strikes: 8))
    }

    @Test func preparingUndoThenCancellingLeavesDurableTimelineAndSnapshotUnchanged() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        context.insert(try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .pitch(.init(
                result: .ball,
                pitcherID: game.startingPitcherID!,
                opponentBatterSlot: 1
            ))
        ))
        try context.save()
        let before = try LiveGameSnapshotLoader.load(game: game, modelContext: context)

        _ = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        let freshContext = ModelContext(container)
        let after = try LiveGameSnapshotLoader.load(game: game, modelContext: freshContext)
        #expect(after.records.map(\.id) == before.records.map(\.id))
        #expect(after.records.map(\.sequenceNumber) == before.records.map(\.sequenceNumber))
        #expect(after.records.map(\.timestamp) == before.records.map(\.timestamp))
        #expect(after.replay.state == before.replay.state)
        #expect(after.battingLines == before.battingLines)
        #expect(after.history == before.history)
    }

    @Test func undoUsesOnlyFreshlyPersistedRecordsAndDoesNotSavePendingContextChanges() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        context.insert(try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .pitch(.init(
                result: .ball,
                pitcherID: game.startingPitcherID!,
                opponentBatterSlot: 1
            ))
        ))
        try context.save()
        context.insert(try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 2,
            body: .pitch(.init(
                result: .calledStrike,
                pitcherID: game.startingPitcherID!,
                opponentBatterSlot: 1
            ))
        ))

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )
        _ = try GameEventCorrection.undoLatestAction(
            candidate,
            game: game,
            modelContext: context
        )

        let durableRecords = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>())
        #expect(candidate.sequenceNumber == 1)
        #expect(durableRecords.isEmpty)
        #expect(context.hasChanges)
    }

    @Test(arguments: [
        PitchResult.ball,
        .calledStrike,
        .swingingStrike,
        .foul
    ])
    func undoSupportsEveryNonTerminalDefensiveCountPitch(_ result: PitchResult) throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        context.insert(try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .pitch(.init(
                result: result,
                pitcherID: game.startingPitcherID!,
                opponentBatterSlot: 1
            ))
        ))
        try context.save()

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )
        let snapshot = try GameEventCorrection.undoLatestAction(
            candidate,
            game: game,
            modelContext: context
        )

        #expect(snapshot.records.isEmpty)
        #expect(snapshot.replay.state == GameState())
    }

    @Test func undoRejectsWrongGameMovedLatestActionAndStaleTimeline() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let record = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .pitch(.init(
                result: .ball,
                pitcherID: game.startingPitcherID!,
                opponentBatterSlot: 1
            ))
        )
        context.insert(record)
        try context.save()
        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        #expect(throws: GameEventCorrectionError.gameMismatch) {
            _ = try GameEventCorrection.undoLatestAction(
                candidate,
                game: makeGame(),
                modelContext: context
            )
        }

        record.payload = try GameEventCodec.encode(.pitch(.init(
            result: .calledStrike,
            pitcherID: game.startingPitcherID!,
            opponentBatterSlot: 1
        ))).payload
        try context.save()
        #expect(throws: GameEventCorrectionError.staleTimeline) {
            _ = try GameEventCorrection.undoLatestAction(
                candidate,
                game: game,
                modelContext: context
            )
        }

        let refreshedCandidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )
        context.insert(try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 2,
            body: .pitch(.init(
                result: .ball,
                pitcherID: game.startingPitcherID!,
                opponentBatterSlot: 1
            ))
        ))
        try context.save()
        #expect(throws: GameEventCorrectionError.latestActionChanged) {
            _ = try GameEventCorrection.undoLatestAction(
                refreshedCandidate,
                game: game,
                modelContext: context
            )
        }
    }

    @Test func undoRejectsBallInPlayOrCorruptLatestActions() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = game.startingPitcherID!
        context.insert(try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .pitch(.init(
                result: .ballInPlay,
                pitcherID: pitcherID,
                opponentBatterSlot: 1
            ))
        ))
        try context.save()

        #expect(throws: GameEventCorrectionError.noUndoAvailable) {
            _ = try GameEventCorrection.prepareUndoLatestAction(
                game: game,
                modelContext: context
            )
        }

        let corrupt = try #require(try context.fetch(FetchDescriptor<GameEventRecord>()).first)
        corrupt.kindRawValue = "unknown"
        try context.save()
        #expect(throws: GameEventCorrectionError.invalidTimeline) {
            _ = try GameEventCorrection.prepareUndoLatestAction(
                game: game,
                modelContext: context
            )
        }
    }

    @Test func undoOffersLatestCompletedBallInPlayResultAsOneScoringAction() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        context.insert(try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .pitch(.init(
                result: .ballInPlay,
                pitcherID: game.startingPitcherID!,
                opponentBatterSlot: 1
            ))
        ))
        context.insert(try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 2,
            body: .ballInPlay(.init(
                outcome: .single,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                thirdOutRunsCounted: nil
            ))
        ))
        try context.save()

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        let latestRecordID = try context.fetch(FetchDescriptor<GameEventRecord>())
            .first { $0.sequenceNumber == 2 }?.id
        #expect(candidate.id == latestRecordID)
        #expect(candidate.action == .ballInPlayResult(.single))
    }

    @Test func cancellingBallInPlayResultUndoLeavesCompletedPlayIntact() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let records = try seedCompletedSingle(game: game, modelContext: context)
        let before = try LiveGameSnapshotLoader.load(game: game, modelContext: context)

        _ = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        let after = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(after.records.map(\.id) == records.map(\.id))
        #expect(after.replay.state == before.replay.state)
        #expect(!after.replay.state.isAwaitingBallInPlayResult)
    }

    @Test func invalidBallInPlayCandidateReplayLeavesCompletedRecordsIntact() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let records = try seedCompletedSingle(game: game, modelContext: context)
        records[1].payload = try GameEventCodec.encode(.ballInPlay(.init(
            outcome: .single,
            opponentBatterSlot: 1,
            movements: [],
            rbi: 0,
            thirdOutRunsCounted: nil
        ))).payload
        try context.save()

        #expect(throws: GameEventCorrectionError.invalidTimeline) {
            _ = try GameEventCorrection.prepareUndoLatestAction(
                game: game,
                modelContext: context
            )
        }

        let stored = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>())
        let storedIDs = stored.map(\.id).sorted { $0.uuidString < $1.uuidString }
        let originalIDs = records.map(\.id).sorted { $0.uuidString < $1.uuidString }
        #expect(storedIDs == originalIDs)
    }

    @Test func wrongGameAndStaleBallInPlayUndoLeaveCompletedPlayIntact() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let records = try seedCompletedSingle(game: game, modelContext: context)
        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        #expect(throws: GameEventCorrectionError.gameMismatch) {
            _ = try GameEventCorrection.undoLatestAction(
                candidate,
                game: makeGame(),
                modelContext: context
            )
        }
        #expect(try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>()).count == 2)

        records[1].payload = try GameEventCodec.encode(.ballInPlay(.init(
            outcome: .double,
            opponentBatterSlot: 1,
            movements: [.init(source: .batter, destination: .second)],
            rbi: 0,
            thirdOutRunsCounted: nil
        ))).payload
        try context.save()
        #expect(throws: GameEventCorrectionError.staleTimeline) {
            _ = try GameEventCorrection.undoLatestAction(
                candidate,
                game: game,
                modelContext: context
            )
        }
        #expect(try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>()).count == 2)
    }

    @Test func failedBallInPlayResultUndoSaveRollsBackCompletedPlay() throws {
        struct ForcedSaveError: Error {}

        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let records = try seedCompletedSingle(game: game, modelContext: context)
        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        #expect(throws: ForcedSaveError.self) {
            _ = try GameEventCorrection.undoLatestAction(
                candidate,
                game: game,
                modelContext: context,
                save: { _ in throw ForcedSaveError() }
            )
        }

        let stored = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>())
            .sorted { $0.sequenceNumber < $1.sequenceNumber }
        let storedBody = try stored[1].decoded().body
        let originalBody = try records[1].decoded().body
        #expect(stored.map(\.id) == records.map(\.id))
        #expect(stored.map(\.sequenceNumber) == [1, 2])
        #expect(storedBody == originalBody)
    }

    @Test func pendingBallInPlayStateSurvivesFreshContextAndColdStoreReloadAfterUndo() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appending(path: "softball-scoring-bip-undo-reload-\(UUID().uuidString).store")
        let gameID = UUID()
        let pitcherID = UUID()
        var expectedState: GameState?
        var expectedRecordID: UUID?

        do {
            let container = try AppModelContainer.make(storeURL: storeURL)
            let context = container.mainContext
            let game = Game(
                id: gameID,
                seasonID: UUID(),
                opponentName: "Thunder",
                homeAway: .home,
                status: .inProgress,
                startingPitcherID: pitcherID
            )
            context.insert(game)
            let records = try seedCompletedSingle(game: game, modelContext: context)
            let restored = try GameEventCorrection.undoLatestAction(
                GameEventCorrection.prepareUndoLatestAction(game: game, modelContext: context),
                game: game,
                modelContext: context
            )
            expectedState = restored.replay.state
            expectedRecordID = records[0].id

            let freshContext = ModelContext(container)
            let freshGame = try #require(freshContext.fetch(FetchDescriptor<Game>()).first)
            let fresh = try LiveGameSnapshotLoader.load(game: freshGame, modelContext: freshContext)
            #expect(fresh.replay.state == expectedState)
            #expect(fresh.records.count == 1)
            #expect(fresh.records.first?.id == expectedRecordID)
            #expect(fresh.replay.state.isAwaitingBallInPlayResult)
            #expect(fresh.replay.state.pitchCount(for: pitcherID) == PitchCount(total: 1, balls: 0, strikes: 1))
        }

        let reloadedContainer = try AppModelContainer.make(storeURL: storeURL)
        let reloadedContext = ModelContext(reloadedContainer)
        let reloadedGame = try #require(reloadedContext.fetch(FetchDescriptor<Game>()).first)
        let reloaded = try LiveGameSnapshotLoader.load(
            game: reloadedGame,
            modelContext: reloadedContext
        )
        #expect(reloaded.replay.state == expectedState)
        #expect(reloaded.records.count == 1)
        #expect(reloaded.records.first?.id == expectedRecordID)
        #expect(reloaded.replay.state.isAwaitingBallInPlayResult)
    }

    @Test func failedUndoSaveRollsBackEveryOriginalRecord() throws {
        struct ForcedSaveError: Error {}

        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let records = try [PitchResult.ball, .calledStrike].enumerated().map { index, result in
            try GameEventRecord(
                gameID: game.id,
                sequenceNumber: index + 1,
                body: .pitch(.init(
                    result: result,
                    pitcherID: game.startingPitcherID!,
                    opponentBatterSlot: 1
                ))
            )
        }
        records.forEach(context.insert)
        try context.save()
        let expectedIDs = records.map(\.id)
        let expectedSequences = records.map(\.sequenceNumber)
        let expectedTimestamps = records.map(\.timestamp)
        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )

        #expect(throws: ForcedSaveError.self) {
            _ = try GameEventCorrection.undoLatestAction(
                candidate,
                game: game,
                modelContext: context,
                save: { _ in throw ForcedSaveError() }
            )
        }

        let stored = try context.fetch(FetchDescriptor<GameEventRecord>())
            .sorted { $0.sequenceNumber < $1.sequenceNumber }
        #expect(stored.map(\.id) == expectedIDs)
        #expect(stored.map(\.sequenceNumber) == expectedSequences)
        #expect(stored.map(\.timestamp) == expectedTimestamps)
    }

    @Test func scoringAfterUndoUsesMaximumSurvivingSequenceWithoutCollision() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let first = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 2,
            body: .pitch(.init(
                result: .ball,
                pitcherID: game.startingPitcherID!,
                opponentBatterSlot: 1
            ))
        )
        let latest = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 7,
            body: .pitch(.init(
                result: .calledStrike,
                pitcherID: game.startingPitcherID!,
                opponentBatterSlot: 1
            ))
        )
        context.insert(first)
        context.insert(latest)
        try context.save()

        let candidate = try GameEventCorrection.prepareUndoLatestAction(
            game: game,
            modelContext: context
        )
        let corrected = try GameEventCorrection.undoLatestAction(
            candidate,
            game: game,
            modelContext: context
        )
        try GameEventRecorder.recordPitch(
            result: .foul,
            game: game,
            existingRecords: corrected.records,
            modelContext: context
        )

        let stored = try context.fetch(FetchDescriptor<GameEventRecord>())
        #expect(stored.map(\.sequenceNumber).sorted() == [2, 3])
        #expect(stored.first { $0.id == first.id }?.timestamp == first.timestamp)
        #expect(!stored.contains { $0.id == latest.id })
    }

    @Test func undoSurvivesFreshPersistenceContextAndColdStoreReload() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appending(path: "softball-scoring-undo-reload-\(UUID().uuidString).store")
        let gameID = UUID()
        let pitcherID = UUID()
        let batters = (1...4).map { slot in
            TrackedBatterIdentity(
                playerID: UUID(),
                lineupSlot: slot,
                displayName: "Batter \(slot)",
                jerseyNumber: "\(slot)",
                position: nil
            )
        }
        var expectedState: GameState?
        var expectedBattingLines: [UUID: BattingLine]?
        var expectedHistory: PlayHistory?
        var expectedRecordIDs: [UUID]?
        var expectedSequences: [Int]?
        var expectedTimestamps: [Date]?

        do {
            let container = try AppModelContainer.make(storeURL: storeURL)
            let context = container.mainContext
            let game = Game(
                id: gameID,
                seasonID: UUID(),
                opponentName: "Thunder",
                homeAway: .away,
                status: .inProgress,
                startingPitcherID: pitcherID
            )
            context.insert(game)
            let bodies: [GameEventBody] = [
                .offensivePlateAppearance(.init(
                    batter: batters[0],
                    battingOrderSize: batters.count,
                    result: .homeRun,
                    movements: [.init(source: .batter, destination: .home)],
                    rbi: 1,
                    countedRunSources: [.batter],
                    thirdOutClassification: nil
                )),
                .offensivePlateAppearance(.init(
                    batter: batters[1],
                    battingOrderSize: batters.count,
                    result: .strikeout,
                    movements: [.init(source: .batter, destination: .out)],
                    rbi: 0,
                    countedRunSources: [],
                    thirdOutClassification: nil
                )),
                .offensivePlateAppearance(.init(
                    batter: batters[2],
                    battingOrderSize: batters.count,
                    result: .strikeout,
                    movements: [.init(source: .batter, destination: .out)],
                    rbi: 0,
                    countedRunSources: [],
                    thirdOutClassification: nil
                )),
                .offensivePlateAppearance(.init(
                    batter: batters[3],
                    battingOrderSize: batters.count,
                    result: .strikeout,
                    movements: [.init(source: .batter, destination: .out)],
                    rbi: 0,
                    countedRunSources: [],
                    thirdOutClassification: nil
                )),
                .pitch(.init(result: .calledStrike, pitcherID: pitcherID, opponentBatterSlot: 1)),
                .pitch(.init(result: .calledStrike, pitcherID: pitcherID, opponentBatterSlot: 1)),
                .pitch(.init(result: .calledStrike, pitcherID: pitcherID, opponentBatterSlot: 1))
            ]
            for (index, body) in bodies.enumerated() {
                context.insert(try GameEventRecord(
                    gameID: gameID,
                    sequenceNumber: index + 1,
                    body: body
                ))
            }
            try context.save()
            let diagnostic = try LiveGameSnapshotLoader.load(game: game, modelContext: context)
            #expect(
                diagnostic.replay.rejectedRecordIDs.isEmpty,
                "Rejected entries: \(diagnostic.replay.entries.map { ($0.sequenceNumber, String(describing: $0.rejection)) })"
            )

            let candidate = try GameEventCorrection.prepareUndoLatestAction(
                game: game,
                modelContext: context
            )
            let immediate = try GameEventCorrection.undoLatestAction(
                candidate,
                game: game,
                modelContext: context
            )
            expectedState = immediate.replay.state
            expectedBattingLines = immediate.battingLines
            expectedHistory = immediate.history
            expectedRecordIDs = immediate.records.map(\.id)
            expectedSequences = immediate.records.map(\.sequenceNumber)
            expectedTimestamps = immediate.records.map(\.timestamp)
            #expect(immediate.replay.state.half == .bottom)
            #expect(immediate.replay.state.outs == 0)
            #expect(immediate.replay.state.currentOpponentBatterSlot == 1)
            #expect(immediate.replay.state.balls == 0)
            #expect(immediate.replay.state.strikes == 2)
            #expect(immediate.replay.state.pitchCount(for: pitcherID) == PitchCount(total: 2, balls: 0, strikes: 2))
            #expect(immediate.battingLines[batters[0].playerID]?.homeRuns == 1)

            let freshContext = ModelContext(container)
            let freshGame = try #require(freshContext.fetch(FetchDescriptor<Game>()).first)
            let fresh = try LiveGameSnapshotLoader.load(game: freshGame, modelContext: freshContext)
            #expect(fresh.replay.state == expectedState)
            #expect(fresh.battingLines == expectedBattingLines)
            #expect(fresh.history == expectedHistory)
            #expect(fresh.records.map(\.id) == expectedRecordIDs)
            #expect(fresh.records.map(\.sequenceNumber) == expectedSequences)
            #expect(fresh.records.map(\.timestamp) == expectedTimestamps)
        }

        let reloadedContainer = try AppModelContainer.make(storeURL: storeURL)
        let reloadedContext = ModelContext(reloadedContainer)
        let reloadedGame = try #require(reloadedContext.fetch(FetchDescriptor<Game>()).first)
        let reloaded = try LiveGameSnapshotLoader.load(
            game: reloadedGame,
            modelContext: reloadedContext
        )
        #expect(reloaded.replay.state == expectedState)
        #expect(reloaded.battingLines == expectedBattingLines)
        #expect(reloaded.history == expectedHistory)
        #expect(reloaded.records.map(\.id) == expectedRecordIDs)
        #expect(reloaded.records.map(\.sequenceNumber) == expectedSequences)
        #expect(reloaded.records.map(\.timestamp) == expectedTimestamps)
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

    @Test func stagedDefensivePitchDeletionSavesExactRecordAndPreservesSequenceGap() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let timestamps = [
            Date(timeIntervalSince1970: 1_786_600_000),
            Date(timeIntervalSince1970: 1_786_600_010),
            Date(timeIntervalSince1970: 1_786_600_020)
        ]
        let results: [PitchResult] = [.ball, .calledStrike, .foul]
        let records = try results.enumerated().map { index, result in
            try GameEventRecord(
                gameID: game.id,
                sequenceNumber: index + 1,
                timestamp: timestamps[index],
                body: .pitch(.init(
                    result: result,
                    pitcherID: pitcherID,
                    opponentBatterSlot: 1
                ))
            )
        }
        records.forEach(context.insert)
        try context.save()

        let session = try GameEventCorrection.prepareDefensivePitchDeletion(
            recordID: records[1].id,
            game: game,
            modelContext: context
        )
        let preview = try GameEventCorrection.stageDefensivePitchDeletion(
            session,
            game: game,
            modelContext: context
        )

        #expect(session.originalResult == .calledStrike)
        #expect(preview.canSave)
        #expect(preview.firstInvalidRecord == nil)
        #expect(preview.snapshot.records.map(\.sequenceNumber) == [1, 3])
        #expect(preview.snapshot.replay.state.balls == 1)
        #expect(preview.snapshot.replay.state.strikes == 1)
        #expect(preview.snapshot.replay.state.pitchCount(for: pitcherID) == PitchCount(
            total: 2,
            balls: 1,
            strikes: 1
        ))

        let stagedStored = try context.fetch(FetchDescriptor<GameEventRecord>(
            sortBy: [SortDescriptor(\GameEventRecord.sequenceNumber)]
        ))
        #expect(stagedStored.map(\.id) == records.map(\.id))

        _ = try GameEventCorrection.saveDefensivePitchDeletion(
            preview,
            game: game,
            modelContext: context
        )

        let reloaded = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(reloaded.records.map(\.id) == [records[0].id, records[2].id])
        #expect(reloaded.records.map(\.sequenceNumber) == [1, 3])
        #expect(reloaded.records.map(\.timestamp) == [timestamps[0], timestamps[2]])
        #expect(reloaded.replay.state.balls == 1)
        #expect(reloaded.replay.state.strikes == 1)
        #expect(reloaded.replay.state.pitchCount(for: pitcherID) == PitchCount(
            total: 2,
            balls: 1,
            strikes: 1
        ))
    }

    @Test func deletingPitchThatInvalidatesLaterPlayDisablesSaveAndPreservesHistory() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let pitch = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .pitch(.init(
                result: .ballInPlay,
                pitcherID: pitcherID,
                opponentBatterSlot: 1
            ))
        )
        let result = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 2,
            body: .ballInPlay(.init(
                outcome: .single,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                thirdOutRunsCounted: nil
            ))
        )
        context.insert(pitch)
        context.insert(result)
        try context.save()

        let session = try GameEventCorrection.prepareDefensivePitchDeletion(
            recordID: pitch.id,
            game: game,
            modelContext: context
        )
        let preview = try GameEventCorrection.stageDefensivePitchDeletion(
            session,
            game: game,
            modelContext: context
        )

        #expect(!preview.canSave)
        #expect(preview.firstInvalidRecord == DefensivePitchEditInvalidRecord(
            id: result.id,
            sequenceNumber: 2,
            summary: "Play conflicts with the proposed pitch"
        ))
        #expect(preview.snapshot.replay.rejectedRecordIDs == [result.id])
        #expect(throws: GameEventCorrectionError.invalidCandidate) {
            _ = try GameEventCorrection.saveDefensivePitchDeletion(
                preview,
                game: game,
                modelContext: context
            )
        }

        let stored = try context.fetch(FetchDescriptor<GameEventRecord>(
            sortBy: [SortDescriptor(\GameEventRecord.sequenceNumber)]
        ))
        #expect(stored.map(\.id) == [pitch.id, result.id])
    }

    @Test func rejectedPitchDeletionInputsAndSaveFailurePreserveEveryRecord() throws {
        struct ProjectionFailure: Error {}
        struct SaveFailure: Error {}

        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let otherGame = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let original = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .pitch(.init(
                result: .ball,
                pitcherID: pitcherID,
                opponentBatterSlot: 1
            ))
        )
        context.insert(original)
        try context.save()

        let session = try GameEventCorrection.prepareDefensivePitchDeletion(
            recordID: original.id,
            game: game,
            modelContext: context
        )
        #expect(throws: GameEventCorrectionError.gameMismatch) {
            _ = try GameEventCorrection.stageDefensivePitchDeletion(
                session,
                game: otherGame,
                modelContext: context
            )
        }
        #expect(throws: ProjectionFailure.self) {
            _ = try GameEventCorrection.stageDefensivePitchDeletion(
                session,
                game: game,
                modelContext: context,
                projectBattingLines: { _ in throw ProjectionFailure() }
            )
        }

        let preview = try GameEventCorrection.stageDefensivePitchDeletion(
            session,
            game: game,
            modelContext: context
        )
        #expect(throws: GameEventCorrectionError.gameMismatch) {
            _ = try GameEventCorrection.saveDefensivePitchDeletion(
                preview,
                game: otherGame,
                modelContext: context
            )
        }
        #expect(throws: SaveFailure.self) {
            _ = try GameEventCorrection.saveDefensivePitchDeletion(
                preview,
                game: game,
                modelContext: context,
                save: { _ in throw SaveFailure() }
            )
        }

        var stored = try context.fetch(FetchDescriptor<GameEventRecord>())
        #expect(stored.map(\.id) == [original.id])

        let newer = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 2,
            body: .pitch(.init(
                result: .foul,
                pitcherID: pitcherID,
                opponentBatterSlot: 1
            ))
        )
        context.insert(newer)
        try context.save()
        #expect(throws: GameEventCorrectionError.staleTimeline) {
            _ = try GameEventCorrection.stageDefensivePitchDeletion(
                session,
                game: game,
                modelContext: context
            )
        }

        stored = try context.fetch(FetchDescriptor<GameEventRecord>(
            sortBy: [SortDescriptor(\GameEventRecord.sequenceNumber)]
        ))
        #expect(stored.map(\.id) == [original.id, newer.id])
    }

    @Test func recordingAfterPitchDeletionUsesMaximumSurvivingSequence() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let sequences = [1, 2, 4]
        let results: [PitchResult] = [.ball, .calledStrike, .foul]
        let records = try zip(sequences, results).map { sequence, result in
            try GameEventRecord(
                gameID: game.id,
                sequenceNumber: sequence,
                body: .pitch(.init(
                    result: result,
                    pitcherID: pitcherID,
                    opponentBatterSlot: 1
                ))
            )
        }
        records.forEach(context.insert)
        try context.save()

        let session = try GameEventCorrection.prepareDefensivePitchDeletion(
            recordID: records[1].id,
            game: game,
            modelContext: context
        )
        let preview = try GameEventCorrection.stageDefensivePitchDeletion(
            session,
            game: game,
            modelContext: context
        )
        let corrected = try GameEventCorrection.saveDefensivePitchDeletion(
            preview,
            game: game,
            modelContext: context
        )

        try GameEventRecorder.recordPitch(
            result: .calledStrike,
            game: game,
            existingRecords: corrected.records,
            modelContext: context
        )

        let reloaded = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(reloaded.records.map(\.sequenceNumber) == [1, 4, 5])
        #expect(reloaded.replay.rejectedRecordIDs.isEmpty)
        #expect(reloaded.replay.state.balls == 1)
        #expect(reloaded.replay.state.strikes == 2)
    }

    @Test func defensivePitchDeletionSurvivesColdStoreReload() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appending(path: "softball-scoring-pitch-deletion-reload-\(UUID().uuidString).store")
        let gameID = UUID()
        let pitcherID = UUID()

        do {
            let container = try AppModelContainer.make(storeURL: storeURL)
            let context = container.mainContext
            let game = Game(
                id: gameID,
                seasonID: UUID(),
                opponentName: "Thunder",
                homeAway: .home,
                status: .inProgress,
                startingPitcherID: pitcherID
            )
            context.insert(game)
            let records = try [PitchResult.ball, .calledStrike, .foul]
                .enumerated()
                .map { index, result in
                    try GameEventRecord(
                        gameID: gameID,
                        sequenceNumber: index + 1,
                        body: .pitch(.init(
                            result: result,
                            pitcherID: pitcherID,
                            opponentBatterSlot: 1
                        ))
                    )
                }
            records.forEach(context.insert)
            try context.save()
            let session = try GameEventCorrection.prepareDefensivePitchDeletion(
                recordID: records[1].id,
                game: game,
                modelContext: context
            )
            let preview = try GameEventCorrection.stageDefensivePitchDeletion(
                session,
                game: game,
                modelContext: context
            )
            _ = try GameEventCorrection.saveDefensivePitchDeletion(
                preview,
                game: game,
                modelContext: context
            )
        }

        let reloadedContainer = try AppModelContainer.make(storeURL: storeURL)
        let reloadedContext = ModelContext(reloadedContainer)
        let reloadedGame = try #require(reloadedContext.fetch(FetchDescriptor<Game>()).first)
        let reloaded = try LiveGameSnapshotLoader.load(
            game: reloadedGame,
            modelContext: reloadedContext
        )

        #expect(reloaded.records.map(\.sequenceNumber) == [1, 3])
        #expect(reloaded.replay.state.balls == 1)
        #expect(reloaded.replay.state.strikes == 1)
        #expect(reloaded.replay.state.pitchCount(for: pitcherID) == PitchCount(
            total: 2,
            balls: 1,
            strikes: 1
        ))
        #expect(reloaded.history.sections[0].entries[0].components.map(\.summary) == [
            "Ball", "Foul"
        ])
    }

    @Test func stagedDefensivePitchEditReplaysBeforeSavingAndPreservesRecordIdentity() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let originalTimestamp = Date(timeIntervalSince1970: 1_786_600_000)
        let original = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            timestamp: originalTimestamp,
            body: .pitch(.init(
                result: .ball,
                pitcherID: pitcherID,
                opponentBatterSlot: 1
            ))
        )
        let later = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 2,
            body: .pitch(.init(
                result: .calledStrike,
                pitcherID: pitcherID,
                opponentBatterSlot: 1
            ))
        )
        context.insert(original)
        context.insert(later)
        try context.save()

        let session = try GameEventCorrection.prepareDefensivePitchEdit(
            recordID: original.id,
            game: game,
            modelContext: context
        )
        let preview = try GameEventCorrection.stageDefensivePitchEdit(
            .swingingStrike,
            in: session,
            game: game,
            modelContext: context
        )

        #expect(session.inning == 1)
        #expect(session.half == .top)
        #expect(session.opponentBatterSlot == 1)
        #expect(session.originalResult == .ball)
        #expect(session.stateBefore.balls == 0)
        #expect(session.stateBefore.strikes == 0)
        #expect(session.originalStateAfter.balls == 1)
        #expect(preview.proposedResult == .swingingStrike)
        #expect(preview.canSave)
        #expect(preview.firstInvalidRecord == nil)
        #expect(preview.snapshot.replay.state.balls == 0)
        #expect(preview.snapshot.replay.state.strikes == 2)
        #expect(preview.snapshot.replay.state.pitchCount(for: pitcherID) == PitchCount(
            total: 2,
            balls: 0,
            strikes: 2
        ))

        let stagedStored = try context.fetch(FetchDescriptor<GameEventRecord>(
            sortBy: [SortDescriptor(\GameEventRecord.sequenceNumber)]
        ))
        #expect(try stagedStored[0].decoded().body == .pitch(.init(
            result: .ball,
            pitcherID: pitcherID,
            opponentBatterSlot: 1
        )))

        let saved = try GameEventCorrection.saveDefensivePitchEdit(
            preview,
            game: game,
            modelContext: context
        )

        #expect(saved.records.map(\.id) == [original.id, later.id])
        #expect(saved.records.map(\.sequenceNumber) == [1, 2])
        #expect(saved.records[0].gameID == game.id)
        #expect(saved.records[0].timestamp == originalTimestamp)
        #expect(try saved.records[0].decoded().body == .pitch(.init(
            result: .swingingStrike,
            pitcherID: pitcherID,
            opponentBatterSlot: 1
        )))

        let freshContext = ModelContext(container)
        let persisted = try freshContext.fetch(FetchDescriptor<GameEventRecord>(
            sortBy: [SortDescriptor(\GameEventRecord.sequenceNumber)]
        ))
        #expect(persisted.map(\.id) == [original.id, later.id])
        #expect(persisted[0].timestamp == originalTimestamp)
        #expect(try persisted[0].decoded().body == .pitch(.init(
            result: .swingingStrike,
            pitcherID: pitcherID,
            opponentBatterSlot: 1
        )))
    }

    @Test(arguments: defensivePitchEditScenarios)
    fileprivate func defensivePitchEditSavesEverySupportedReplacementAtCountBoundaries(
        _ scenario: DefensivePitchEditScenario
    ) throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let results = scenario.precedingResults + [scenario.originalResult]
        let records = try results.enumerated().map { index, result in
            try GameEventRecord(
                gameID: game.id,
                sequenceNumber: index + 1,
                body: .pitch(.init(
                    result: result,
                    pitcherID: pitcherID,
                    opponentBatterSlot: 1
                ))
            )
        }
        records.forEach(context.insert)
        try context.save()

        let selectedRecord = try #require(records.last)
        let session = try GameEventCorrection.prepareDefensivePitchEdit(
            recordID: selectedRecord.id,
            game: game,
            modelContext: context
        )
        let preview = try GameEventCorrection.stageDefensivePitchEdit(
            scenario.proposedResult,
            in: session,
            game: game,
            modelContext: context
        )
        let saved = try GameEventCorrection.saveDefensivePitchEdit(
            preview,
            game: game,
            modelContext: context
        )

        #expect(preview.canSave)
        #expect(saved.replay.rejectedRecordIDs.isEmpty)
        #expect(saved.replay.state.balls == scenario.expectedBalls)
        #expect(saved.replay.state.strikes == scenario.expectedStrikes)
        #expect(saved.replay.state.currentOpponentBatterSlot == scenario.expectedBatterSlot)
        #expect(saved.replay.state.outs == scenario.expectedOuts)
        #expect(try saved.records.last?.decoded().body == .pitch(.init(
            result: scenario.proposedResult,
            pitcherID: pitcherID,
            opponentBatterSlot: 1
        )))
    }

    @Test func recordingAfterPitchEditUsesCorrectedMainContextAndNextSequence() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let records = try [PitchResult.ball, .calledStrike].enumerated().map { index, result in
            try GameEventRecord(
                gameID: game.id,
                sequenceNumber: index + 1,
                body: .pitch(.init(
                    result: result,
                    pitcherID: pitcherID,
                    opponentBatterSlot: 1
                ))
            )
        }
        records.forEach(context.insert)
        try context.save()
        let session = try GameEventCorrection.prepareDefensivePitchEdit(
            recordID: records[0].id,
            game: game,
            modelContext: context
        )
        let preview = try GameEventCorrection.stageDefensivePitchEdit(
            .swingingStrike,
            in: session,
            game: game,
            modelContext: context
        )
        let corrected = try GameEventCorrection.saveDefensivePitchEdit(
            preview,
            game: game,
            modelContext: context
        )

        try GameEventRecorder.recordPitch(
            result: .calledStrike,
            game: game,
            existingRecords: corrected.records,
            modelContext: context
        )

        let freshSnapshot = try LiveGameSnapshotLoader.load(
            game: game,
            modelContext: ModelContext(container)
        )
        #expect(freshSnapshot.records.map(\.sequenceNumber) == [1, 2, 3])
        #expect(freshSnapshot.replay.rejectedRecordIDs.isEmpty)
        #expect(freshSnapshot.replay.state.outs == 1)
        #expect(freshSnapshot.replay.state.currentOpponentBatterSlot == 2)
        #expect(freshSnapshot.replay.state.balls == 0)
        #expect(freshSnapshot.replay.state.strikes == 0)
    }

    @Test func pitchEditPerformsNoThrowableProjectionAfterCommit() throws {
        struct UnexpectedSecondProjection: Error {}

        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let original = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .pitch(.init(
                result: .ball,
                pitcherID: pitcherID,
                opponentBatterSlot: 1
            ))
        )
        context.insert(original)
        try context.save()
        let session = try GameEventCorrection.prepareDefensivePitchEdit(
            recordID: original.id,
            game: game,
            modelContext: context
        )
        let preview = try GameEventCorrection.stageDefensivePitchEdit(
            .calledStrike,
            in: session,
            game: game,
            modelContext: context
        )
        var projectionCalls = 0

        _ = try GameEventCorrection.saveDefensivePitchEdit(
            preview,
            game: game,
            modelContext: context,
            projectBattingLines: { events in
                projectionCalls += 1
                guard projectionCalls == 1 else { throw UnexpectedSecondProjection() }
                return try BattingStatProjector.project(events: events)
            }
        )

        #expect(projectionCalls == 1)
        let persisted = try ModelContext(container).fetch(FetchDescriptor<GameEventRecord>())
        #expect(try persisted.first?.decoded().body == .pitch(.init(
            result: .calledStrike,
            pitcherID: pitcherID,
            opponentBatterSlot: 1
        )))
    }

    @Test func defensivePitchEditSurvivesColdStoreReloadWithDerivedStateAndHistory() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appending(path: "softball-scoring-pitch-edit-reload-\(UUID().uuidString).store")
        let gameID = UUID()
        let pitcherID = UUID()
        let editedRecordID = UUID()
        let editedTimestamp = Date(timeIntervalSince1970: 1_786_600_100)

        do {
            let container = try AppModelContainer.make(storeURL: storeURL)
            let context = container.mainContext
            let game = Game(
                id: gameID,
                seasonID: UUID(),
                opponentName: "Thunder",
                homeAway: .home,
                status: .inProgress,
                startingPitcherID: pitcherID
            )
            context.insert(game)
            context.insert(try GameEventRecord(
                id: editedRecordID,
                gameID: gameID,
                sequenceNumber: 1,
                timestamp: editedTimestamp,
                body: .pitch(.init(
                    result: .ball,
                    pitcherID: pitcherID,
                    opponentBatterSlot: 1
                ))
            ))
            context.insert(try GameEventRecord(
                gameID: gameID,
                sequenceNumber: 2,
                body: .pitch(.init(
                    result: .calledStrike,
                    pitcherID: pitcherID,
                    opponentBatterSlot: 1
                ))
            ))
            try context.save()

            let session = try GameEventCorrection.prepareDefensivePitchEdit(
                recordID: editedRecordID,
                game: game,
                modelContext: context
            )
            let preview = try GameEventCorrection.stageDefensivePitchEdit(
                .swingingStrike,
                in: session,
                game: game,
                modelContext: context
            )
            _ = try GameEventCorrection.saveDefensivePitchEdit(
                preview,
                game: game,
                modelContext: context
            )
        }

        let reloadedContainer = try AppModelContainer.make(storeURL: storeURL)
        let reloadedContext = ModelContext(reloadedContainer)
        let reloadedGame = try #require(reloadedContext.fetch(FetchDescriptor<Game>()).first)
        let reloaded = try LiveGameSnapshotLoader.load(
            game: reloadedGame,
            modelContext: reloadedContext
        )

        #expect(reloaded.replay.state.balls == 0)
        #expect(reloaded.replay.state.strikes == 2)
        #expect(reloaded.replay.state.pitchCount(for: pitcherID) == PitchCount(
            total: 2,
            balls: 0,
            strikes: 2
        ))
        #expect(reloaded.records.map(\.sequenceNumber) == [1, 2])
        #expect(reloaded.records[0].id == editedRecordID)
        #expect(reloaded.records[0].gameID == gameID)
        #expect(reloaded.records[0].timestamp == editedTimestamp)
        #expect(try reloaded.records[0].decoded().body == .pitch(.init(
            result: .swingingStrike,
            pitcherID: pitcherID,
            opponentBatterSlot: 1
        )))
        #expect(reloaded.history.sections[0].entries[0].components.map(\.summary) == [
            "Swinging Strike", "Called Strike"
        ])
    }

    @Test func invalidDownstreamPitchDisablesSaveAndLeavesDurableTimelineUntouched() throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let results: [PitchResult] = [.calledStrike, .swingingStrike, .foul, .calledStrike]
        let records = try results.enumerated().map { index, result in
            try GameEventRecord(
                gameID: game.id,
                sequenceNumber: index + 1,
                body: .pitch(.init(
                    result: result,
                    pitcherID: pitcherID,
                    opponentBatterSlot: 1
                ))
            )
        }
        records.forEach(context.insert)
        try context.save()
        let originalRevisions = try records.map { try $0.decoded() }

        let session = try GameEventCorrection.prepareDefensivePitchEdit(
            recordID: records[2].id,
            game: game,
            modelContext: context
        )
        let preview = try GameEventCorrection.stageDefensivePitchEdit(
            .calledStrike,
            in: session,
            game: game,
            modelContext: context
        )

        #expect(!preview.canSave)
        #expect(preview.firstInvalidRecord == DefensivePitchEditInvalidRecord(
            id: records[3].id,
            sequenceNumber: 4,
            summary: "Play conflicts with the proposed pitch"
        ))
        #expect(preview.snapshot.replay.rejectedRecordIDs == [records[3].id])
        #expect(throws: GameEventCorrectionError.invalidCandidate) {
            _ = try GameEventCorrection.saveDefensivePitchEdit(
                preview,
                game: game,
                modelContext: context
            )
        }

        let stored = try context.fetch(FetchDescriptor<GameEventRecord>(
            sortBy: [SortDescriptor(\GameEventRecord.sequenceNumber)]
        ))
        #expect(stored.map(\.id) == records.map(\.id))
        #expect(try stored.map { try $0.decoded() } == originalRevisions)
    }

    @Test func rejectedPitchEditInputsAndSaveFailurePreserveEveryOriginalRecord() throws {
        struct ProjectionFailure: Error {}
        struct SaveFailure: Error {}

        let container = try AppModelContainer.make(inMemory: true)
        let context = container.mainContext
        let game = makeGame()
        let otherGame = makeGame()
        let pitcherID = try #require(game.startingPitcherID)
        let original = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 1,
            body: .pitch(.init(
                result: .ball,
                pitcherID: pitcherID,
                opponentBatterSlot: 1
            ))
        )
        context.insert(original)
        try context.save()

        let session = try GameEventCorrection.prepareDefensivePitchEdit(
            recordID: original.id,
            game: game,
            modelContext: context
        )
        #expect(throws: GameEventCorrectionError.gameMismatch) {
            _ = try GameEventCorrection.stageDefensivePitchEdit(
                .calledStrike,
                in: session,
                game: otherGame,
                modelContext: context
            )
        }
        #expect(throws: GameEventCorrectionError.pitchNotEditable) {
            _ = try GameEventCorrection.stageDefensivePitchEdit(
                .hitByPitch,
                in: session,
                game: game,
                modelContext: context
            )
        }
        #expect(throws: ProjectionFailure.self) {
            _ = try GameEventCorrection.stageDefensivePitchEdit(
                .calledStrike,
                in: session,
                game: game,
                modelContext: context,
                projectBattingLines: { _ in throw ProjectionFailure() }
            )
        }

        let preview = try GameEventCorrection.stageDefensivePitchEdit(
            .calledStrike,
            in: session,
            game: game,
            modelContext: context
        )
        let forgedUnsupportedPreview = DefensivePitchEditPreview(
            session: session,
            proposedResult: .hitByPitch,
            snapshot: preview.snapshot,
            firstInvalidRecord: nil
        )
        #expect(throws: GameEventCorrectionError.pitchNotEditable) {
            _ = try GameEventCorrection.saveDefensivePitchEdit(
                forgedUnsupportedPreview,
                game: game,
                modelContext: context
            )
        }
        #expect(throws: SaveFailure.self) {
            _ = try GameEventCorrection.saveDefensivePitchEdit(
                preview,
                game: game,
                modelContext: context,
                save: { _ in throw SaveFailure() }
            )
        }
        var stored = try context.fetch(FetchDescriptor<GameEventRecord>())
        #expect(stored.count == 1)
        #expect(try stored[0].decoded().body == .pitch(.init(
            result: .ball,
            pitcherID: pitcherID,
            opponentBatterSlot: 1
        )))

        let newer = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: 2,
            body: .pitch(.init(
                result: .foul,
                pitcherID: pitcherID,
                opponentBatterSlot: 1
            ))
        )
        context.insert(newer)
        try context.save()
        #expect(throws: GameEventCorrectionError.staleTimeline) {
            _ = try GameEventCorrection.stageDefensivePitchEdit(
                .calledStrike,
                in: session,
                game: game,
                modelContext: context
            )
        }
        stored = try context.fetch(FetchDescriptor<GameEventRecord>(
            sortBy: [SortDescriptor(\GameEventRecord.sequenceNumber)]
        ))
        #expect(stored.map(\.id) == [original.id, newer.id])
        #expect(try stored[0].decoded().body == .pitch(.init(
            result: .ball,
            pitcherID: pitcherID,
            opponentBatterSlot: 1
        )))
    }

    private func twoConsecutiveSingles(pitcherID: UUID) -> [GameEventBody] {
        [
            .pitch(.init(result: .ballInPlay, pitcherID: pitcherID, opponentBatterSlot: 1)),
            .ballInPlay(.init(
                outcome: .single,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                thirdOutRunsCounted: nil
            )),
            .pitch(.init(result: .ballInPlay, pitcherID: pitcherID, opponentBatterSlot: 2)),
            .ballInPlay(.init(
                outcome: .single,
                opponentBatterSlot: 2,
                movements: [
                    .init(source: .first, destination: .second),
                    .init(source: .batter, destination: .first)
                ],
                rbi: 0,
                thirdOutRunsCounted: nil
            ))
        ]
    }

    private func seedCompletedSingle(
        game: Game,
        modelContext: ModelContext
    ) throws -> [GameEventRecord] {
        let pitcherID = try #require(game.startingPitcherID)
        let records = try [
            GameEventBody.pitch(.init(
                result: .ballInPlay,
                pitcherID: pitcherID,
                opponentBatterSlot: 1
            )),
            .ballInPlay(.init(
                outcome: .single,
                opponentBatterSlot: 1,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                thirdOutRunsCounted: nil
            ))
        ].enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(modelContext.insert)
        try modelContext.save()
        return records
    }

    private func makeOffensiveGame(id: UUID = UUID()) -> Game {
        Game(
            id: id,
            seasonID: UUID(),
            opponentName: "Thunder",
            homeAway: .away,
            status: .inProgress,
            startingPitcherID: UUID()
        )
    }

    private func makeTrackedBatter(
        playerID: UUID = UUID(),
        displayName: String = "Avery Stone",
        jerseyNumber: String = "8",
        position: DefensivePosition = .shortstop,
        lineupSlot: Int = 1
    ) -> TrackedBatterIdentity {
        TrackedBatterIdentity(
            playerID: playerID,
            lineupSlot: lineupSlot,
            displayName: displayName,
            jerseyNumber: jerseyNumber,
            position: position
        )
    }

    private func seedOffensivePitches(
        _ results: [OffensivePitchResult],
        sequences: [Int]? = nil,
        game: Game,
        batter: TrackedBatterIdentity,
        battingOrderSize: Int = 10,
        modelContext: ModelContext
    ) throws -> [GameEventRecord] {
        let sequenceNumbers = sequences ?? results.indices.map { $0 + 1 }
        let records = try zip(sequenceNumbers, results).map { sequence, result in
            try GameEventRecord(
                gameID: game.id,
                sequenceNumber: sequence,
                body: .offensivePitch(.init(
                    batter: batter,
                    battingOrderSize: battingOrderSize,
                    result: result
                ))
            )
        }
        records.forEach(modelContext.insert)
        try modelContext.save()
        return records
    }

    private func seedStolenBaseUndoTimeline(
        game: Game,
        modelContext: ModelContext
    ) throws -> (
        records: [GameEventRecord],
        runner: TrackedBatterIdentity,
        activeBatter: TrackedBatterIdentity
    ) {
        let runner = makeTrackedBatter()
        let activeBatter = makeTrackedBatter(
            displayName: "Jordan Lee",
            jerseyNumber: "12",
            position: .centerField,
            lineupSlot: 2
        )
        let records = try [
            GameEventBody.offensivePlateAppearance(.init(
                batter: runner,
                battingOrderSize: 10,
                result: .single,
                movements: [.init(source: .batter, destination: .first)],
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            )),
            .offensivePitch(.init(
                batter: activeBatter,
                battingOrderSize: 10,
                result: .ball
            )),
            .offensiveBaseRunning(.init(
                runnerID: runner.playerID,
                source: .first,
                destination: .second,
                result: .stolenBase
            ))
        ].enumerated().map { index, body in
            try GameEventRecord(gameID: game.id, sequenceNumber: index + 1, body: body)
        }
        records.forEach(modelContext.insert)
        try modelContext.save()
        return (records, runner, activeBatter)
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
