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
