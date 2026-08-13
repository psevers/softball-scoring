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

struct DefensivePitchCorrectionInvalidRecord: Equatable {
    let id: UUID
    let sequenceNumber: Int
    let summary: String
}

struct DefensivePitchEditPreview {
    let session: DefensivePitchEditSession
    let proposedResult: PitchResult
    let snapshot: LiveGameSnapshot
    let firstInvalidRecord: DefensivePitchCorrectionInvalidRecord?

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
    case pitchNotDeletable
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
            "The game history changed before the correction was confirmed. Refresh and try again."
        case .pitchNotEditable:
            "This saved event is not an editable non-terminal defensive pitch."
        case .pitchNotDeletable:
            "This saved event is not a defensive pitch that can be deleted."
        case .invalidCandidate:
            "The proposed pitch change leaves invalid game history and cannot be saved."
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

        let correctionContext = freshContext(from: modelContext)
        let records = try fetchRecords(gameID: game.id, modelContext: correctionContext)
        guard records.map(GameEventRecordRevision.init) == session.expectedTimeline else {
            throw GameEventCorrectionError.staleTimeline
        }
        let candidateRecords = try replacingPitch(
            in: records,
            session: session,
            with: proposedResult
        )
        let snapshot = try LiveGameSnapshotLoader.makeSnapshot(
            game: game,
            records: candidateRecords,
            projectBattingLines: projectBattingLines
        )
        let invalidRecord = snapshot.replay.entries
            .first(where: { $0.rejection != nil })
            .map { entry in
                DefensivePitchCorrectionInvalidRecord(
                    id: entry.recordID,
                    sequenceNumber: entry.sequenceNumber,
                    summary: invalidSummary(for: entry.rejection)
                )
            }
        return DefensivePitchEditPreview(
            session: session,
            proposedResult: proposedResult,
            snapshot: snapshot,
            firstInvalidRecord: invalidRecord
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

        let records = try fetchRecords(gameID: game.id, modelContext: modelContext)
        guard records.map(GameEventRecordRevision.init) == preview.session.expectedTimeline else {
            throw GameEventCorrectionError.staleTimeline
        }
        let candidateRecords = try replacingPitch(
            in: records,
            session: preview.session,
            with: preview.proposedResult
        )
        let correctedSnapshot = try validatedSnapshot(
            game: game,
            records: candidateRecords,
            projectBattingLines: projectBattingLines
        )
        guard let record = records.first(where: { $0.id == preview.session.recordID }) else {
            throw GameEventCorrectionError.staleTimeline
        }
        let encoded = try GameEventCodec.encode(.pitch(PitchEvent(
            result: preview.proposedResult,
            pitcherID: preview.session.pitcherID,
            opponentBatterSlot: preview.session.opponentBatterSlot
        )))
        record.kindRawValue = encoded.kind.rawValue
        record.payload = encoded.payload
        do {
            try save(modelContext)
        } catch {
            modelContext.rollback()
            throw error
        }
        return correctedSnapshot
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

        let correctionContext = freshContext(from: modelContext)
        let records = try fetchRecords(gameID: game.id, modelContext: correctionContext)
        guard records.map(GameEventRecordRevision.init) == session.expectedTimeline else {
            throw GameEventCorrectionError.staleTimeline
        }
        let candidateRecords = try deletingPitch(in: records, session: session)
        let snapshot = try LiveGameSnapshotLoader.makeSnapshot(
            game: game,
            records: candidateRecords,
            projectBattingLines: projectBattingLines
        )
        let invalidRecord = snapshot.replay.entries
            .first(where: { $0.rejection != nil })
            .map { entry in
                DefensivePitchCorrectionInvalidRecord(
                    id: entry.recordID,
                    sequenceNumber: entry.sequenceNumber,
                    summary: invalidSummary(for: entry.rejection)
                )
            }
        return DefensivePitchDeletionPreview(
            session: session,
            snapshot: snapshot,
            firstInvalidRecord: invalidRecord
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

        let correctionContext = freshContext(from: modelContext)
        let records = try fetchRecords(gameID: game.id, modelContext: correctionContext)
        guard records.map(GameEventRecordRevision.init) == preview.session.expectedTimeline else {
            throw GameEventCorrectionError.staleTimeline
        }
        let candidateRecords = try deletingPitch(in: records, session: preview.session)
        let correctedSnapshot = try validatedSnapshot(
            game: game,
            records: candidateRecords,
            projectBattingLines: projectBattingLines
        )
        guard let record = records.first(where: { $0.id == preview.session.recordID }) else {
            throw GameEventCorrectionError.staleTimeline
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

    private static func replacingPitch(
        in records: [GameEventRecord],
        session: DefensivePitchEditSession,
        with result: PitchResult
    ) throws -> [GameEventRecord] {
        guard records.contains(where: { $0.id == session.recordID }) else {
            throw GameEventCorrectionError.staleTimeline
        }
        return try records.map { record in
            guard record.id == session.recordID else { return record }
            return try GameEventRecord(
                id: record.id,
                gameID: record.gameID,
                sequenceNumber: record.sequenceNumber,
                timestamp: record.timestamp,
                body: .pitch(PitchEvent(
                    result: result,
                    pitcherID: session.pitcherID,
                    opponentBatterSlot: session.opponentBatterSlot
                ))
            )
        }
    }

    private static func deletingPitch(
        in records: [GameEventRecord],
        session: DefensivePitchDeletionSession
    ) throws -> [GameEventRecord] {
        guard records.contains(where: { $0.id == session.recordID }) else {
            throw GameEventCorrectionError.staleTimeline
        }
        return records.filter { $0.id != session.recordID }
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
