import Foundation
import SwiftData

enum UndoLatestAction: Equatable {
    case pitch(PitchResult)
    case ballInPlayResult(BallInPlayOutcome)
    case offensivePitch(OffensivePitchResult)
    case offensiveBaseRunning(OffensiveBaseRunningEvent)
    case offensivePlateAppearance(OffensivePlateAppearanceEvent)

    var label: String {
        switch self {
        case .pitch(let result): result.label
        case .ballInPlayResult(let outcome): "\(outcome.shortLabel) Result"
        case .offensivePitch(let result): result.label
        case .offensiveBaseRunning(let event):
            "\(event.result.shortLabel) · \(event.source.baseLabel) to \(event.destination.label)"
        case .offensivePlateAppearance(let plateAppearance): plateAppearance.result.label
        }
    }

    var buttonTitle: String {
        switch self {
        case .pitch, .offensivePitch: "Undo Latest Pitch"
        case .ballInPlayResult: "Undo Latest Result"
        case .offensiveBaseRunning(let event): "Undo Latest \(event.result.shortLabel)"
        case .offensivePlateAppearance: "Undo Latest Play"
        }
    }
}

enum UndoLatestActor: Equatable {
    case opponentBatter(slot: Int)
    case trackedBatter(TrackedBatterIdentity, battingOrderSize: Int)
}

struct UndoLatestActionCandidate: Identifiable {
    let id: UUID
    let gameID: UUID
    let sequenceNumber: Int
    let inning: Int
    let half: InningHalf
    let actor: UndoLatestActor
    let action: UndoLatestAction
    let completedPlateAppearance: Bool
    let precedingBallInPlayPitchSequenceNumber: Int?

    fileprivate let expectedTimeline: [GameEventRecordRevision]

    var opponentBatterSlot: Int? {
        guard case .opponentBatter(let slot) = actor else { return nil }
        return slot
    }

    var confirmationTitle: String {
        switch action {
        case .pitch, .offensivePitch: "Undo latest pitch?"
        case .ballInPlayResult: "Undo latest result?"
        case .offensiveBaseRunning(let event): "Undo latest \(event.result.confirmationName)?"
        case .offensivePlateAppearance: "Undo latest plate appearance?"
        }
    }

    var confirmationMessage: String {
        let actorDescription = switch actor {
        case .opponentBatter(let slot):
            "opponent batting slot \(slot)"
        case .trackedBatter(let batter, let battingOrderSize):
            "\(batter.displayName), batting slot \(batter.lineupSlot) of \(battingOrderSize)"
        }
        return "\(half.displayName) of inning \(inning), \(actorDescription), "
            + "sequence \(sequenceNumber): \(action.label)."
    }

    var confirmationDetail: String {
        switch action {
        case .pitch:
            guard case .opponentBatter(let opponentBatterSlot) = actor else {
                return "Remove \(confirmationMessage)"
            }
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
        case .offensivePitch:
            return "Remove \(confirmationMessage) The event-time tracked batter and batting-order size "
                + "will remain unchanged, and the offensive count will be rebuilt from the remaining event history."
        case .offensiveBaseRunning(let event):
            return "Remove \(confirmationMessage) The identified runner will return to \(event.source.baseLabel). "
                + "The active tracked batter, count, and plate-appearance progression will remain unchanged. "
                + "The game state and batting projection will be rebuilt from the remaining event history."
        case .offensivePlateAppearance(let plateAppearance):
            let movements = plateAppearance.movements
                .map { "\($0.source.label) to \($0.destination.label)" }
                .joined(separator: "; ")
            return "Remove \(confirmationMessage) Runner movements: \(movements). "
                + "Runs: \(plateAppearance.countedRunSources.count). RBI: \(plateAppearance.rbi). "
                + "The game state and batting projection will be rebuilt from the remaining event history."
        }
    }
}

struct DefensivePitchEditSession: Identifiable {
    var id: UUID { recordID }

    let recordID: UUID
    let gameID: UUID
    let sequenceNumber: Int
    let inning: Int
    let half: InningHalf
    let opponentBatterSlot: Int
    let pitcherID: UUID
    let originalResult: PitchResult
    let stateBefore: GameState
    let originalStateAfter: GameState

    fileprivate let expectedTimeline: [GameEventRecordRevision]
}

struct OffensivePitchEditSession: Identifiable {
    var id: UUID { recordID }

    let recordID: UUID
    let gameID: UUID
    let sequenceNumber: Int
    let inning: Int
    let half: InningHalf
    let batter: TrackedBatterIdentity
    let battingOrderSize: Int
    let originalResult: OffensivePitchResult
    let stateBefore: GameState
    let originalStateAfter: GameState

    fileprivate let expectedTimeline: [GameEventRecordRevision]
}

struct OffensivePitchDeletionSession: Identifiable {
    var id: UUID { recordID }

    let recordID: UUID
    let gameID: UUID
    let sequenceNumber: Int
    let inning: Int
    let half: InningHalf
    let batter: TrackedBatterIdentity
    let battingOrderSize: Int
    let originalResult: OffensivePitchResult
    let originalStateAfter: GameState

    fileprivate let expectedTimeline: [GameEventRecordRevision]

    var confirmationTitle: String {
        "Delete \(originalResult.label) pitch?"
    }

    var confirmationDetail: String {
        "\(half.displayName) of inning \(inning), \(batter.displayName), batting slot "
            + "\(batter.lineupSlot) of \(battingOrderSize), sequence \(sequenceNumber): "
            + "\(originalResult.label). The deletion remains staged until Save."
    }
}

struct DefensivePitchCorrectionInvalidRecord: Equatable {
    let id: UUID
    let sequenceNumber: Int
    let summary: String
}

enum DefensivePitchStagedAction: Equatable {
    case edit(PitchResult)
    case delete

    var label: String {
        switch self {
        case .edit(let result): "Change to \(result.label)"
        case .delete: "Delete"
        }
    }
}

struct DefensivePitchStagedChange: Identifiable, Equatable {
    var id: UUID { recordID }

    let recordID: UUID
    let sequenceNumber: Int
    let inning: Int
    let half: InningHalf
    let opponentBatterSlot: Int
    let pitcherID: UUID
    let originalResult: PitchResult
    let action: DefensivePitchStagedAction

    var summary: String {
        "Sequence \(sequenceNumber) · \(originalResult.label) · \(action.label)"
    }
}

enum OffensivePitchStagedAction: Equatable {
    case edit(OffensivePitchResult)
    case delete

    var label: String {
        switch self {
        case .edit(let result): "Change to \(result.label)"
        case .delete: "Delete"
        }
    }
}

struct OffensivePitchStagedChange: Identifiable, Equatable {
    var id: UUID { recordID }

    let recordID: UUID
    let sequenceNumber: Int
    let inning: Int
    let half: InningHalf
    let batter: TrackedBatterIdentity
    let battingOrderSize: Int
    let originalResult: OffensivePitchResult
    let action: OffensivePitchStagedAction

    var summary: String {
        "Sequence \(sequenceNumber) · \(batter.displayName) · \(originalResult.label) · "
            + action.label
    }
}

struct DefensiveBallInPlayStagedChange: Identifiable, Equatable {
    var id: UUID { recordID }

    let recordID: UUID
    let sequenceNumber: Int
    let originalPlay: BallInPlayEvent
    let proposedPlay: BallInPlayEvent

    var summary: String {
        "Sequence \(sequenceNumber) · \(originalPlay.outcome.shortLabel) · "
            + "Change to \(proposedPlay.outcome.shortLabel)"
    }
}

struct DefensiveLogicalPlayDeletionComponent: Identifiable, Equatable {
    var id: UUID { recordID }

    let recordID: UUID
    let sequenceNumber: Int
    let summary: String
}

struct DefensiveLogicalPlayStagedDeletion: Identifiable, Equatable {
    var id: UUID { resultRecordID }

    let pitchRecordID: UUID
    let pitchSequenceNumber: Int
    let resultRecordID: UUID
    let resultSequenceNumber: Int
    let resultSummary: String

    var summary: String {
        "Sequences \(pitchSequenceNumber) and \(resultSequenceNumber) · Delete completed \(resultSummary)"
    }
}

struct GameEventCorrectionProblem: Equatable {
    let id: UUID
    let sequenceNumber: Int
    let context: String
    let explanation: String
    let canEditPitch: Bool
    let canEditOffensivePitch: Bool
    let canDeleteOffensivePitch: Bool
    let canDeletePitch: Bool
    let canEditBallInPlay: Bool
}

struct GameEventCorrectionSession {
    let gameID: UUID
    let stagedChanges: [DefensivePitchStagedChange]
    let stagedOffensivePitchChanges: [OffensivePitchStagedChange]
    let stagedBallInPlayChanges: [DefensiveBallInPlayStagedChange]
    let stagedLogicalPlayDeletions: [DefensiveLogicalPlayStagedDeletion]
    let snapshot: LiveGameSnapshot
    let firstInvalidRecord: GameEventCorrectionProblem?

    fileprivate let expectedTimeline: [GameEventRecordRevision]

    var canSave: Bool {
        (!stagedChanges.isEmpty
            || stagedOffensivePitchChanges.contains {
                switch $0.action {
                case .edit(let result): result != $0.originalResult
                case .delete: true
                }
            }
            || stagedBallInPlayChanges.contains { $0.proposedPlay != $0.originalPlay }
            || !stagedLogicalPlayDeletions.isEmpty)
            && firstInvalidRecord == nil
    }
}

struct DefensiveLogicalPlayDeletionSession: Identifiable {
    var id: UUID { resultRecordID }

    let resultRecordID: UUID
    let gameID: UUID
    let inning: Int
    let half: InningHalf
    let opponentBatterSlot: Int
    let components: [DefensiveLogicalPlayDeletionComponent]

    fileprivate let stagedDeletion: DefensiveLogicalPlayStagedDeletion
    fileprivate let expectedTimeline: [GameEventRecordRevision]

    var confirmationTitle: String {
        "Delete completed play?"
    }

    var confirmationDetail: String {
        let componentList = components
            .map { "Sequence \($0.sequenceNumber): \($0.summary)" }
            .joined(separator: "\n")
        return "\(half.displayName) of inning \(inning), opponent batting slot "
            + "\(opponentBatterSlot). Both records will be removed:\n\(componentList)\n"
            + "Individual component deletion remains available separately."
    }
}

struct DefensiveLogicalPlayDeletionPreview {
    let session: DefensiveLogicalPlayDeletionSession
    let correctionSession: GameEventCorrectionSession

    var snapshot: LiveGameSnapshot {
        correctionSession.snapshot
    }

    var firstInvalidRecord: GameEventCorrectionProblem? {
        correctionSession.firstInvalidRecord
    }

    var canSave: Bool {
        correctionSession.canSave
    }
}

struct DefensiveBallInPlayEditSession: Identifiable {
    var id: UUID { recordID }

    let recordID: UUID
    let gameID: UUID
    let sequenceNumber: Int
    let inning: Int
    let half: InningHalf
    let opponentBatterSlot: Int
    let homeAway: HomeAway
    let precedingPitchSequenceNumber: Int
    let originalPlay: BallInPlayEvent
    let stateBefore: GameState

    fileprivate let expectedTimeline: [GameEventRecordRevision]
}

struct DefensiveBallInPlayEditPreview {
    let session: DefensiveBallInPlayEditSession
    let proposedPlay: BallInPlayEvent
    let snapshot: LiveGameSnapshot
    let firstInvalidRecord: GameEventCorrectionProblem?
    let correctionSession: GameEventCorrectionSession?

    var canSave: Bool {
        proposedPlay != session.originalPlay && firstInvalidRecord == nil
    }
}

struct DefensivePitchEditPreview {
    let session: DefensivePitchEditSession
    let proposedResult: PitchResult
    let snapshot: LiveGameSnapshot
    let firstInvalidRecord: DefensivePitchCorrectionInvalidRecord?
    fileprivate let correctionSession: GameEventCorrectionSession?

    init(
        session: DefensivePitchEditSession,
        proposedResult: PitchResult,
        snapshot: LiveGameSnapshot,
        firstInvalidRecord: DefensivePitchCorrectionInvalidRecord?,
        correctionSession: GameEventCorrectionSession? = nil
    ) {
        self.session = session
        self.proposedResult = proposedResult
        self.snapshot = snapshot
        self.firstInvalidRecord = firstInvalidRecord
        self.correctionSession = correctionSession
    }

    var canSave: Bool {
        proposedResult != session.originalResult && firstInvalidRecord == nil
    }
}

struct DefensivePitchDeletionSession: Identifiable {
    var id: UUID { recordID }

    let recordID: UUID
    let gameID: UUID
    let sequenceNumber: Int
    let inning: Int
    let half: InningHalf
    let opponentBatterSlot: Int
    let originalResult: PitchResult
    let originalStateAfter: GameState

    fileprivate let expectedTimeline: [GameEventRecordRevision]

    var confirmationTitle: String {
        "Delete \(originalResult.label) pitch?"
    }

    var confirmationDetail: String {
        "\(half.displayName) of inning \(inning), opponent batting slot "
            + "\(opponentBatterSlot), sequence \(sequenceNumber): \(originalResult.label). "
            + "The deletion remains staged until Save."
    }
}

struct DefensivePitchDeletionPreview {
    let session: DefensivePitchDeletionSession
    let snapshot: LiveGameSnapshot
    let firstInvalidRecord: DefensivePitchCorrectionInvalidRecord?
    fileprivate let correctionSession: GameEventCorrectionSession?

    init(
        session: DefensivePitchDeletionSession,
        snapshot: LiveGameSnapshot,
        firstInvalidRecord: DefensivePitchCorrectionInvalidRecord?,
        correctionSession: GameEventCorrectionSession? = nil
    ) {
        self.session = session
        self.snapshot = snapshot
        self.firstInvalidRecord = firstInvalidRecord
        self.correctionSession = correctionSession
    }

    var canSave: Bool {
        firstInvalidRecord == nil
    }
}

enum GameEventCorrectionError: LocalizedError {
    case gameMismatch
    case noUndoAvailable
    case invalidTimeline
    case latestActionChanged
    case staleTimeline
    case pitchNotEditable
    case offensivePitchNotEditable
    case offensivePitchNotDeletable
    case pitchNotDeletable
    case ballInPlayNotEditable
    case logicalPlayNotDeletable
    case invalidCandidate

    var errorDescription: String? {
        switch self {
        case .gameMismatch:
            "This correction belongs to a different game."
        case .noUndoAvailable:
            "The latest scoring action cannot be undone."
        case .invalidTimeline:
            "The remaining game history could not be replayed safely."
        case .latestActionChanged:
            "The latest scoring action changed before Undo was confirmed. Refresh and try again."
        case .staleTimeline:
            "The game history changed before the correction was confirmed. Return to Play History and reopen the event."
        case .pitchNotEditable:
            "This saved event is not an editable non-terminal defensive pitch."
        case .offensivePitchNotEditable:
            "This saved event is not an editable tracked-team pitch."
        case .offensivePitchNotDeletable:
            "This saved event is not a tracked-team pitch that can be deleted."
        case .pitchNotDeletable:
            "This saved event is not a defensive pitch that can be deleted."
        case .ballInPlayNotEditable:
            "This saved event is not an editable defensive Ball In Play result."
        case .logicalPlayNotDeletable:
            "This saved event is not a completed defensive Ball In Play."
        case .invalidCandidate:
            "The proposed change leaves invalid game history and cannot be saved."
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
        let actor: UndoLatestActor
        let completedPlateAppearance: Bool
        let precedingPitchSequenceNumber: Int?
        switch latestEntry.body {
        case .pitch(let pitch) where isUndoEligiblePitch(pitch.result):
            action = .pitch(pitch.result)
            actor = .opponentBatter(slot: pitch.opponentBatterSlot)
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
            actor = .opponentBatter(slot: play.opponentBatterSlot)
            completedPlateAppearance = true
            precedingPitchSequenceNumber = precedingEntry.sequenceNumber
        case .offensivePitch(let pitch):
            action = .offensivePitch(pitch.result)
            actor = .trackedBatter(pitch.batter, battingOrderSize: pitch.battingOrderSize)
            completedPlateAppearance = false
            precedingPitchSequenceNumber = nil
        case .offensiveBaseRunning(let event):
            guard let runner = trackedRunnerContext(
                playerID: event.runnerID,
                source: event.source,
                entries: snapshot.replay.entries.dropLast()
            ) else {
                throw GameEventCorrectionError.invalidTimeline
            }
            action = .offensiveBaseRunning(event)
            actor = .trackedBatter(runner.identity, battingOrderSize: runner.battingOrderSize)
            completedPlateAppearance = false
            precedingPitchSequenceNumber = nil
        case .offensivePlateAppearance(let plateAppearance):
            action = .offensivePlateAppearance(plateAppearance)
            actor = .trackedBatter(
                plateAppearance.batter,
                battingOrderSize: plateAppearance.battingOrderSize
            )
            completedPlateAppearance = true
            precedingPitchSequenceNumber = nil
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
            actor: actor,
            action: action,
            completedPlateAppearance: completedPlateAppearance,
            precedingBallInPlayPitchSequenceNumber: precedingPitchSequenceNumber,
            expectedTimeline: records.map(GameEventRecordRevision.init)
        )
    }

    static func beginGameEventCorrection(
        game: Game,
        modelContext: ModelContext
    ) throws -> GameEventCorrectionSession {
        let correctionContext = freshContext(from: modelContext)
        let records = try fetchRecords(gameID: game.id, modelContext: correctionContext)
        let snapshot = try validatedSnapshot(game: game, records: records)
        return GameEventCorrectionSession(
            gameID: game.id,
            stagedChanges: [],
            stagedOffensivePitchChanges: [],
            stagedBallInPlayChanges: [],
            stagedLogicalPlayDeletions: [],
            snapshot: snapshot,
            firstInvalidRecord: nil,
            expectedTimeline: records.map(GameEventRecordRevision.init)
        )
    }

    static func stagePitchDeletion(
        recordID: UUID,
        in session: GameEventCorrectionSession,
        game: Game,
        modelContext: ModelContext,
        projectBattingLines: LiveGameSnapshotLoader.ProjectBattingLines = BattingStatProjector.project
    ) throws -> GameEventCorrectionSession {
        try stagePitchChange(
            recordID: recordID,
            action: .delete,
            in: session,
            game: game,
            modelContext: modelContext,
            projectBattingLines: projectBattingLines
        )
    }

    static func stagePitchEdit(
        recordID: UUID,
        result: PitchResult,
        in session: GameEventCorrectionSession,
        game: Game,
        modelContext: ModelContext,
        projectBattingLines: LiveGameSnapshotLoader.ProjectBattingLines = BattingStatProjector.project
    ) throws -> GameEventCorrectionSession {
        guard isEditablePitch(result) else {
            throw GameEventCorrectionError.pitchNotEditable
        }
        return try stagePitchChange(
            recordID: recordID,
            action: .edit(result),
            in: session,
            game: game,
            modelContext: modelContext,
            projectBattingLines: projectBattingLines
        )
    }

    static func stageOffensivePitchEdit(
        recordID: UUID,
        result: OffensivePitchResult,
        in session: GameEventCorrectionSession,
        game: Game,
        modelContext: ModelContext,
        projectBattingLines: LiveGameSnapshotLoader.ProjectBattingLines = BattingStatProjector.project
    ) throws -> GameEventCorrectionSession {
        try stageOffensivePitchChange(
            recordID: recordID,
            action: .edit(result),
            in: session,
            game: game,
            modelContext: modelContext,
            projectBattingLines: projectBattingLines
        )
    }

    static func stageOffensivePitchDeletion(
        recordID: UUID,
        in session: GameEventCorrectionSession,
        game: Game,
        modelContext: ModelContext,
        projectBattingLines: LiveGameSnapshotLoader.ProjectBattingLines = BattingStatProjector.project
    ) throws -> GameEventCorrectionSession {
        try stageOffensivePitchChange(
            recordID: recordID,
            action: .delete,
            in: session,
            game: game,
            modelContext: modelContext,
            projectBattingLines: projectBattingLines
        )
    }

    static func saveGameEventCorrection(
        _ session: GameEventCorrectionSession,
        game: Game,
        modelContext: ModelContext,
        projectBattingLines: LiveGameSnapshotLoader.ProjectBattingLines = BattingStatProjector.project,
        save: Save = { try $0.save() }
    ) throws -> LiveGameSnapshot {
        guard session.gameID == game.id else {
            throw GameEventCorrectionError.gameMismatch
        }
        guard session.canSave else {
            throw GameEventCorrectionError.invalidCandidate
        }

        let correctionContext = freshContext(from: modelContext)
        let records = try fetchRecords(gameID: game.id, modelContext: correctionContext)
        guard records.map(GameEventRecordRevision.init) == session.expectedTimeline else {
            throw GameEventCorrectionError.staleTimeline
        }
        let candidateRecords = try applying(
            session.stagedChanges,
            offensivePitchChanges: session.stagedOffensivePitchChanges,
            ballInPlayChanges: session.stagedBallInPlayChanges,
            logicalPlayDeletions: session.stagedLogicalPlayDeletions,
            to: records
        )
        let correctedSnapshot = try validatedSnapshot(
            game: game,
            records: candidateRecords,
            projectBattingLines: projectBattingLines
        )

        for change in session.stagedChanges {
            guard let record = records.first(where: { $0.id == change.recordID }) else {
                throw GameEventCorrectionError.staleTimeline
            }
            switch change.action {
            case .edit(let result):
                let encoded = try GameEventCodec.encode(.pitch(PitchEvent(
                    result: result,
                    pitcherID: change.pitcherID,
                    opponentBatterSlot: change.opponentBatterSlot
                )))
                record.kindRawValue = encoded.kind.rawValue
                record.payload = encoded.payload
            case .delete:
                correctionContext.delete(record)
            }
        }
        for change in session.stagedOffensivePitchChanges {
            guard let record = records.first(where: { $0.id == change.recordID }) else {
                throw GameEventCorrectionError.staleTimeline
            }
            switch change.action {
            case .edit(let result):
                let encoded = try GameEventCodec.encode(.offensivePitch(OffensivePitchEvent(
                    batter: change.batter,
                    battingOrderSize: change.battingOrderSize,
                    result: result
                )))
                record.kindRawValue = encoded.kind.rawValue
                record.payload = encoded.payload
            case .delete:
                correctionContext.delete(record)
            }
        }
        for change in session.stagedBallInPlayChanges {
            guard let record = records.first(where: { $0.id == change.recordID }) else {
                throw GameEventCorrectionError.staleTimeline
            }
            let encoded = try GameEventCodec.encode(.ballInPlay(change.proposedPlay))
            record.kindRawValue = encoded.kind.rawValue
            record.payload = encoded.payload
        }
        let logicalPlayRecordIDs = Set(session.stagedLogicalPlayDeletions.flatMap {
            [$0.pitchRecordID, $0.resultRecordID]
        })
        for record in records where logicalPlayRecordIDs.contains(record.id) {
            correctionContext.delete(record)
        }

        do {
            try save(correctionContext)
        } catch {
            correctionContext.rollback()
            throw error
        }
        return correctedSnapshot
    }

    static func undoLatestAction(
        _ candidate: UndoLatestActionCandidate,
        game: Game,
        modelContext: ModelContext,
        projectBattingLines: LiveGameSnapshotLoader.ProjectBattingLines = BattingStatProjector.project,
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

        let correctedSnapshot = try validatedSnapshot(
            game: game,
            records: Array(records.dropLast()),
            projectBattingLines: projectBattingLines
        )
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

    static func prepareDefensivePitchEdit(
        recordID: UUID,
        game: Game,
        modelContext: ModelContext
    ) throws -> DefensivePitchEditSession {
        let correctionContext = freshContext(from: modelContext)
        let records = try fetchRecords(gameID: game.id, modelContext: correctionContext)
        let snapshot = try validatedSnapshot(game: game, records: records)
        guard let record = records.first(where: { $0.id == recordID }),
              let entry = snapshot.replay.entries.first(where: { $0.recordID == recordID }),
              case .pitch(let pitch) = entry.body,
              isEditablePitch(pitch.result),
              !completesPlateAppearance(pitch.result, stateBefore: entry.stateBefore) else {
            throw GameEventCorrectionError.pitchNotEditable
        }

        return DefensivePitchEditSession(
            recordID: record.id,
            gameID: game.id,
            sequenceNumber: record.sequenceNumber,
            inning: entry.stateBefore.inning,
            half: entry.stateBefore.half,
            opponentBatterSlot: pitch.opponentBatterSlot,
            pitcherID: pitch.pitcherID,
            originalResult: pitch.result,
            stateBefore: entry.stateBefore,
            originalStateAfter: entry.stateAfter,
            expectedTimeline: records.map(GameEventRecordRevision.init)
        )
    }

    static func prepareOffensivePitchEdit(
        recordID: UUID,
        game: Game,
        modelContext: ModelContext
    ) throws -> OffensivePitchEditSession {
        let correctionContext = freshContext(from: modelContext)
        let records = try fetchRecords(gameID: game.id, modelContext: correctionContext)
        let snapshot = try validatedSnapshot(game: game, records: records)
        guard let record = records.first(where: { $0.id == recordID }),
              let entry = snapshot.replay.entries.first(where: { $0.recordID == recordID }),
              case .offensivePitch(let pitch) = entry.body else {
            throw GameEventCorrectionError.offensivePitchNotEditable
        }

        return OffensivePitchEditSession(
            recordID: record.id,
            gameID: game.id,
            sequenceNumber: record.sequenceNumber,
            inning: entry.stateBefore.inning,
            half: entry.stateBefore.half,
            batter: pitch.batter,
            battingOrderSize: pitch.battingOrderSize,
            originalResult: pitch.result,
            stateBefore: entry.stateBefore,
            originalStateAfter: entry.stateAfter,
            expectedTimeline: records.map(GameEventRecordRevision.init)
        )
    }

    static func prepareOffensivePitchDeletion(
        recordID: UUID,
        game: Game,
        modelContext: ModelContext
    ) throws -> OffensivePitchDeletionSession {
        let correctionContext = freshContext(from: modelContext)
        let records = try fetchRecords(gameID: game.id, modelContext: correctionContext)
        let snapshot = try validatedSnapshot(game: game, records: records)
        guard let record = records.first(where: { $0.id == recordID }),
              let entry = snapshot.replay.entries.first(where: { $0.recordID == recordID }),
              case .offensivePitch(let pitch) = entry.body else {
            throw GameEventCorrectionError.offensivePitchNotDeletable
        }

        return OffensivePitchDeletionSession(
            recordID: record.id,
            gameID: game.id,
            sequenceNumber: record.sequenceNumber,
            inning: entry.stateBefore.inning,
            half: entry.stateBefore.half,
            batter: pitch.batter,
            battingOrderSize: pitch.battingOrderSize,
            originalResult: pitch.result,
            originalStateAfter: entry.stateAfter,
            expectedTimeline: records.map(GameEventRecordRevision.init)
        )
    }

    static func stageOffensivePitchDeletion(
        _ deletionSession: OffensivePitchDeletionSession,
        game: Game,
        modelContext: ModelContext,
        projectBattingLines: LiveGameSnapshotLoader.ProjectBattingLines = BattingStatProjector.project
    ) throws -> GameEventCorrectionSession {
        guard deletionSession.gameID == game.id else {
            throw GameEventCorrectionError.gameMismatch
        }
        let session = try beginGameEventCorrection(game: game, modelContext: modelContext)
        guard session.expectedTimeline == deletionSession.expectedTimeline else {
            throw GameEventCorrectionError.staleTimeline
        }
        return try stageOffensivePitchDeletion(
            recordID: deletionSession.recordID,
            in: session,
            game: game,
            modelContext: modelContext,
            projectBattingLines: projectBattingLines
        )
    }

    static func stageOffensivePitchEdit(
        _ proposedResult: OffensivePitchResult,
        in session: OffensivePitchEditSession,
        game: Game,
        modelContext: ModelContext,
        projectBattingLines: LiveGameSnapshotLoader.ProjectBattingLines = BattingStatProjector.project
    ) throws -> GameEventCorrectionSession {
        guard session.gameID == game.id else {
            throw GameEventCorrectionError.gameMismatch
        }

        let correctionSession = try beginGameEventCorrection(
            game: game,
            modelContext: modelContext
        )
        guard correctionSession.expectedTimeline == session.expectedTimeline else {
            throw GameEventCorrectionError.staleTimeline
        }
        return try stageOffensivePitchEdit(
            recordID: session.recordID,
            result: proposedResult,
            in: correctionSession,
            game: game,
            modelContext: modelContext,
            projectBattingLines: projectBattingLines
        )
    }

    static func stageDefensivePitchEdit(
        _ proposedResult: PitchResult,
        in session: DefensivePitchEditSession,
        game: Game,
        modelContext: ModelContext,
        projectBattingLines: LiveGameSnapshotLoader.ProjectBattingLines = BattingStatProjector.project
    ) throws -> DefensivePitchEditPreview {
        guard session.gameID == game.id else {
            throw GameEventCorrectionError.gameMismatch
        }
        guard isEditablePitch(proposedResult) else {
            throw GameEventCorrectionError.pitchNotEditable
        }

        let correctionSession = try beginGameEventCorrection(
            game: game,
            modelContext: modelContext
        )
        guard correctionSession.expectedTimeline == session.expectedTimeline else {
            throw GameEventCorrectionError.staleTimeline
        }
        let stagedCorrection = try stagePitchEdit(
            recordID: session.recordID,
            result: proposedResult,
            in: correctionSession,
            game: game,
            modelContext: modelContext,
            projectBattingLines: projectBattingLines
        )
        return DefensivePitchEditPreview(
            session: session,
            proposedResult: proposedResult,
            snapshot: stagedCorrection.snapshot,
            firstInvalidRecord: legacyInvalidRecord(in: stagedCorrection),
            correctionSession: stagedCorrection
        )
    }

    static func saveDefensivePitchEdit(
        _ preview: DefensivePitchEditPreview,
        game: Game,
        modelContext: ModelContext,
        projectBattingLines: LiveGameSnapshotLoader.ProjectBattingLines = BattingStatProjector.project,
        save: Save = { try $0.save() }
    ) throws -> LiveGameSnapshot {
        guard preview.session.gameID == game.id else {
            throw GameEventCorrectionError.gameMismatch
        }
        guard isEditablePitch(preview.proposedResult) else {
            throw GameEventCorrectionError.pitchNotEditable
        }
        guard preview.canSave else {
            throw GameEventCorrectionError.invalidCandidate
        }
        guard let correctionSession = preview.correctionSession else {
            throw GameEventCorrectionError.invalidCandidate
        }
        return try saveGameEventCorrection(
            correctionSession,
            game: game,
            modelContext: modelContext,
            projectBattingLines: projectBattingLines,
            save: save
        )
    }

    static func prepareDefensivePitchDeletion(
        recordID: UUID,
        game: Game,
        modelContext: ModelContext
    ) throws -> DefensivePitchDeletionSession {
        let correctionContext = freshContext(from: modelContext)
        let records = try fetchRecords(gameID: game.id, modelContext: correctionContext)
        let snapshot = try validatedSnapshot(game: game, records: records)
        guard let record = records.first(where: { $0.id == recordID }),
              let entry = snapshot.replay.entries.first(where: { $0.recordID == recordID }),
              case .pitch(let pitch) = entry.body else {
            throw GameEventCorrectionError.pitchNotDeletable
        }

        return DefensivePitchDeletionSession(
            recordID: record.id,
            gameID: game.id,
            sequenceNumber: record.sequenceNumber,
            inning: entry.stateBefore.inning,
            half: entry.stateBefore.half,
            opponentBatterSlot: pitch.opponentBatterSlot,
            originalResult: pitch.result,
            originalStateAfter: entry.stateAfter,
            expectedTimeline: records.map(GameEventRecordRevision.init)
        )
    }

    static func stageDefensivePitchDeletion(
        _ session: DefensivePitchDeletionSession,
        game: Game,
        modelContext: ModelContext,
        projectBattingLines: LiveGameSnapshotLoader.ProjectBattingLines = BattingStatProjector.project
    ) throws -> DefensivePitchDeletionPreview {
        guard session.gameID == game.id else {
            throw GameEventCorrectionError.gameMismatch
        }

        let correctionSession = try beginGameEventCorrection(
            game: game,
            modelContext: modelContext
        )
        guard correctionSession.expectedTimeline == session.expectedTimeline else {
            throw GameEventCorrectionError.staleTimeline
        }
        let stagedCorrection = try stagePitchDeletion(
            recordID: session.recordID,
            in: correctionSession,
            game: game,
            modelContext: modelContext,
            projectBattingLines: projectBattingLines
        )
        return DefensivePitchDeletionPreview(
            session: session,
            snapshot: stagedCorrection.snapshot,
            firstInvalidRecord: legacyInvalidRecord(in: stagedCorrection),
            correctionSession: stagedCorrection
        )
    }

    static func saveDefensivePitchDeletion(
        _ preview: DefensivePitchDeletionPreview,
        game: Game,
        modelContext: ModelContext,
        projectBattingLines: LiveGameSnapshotLoader.ProjectBattingLines = BattingStatProjector.project,
        save: Save = { try $0.save() }
    ) throws -> LiveGameSnapshot {
        guard preview.session.gameID == game.id else {
            throw GameEventCorrectionError.gameMismatch
        }
        guard preview.canSave else {
            throw GameEventCorrectionError.invalidCandidate
        }
        guard let correctionSession = preview.correctionSession else {
            throw GameEventCorrectionError.invalidCandidate
        }
        return try saveGameEventCorrection(
            correctionSession,
            game: game,
            modelContext: modelContext,
            projectBattingLines: projectBattingLines,
            save: save
        )
    }

    static func prepareDefensiveBallInPlayEdit(
        recordID: UUID,
        game: Game,
        modelContext: ModelContext
    ) throws -> DefensiveBallInPlayEditSession {
        let correctionContext = freshContext(from: modelContext)
        let records = try fetchRecords(gameID: game.id, modelContext: correctionContext)
        let snapshot = try validatedSnapshot(game: game, records: records)
        guard let homeAway = HomeAway(rawValue: game.homeAwayRawValue) else {
            throw GameEventCorrectionError.invalidTimeline
        }
        guard let record = records.first(where: { $0.id == recordID }),
              let entryIndex = snapshot.replay.entries.firstIndex(where: { $0.recordID == recordID }),
              entryIndex > snapshot.replay.entries.startIndex,
              case .ballInPlay(let play) = snapshot.replay.entries[entryIndex].body,
              BallInPlayValidator.supportsCorrection(
                play,
                stateBefore: snapshot.replay.entries[entryIndex].stateBefore
              ),
              case .pitch(let pitch) = snapshot.replay.entries[entryIndex - 1].body,
              pitch.result == .ballInPlay,
              pitch.opponentBatterSlot == play.opponentBatterSlot,
              snapshot.replay.entries[entryIndex - 1].rejection == nil else {
            throw GameEventCorrectionError.ballInPlayNotEditable
        }
        let entry = snapshot.replay.entries[entryIndex]
        return DefensiveBallInPlayEditSession(
            recordID: record.id,
            gameID: game.id,
            sequenceNumber: record.sequenceNumber,
            inning: entry.stateBefore.inning,
            half: entry.stateBefore.half,
            opponentBatterSlot: play.opponentBatterSlot,
            homeAway: homeAway,
            precedingPitchSequenceNumber: snapshot.replay.entries[entryIndex - 1].sequenceNumber,
            originalPlay: play,
            stateBefore: entry.stateBefore,
            expectedTimeline: records.map(GameEventRecordRevision.init)
        )
    }

    static func prepareDefensiveLogicalPlayDeletion(
        resultRecordID: UUID,
        game: Game,
        modelContext: ModelContext
    ) throws -> DefensiveLogicalPlayDeletionSession {
        let correctionContext = freshContext(from: modelContext)
        let records = try fetchRecords(gameID: game.id, modelContext: correctionContext)
        let snapshot = try validatedSnapshot(game: game, records: records)
        guard let resultIndex = snapshot.replay.entries.firstIndex(where: {
            $0.recordID == resultRecordID
        }),
              resultIndex > snapshot.replay.entries.startIndex,
              let resultRecord = records.first(where: { $0.id == resultRecordID }),
              case .ballInPlay(let play) = snapshot.replay.entries[resultIndex].body,
              snapshot.replay.entries[resultIndex].rejection == nil,
              case .pitch(let pitch) = snapshot.replay.entries[resultIndex - 1].body,
              pitch.result == .ballInPlay,
              pitch.opponentBatterSlot == play.opponentBatterSlot,
              snapshot.replay.entries[resultIndex - 1].rejection == nil,
              let pitchRecord = records.first(where: {
                  $0.id == snapshot.replay.entries[resultIndex - 1].recordID
              }) else {
            throw GameEventCorrectionError.logicalPlayNotDeletable
        }
        let stagedDeletion = DefensiveLogicalPlayStagedDeletion(
            pitchRecordID: pitchRecord.id,
            pitchSequenceNumber: pitchRecord.sequenceNumber,
            resultRecordID: resultRecord.id,
            resultSequenceNumber: resultRecord.sequenceNumber,
            resultSummary: play.outcome.label
        )
        return DefensiveLogicalPlayDeletionSession(
            resultRecordID: resultRecord.id,
            gameID: game.id,
            inning: snapshot.replay.entries[resultIndex - 1].stateBefore.inning,
            half: snapshot.replay.entries[resultIndex - 1].stateBefore.half,
            opponentBatterSlot: play.opponentBatterSlot,
            components: [
                DefensiveLogicalPlayDeletionComponent(
                    recordID: pitchRecord.id,
                    sequenceNumber: pitchRecord.sequenceNumber,
                    summary: "Ball In Play pitch"
                ),
                DefensiveLogicalPlayDeletionComponent(
                    recordID: resultRecord.id,
                    sequenceNumber: resultRecord.sequenceNumber,
                    summary: "\(play.outcome.label) result"
                )
            ],
            stagedDeletion: stagedDeletion,
            expectedTimeline: records.map(GameEventRecordRevision.init)
        )
    }

    static func stageDefensiveLogicalPlayDeletion(
        _ deletionSession: DefensiveLogicalPlayDeletionSession,
        game: Game,
        modelContext: ModelContext,
        projectBattingLines: LiveGameSnapshotLoader.ProjectBattingLines = BattingStatProjector.project
    ) throws -> DefensiveLogicalPlayDeletionPreview {
        guard deletionSession.gameID == game.id else {
            throw GameEventCorrectionError.gameMismatch
        }
        let session = try beginGameEventCorrection(game: game, modelContext: modelContext)
        guard session.expectedTimeline == deletionSession.expectedTimeline else {
            throw GameEventCorrectionError.staleTimeline
        }
        let deletions = [deletionSession.stagedDeletion]
        let candidateRecords = try applying(
            session.stagedChanges,
            offensivePitchChanges: session.stagedOffensivePitchChanges,
            ballInPlayChanges: session.stagedBallInPlayChanges,
            logicalPlayDeletions: deletions,
            to: session.snapshot.records
        )
        let snapshot = try LiveGameSnapshotLoader.makeSnapshot(
            game: game,
            records: candidateRecords,
            projectBattingLines: projectBattingLines
        )
        let correctionSession = GameEventCorrectionSession(
            gameID: game.id,
            stagedChanges: session.stagedChanges,
            stagedOffensivePitchChanges: session.stagedOffensivePitchChanges,
            stagedBallInPlayChanges: session.stagedBallInPlayChanges,
            stagedLogicalPlayDeletions: deletions,
            snapshot: snapshot,
            firstInvalidRecord: firstCorrectionProblem(
                in: snapshot.replay,
                originalReplay: session.snapshot.replay
            ),
            expectedTimeline: session.expectedTimeline
        )
        return DefensiveLogicalPlayDeletionPreview(
            session: deletionSession,
            correctionSession: correctionSession
        )
    }

    static func saveDefensiveLogicalPlayDeletion(
        _ preview: DefensiveLogicalPlayDeletionPreview,
        game: Game,
        modelContext: ModelContext,
        projectBattingLines: LiveGameSnapshotLoader.ProjectBattingLines = BattingStatProjector.project,
        save: Save = { try $0.save() }
    ) throws -> LiveGameSnapshot {
        guard preview.session.gameID == game.id else {
            throw GameEventCorrectionError.gameMismatch
        }
        guard preview.canSave else {
            throw GameEventCorrectionError.invalidCandidate
        }
        return try saveGameEventCorrection(
            preview.correctionSession,
            game: game,
            modelContext: modelContext,
            projectBattingLines: projectBattingLines,
            save: save
        )
    }

    static func stageDefensiveBallInPlayEdit(
        _ proposedPlay: BallInPlayEvent,
        in editSession: DefensiveBallInPlayEditSession,
        game: Game,
        modelContext: ModelContext,
        projectBattingLines: LiveGameSnapshotLoader.ProjectBattingLines = BattingStatProjector.project
    ) throws -> DefensiveBallInPlayEditPreview {
        guard editSession.gameID == game.id else {
            throw GameEventCorrectionError.gameMismatch
        }
        guard BallInPlayValidator.supportsCorrection(
                proposedPlay,
                stateBefore: editSession.stateBefore
              ),
              proposedPlay.opponentBatterSlot == editSession.opponentBatterSlot,
              let homeAway = HomeAway(rawValue: game.homeAwayRawValue),
              BallInPlayValidator.validate(
                proposedPlay,
                state: editSession.stateBefore,
                trackedTeamHomeAway: homeAway
              ) == nil else {
            throw GameEventCorrectionError.ballInPlayNotEditable
        }

        let session = try beginGameEventCorrection(game: game, modelContext: modelContext)
        guard session.expectedTimeline == editSession.expectedTimeline else {
            throw GameEventCorrectionError.staleTimeline
        }
        let change = DefensiveBallInPlayStagedChange(
            recordID: editSession.recordID,
            sequenceNumber: editSession.sequenceNumber,
            originalPlay: editSession.originalPlay,
            proposedPlay: proposedPlay
        )
        let candidateRecords = try applying(
            session.stagedChanges,
            offensivePitchChanges: session.stagedOffensivePitchChanges,
            ballInPlayChanges: [change],
            to: session.snapshot.records
        )
        let snapshot = try LiveGameSnapshotLoader.makeSnapshot(
            game: game,
            records: candidateRecords,
            projectBattingLines: projectBattingLines
        )
        let correctionSession = GameEventCorrectionSession(
            gameID: game.id,
            stagedChanges: session.stagedChanges,
            stagedOffensivePitchChanges: session.stagedOffensivePitchChanges,
            stagedBallInPlayChanges: [change],
            stagedLogicalPlayDeletions: session.stagedLogicalPlayDeletions,
            snapshot: snapshot,
            firstInvalidRecord: firstCorrectionProblem(
                in: snapshot.replay,
                originalReplay: session.snapshot.replay
            ),
            expectedTimeline: session.expectedTimeline
        )
        return DefensiveBallInPlayEditPreview(
            session: editSession,
            proposedPlay: proposedPlay,
            snapshot: snapshot,
            firstInvalidRecord: correctionSession.firstInvalidRecord,
            correctionSession: correctionSession
        )
    }

    static func saveDefensiveBallInPlayEdit(
        _ preview: DefensiveBallInPlayEditPreview,
        game: Game,
        modelContext: ModelContext,
        projectBattingLines: LiveGameSnapshotLoader.ProjectBattingLines = BattingStatProjector.project,
        save: Save = { try $0.save() }
    ) throws -> LiveGameSnapshot {
        guard preview.session.gameID == game.id else {
            throw GameEventCorrectionError.gameMismatch
        }
        guard preview.canSave,
              BallInPlayValidator.supportsCorrection(
                preview.proposedPlay,
                stateBefore: preview.session.stateBefore
              ),
              let correctionSession = preview.correctionSession else {
            throw GameEventCorrectionError.invalidCandidate
        }
        return try saveGameEventCorrection(
            correctionSession,
            game: game,
            modelContext: modelContext,
            projectBattingLines: projectBattingLines,
            save: save
        )
    }

    static func stageBallInPlayEdit(
        recordID: UUID,
        play: BallInPlayEvent,
        in session: GameEventCorrectionSession,
        game: Game,
        modelContext: ModelContext,
        projectBattingLines: LiveGameSnapshotLoader.ProjectBattingLines = BattingStatProjector.project
    ) throws -> GameEventCorrectionSession {
        guard session.gameID == game.id else {
            throw GameEventCorrectionError.gameMismatch
        }

        let correctionContext = freshContext(from: modelContext)
        let records = try fetchRecords(gameID: game.id, modelContext: correctionContext)
        guard records.map(GameEventRecordRevision.init) == session.expectedTimeline else {
            throw GameEventCorrectionError.staleTimeline
        }
        guard let record = records.first(where: { $0.id == recordID }),
              case .ballInPlay(let persistedPlay) = try record.decoded().body else {
            throw GameEventCorrectionError.ballInPlayNotEditable
        }
        let originalSnapshot = try validatedSnapshot(
            game: game,
            records: records,
            projectBattingLines: projectBattingLines
        )
        guard let originalEntry = originalSnapshot.replay.entries.first(where: {
            $0.recordID == recordID
        }),
              BallInPlayValidator.supportsCorrection(
                persistedPlay,
                stateBefore: originalEntry.stateBefore
              ) else {
            throw GameEventCorrectionError.ballInPlayNotEditable
        }

        let currentRecords = try applying(
            session.stagedChanges,
            offensivePitchChanges: session.stagedOffensivePitchChanges,
            ballInPlayChanges: session.stagedBallInPlayChanges,
            logicalPlayDeletions: session.stagedLogicalPlayDeletions,
            to: records
        )
        let currentSnapshot = try LiveGameSnapshotLoader.makeSnapshot(
            game: game,
            records: currentRecords,
            projectBattingLines: projectBattingLines
        )
        guard let entry = currentSnapshot.replay.entries.first(where: { $0.recordID == recordID }),
              play.opponentBatterSlot == entry.stateBefore.currentOpponentBatterSlot,
              BallInPlayValidator.supportsCorrection(play, stateBefore: entry.stateBefore),
              let homeAway = HomeAway(rawValue: game.homeAwayRawValue),
              BallInPlayValidator.validate(
                play,
                state: entry.stateBefore,
                trackedTeamHomeAway: homeAway
              ) == nil else {
            throw GameEventCorrectionError.ballInPlayNotEditable
        }

        let originalPlay = session.stagedBallInPlayChanges
            .first(where: { $0.recordID == recordID })?.originalPlay ?? persistedPlay
        let change = DefensiveBallInPlayStagedChange(
            recordID: record.id,
            sequenceNumber: record.sequenceNumber,
            originalPlay: originalPlay,
            proposedPlay: play
        )
        var ballInPlayChanges = session.stagedBallInPlayChanges
        if let index = ballInPlayChanges.firstIndex(where: { $0.recordID == recordID }) {
            ballInPlayChanges[index] = change
        } else {
            ballInPlayChanges.append(change)
        }

        let candidateRecords = try applying(
            session.stagedChanges,
            offensivePitchChanges: session.stagedOffensivePitchChanges,
            ballInPlayChanges: ballInPlayChanges,
            logicalPlayDeletions: session.stagedLogicalPlayDeletions,
            to: records
        )
        let snapshot = try LiveGameSnapshotLoader.makeSnapshot(
            game: game,
            records: candidateRecords,
            projectBattingLines: projectBattingLines
        )
        return GameEventCorrectionSession(
            gameID: game.id,
            stagedChanges: session.stagedChanges,
            stagedOffensivePitchChanges: session.stagedOffensivePitchChanges,
            stagedBallInPlayChanges: ballInPlayChanges,
            stagedLogicalPlayDeletions: session.stagedLogicalPlayDeletions,
            snapshot: snapshot,
            firstInvalidRecord: firstCorrectionProblem(
                in: snapshot.replay,
                originalReplay: originalSnapshot.replay
            ),
            expectedTimeline: session.expectedTimeline
        )
    }

    private static func stagePitchChange(
        recordID: UUID,
        action: DefensivePitchStagedAction,
        in session: GameEventCorrectionSession,
        game: Game,
        modelContext: ModelContext,
        projectBattingLines: LiveGameSnapshotLoader.ProjectBattingLines
    ) throws -> GameEventCorrectionSession {
        guard session.gameID == game.id else {
            throw GameEventCorrectionError.gameMismatch
        }

        let correctionContext = freshContext(from: modelContext)
        let records = try fetchRecords(gameID: game.id, modelContext: correctionContext)
        guard records.map(GameEventRecordRevision.init) == session.expectedTimeline else {
            throw GameEventCorrectionError.staleTimeline
        }
        guard let record = records.first(where: { $0.id == recordID }),
              case .pitch(let pitch) = try record.decoded().body else {
            switch action {
            case .edit: throw GameEventCorrectionError.pitchNotEditable
            case .delete: throw GameEventCorrectionError.pitchNotDeletable
            }
        }
        let originalSnapshot = try validatedSnapshot(
            game: game,
            records: records,
            projectBattingLines: projectBattingLines
        )

        let currentRecords = try applying(
            session.stagedChanges,
            offensivePitchChanges: session.stagedOffensivePitchChanges,
            ballInPlayChanges: session.stagedBallInPlayChanges,
            logicalPlayDeletions: session.stagedLogicalPlayDeletions,
            to: records
        )
        let currentSnapshot = try LiveGameSnapshotLoader.makeSnapshot(
            game: game,
            records: currentRecords,
            projectBattingLines: projectBattingLines
        )
        let referenceEntry = currentSnapshot.replay.entries.first(where: { $0.recordID == recordID })
            ?? session.snapshot.replay.entries.first(where: { $0.recordID == recordID })
        guard let referenceEntry else {
            throw GameEventCorrectionError.staleTimeline
        }
        if case .edit = action {
            guard isEditablePitch(pitch.result),
                  !completesPlateAppearance(pitch.result, stateBefore: referenceEntry.stateBefore) else {
                throw GameEventCorrectionError.pitchNotEditable
            }
        }

        let change = DefensivePitchStagedChange(
            recordID: record.id,
            sequenceNumber: record.sequenceNumber,
            inning: referenceEntry.stateBefore.inning,
            half: referenceEntry.stateBefore.half,
            opponentBatterSlot: pitch.opponentBatterSlot,
            pitcherID: pitch.pitcherID,
            originalResult: pitch.result,
            action: action
        )
        var changes = session.stagedChanges
        if let existingIndex = changes.firstIndex(where: { $0.recordID == recordID }) {
            changes[existingIndex] = change
        } else {
            changes.append(change)
        }

        let candidateRecords = try applying(
            changes,
            offensivePitchChanges: session.stagedOffensivePitchChanges,
            ballInPlayChanges: session.stagedBallInPlayChanges,
            logicalPlayDeletions: session.stagedLogicalPlayDeletions,
            to: records
        )
        let snapshot = try LiveGameSnapshotLoader.makeSnapshot(
            game: game,
            records: candidateRecords,
            projectBattingLines: projectBattingLines
        )
        return GameEventCorrectionSession(
            gameID: game.id,
            stagedChanges: changes,
            stagedOffensivePitchChanges: session.stagedOffensivePitchChanges,
            stagedBallInPlayChanges: session.stagedBallInPlayChanges,
            stagedLogicalPlayDeletions: session.stagedLogicalPlayDeletions,
            snapshot: snapshot,
            firstInvalidRecord: firstCorrectionProblem(
                in: snapshot.replay,
                originalReplay: originalSnapshot.replay
            ),
            expectedTimeline: session.expectedTimeline
        )
    }

    private static func stageOffensivePitchChange(
        recordID: UUID,
        action: OffensivePitchStagedAction,
        in session: GameEventCorrectionSession,
        game: Game,
        modelContext: ModelContext,
        projectBattingLines: LiveGameSnapshotLoader.ProjectBattingLines
    ) throws -> GameEventCorrectionSession {
        guard session.gameID == game.id else {
            throw GameEventCorrectionError.gameMismatch
        }

        let correctionContext = freshContext(from: modelContext)
        let records = try fetchRecords(gameID: game.id, modelContext: correctionContext)
        guard records.map(GameEventRecordRevision.init) == session.expectedTimeline else {
            throw GameEventCorrectionError.staleTimeline
        }
        guard let record = records.first(where: { $0.id == recordID }),
              case .offensivePitch(let persistedPitch) = try record.decoded().body,
              let homeAway = HomeAway(rawValue: game.homeAwayRawValue) else {
            throw GameEventCorrectionError.offensivePitchNotEditable
        }
        let originalSnapshot = try validatedSnapshot(
            game: game,
            records: records,
            projectBattingLines: projectBattingLines
        )
        let validateEvent = terminalCountValidator(originalReplay: originalSnapshot.replay)
        let currentRecords = try applying(
            session.stagedChanges,
            offensivePitchChanges: session.stagedOffensivePitchChanges,
            ballInPlayChanges: session.stagedBallInPlayChanges,
            logicalPlayDeletions: session.stagedLogicalPlayDeletions,
            to: records
        )
        let currentSnapshot = try LiveGameSnapshotLoader.makeSnapshot(
            game: game,
            records: currentRecords,
            projectBattingLines: projectBattingLines,
            validateEvent: validateEvent
        )
        guard let referenceEntry = currentSnapshot.replay.entries.first(where: {
            $0.recordID == recordID
        }) ?? session.snapshot.replay.entries.first(where: { $0.recordID == recordID }) else {
            throw GameEventCorrectionError.staleTimeline
        }
        if case .edit(let result) = action {
            let proposedPitch = OffensivePitchEvent(
                batter: persistedPitch.batter,
                battingOrderSize: persistedPitch.battingOrderSize,
                result: result
            )
            guard OffensivePitchValidator.isValid(
                proposedPitch,
                state: referenceEntry.stateBefore,
                trackedTeamHomeAway: homeAway
            ) else {
                throw GameEventCorrectionError.offensivePitchNotEditable
            }
        }

        let originalResult = session.stagedOffensivePitchChanges.first(where: {
            $0.recordID == recordID
        })?.originalResult ?? persistedPitch.result
        let change = OffensivePitchStagedChange(
            recordID: record.id,
            sequenceNumber: record.sequenceNumber,
            inning: referenceEntry.stateBefore.inning,
            half: referenceEntry.stateBefore.half,
            batter: persistedPitch.batter,
            battingOrderSize: persistedPitch.battingOrderSize,
            originalResult: originalResult,
            action: action
        )
        var offensivePitchChanges = session.stagedOffensivePitchChanges
        if let index = offensivePitchChanges.firstIndex(where: { $0.recordID == recordID }) {
            offensivePitchChanges[index] = change
        } else {
            offensivePitchChanges.append(change)
        }

        let candidateRecords = try applying(
            session.stagedChanges,
            offensivePitchChanges: offensivePitchChanges,
            ballInPlayChanges: session.stagedBallInPlayChanges,
            logicalPlayDeletions: session.stagedLogicalPlayDeletions,
            to: records
        )
        let snapshot = try LiveGameSnapshotLoader.makeSnapshot(
            game: game,
            records: candidateRecords,
            projectBattingLines: projectBattingLines,
            validateEvent: validateEvent
        )
        return GameEventCorrectionSession(
            gameID: game.id,
            stagedChanges: session.stagedChanges,
            stagedOffensivePitchChanges: offensivePitchChanges,
            stagedBallInPlayChanges: session.stagedBallInPlayChanges,
            stagedLogicalPlayDeletions: session.stagedLogicalPlayDeletions,
            snapshot: snapshot,
            firstInvalidRecord: firstCorrectionProblem(
                in: snapshot.replay,
                originalReplay: originalSnapshot.replay
            ),
            expectedTimeline: session.expectedTimeline
        )
    }

    private static func applying(
        _ changes: [DefensivePitchStagedChange],
        offensivePitchChanges: [OffensivePitchStagedChange],
        ballInPlayChanges: [DefensiveBallInPlayStagedChange],
        logicalPlayDeletions: [DefensiveLogicalPlayStagedDeletion] = [],
        to records: [GameEventRecord]
    ) throws -> [GameEventRecord] {
        let changesByRecordID = Dictionary(uniqueKeysWithValues: changes.map { ($0.recordID, $0) })
        let offensivePitchChangesByRecordID = Dictionary(
            uniqueKeysWithValues: offensivePitchChanges.map { ($0.recordID, $0) }
        )
        let ballInPlayChangesByRecordID = Dictionary(
            uniqueKeysWithValues: ballInPlayChanges.map { ($0.recordID, $0) }
        )
        let deletedLogicalPlayRecordIDs = Set(logicalPlayDeletions.flatMap {
            [$0.pitchRecordID, $0.resultRecordID]
        })
        return try records.compactMap { record in
            guard !deletedLogicalPlayRecordIDs.contains(record.id) else { return nil }
            if let change = ballInPlayChangesByRecordID[record.id] {
                return try GameEventRecord(
                    id: record.id,
                    gameID: record.gameID,
                    sequenceNumber: record.sequenceNumber,
                    timestamp: record.timestamp,
                    body: .ballInPlay(change.proposedPlay)
                )
            }
            if let change = offensivePitchChangesByRecordID[record.id] {
                switch change.action {
                case .delete:
                    return nil
                case .edit(let result):
                    return try GameEventRecord(
                        id: record.id,
                        gameID: record.gameID,
                        sequenceNumber: record.sequenceNumber,
                        timestamp: record.timestamp,
                        body: .offensivePitch(OffensivePitchEvent(
                            batter: change.batter,
                            battingOrderSize: change.battingOrderSize,
                            result: result
                        ))
                    )
                }
            }
            guard let change = changesByRecordID[record.id] else { return record }
            switch change.action {
            case .delete:
                return nil
            case .edit(let result):
                return try GameEventRecord(
                    id: record.id,
                    gameID: record.gameID,
                    sequenceNumber: record.sequenceNumber,
                    timestamp: record.timestamp,
                    body: .pitch(PitchEvent(
                        result: result,
                        pitcherID: change.pitcherID,
                        opponentBatterSlot: change.opponentBatterSlot
                    ))
                )
            }
        }
    }

    private static func firstCorrectionProblem(
        in replay: GameEventReplay.Result,
        originalReplay: GameEventReplay.Result
    ) -> GameEventCorrectionProblem? {
        let entry: GameEventReplay.Entry
        let hasTerminalCountMismatch: Bool
        if let rejectedEntry = replay.entries.first(where: { $0.rejection != nil }) {
            entry = rejectedEntry
            hasTerminalCountMismatch = violatesOriginalTerminalCount(
                rejectedEntry,
                originalReplay: originalReplay
            )
        } else {
            return nil
        }
        let context: String
        let explanation: String
        let canEditPitch: Bool
        let canEditOffensivePitch: Bool
        let canDeleteOffensivePitch: Bool
        let canDeletePitch: Bool
        let canEditBallInPlay: Bool
        switch entry.body {
        case .pitch(let pitch):
            context = "\(entry.stateBefore.half.displayName) \(entry.stateBefore.inning) · "
                + "Opponent batter \(pitch.opponentBatterSlot) · \(pitch.result.label)"
            explanation = "Full replay reached opponent batter "
                + "\(entry.stateBefore.currentOpponentBatterSlot) with a "
                + "\(entry.stateBefore.balls)–\(entry.stateBefore.strikes) count "
                + "before rejecting this pitch."
            canEditPitch = isEditablePitch(pitch.result)
                && !completesPlateAppearance(pitch.result, stateBefore: entry.stateBefore)
            canEditOffensivePitch = false
            canDeleteOffensivePitch = false
            canDeletePitch = true
            canEditBallInPlay = false
        case .ballInPlay(let play):
            context = "\(entry.stateBefore.half.displayName) \(entry.stateBefore.inning) · "
                + "Opponent batter \(play.opponentBatterSlot) · \(play.outcome.label)"
            explanation = "Full replay rejected this completed play at its original "
                + "chronological position. Confirm a result and every runner destination "
                + "against the proposed game state."
            canEditPitch = false
            canEditOffensivePitch = false
            canDeleteOffensivePitch = false
            canDeletePitch = false
            if let originalEntry = originalReplay.entries.first(where: {
                $0.recordID == entry.recordID
            }),
               case .ballInPlay(let originalPlay) = originalEntry.body {
                canEditBallInPlay = BallInPlayValidator.supportsCorrection(
                    originalPlay,
                    stateBefore: originalEntry.stateBefore
                ) && BallInPlayValidator.supportsCorrection(
                    play,
                    stateBefore: entry.stateBefore
                )
            } else {
                canEditBallInPlay = false
            }
        case .offensivePitch(let pitch):
            context = "\(entry.stateBefore.half.displayName) \(entry.stateBefore.inning) · "
                + "\(pitch.batter.displayName) · Batting slot \(pitch.batter.lineupSlot) "
                + "of \(pitch.battingOrderSize) · \(pitch.result.label)"
            explanation = "Full replay reached tracked batting slot "
                + "\(entry.stateBefore.currentTrackedBatterSlot) with a "
                + "\(entry.stateBefore.balls)–\(entry.stateBefore.strikes) count "
                + "before rejecting this pitch for its event-time batter."
            canEditPitch = false
            canEditOffensivePitch = true
            canDeleteOffensivePitch = true
            canDeletePitch = false
            canEditBallInPlay = false
        case .offensivePlateAppearance(let plateAppearance) where hasTerminalCountMismatch:
            context = "\(entry.stateBefore.half.displayName) \(entry.stateBefore.inning) · "
                + "\(plateAppearance.batter.displayName) · Batting slot "
                + "\(plateAppearance.batter.lineupSlot) of "
                + "\(plateAppearance.battingOrderSize) · \(plateAppearance.result.label)"
            explanation = "Full replay reached tracked batting slot "
                + "\(entry.stateBefore.currentTrackedBatterSlot) with a "
                + "\(entry.stateBefore.balls)–\(entry.stateBefore.strikes) count "
                + "before rejecting this \(plateAppearance.result.label) for its saved count contract."
            canEditPitch = false
            canEditOffensivePitch = false
            canDeleteOffensivePitch = false
            canDeletePitch = false
            canEditBallInPlay = false
        default:
            context = "\(entry.stateBefore.half.displayName) \(entry.stateBefore.inning) · Saved event"
            explanation = "Full replay rejected this record at its original chronological position."
            canEditPitch = false
            canEditOffensivePitch = false
            canDeleteOffensivePitch = false
            canDeletePitch = false
            canEditBallInPlay = false
        }
        return GameEventCorrectionProblem(
            id: entry.recordID,
            sequenceNumber: entry.sequenceNumber,
            context: context,
            explanation: explanation,
            canEditPitch: canEditPitch,
            canEditOffensivePitch: canEditOffensivePitch,
            canDeleteOffensivePitch: canDeleteOffensivePitch,
            canDeletePitch: canDeletePitch,
            canEditBallInPlay: canEditBallInPlay
        )
    }

    private static func terminalCountValidator(
        originalReplay: GameEventReplay.Result
    ) -> GameEventReplay.ValidateEvent {
        { record, event, state in
            guard case .offensivePlateAppearance(let plateAppearance) = event.body,
                  let originalEntry = originalReplay.entries.first(where: {
                      $0.recordID == record.id
                  }),
                  case .offensivePlateAppearance(let originalPlateAppearance) = originalEntry.body,
                  terminalCountMatches(
                    originalPlateAppearance.result,
                    state: originalEntry.stateBefore
                  ) else {
                return true
            }
            return terminalCountMatches(plateAppearance.result, state: state)
        }
    }

    private static func violatesOriginalTerminalCount(
        _ entry: GameEventReplay.Entry,
        originalReplay: GameEventReplay.Result
    ) -> Bool {
        guard case .offensivePlateAppearance(let plateAppearance) = entry.body,
              let originalEntry = originalReplay.entries.first(where: {
                  $0.recordID == entry.recordID
              }),
              case .offensivePlateAppearance(let originalPlateAppearance) = originalEntry.body,
              terminalCountMatches(
                originalPlateAppearance.result,
                state: originalEntry.stateBefore
              ) else {
            return false
        }
        return !terminalCountMatches(plateAppearance.result, state: entry.stateBefore)
    }

    private static func terminalCountMatches(
        _ result: OffensivePlateAppearanceResult,
        state: GameState
    ) -> Bool {
        switch result {
        case .walk: state.balls == 3
        case .strikeout: state.strikes == 2
        default: false
        }
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
        records: [GameEventRecord],
        projectBattingLines: LiveGameSnapshotLoader.ProjectBattingLines = BattingStatProjector.project
    ) throws -> LiveGameSnapshot {
        let snapshot = try LiveGameSnapshotLoader.makeSnapshot(
            game: game,
            records: records,
            projectBattingLines: projectBattingLines
        )
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

    private static func isEditablePitch(_ result: PitchResult) -> Bool {
        switch result {
        case .ball, .calledStrike, .swingingStrike, .foul: true
        case .ballInPlay, .hitByPitch: false
        }
    }

    private static func legacyInvalidRecord(
        in correctionSession: GameEventCorrectionSession
    ) -> DefensivePitchCorrectionInvalidRecord? {
        correctionSession.snapshot.replay.entries
            .first(where: { $0.rejection != nil })
            .map { entry in
                DefensivePitchCorrectionInvalidRecord(
                    id: entry.recordID,
                    sequenceNumber: entry.sequenceNumber,
                    summary: invalidSummary(for: entry.rejection)
                )
            }
    }

    private static func invalidSummary(for rejection: GameEventReplay.Rejection?) -> String {
        switch rejection {
        case .invalidSequence: "Invalid event sequence"
        case .unknownKind: "Unsupported saved event"
        case .malformedPayload: "Unreadable saved event"
        case .semanticallyRejected: "Play conflicts with the proposed pitch"
        case nil: "Invalid saved event"
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

    private static func trackedRunnerContext(
        playerID: UUID,
        source: RunnerSource,
        entries: ArraySlice<GameEventReplay.Entry>
    ) -> (identity: TrackedBatterIdentity, battingOrderSize: Int)? {
        var occupiedSource = source
        for entry in entries.reversed() {
            guard runnerPlayerID(in: entry.stateAfter, at: occupiedSource) == playerID else {
                return nil
            }

            switch entry.body {
            case .offensiveBaseRunning(let event):
                guard event.destination.occupiedSource == occupiedSource else { continue }
                guard event.runnerID == playerID else { return nil }
                occupiedSource = event.source

            case .offensivePlateAppearance(let plateAppearance):
                guard let movement = plateAppearance.movements.first(where: {
                    $0.destination.occupiedSource == occupiedSource
                }) else { continue }
                if movement.source == .batter {
                    guard plateAppearance.batter.playerID == playerID else { return nil }
                    return (plateAppearance.batter, plateAppearance.battingOrderSize)
                }
                guard runnerPlayerID(in: entry.stateBefore, at: movement.source) == playerID else {
                    return nil
                }
                occupiedSource = movement.source

            default:
                continue
            }
        }
        return nil
    }

    private static func runnerPlayerID(in state: GameState, at source: RunnerSource) -> UUID? {
        switch source {
        case .batter: nil
        case .first: state.firstBaseRunnerPlayerID
        case .second: state.secondBaseRunnerPlayerID
        case .third: state.thirdBaseRunnerPlayerID
        }
    }
}

private extension RunnerDestination {
    var occupiedSource: RunnerSource? {
        switch self {
        case .first: .first
        case .second: .second
        case .third: .third
        case .home, .out: nil
        }
    }
}
