import Foundation
import SwiftData

enum GameEventRecorderError: LocalizedError {
    case noStartingPitcher
    case notDefensiveHalf
    case corruptHistory
    case batterMismatch
    case awaitingBallInPlayResult
    case noPendingBallInPlay
    case invalidBallInPlay(BallInPlayValidationError)
    case noTrackedBattingOrder
    case notOffensiveHalf
    case invalidOffensivePlateAppearance

    var errorDescription: String? {
        switch self {
        case .noStartingPitcher:
            "This game does not have a starting pitcher."
        case .notDefensiveHalf:
            "Pitch tracking is available while the opponent is batting."
        case .corruptHistory:
            "One or more saved plays could not be read. Scoring is paused to protect the game history."
        case .batterMismatch:
            "The saved batting order and current batter disagree."
        case .awaitingBallInPlayResult:
            "Finish the ball-in-play result before recording another pitch."
        case .noPendingBallInPlay:
            "Record an In Play pitch before recording the play result."
        case .invalidBallInPlay(let error):
            "That runner result is not valid (\(String(describing: error))). Check each runner and try again."
        case .noTrackedBattingOrder:
            "The saved lineup cannot identify the current batter."
        case .notOffensiveHalf:
            "Offensive scoring is available while your team is batting."
        case .invalidOffensivePlateAppearance:
            "That offensive result is not valid for the current batter and runners."
        }
    }
}

@MainActor
enum GameEventRecorder {
    typealias Save = (ModelContext) throws -> Void

    static func recordPitch(
        result: PitchResult,
        game: Game,
        existingRecords: [GameEventRecord],
        modelContext: ModelContext,
        save: Save = { try $0.save() }
    ) throws {
        guard let pitcherID = game.startingPitcherID else {
            throw GameEventRecorderError.noStartingPitcher
        }
        let (replay, homeAway, authoritativeRecords) = try validatedAuthoritativeReplay(
            game: game,
            existingRecords: existingRecords,
            modelContext: modelContext
        )
        guard replay.state.isOpponentBatting(homeAway: homeAway) else {
            throw GameEventRecorderError.notDefensiveHalf
        }
        guard !replay.state.isAwaitingBallInPlayResult else {
            throw GameEventRecorderError.awaitingBallInPlayResult
        }

        let nextSequence = nextSequenceNumber(authoritativeRecords)
        let pitch = PitchEvent(
            result: result,
            pitcherID: pitcherID,
            opponentBatterSlot: replay.state.currentOpponentBatterSlot
        )
        try persist(
            GameEventRecord(gameID: game.id, sequenceNumber: nextSequence, body: .pitch(pitch)),
            modelContext: modelContext,
            save: save
        )
    }

    static func recordBallInPlay(
        play: BallInPlayEvent,
        game: Game,
        existingRecords: [GameEventRecord],
        modelContext: ModelContext,
        save: Save = { try $0.save() }
    ) throws {
        let (replay, homeAway, authoritativeRecords) = try validatedAuthoritativeReplay(
            game: game,
            existingRecords: existingRecords,
            modelContext: modelContext
        )
        guard replay.state.isOpponentBatting(homeAway: homeAway) else {
            throw GameEventRecorderError.notDefensiveHalf
        }
        guard replay.state.isAwaitingBallInPlayResult else {
            throw GameEventRecorderError.noPendingBallInPlay
        }
        guard play.opponentBatterSlot == replay.state.currentOpponentBatterSlot else {
            throw GameEventRecorderError.batterMismatch
        }
        if let validationError = BallInPlayValidator.validate(
            play,
            state: replay.state,
            trackedTeamHomeAway: homeAway
        ) {
            throw GameEventRecorderError.invalidBallInPlay(validationError)
        }

        let nextSequence = nextSequenceNumber(authoritativeRecords)
        try persist(
            GameEventRecord(gameID: game.id, sequenceNumber: nextSequence, body: .ballInPlay(play)),
            modelContext: modelContext,
            save: save
        )
    }

    static func recordOffensivePlateAppearance(
        expectedBatter: TrackedBatterIdentity,
        result: OffensivePlateAppearanceResult,
        movements: [RunnerMovementEvent],
        rbi: Int,
        countedRunSources: [RunnerSource],
        thirdOutClassification: ThirdOutClassification? = nil,
        game: Game,
        existingRecords: [GameEventRecord],
        modelContext: ModelContext,
        save: Save = { try $0.save() }
    ) throws {
        let battingOrder = try trackedBattingOrder(gameID: game.id, modelContext: modelContext)
        let (replay, homeAway, authoritativeRecords) = try validatedAuthoritativeReplay(
            game: game,
            existingRecords: existingRecords,
            modelContext: modelContext
        )
        guard replay.state.isTrackedTeamBatting(homeAway: homeAway) else {
            throw GameEventRecorderError.notOffensiveHalf
        }
        guard (1...battingOrder.count).contains(replay.state.currentTrackedBatterSlot) else {
            throw GameEventRecorderError.noTrackedBattingOrder
        }
        let authoritativeBatter = battingOrder[replay.state.currentTrackedBatterSlot - 1]
        guard expectedBatter == authoritativeBatter else {
            throw GameEventRecorderError.batterMismatch
        }

        let plateAppearance = OffensivePlateAppearanceEvent(
            batter: authoritativeBatter,
            battingOrderSize: battingOrder.count,
            result: result,
            movements: movements,
            rbi: rbi,
            countedRunSources: countedRunSources,
            thirdOutClassification: thirdOutClassification
        )
        guard OffensivePlateAppearanceValidator.isValid(
            plateAppearance,
            state: replay.state,
            trackedTeamHomeAway: homeAway
        ) else {
            throw GameEventRecorderError.invalidOffensivePlateAppearance
        }

        try persist(
            GameEventRecord(
                gameID: game.id,
                sequenceNumber: nextSequenceNumber(authoritativeRecords),
                body: .offensivePlateAppearance(plateAppearance)
            ),
            modelContext: modelContext,
            save: save
        )
    }

    static func recordOffensivePitch(
        expectedBatter: TrackedBatterIdentity,
        result: OffensivePitchResult,
        game: Game,
        existingRecords: [GameEventRecord],
        modelContext: ModelContext,
        save: Save = { try $0.save() }
    ) throws {
        let battingOrder = try trackedBattingOrder(gameID: game.id, modelContext: modelContext)
        let (replay, homeAway, authoritativeRecords) = try validatedAuthoritativeReplay(
            game: game,
            existingRecords: existingRecords,
            modelContext: modelContext
        )
        guard replay.state.isTrackedTeamBatting(homeAway: homeAway) else {
            throw GameEventRecorderError.notOffensiveHalf
        }
        guard (1...battingOrder.count).contains(replay.state.currentTrackedBatterSlot) else {
            throw GameEventRecorderError.noTrackedBattingOrder
        }
        let authoritativeBatter = battingOrder[replay.state.currentTrackedBatterSlot - 1]
        guard expectedBatter == authoritativeBatter else {
            throw GameEventRecorderError.batterMismatch
        }

        let body: GameEventBody
        if result == .ball, replay.state.balls == 3 {
            let suggestion = OffensiveMovementSuggestions.awardedFirstBase(state: replay.state)
            body = .offensivePlateAppearance(OffensivePlateAppearanceEvent(
                batter: authoritativeBatter,
                battingOrderSize: battingOrder.count,
                result: .walk,
                movements: suggestion.movements,
                rbi: suggestion.rbi,
                countedRunSources: suggestion.countedRunSources,
                thirdOutClassification: nil
            ))
        } else if [.calledStrike, .swingingStrike].contains(result), replay.state.strikes == 2 {
            let suggestion = OffensiveMovementSuggestions.strikeout(state: replay.state)
            body = .offensivePlateAppearance(OffensivePlateAppearanceEvent(
                batter: authoritativeBatter,
                battingOrderSize: battingOrder.count,
                result: .strikeout,
                movements: suggestion.movements,
                rbi: 0,
                countedRunSources: [],
                thirdOutClassification: nil
            ))
        } else {
            let pitch = OffensivePitchEvent(
                batter: authoritativeBatter,
                battingOrderSize: battingOrder.count,
                result: result
            )
            guard OffensivePitchValidator.isValid(
                pitch,
                state: replay.state,
                trackedTeamHomeAway: homeAway
            ) else {
                throw GameEventRecorderError.invalidOffensivePlateAppearance
            }
            body = .offensivePitch(pitch)
        }

        if case .offensivePlateAppearance(let plateAppearance) = body,
           !OffensivePlateAppearanceValidator.isValid(
            plateAppearance,
            state: replay.state,
            trackedTeamHomeAway: homeAway
           ) {
            throw GameEventRecorderError.invalidOffensivePlateAppearance
        }

        try persist(
            GameEventRecord(
                gameID: game.id,
                sequenceNumber: nextSequenceNumber(authoritativeRecords),
                body: body
            ),
            modelContext: modelContext,
            save: save
        )
    }

    static func recordOffensiveBaseRunning(
        expectedRunnerID: UUID,
        source: RunnerSource,
        result: OffensiveBaseRunningResult,
        game: Game,
        existingRecords: [GameEventRecord],
        modelContext: ModelContext,
        save: Save = { try $0.save() }
    ) throws {
        let (replay, homeAway, authoritativeRecords) = try validatedAuthoritativeReplay(
            game: game,
            existingRecords: existingRecords,
            modelContext: modelContext
        )
        guard replay.state.isTrackedTeamBatting(homeAway: homeAway) else {
            throw GameEventRecorderError.notOffensiveHalf
        }

        let authoritativeRunnerID: UUID?
        switch source {
        case .batter: authoritativeRunnerID = nil
        case .first: authoritativeRunnerID = replay.state.firstBaseRunnerPlayerID
        case .second: authoritativeRunnerID = replay.state.secondBaseRunnerPlayerID
        case .third: authoritativeRunnerID = replay.state.thirdBaseRunnerPlayerID
        }
        guard authoritativeRunnerID == expectedRunnerID else {
            throw GameEventRecorderError.batterMismatch
        }

        let destination: RunnerDestination
        switch (result, source) {
        case (.caughtStealing, _): destination = .out
        case (.stolenBase, .first): destination = .second
        case (.stolenBase, .second): destination = .third
        case (.stolenBase, .third): destination = .home
        case (.stolenBase, .batter):
            throw GameEventRecorderError.invalidOffensivePlateAppearance
        }
        let event = OffensiveBaseRunningEvent(
            runnerID: expectedRunnerID,
            source: source,
            destination: destination,
            result: result
        )
        guard OffensiveBaseRunningValidator.isValid(
            event,
            state: replay.state,
            trackedTeamHomeAway: homeAway
        ) else {
            throw GameEventRecorderError.invalidOffensivePlateAppearance
        }

        try persist(
            GameEventRecord(
                gameID: game.id,
                sequenceNumber: nextSequenceNumber(authoritativeRecords),
                body: .offensiveBaseRunning(event)
            ),
            modelContext: modelContext,
            save: save
        )
    }

    private static func validatedReplay(
        game: Game,
        existingRecords: [GameEventRecord]
    ) throws -> (GameEventReplay.Result, HomeAway) {
        guard let homeAway = HomeAway(rawValue: game.homeAwayRawValue),
              existingRecords.allSatisfy({ $0.gameID == game.id }) else {
            throw GameEventRecorderError.corruptHistory
        }
        let replay = GameEventReplay.replay(
            records: existingRecords,
            homeAway: homeAway,
            startingPitcherID: game.startingPitcherID
        )
        guard replay.rejectedRecordIDs.isEmpty else {
            throw GameEventRecorderError.corruptHistory
        }
        return (replay, homeAway)
    }

    private static func validatedAuthoritativeReplay(
        game: Game,
        existingRecords: [GameEventRecord],
        modelContext: ModelContext
    ) throws -> (GameEventReplay.Result, HomeAway, [GameEventRecord]) {
        let storedRecords = try modelContext.fetch(FetchDescriptor<GameEventRecord>())
            .filter { $0.gameID == game.id }
        let storedRecordIDs = Set(storedRecords.map(\.id))
        guard existingRecords.allSatisfy({
            $0.gameID == game.id && storedRecordIDs.contains($0.id)
        }) else {
            throw GameEventRecorderError.corruptHistory
        }
        let (replay, homeAway) = try validatedReplay(
            game: game,
            existingRecords: storedRecords
        )
        return (replay, homeAway, storedRecords)
    }

    private static func trackedBattingOrder(
        gameID: UUID,
        modelContext: ModelContext
    ) throws -> [TrackedBatterIdentity] {
        guard let battingOrder = try resolvedTrackedBattingOrder(
            gameID: gameID,
            modelContext: modelContext
        ) else {
            throw GameEventRecorderError.noTrackedBattingOrder
        }
        return battingOrder
    }

    private static func resolvedTrackedBattingOrder(
        gameID: UUID,
        modelContext: ModelContext
    ) throws -> [TrackedBatterIdentity]? {
        let lineupEntries = try modelContext.fetch(FetchDescriptor<LineupEntry>())
        let players = try modelContext.fetch(FetchDescriptor<Player>())
        return TrackedBattingOrder.resolve(
            gameID: gameID,
            lineupEntries: lineupEntries,
            players: players
        )
    }

    private static func nextSequenceNumber(_ records: [GameEventRecord]) -> Int {
        (records.map(\.sequenceNumber).max() ?? 0) + 1
    }

    private static func persist(
        _ record: GameEventRecord,
        modelContext: ModelContext,
        save: Save
    ) throws {
        modelContext.insert(record)
        do {
            try save(modelContext)
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}
