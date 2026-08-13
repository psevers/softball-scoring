import Foundation
import SwiftData

enum UndoLatestAction: Equatable {
    case pitch(PitchResult)
    case ballInPlayResult(BallInPlayOutcome)

    var label: String {
        switch self {
        case .pitch(let result): result.label
        case .ballInPlayResult(let outcome): "\(outcome.shortLabel) Result"
        }
    }

    var buttonTitle: String {
        switch self {
        case .pitch: "Undo Latest Pitch"
        case .ballInPlayResult: "Undo Latest Result"
        }
    }
}

struct UndoLatestActionCandidate: Identifiable {
    let id: UUID
    let gameID: UUID
    let sequenceNumber: Int
    let inning: Int
    let half: InningHalf
    let opponentBatterSlot: Int
    let action: UndoLatestAction
    let completedPlateAppearance: Bool
    let precedingBallInPlayPitchSequenceNumber: Int?

    fileprivate let expectedTimeline: [GameEventRecordRevision]

    var confirmationTitle: String {
        switch action {
        case .pitch: "Undo latest pitch?"
        case .ballInPlayResult: "Undo latest result?"
        }
    }

    var confirmationMessage: String {
        "\(half.displayName) of inning \(inning), opponent batting slot \(opponentBatterSlot), "
            + "sequence \(sequenceNumber): \(action.label)."
    }

    var confirmationDetail: String {
        switch action {
        case .pitch:
            let completedPlateAppearanceDetail = completedPlateAppearance
                ? " This pitch completed the plate appearance for opponent batting slot \(opponentBatterSlot)."
                : ""
            return "Remove \(confirmationMessage)\(completedPlateAppearanceDetail) "
                + "The game state and pitcher totals will be rebuilt from the remaining event history."
        case .ballInPlayResult(let outcome):
            let pitchSequence = precedingBallInPlayPitchSequenceNumber.map(String.init) ?? "unknown"
            return "Remove \(confirmationMessage) Only the completed \(outcome.label) result will be removed. "
                + "The preceding Ball In Play pitch at sequence \(pitchSequence) will remain counted, "
                + "and the game will return to pending outcome entry."
        }
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
            "The latest scoring action cannot be undone."
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

    static func prepareUndoLatestAction(
        game: Game,
        modelContext: ModelContext
    ) throws -> UndoLatestActionCandidate {
        let correctionContext = freshContext(from: modelContext)
        let records = try fetchRecords(gameID: game.id, modelContext: correctionContext)
        let snapshot = try validatedSnapshot(game: game, records: records)
        guard let latestRecord = records.last,
              let latestEntry = snapshot.replay.entries.last,
              latestEntry.recordID == latestRecord.id,
              latestEntry.rejection == nil else {
            throw GameEventCorrectionError.noUndoAvailable
        }

        let action: UndoLatestAction
        let completedPlateAppearance: Bool
        let precedingPitchSequenceNumber: Int?
        switch latestEntry.body {
        case .pitch(let pitch) where isUndoEligiblePitch(pitch.result):
            action = .pitch(pitch.result)
            completedPlateAppearance = completesPlateAppearance(
                pitch.result,
                stateBefore: latestEntry.stateBefore
            )
            precedingPitchSequenceNumber = nil
        case .ballInPlay(let play):
            guard let precedingEntry = snapshot.replay.entries.dropLast().last,
                  precedingEntry.rejection == nil,
                  case .pitch(let pitch) = precedingEntry.body,
                  pitch.result == .ballInPlay,
                  pitch.opponentBatterSlot == play.opponentBatterSlot else {
                throw GameEventCorrectionError.invalidTimeline
            }
            action = .ballInPlayResult(play.outcome)
            completedPlateAppearance = true
            precedingPitchSequenceNumber = precedingEntry.sequenceNumber
        default:
            throw GameEventCorrectionError.noUndoAvailable
        }

        _ = try validatedSnapshot(game: game, records: Array(records.dropLast()))

        return UndoLatestActionCandidate(
            id: latestRecord.id,
            gameID: game.id,
            sequenceNumber: latestRecord.sequenceNumber,
            inning: latestEntry.stateBefore.inning,
            half: latestEntry.stateBefore.half,
            opponentBatterSlot: latestEntry.stateBefore.currentOpponentBatterSlot,
            action: action,
            completedPlateAppearance: completedPlateAppearance,
            precedingBallInPlayPitchSequenceNumber: precedingPitchSequenceNumber,
            expectedTimeline: records.map(GameEventRecordRevision.init)
        )
    }

    static func undoLatestAction(
        _ candidate: UndoLatestActionCandidate,
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

        let correctedSnapshot = try validatedSnapshot(game: game, records: Array(records.dropLast()))
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

    private static func isUndoEligiblePitch(_ result: PitchResult) -> Bool {
        switch result {
        case .ball, .calledStrike, .swingingStrike, .foul, .hitByPitch: true
        case .ballInPlay: false
        }
    }

    private static func completesPlateAppearance(
        _ result: PitchResult,
        stateBefore: GameState
    ) -> Bool {
        switch result {
        case .ball: stateBefore.balls == 3
        case .calledStrike, .swingingStrike: stateBefore.strikes == 2
        case .hitByPitch: true
        case .foul, .ballInPlay: false
        }
    }
}
