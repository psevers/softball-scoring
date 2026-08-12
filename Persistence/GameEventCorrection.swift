import Foundation
import SwiftData

struct UndoLatestCountPitchCandidate: Identifiable {
    let id: UUID
    let gameID: UUID
    let sequenceNumber: Int
    let inning: Int
    let half: InningHalf
    let opponentBatterSlot: Int
    let result: PitchResult

    fileprivate let expectedTimeline: [GameEventRecordRevision]

    var confirmationMessage: String {
        "\(half.displayName) of inning \(inning), opponent batting slot \(opponentBatterSlot), "
            + "sequence \(sequenceNumber): \(result.label)."
    }

    var confirmationDetail: String {
        "Remove \(confirmationMessage) The count and pitcher totals will be rebuilt from Play History."
    }
}

enum GameEventCorrectionError: LocalizedError {
    case gameMismatch
    case noUndoAvailable
    case invalidTimeline
    case latestActionChanged
    case staleTimeline

    var errorDescription: String? {
        switch self {
        case .gameMismatch:
            "This undo action belongs to a different game."
        case .noUndoAvailable:
            "The latest scoring action is not a count pitch that can be undone."
        case .invalidTimeline:
            "The remaining game history could not be replayed safely."
        case .latestActionChanged:
            "The latest scoring action changed before Undo was confirmed. Refresh and try again."
        case .staleTimeline:
            "The game history changed before Undo was confirmed. Refresh and try again."
        }
    }
}

private struct GameEventRecordRevision: Equatable {
    let id: UUID
    let gameID: UUID
    let sequenceNumber: Int
    let timestamp: Date
    let kindRawValue: String
    let payload: Data

    init(_ record: GameEventRecord) {
        id = record.id
        gameID = record.gameID
        sequenceNumber = record.sequenceNumber
        timestamp = record.timestamp
        kindRawValue = record.kindRawValue
        payload = record.payload
    }
}

@MainActor
enum GameEventCorrection {
    typealias Save = (ModelContext) throws -> Void

    static func prepareUndoLatestCountPitch(
        game: Game,
        modelContext: ModelContext
    ) throws -> UndoLatestCountPitchCandidate {
        let correctionContext = freshContext(from: modelContext)
        let records = try fetchRecords(gameID: game.id, modelContext: correctionContext)
        let snapshot = try validatedSnapshot(game: game, records: records)
        guard let latestRecord = records.last,
              let latestEntry = snapshot.replay.entries.last,
              latestEntry.recordID == latestRecord.id,
              latestEntry.rejection == nil,
              case .pitch(let pitch) = latestEntry.body,
              isNonTerminalCountPitch(pitch.result, stateBefore: latestEntry.stateBefore) else {
            throw GameEventCorrectionError.noUndoAvailable
        }

        _ = try validatedSnapshot(game: game, records: Array(records.dropLast()))

        return UndoLatestCountPitchCandidate(
            id: latestRecord.id,
            gameID: game.id,
            sequenceNumber: latestRecord.sequenceNumber,
            inning: latestEntry.stateBefore.inning,
            half: latestEntry.stateBefore.half,
            opponentBatterSlot: pitch.opponentBatterSlot,
            result: pitch.result,
            expectedTimeline: records.map(GameEventRecordRevision.init)
        )
    }

    static func undoLatestCountPitch(
        _ candidate: UndoLatestCountPitchCandidate,
        game: Game,
        modelContext: ModelContext,
        save: Save = { try $0.save() }
    ) throws -> LiveGameSnapshot {
        guard candidate.gameID == game.id else {
            throw GameEventCorrectionError.gameMismatch
        }

        let correctionContext = freshContext(from: modelContext)
        let records = try fetchRecords(gameID: game.id, modelContext: correctionContext)
        guard records.last?.id == candidate.id else {
            throw GameEventCorrectionError.latestActionChanged
        }
        guard records.map(GameEventRecordRevision.init) == candidate.expectedTimeline else {
            throw GameEventCorrectionError.staleTimeline
        }

        let survivingRecords = Array(records.dropLast())
        let correctedSnapshot = try validatedSnapshot(game: game, records: survivingRecords)
        guard let record = records.last else {
            throw GameEventCorrectionError.latestActionChanged
        }

        correctionContext.delete(record)
        do {
            try save(correctionContext)
        } catch {
            correctionContext.rollback()
            throw error
        }
        return correctedSnapshot
    }

    private static func freshContext(from modelContext: ModelContext) -> ModelContext {
        let context = ModelContext(modelContext.container)
        context.autosaveEnabled = false
        return context
    }

    private static func fetchRecords(
        gameID: UUID,
        modelContext: ModelContext
    ) throws -> [GameEventRecord] {
        let descriptor = FetchDescriptor<GameEventRecord>(
            predicate: #Predicate { $0.gameID == gameID },
            sortBy: [
                SortDescriptor(\GameEventRecord.sequenceNumber),
                SortDescriptor(\GameEventRecord.timestamp)
            ]
        )
        return try modelContext.fetch(descriptor)
    }

    private static func validatedSnapshot(
        game: Game,
        records: [GameEventRecord]
    ) throws -> LiveGameSnapshot {
        let snapshot = try LiveGameSnapshotLoader.makeSnapshot(game: game, records: records)
        guard snapshot.replay.rejectedRecordIDs.isEmpty else {
            throw GameEventCorrectionError.invalidTimeline
        }
        return snapshot
    }

    private static func isNonTerminalCountPitch(
        _ result: PitchResult,
        stateBefore: GameState
    ) -> Bool {
        switch result {
        case .ball:
            stateBefore.balls < 3
        case .calledStrike, .swingingStrike:
            stateBefore.strikes < 2
        case .foul:
            true
        case .ballInPlay, .hitByPitch:
            false
        }
    }
}
