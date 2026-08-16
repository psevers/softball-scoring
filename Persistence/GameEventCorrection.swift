import Foundation
import SwiftData

enum UndoLatestAction: Equatable {
    case pitch(PitchResult)
    case pitchCountReconciliation(PitchCountReconciliationEvent)
    case ballInPlayResult(BallInPlayOutcome)
    case offensivePitch(OffensivePitchResult)
    case offensiveBaseRunning(OffensiveBaseRunningEvent)
    case offensivePlateAppearance(OffensivePlateAppearanceEvent)

    var label: String {
        switch self {
        case .pitch(let result): result.label
        case .pitchCountReconciliation(let reconciliation):
            "Pitch total \(signedPitchAdjustment(reconciliation.adjustment.total))"
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
        case .pitchCountReconciliation: "Undo Latest Reconciliation"
        case .ballInPlayResult: "Undo Latest Result"
        case .offensiveBaseRunning(let event): "Undo Latest \(event.result.shortLabel)"
        case .offensivePlateAppearance: "Undo Latest Play"
        }
    }
}

enum UndoLatestActor: Equatable {
    case opponentBatter(slot: Int)
    case trackedBatter(TrackedBatterIdentity, battingOrderSize: Int)
    case pitcher(UUID)
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
        case .pitchCountReconciliation: "Undo latest pitch reconciliation?"
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
        case .pitcher:
            "starting pitcher"
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
        case .pitchCountReconciliation(let reconciliation):
            let adjustment = reconciliation.adjustment
            return "Remove \(confirmationMessage) Balls "
                + "\(signedPitchAdjustment(adjustment.balls)), strikes "
                + "\(signedPitchAdjustment(adjustment.strikes)), unclassified "
                + "\(signedPitchAdjustment(adjustment.unclassified)). "
                + "The related scoring plays and live count will remain unchanged."
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

struct CompletedDefensivePlayOption: Identifiable, Equatable, Sendable {
    var id: UUID { recordID }

    let recordID: UUID
    let sequenceNumber: Int
    let inning: Int
    let half: InningHalf
    let opponentBatterSlot: Int
    let summary: String

    fileprivate let reference: RelatedDefensivePlayReference
}

struct PitchCountReconciliationSession: Identifiable {
    var id: UUID { pitcherID }

    let gameID: UUID
    let pitcherID: UUID
    let currentCount: PitchCount
    let completedDefensivePlays: [CompletedDefensivePlayOption]

    fileprivate let expectedTimeline: [GameEventRecordRevision]

    func reconciledCount(adjustment: PitchCountAdjustment) -> PitchCount? {
        currentCount.reconciling(PitchCountReconciliationEvent(
            pitcherID: pitcherID,
            adjustment: adjustment
        ))
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

struct OffensiveBaseRunningRunner: Identifiable, Equatable {
    var id: UUID { identity.playerID }

    let identity: TrackedBatterIdentity
    let battingOrderSize: Int
    let source: RunnerSource
}

struct OffensiveBaseRunningEditSession: Identifiable {
    var id: UUID { recordID }

    let recordID: UUID
    let gameID: UUID
    let sequenceNumber: Int
    let inning: Int
    let half: InningHalf
    let runner: TrackedBatterIdentity
    let runnerBattingOrderSize: Int
    let eligibleRunners: [OffensiveBaseRunningRunner]
    let originalEvent: OffensiveBaseRunningEvent
    let stateBefore: GameState
    let originalStateAfter: GameState
    let originalBattingLines: [UUID: BattingLine]

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

struct OffensivePlateAppearanceEditSession: Identifiable {
    var id: UUID { recordID }

    let recordID: UUID
    let gameID: UUID
    let sequenceNumber: Int
    let inning: Int
    let half: InningHalf
    let homeAway: HomeAway
    let batter: TrackedBatterIdentity
    let battingOrderSize: Int
    let runnerIdentities: [RunnerSource: TrackedBatterIdentity]
    let originalPlateAppearance: OffensivePlateAppearanceEvent
    let stateBefore: GameState
    let originalStateAfter: GameState
    let originalBattingLine: BattingLine
    let originalBattingLines: [UUID: BattingLine]

    fileprivate let expectedTimeline: [GameEventRecordRevision]
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

struct OffensivePlateAppearanceStagedChange: Identifiable, Equatable {
    var id: UUID { recordID }

    let recordID: UUID
    let sequenceNumber: Int
    let originalPlateAppearance: OffensivePlateAppearanceEvent
    let proposedPlateAppearance: OffensivePlateAppearanceEvent

    var summary: String {
        "Sequence \(sequenceNumber) · \(originalPlateAppearance.batter.displayName) · "
            + "\(originalPlateAppearance.result.label) to \(proposedPlateAppearance.result.label)"
    }
}

enum OffensiveBaseRunningStagedAction: Equatable {
    case edit(OffensiveBaseRunningEvent)
    case delete
}

struct OffensiveBaseRunningStagedChange: Identifiable, Equatable {
    var id: UUID { recordID }

    let recordID: UUID
    let sequenceNumber: Int
    let originalEvent: OffensiveBaseRunningEvent
    let action: OffensiveBaseRunningStagedAction

    var summary: String {
        let original = "\(originalEvent.result.shortLabel) "
            + "\(originalEvent.source.baseLabel) to \(originalEvent.destination.label)"
        return switch action {
        case .edit(let event):
            "Sequence \(sequenceNumber) · \(original) · Change to "
                + "\(event.result.shortLabel) \(event.source.baseLabel) to "
                + event.destination.label
        case .delete:
            "Sequence \(sequenceNumber) · Delete \(original)"
        }
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

struct PitchCountReconciliationStagedChange: Identifiable, Equatable {
    var id: UUID { recordID }

    let recordID: UUID
    let sequenceNumber: Int
    let originalReconciliation: PitchCountReconciliationEvent
    let proposedReconciliation: PitchCountReconciliationEvent?

    var summary: String {
        guard let proposedReconciliation else {
            return "Sequence \(sequenceNumber) · Delete pitch reconciliation"
        }
        if let relatedPlay = proposedReconciliation.relatedPlay {
            return "Sequence \(sequenceNumber) · Associate reconciliation with sequence "
                + "\(relatedPlay.sequenceNumber)"
        }
        return "Sequence \(sequenceNumber) · Remove related-play association"
    }
}

struct RelatedDefensivePlayRepairOption: Identifiable, Equatable, Sendable {
    var id: UUID { recordID }

    let recordID: UUID
    let sequenceNumber: Int
    let summary: String
}

struct CompletedPlayDeletionComponent: Identifiable, Equatable {
    var id: UUID { recordID }

    let recordID: UUID
    let sequenceNumber: Int
    let summary: String
}

struct CompletedPlayRepairDeletion: Identifiable, Equatable {
    enum Kind: Equatable {
        case defensive
        case offensive
    }

    var id: UUID { resultRecordID }

    let kind: Kind
    let resultRecordID: UUID
    let context: String
    let components: [CompletedPlayDeletionComponent]

    var confirmationTitle: String { "Delete affected completed play?" }

    var confirmationDetail: String {
        let componentList = components
            .map { "Sequence \($0.sequenceNumber): \($0.summary)" }
            .joined(separator: "\n")
        return "\(context). These records will be added to the staged deletion:\n"
            + componentList
    }
}

struct CompletedPlayStagedDeletion: Identifiable, Equatable {
    var id: UUID { resultComponent.recordID }

    let pitchComponents: [CompletedPlayDeletionComponent]
    let resultComponent: CompletedPlayDeletionComponent
    let resultLabel: String

    var components: [CompletedPlayDeletionComponent] {
        pitchComponents + [resultComponent]
    }

    var recordIDs: [UUID] { components.map(\.recordID) }
    var sequenceNumbers: [Int] { components.map(\.sequenceNumber) }
    var resultRecordID: UUID { resultComponent.recordID }
    var resultSequenceNumber: Int { resultComponent.sequenceNumber }

    var summary: String {
        let sequences = sequenceNumbers.map(String.init).joined(separator: ", ")
        return "Sequences \(sequences) · Delete completed \(resultLabel)"
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
    let canEditOffensiveBaseRunning: Bool
    let canEditOffensivePlateAppearance: Bool
    let canDeleteOffensiveBaseRunning: Bool
    let canRepairPitchCountReconciliation: Bool
    let canDeletePitchCountReconciliation: Bool
    let relatedDefensivePlays: [RelatedDefensivePlayRepairOption]
    let logicalPlayDeletion: CompletedPlayRepairDeletion?
    let offensiveBaseRunningRunners: [OffensiveBaseRunningRunner]
    let offensiveRunnerIdentities: [TrackedBatterIdentity]
}

struct UnreadableRecordDeletionSession: Identifiable {
    var id: UUID { recordID }

    let recordID: UUID
    let gameID: UUID
    let sequenceNumber: Int
    let timestamp: Date
    let kindRawValue: String
    let problemSummary: String

    fileprivate let expectedTimeline: [GameEventRecordRevision]

    var confirmationTitle: String { "Delete unreadable event?" }

    var confirmationDetail: String {
        "Sequence \(sequenceNumber), record \(recordID.uuidString), saved kind \""
            + "\(kindRawValue)\": \(problemSummary). Only this exact record will be staged "
            + "for deletion. Its missing meaning will not be guessed or edited."
    }
}

struct ProblemRecordStagedDeletion: Identifiable, Equatable {
    var id: UUID { recordID }

    let recordID: UUID
    let sequenceNumber: Int
    let problemSummary: String

    var summary: String {
        "Sequence \(sequenceNumber) · Delete \(problemSummary.lowercased())"
    }
}

struct GameEventCorrectionSession {
    let gameID: UUID
    let stagedChanges: [DefensivePitchStagedChange]
    let stagedOffensivePitchChanges: [OffensivePitchStagedChange]
    let stagedOffensiveBaseRunningChanges: [OffensiveBaseRunningStagedChange]
    let stagedOffensivePlateAppearanceChanges: [OffensivePlateAppearanceStagedChange]
    let stagedBallInPlayChanges: [DefensiveBallInPlayStagedChange]
    let stagedPitchCountReconciliationChanges: [PitchCountReconciliationStagedChange]
    let stagedLogicalPlayDeletions: [CompletedPlayStagedDeletion]
    let stagedProblemRecordDeletions: [ProblemRecordStagedDeletion]
    let snapshot: LiveGameSnapshot
    let firstInvalidRecord: GameEventCorrectionProblem?

    fileprivate let expectedTimeline: [GameEventRecordRevision]

    fileprivate init(
        gameID: UUID,
        stagedChanges: [DefensivePitchStagedChange],
        stagedOffensivePitchChanges: [OffensivePitchStagedChange],
        stagedOffensiveBaseRunningChanges: [OffensiveBaseRunningStagedChange],
        stagedOffensivePlateAppearanceChanges: [OffensivePlateAppearanceStagedChange],
        stagedBallInPlayChanges: [DefensiveBallInPlayStagedChange],
        stagedPitchCountReconciliationChanges: [PitchCountReconciliationStagedChange],
        stagedLogicalPlayDeletions: [CompletedPlayStagedDeletion],
        stagedProblemRecordDeletions: [ProblemRecordStagedDeletion] = [],
        snapshot: LiveGameSnapshot,
        firstInvalidRecord: GameEventCorrectionProblem?,
        expectedTimeline: [GameEventRecordRevision]
    ) {
        self.gameID = gameID
        self.stagedChanges = stagedChanges
        self.stagedOffensivePitchChanges = stagedOffensivePitchChanges
        self.stagedOffensiveBaseRunningChanges = stagedOffensiveBaseRunningChanges
        self.stagedOffensivePlateAppearanceChanges = stagedOffensivePlateAppearanceChanges
        self.stagedBallInPlayChanges = stagedBallInPlayChanges
        self.stagedPitchCountReconciliationChanges = stagedPitchCountReconciliationChanges
        self.stagedLogicalPlayDeletions = stagedLogicalPlayDeletions
        self.stagedProblemRecordDeletions = stagedProblemRecordDeletions
        self.snapshot = snapshot
        self.firstInvalidRecord = firstInvalidRecord
        self.expectedTimeline = expectedTimeline
    }

    var canSave: Bool {
        (!stagedChanges.isEmpty
            || stagedOffensivePitchChanges.contains {
                switch $0.action {
                case .edit(let result): result != $0.originalResult
                case .delete: true
                }
            }
            || stagedOffensiveBaseRunningChanges.contains {
                switch $0.action {
                case .edit(let event): event != $0.originalEvent
                case .delete: true
                }
            }
            || stagedOffensivePlateAppearanceChanges.contains {
                $0.proposedPlateAppearance != $0.originalPlateAppearance
            }
            || stagedBallInPlayChanges.contains { $0.proposedPlay != $0.originalPlay }
            || stagedPitchCountReconciliationChanges.contains {
                $0.proposedReconciliation != $0.originalReconciliation
            }
            || !stagedLogicalPlayDeletions.isEmpty
            || !stagedProblemRecordDeletions.isEmpty)
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

    fileprivate let stagedDeletion: CompletedPlayStagedDeletion
    fileprivate let expectedTimeline: [GameEventRecordRevision]

    var components: [CompletedPlayDeletionComponent] { stagedDeletion.components }

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

struct OffensiveLogicalPlayDeletionSession: Identifiable {
    var id: UUID { resultRecordID }

    let resultRecordID: UUID
    let gameID: UUID
    let inning: Int
    let half: InningHalf
    let batter: TrackedBatterIdentity
    let battingOrderSize: Int

    fileprivate let stagedDeletion: CompletedPlayStagedDeletion
    fileprivate let expectedTimeline: [GameEventRecordRevision]

    var components: [CompletedPlayDeletionComponent] { stagedDeletion.components }

    var confirmationTitle: String {
        "Delete completed tracked play?"
    }

    var confirmationDetail: String {
        let componentList = components
            .map { "Sequence \($0.sequenceNumber): \($0.summary)" }
            .joined(separator: "\n")
        return "\(half.displayName) of inning \(inning), \(batter.displayName), batting slot "
            + "\(batter.lineupSlot) of \(battingOrderSize). These records will be removed:\n"
            + "\(componentList)\nUnrelated base-running and later records will remain."
    }
}

struct OffensiveLogicalPlayDeletionPreview {
    let session: OffensiveLogicalPlayDeletionSession
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
    case offensiveBaseRunningNotEditable
    case offensivePitchNotDeletable
    case offensivePlateAppearanceNotEditable
    case pitchNotDeletable
    case ballInPlayNotEditable
    case logicalPlayNotDeletable
    case offensiveLogicalPlayNotDeletable
    case invalidCandidate
    case noStartingPitcher
    case invalidReconciliation
    case invalidRelatedPlay
    case unreadableRecordNotDeletable

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
        case .offensiveBaseRunningNotEditable:
            "This saved event is not an editable tracked-team SB or CS entry."
        case .offensivePitchNotDeletable:
            "This saved event is not a tracked-team pitch that can be deleted."
        case .offensivePlateAppearanceNotEditable:
            "This saved event is not an editable tracked-team plate appearance that stays within its half-inning."
        case .pitchNotDeletable:
            "This saved event is not a defensive pitch that can be deleted."
        case .ballInPlayNotEditable:
            "This saved event is not an editable defensive Ball In Play result."
        case .logicalPlayNotDeletable:
            "This saved event is not a completed defensive Ball In Play."
        case .offensiveLogicalPlayNotDeletable:
            "This saved event is not a completed tracked-team logical play."
        case .invalidCandidate:
            "The proposed change leaves invalid game history and cannot be saved."
        case .noStartingPitcher:
            "This game does not have a starting pitcher to reconcile."
        case .invalidReconciliation:
            "The adjustment would produce invalid pitcher totals."
        case .invalidRelatedPlay:
            "Choose a readable completed defensive play from this game."
        case .unreadableRecordNotDeletable:
            "Only an unknown event kind or malformed saved payload can use deletion-only repair."
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

    static func preparePitchCountReconciliation(
        game: Game,
        modelContext: ModelContext
    ) throws -> PitchCountReconciliationSession {
        guard let pitcherID = game.startingPitcherID else {
            throw GameEventCorrectionError.noStartingPitcher
        }
        let correctionContext = freshContext(from: modelContext)
        let records = try fetchRecords(gameID: game.id, modelContext: correctionContext)
        let snapshot = try validatedSnapshot(game: game, records: records)
        return PitchCountReconciliationSession(
            gameID: game.id,
            pitcherID: pitcherID,
            currentCount: snapshot.replay.state.pitchCount(for: pitcherID),
            completedDefensivePlays: completedDefensivePlays(
                records: records,
                replay: snapshot.replay
            ),
            expectedTimeline: records.map(GameEventRecordRevision.init)
        )
    }

    static func savePitchCountReconciliation(
        adjustment: PitchCountAdjustment,
        relatedPlayRecordID: UUID? = nil,
        session: PitchCountReconciliationSession,
        game: Game,
        modelContext: ModelContext,
        save: Save = { try $0.save() }
    ) throws -> LiveGameSnapshot {
        guard session.gameID == game.id else {
            throw GameEventCorrectionError.gameMismatch
        }
        guard game.startingPitcherID == session.pitcherID else {
            throw GameEventCorrectionError.staleTimeline
        }
        let relatedPlay = try relatedPlayRecordID.map { recordID in
            guard let play = session.completedDefensivePlays.first(where: {
                $0.recordID == recordID
            }) else {
                throw GameEventCorrectionError.invalidRelatedPlay
            }
            return play.reference
        }
        let event = PitchCountReconciliationEvent(
            pitcherID: session.pitcherID,
            adjustment: adjustment,
            relatedPlay: relatedPlay
        )
        guard session.currentCount.reconciling(event) != nil else {
            throw GameEventCorrectionError.invalidReconciliation
        }

        let correctionContext = freshContext(from: modelContext)
        let records = try fetchRecords(gameID: game.id, modelContext: correctionContext)
        guard records.map(GameEventRecordRevision.init) == session.expectedTimeline else {
            throw GameEventCorrectionError.staleTimeline
        }
        let record = try GameEventRecord(
            gameID: game.id,
            sequenceNumber: (records.map(\.sequenceNumber).max() ?? 0) + 1,
            body: .pitchCountReconciliation(event)
        )
        let snapshot = try validatedSnapshot(game: game, records: records + [record])

        correctionContext.insert(record)
        do {
            try save(correctionContext)
        } catch {
            correctionContext.rollback()
            throw error
        }
        return snapshot
    }

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
        case .pitchCountReconciliation(let reconciliation):
            action = .pitchCountReconciliation(reconciliation)
            actor = .pitcher(reconciliation.pitcherID)
            completedPlateAppearance = false
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
            stagedOffensiveBaseRunningChanges: [],
            stagedOffensivePlateAppearanceChanges: [],
            stagedBallInPlayChanges: [],
            stagedPitchCountReconciliationChanges: [],
            stagedLogicalPlayDeletions: [],
            snapshot: snapshot,
            firstInvalidRecord: nil,
            expectedTimeline: records.map(GameEventRecordRevision.init)
        )
    }

    static func prepareUnreadableRecordDeletion(
        recordID: UUID,
        game: Game,
        modelContext: ModelContext
    ) throws -> UnreadableRecordDeletionSession {
        let correctionContext = freshContext(from: modelContext)
        let records = try fetchRecords(gameID: game.id, modelContext: correctionContext)
        let snapshot = try LiveGameSnapshotLoader.makeSnapshot(game: game, records: records)
        guard let record = records.first(where: { $0.id == recordID }),
              let entry = snapshot.replay.entries.first(where: { $0.recordID == recordID }),
              isDeletionOnlyRejection(entry.rejection) else {
            throw GameEventCorrectionError.unreadableRecordNotDeletable
        }
        return UnreadableRecordDeletionSession(
            recordID: record.id,
            gameID: record.gameID,
            sequenceNumber: record.sequenceNumber,
            timestamp: record.timestamp,
            kindRawValue: record.kindRawValue,
            problemSummary: invalidSummary(for: entry.rejection),
            expectedTimeline: records.map(GameEventRecordRevision.init)
        )
    }

    static func stageUnreadableRecordDeletion(
        _ deletion: UnreadableRecordDeletionSession,
        game: Game,
        modelContext: ModelContext,
        projectBattingLines: LiveGameSnapshotLoader.ProjectBattingLines = BattingStatProjector.project
    ) throws -> GameEventCorrectionSession {
        guard deletion.gameID == game.id else {
            throw GameEventCorrectionError.gameMismatch
        }
        let correctionContext = freshContext(from: modelContext)
        let records = try fetchRecords(gameID: game.id, modelContext: correctionContext)
        guard records.map(GameEventRecordRevision.init) == deletion.expectedTimeline else {
            throw GameEventCorrectionError.staleTimeline
        }
        let originalSnapshot = try LiveGameSnapshotLoader.makeSnapshot(
            game: game,
            records: records,
            projectBattingLines: projectBattingLines
        )
        guard let entry = originalSnapshot.replay.entries.first(where: {
            $0.recordID == deletion.recordID
        }), isDeletionOnlyRejection(entry.rejection) else {
            throw GameEventCorrectionError.unreadableRecordNotDeletable
        }
        let stagedDeletion = ProblemRecordStagedDeletion(
            recordID: deletion.recordID,
            sequenceNumber: deletion.sequenceNumber,
            problemSummary: deletion.problemSummary
        )
        let candidateRecords = try applying(
            [],
            offensivePitchChanges: [],
            offensiveBaseRunningChanges: [],
            offensivePlateAppearanceChanges: [],
            ballInPlayChanges: [],
            pitchCountReconciliationChanges: [],
            problemRecordDeletions: [stagedDeletion],
            to: records
        )
        let snapshot = try LiveGameSnapshotLoader.makeSnapshot(
            game: game,
            records: candidateRecords,
            projectBattingLines: projectBattingLines
        )
        return GameEventCorrectionSession(
            gameID: game.id,
            stagedChanges: [],
            stagedOffensivePitchChanges: [],
            stagedOffensiveBaseRunningChanges: [],
            stagedOffensivePlateAppearanceChanges: [],
            stagedBallInPlayChanges: [],
            stagedPitchCountReconciliationChanges: [],
            stagedLogicalPlayDeletions: [],
            stagedProblemRecordDeletions: [stagedDeletion],
            snapshot: snapshot,
            firstInvalidRecord: firstCorrectionProblem(
                in: snapshot.replay,
                originalReplay: originalSnapshot.replay
            ),
            expectedTimeline: deletion.expectedTimeline
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

    static func stagePitchCountReconciliationAssociation(
        recordID: UUID,
        relatedPlayRecordID: UUID?,
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
        let originalSnapshot = try validatedSnapshot(
            game: game,
            records: records,
            projectBattingLines: projectBattingLines
        )
        guard let storedRecord = records.first(where: { $0.id == recordID }),
              case .pitchCountReconciliation(let storedReconciliation) =
                try storedRecord.decoded().body else {
            throw GameEventCorrectionError.invalidCandidate
        }
        let currentRecords = try applying(
            session.stagedChanges,
            offensivePitchChanges: session.stagedOffensivePitchChanges,
            offensiveBaseRunningChanges: session.stagedOffensiveBaseRunningChanges,
            offensivePlateAppearanceChanges: session.stagedOffensivePlateAppearanceChanges,
            ballInPlayChanges: session.stagedBallInPlayChanges,
            pitchCountReconciliationChanges: session.stagedPitchCountReconciliationChanges,
            logicalPlayDeletions: session.stagedLogicalPlayDeletions,
            to: records
        )
        let relatedPlay: RelatedDefensivePlayReference?
        if let relatedPlayRecordID {
            guard let targetRecord = currentRecords.first(where: {
                $0.id == relatedPlayRecordID && $0.sequenceNumber < storedRecord.sequenceNumber
            }),
                  let targetEntry = session.snapshot.replay.entries.first(where: {
                      $0.recordID == relatedPlayRecordID && $0.rejection == nil
                  }),
                  let targetBody = targetEntry.body,
                  GameEventReplay.isCompletedDefensivePlay(
                      targetBody,
                      stateBefore: targetEntry.stateBefore
                  ) else {
                throw GameEventCorrectionError.invalidRelatedPlay
            }
            relatedPlay = targetRecord.relatedDefensivePlayReference
        } else {
            relatedPlay = nil
        }
        let currentReconciliation = session.stagedPitchCountReconciliationChanges
            .first(where: { $0.recordID == recordID })?
            .proposedReconciliation ?? storedReconciliation
        let proposedReconciliation = PitchCountReconciliationEvent(
            pitcherID: currentReconciliation.pitcherID,
            adjustment: currentReconciliation.adjustment,
            relatedPlay: relatedPlay
        )
        return try stagingPitchCountReconciliationChange(
            storedRecord: storedRecord,
            storedReconciliation: storedReconciliation,
            proposedReconciliation: proposedReconciliation,
            records: records,
            originalSnapshot: originalSnapshot,
            in: session,
            game: game,
            projectBattingLines: projectBattingLines
        )
    }

    static func stagePitchCountReconciliationDeletion(
        recordID: UUID,
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
        let originalSnapshot = try validatedSnapshot(
            game: game,
            records: records,
            projectBattingLines: projectBattingLines
        )
        guard let storedRecord = records.first(where: { $0.id == recordID }),
              case .pitchCountReconciliation(let storedReconciliation) =
                try storedRecord.decoded().body else {
            throw GameEventCorrectionError.invalidCandidate
        }
        return try stagingPitchCountReconciliationChange(
            storedRecord: storedRecord,
            storedReconciliation: storedReconciliation,
            proposedReconciliation: nil,
            records: records,
            originalSnapshot: originalSnapshot,
            in: session,
            game: game,
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
            offensiveBaseRunningChanges: session.stagedOffensiveBaseRunningChanges,
            offensivePlateAppearanceChanges: session.stagedOffensivePlateAppearanceChanges,
            ballInPlayChanges: session.stagedBallInPlayChanges,
            pitchCountReconciliationChanges: session.stagedPitchCountReconciliationChanges,
            logicalPlayDeletions: session.stagedLogicalPlayDeletions,
            problemRecordDeletions: session.stagedProblemRecordDeletions,
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
        for change in session.stagedOffensiveBaseRunningChanges {
            guard let record = records.first(where: { $0.id == change.recordID }) else {
                throw GameEventCorrectionError.staleTimeline
            }
            switch change.action {
            case .edit(let event):
                let encoded = try GameEventCodec.encode(.offensiveBaseRunning(event))
                record.kindRawValue = encoded.kind.rawValue
                record.payload = encoded.payload
            case .delete:
                correctionContext.delete(record)
            }
        }
        for change in session.stagedOffensivePlateAppearanceChanges {
            guard let record = records.first(where: { $0.id == change.recordID }) else {
                throw GameEventCorrectionError.staleTimeline
            }
            let encoded = try GameEventCodec.encode(
                .offensivePlateAppearance(change.proposedPlateAppearance)
            )
            record.kindRawValue = encoded.kind.rawValue
            record.payload = encoded.payload
        }
        for change in session.stagedBallInPlayChanges {
            guard let record = records.first(where: { $0.id == change.recordID }) else {
                throw GameEventCorrectionError.staleTimeline
            }
            let encoded = try GameEventCodec.encode(.ballInPlay(change.proposedPlay))
            record.kindRawValue = encoded.kind.rawValue
            record.payload = encoded.payload
        }
        for change in session.stagedPitchCountReconciliationChanges {
            guard let record = records.first(where: { $0.id == change.recordID }) else {
                throw GameEventCorrectionError.staleTimeline
            }
            if let proposedReconciliation = change.proposedReconciliation {
                let encoded = try GameEventCodec.encode(
                    .pitchCountReconciliation(proposedReconciliation)
                )
                record.kindRawValue = encoded.kind.rawValue
                record.payload = encoded.payload
            } else {
                correctionContext.delete(record)
            }
        }
        let logicalPlayRecordIDs = Set(session.stagedLogicalPlayDeletions.flatMap {
            $0.recordIDs
        })
        for record in records where logicalPlayRecordIDs.contains(record.id) {
            correctionContext.delete(record)
        }
        let problemRecordIDs = Set(session.stagedProblemRecordDeletions.map(\.recordID))
        for record in records where problemRecordIDs.contains(record.id) {
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

    static func prepareOffensiveBaseRunningEdit(
        recordID: UUID,
        game: Game,
        modelContext: ModelContext
    ) throws -> OffensiveBaseRunningEditSession {
        let correctionContext = freshContext(from: modelContext)
        let records = try fetchRecords(gameID: game.id, modelContext: correctionContext)
        let snapshot = try validatedSnapshot(game: game, records: records)
        guard let record = records.first(where: { $0.id == recordID }),
              let entryIndex = snapshot.replay.entries.firstIndex(where: { $0.recordID == recordID }),
              case .offensiveBaseRunning(let event) = snapshot.replay.entries[entryIndex].body else {
            throw GameEventCorrectionError.offensiveBaseRunningNotEditable
        }

        let entry = snapshot.replay.entries[entryIndex]
        guard let eligibleRunners = offensiveBaseRunningRunners(
            at: entryIndex,
            in: snapshot.replay
        ) else {
            throw GameEventCorrectionError.invalidTimeline
        }
        guard let originalRunner = eligibleRunners.first(where: {
            $0.source == event.source && $0.identity.playerID == event.runnerID
        }) else {
            throw GameEventCorrectionError.invalidTimeline
        }

        return OffensiveBaseRunningEditSession(
            recordID: record.id,
            gameID: game.id,
            sequenceNumber: record.sequenceNumber,
            inning: entry.stateBefore.inning,
            half: entry.stateBefore.half,
            runner: originalRunner.identity,
            runnerBattingOrderSize: originalRunner.battingOrderSize,
            eligibleRunners: eligibleRunners,
            originalEvent: event,
            stateBefore: entry.stateBefore,
            originalStateAfter: entry.stateAfter,
            originalBattingLines: snapshot.battingLines,
            expectedTimeline: records.map(GameEventRecordRevision.init)
        )
    }

    static func prepareOffensivePlateAppearanceEdit(
        recordID: UUID,
        game: Game,
        modelContext: ModelContext
    ) throws -> OffensivePlateAppearanceEditSession {
        let correctionContext = freshContext(from: modelContext)
        let records = try fetchRecords(gameID: game.id, modelContext: correctionContext)
        let snapshot = try validatedSnapshot(game: game, records: records)
        guard let record = records.first(where: { $0.id == recordID }),
              let entryIndex = snapshot.replay.entries.firstIndex(where: { $0.recordID == recordID }),
              case .offensivePlateAppearance(let plateAppearance) = snapshot.replay.entries[entryIndex].body,
              let homeAway = HomeAway(rawValue: game.homeAwayRawValue),
              isCorrectableOffensivePlateAppearance(
                plateAppearance,
                stateBefore: snapshot.replay.entries[entryIndex].stateBefore,
                trackedTeamHomeAway: homeAway
              ) else {
            throw GameEventCorrectionError.offensivePlateAppearanceNotEditable
        }

        let entry = snapshot.replay.entries[entryIndex]
        var runnerIdentities: [RunnerSource: TrackedBatterIdentity] = [
            .batter: plateAppearance.batter
        ]
        for source in entry.stateBefore.occupiedTrackedRunnerSources where source != .batter {
            guard let playerID = runnerPlayerID(in: entry.stateBefore, at: source),
                  let runner = trackedRunnerContext(
                    playerID: playerID,
                    source: source,
                    entries: snapshot.replay.entries[..<entryIndex]
                  ) else {
                throw GameEventCorrectionError.invalidTimeline
            }
            runnerIdentities[source] = runner.identity
        }

        return OffensivePlateAppearanceEditSession(
            recordID: record.id,
            gameID: game.id,
            sequenceNumber: record.sequenceNumber,
            inning: entry.stateBefore.inning,
            half: entry.stateBefore.half,
            homeAway: homeAway,
            batter: plateAppearance.batter,
            battingOrderSize: plateAppearance.battingOrderSize,
            runnerIdentities: runnerIdentities,
            originalPlateAppearance: plateAppearance,
            stateBefore: entry.stateBefore,
            originalStateAfter: entry.stateAfter,
            originalBattingLine: snapshot.battingLines[
                plateAppearance.batter.playerID,
                default: BattingLine()
            ],
            originalBattingLines: snapshot.battingLines,
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

    static func stageOffensiveBaseRunningEdit(
        _ proposedEvent: OffensiveBaseRunningEvent,
        in editSession: OffensiveBaseRunningEditSession,
        game: Game,
        modelContext: ModelContext,
        projectBattingLines: LiveGameSnapshotLoader.ProjectBattingLines = BattingStatProjector.project
    ) throws -> GameEventCorrectionSession {
        guard editSession.gameID == game.id else {
            throw GameEventCorrectionError.gameMismatch
        }
        let session = try beginGameEventCorrection(game: game, modelContext: modelContext)
        guard session.expectedTimeline == editSession.expectedTimeline else {
            throw GameEventCorrectionError.staleTimeline
        }
        return try stageOffensiveBaseRunningEdit(
            recordID: editSession.recordID,
            event: proposedEvent,
            in: session,
            game: game,
            modelContext: modelContext,
            projectBattingLines: projectBattingLines
        )
    }

    static func stageOffensivePlateAppearanceEdit(
        _ proposedPlateAppearance: OffensivePlateAppearanceEvent,
        in editSession: OffensivePlateAppearanceEditSession,
        game: Game,
        modelContext: ModelContext,
        projectBattingLines: LiveGameSnapshotLoader.ProjectBattingLines = BattingStatProjector.project
    ) throws -> GameEventCorrectionSession {
        guard editSession.gameID == game.id else {
            throw GameEventCorrectionError.gameMismatch
        }
        let session = try beginGameEventCorrection(game: game, modelContext: modelContext)
        guard session.expectedTimeline == editSession.expectedTimeline else {
            throw GameEventCorrectionError.staleTimeline
        }
        return try stageOffensivePlateAppearanceEdit(
            recordID: editSession.recordID,
            plateAppearance: proposedPlateAppearance,
            in: session,
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
        let pitchComponent = CompletedPlayDeletionComponent(
            recordID: pitchRecord.id,
            sequenceNumber: pitchRecord.sequenceNumber,
            summary: "Ball In Play pitch"
        )
        let resultComponent = CompletedPlayDeletionComponent(
            recordID: resultRecord.id,
            sequenceNumber: resultRecord.sequenceNumber,
            summary: "\(play.outcome.label) result"
        )
        let stagedDeletion = CompletedPlayStagedDeletion(
            pitchComponents: [pitchComponent],
            resultComponent: resultComponent,
            resultLabel: play.outcome.label
        )
        return DefensiveLogicalPlayDeletionSession(
            resultRecordID: resultRecord.id,
            gameID: game.id,
            inning: snapshot.replay.entries[resultIndex - 1].stateBefore.inning,
            half: snapshot.replay.entries[resultIndex - 1].stateBefore.half,
            opponentBatterSlot: play.opponentBatterSlot,
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
        let correctionSession = try addingLogicalPlayDeletion(
            deletionSession.stagedDeletion,
            expectedTimeline: deletionSession.expectedTimeline,
            to: session,
            game: game,
            modelContext: modelContext,
            projectBattingLines: projectBattingLines
        )
        return DefensiveLogicalPlayDeletionPreview(
            session: deletionSession,
            correctionSession: correctionSession
        )
    }

    static func stageDefensiveLogicalPlayDeletion(
        resultRecordID: UUID,
        in session: GameEventCorrectionSession,
        game: Game,
        modelContext: ModelContext,
        projectBattingLines: LiveGameSnapshotLoader.ProjectBattingLines = BattingStatProjector.project
    ) throws -> GameEventCorrectionSession {
        guard session.gameID == game.id else {
            throw GameEventCorrectionError.gameMismatch
        }
        let deletionSession = try prepareDefensiveLogicalPlayDeletion(
            resultRecordID: resultRecordID,
            game: game,
            modelContext: modelContext
        )
        return try addingLogicalPlayDeletion(
            deletionSession.stagedDeletion,
            expectedTimeline: deletionSession.expectedTimeline,
            to: session,
            game: game,
            modelContext: modelContext,
            projectBattingLines: projectBattingLines
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

    static func prepareOffensiveLogicalPlayDeletion(
        resultRecordID: UUID,
        game: Game,
        modelContext: ModelContext
    ) throws -> OffensiveLogicalPlayDeletionSession {
        let correctionContext = freshContext(from: modelContext)
        let records = try fetchRecords(gameID: game.id, modelContext: correctionContext)
        let snapshot = try validatedSnapshot(game: game, records: records)
        guard let resultIndex = snapshot.replay.entries.firstIndex(where: {
            $0.recordID == resultRecordID
        }),
              let resultRecord = records.first(where: { $0.id == resultRecordID }),
              case .offensivePlateAppearance(let plateAppearance) =
                snapshot.replay.entries[resultIndex].body,
              snapshot.replay.entries[resultIndex].rejection == nil,
              let homeAway = HomeAway(rawValue: game.homeAwayRawValue),
              isCorrectableOffensivePlateAppearance(
                plateAppearance,
                stateBefore: snapshot.replay.entries[resultIndex].stateBefore,
                trackedTeamHomeAway: homeAway
              ),
              let componentEntries = offensiveLogicalPlayEntries(
                endingAt: resultIndex,
                in: snapshot.replay
              ) else {
            throw GameEventCorrectionError.offensiveLogicalPlayNotDeletable
        }

        let recordsByID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        var components: [CompletedPlayDeletionComponent] = []
        for entry in componentEntries {
            guard let record = recordsByID[entry.recordID], let body = entry.body else {
                throw GameEventCorrectionError.invalidTimeline
            }
            let summary = switch body {
            case .offensivePitch(let pitch): "\(pitch.result.label) pitch"
            case .offensivePlateAppearance(let result): "\(result.result.label) result"
            default: throw GameEventCorrectionError.invalidTimeline
            }
            components.append(CompletedPlayDeletionComponent(
                recordID: record.id,
                sequenceNumber: record.sequenceNumber,
                summary: summary
            ))
        }
        guard let firstEntry = componentEntries.first,
              let resultComponent = components.last else {
            throw GameEventCorrectionError.invalidTimeline
        }
        let stagedDeletion = CompletedPlayStagedDeletion(
            pitchComponents: Array(components.dropLast()),
            resultComponent: resultComponent,
            resultLabel: plateAppearance.result.label
        )
        return OffensiveLogicalPlayDeletionSession(
            resultRecordID: resultRecord.id,
            gameID: game.id,
            inning: firstEntry.stateBefore.inning,
            half: firstEntry.stateBefore.half,
            batter: plateAppearance.batter,
            battingOrderSize: plateAppearance.battingOrderSize,
            stagedDeletion: stagedDeletion,
            expectedTimeline: records.map(GameEventRecordRevision.init)
        )
    }

    static func stageOffensiveLogicalPlayDeletion(
        _ deletionSession: OffensiveLogicalPlayDeletionSession,
        game: Game,
        modelContext: ModelContext,
        projectBattingLines: LiveGameSnapshotLoader.ProjectBattingLines = BattingStatProjector.project
    ) throws -> OffensiveLogicalPlayDeletionPreview {
        guard deletionSession.gameID == game.id else {
            throw GameEventCorrectionError.gameMismatch
        }
        let session = try beginGameEventCorrection(game: game, modelContext: modelContext)
        guard session.expectedTimeline == deletionSession.expectedTimeline else {
            throw GameEventCorrectionError.staleTimeline
        }
        let correctionSession = try addingLogicalPlayDeletion(
            deletionSession.stagedDeletion,
            expectedTimeline: deletionSession.expectedTimeline,
            to: session,
            game: game,
            modelContext: modelContext,
            projectBattingLines: projectBattingLines
        )
        return OffensiveLogicalPlayDeletionPreview(
            session: deletionSession,
            correctionSession: correctionSession
        )
    }

    static func stageOffensiveLogicalPlayDeletion(
        resultRecordID: UUID,
        in session: GameEventCorrectionSession,
        game: Game,
        modelContext: ModelContext,
        projectBattingLines: LiveGameSnapshotLoader.ProjectBattingLines = BattingStatProjector.project
    ) throws -> GameEventCorrectionSession {
        guard session.gameID == game.id else {
            throw GameEventCorrectionError.gameMismatch
        }
        let deletionSession = try prepareOffensiveLogicalPlayDeletion(
            resultRecordID: resultRecordID,
            game: game,
            modelContext: modelContext
        )
        return try addingLogicalPlayDeletion(
            deletionSession.stagedDeletion,
            expectedTimeline: deletionSession.expectedTimeline,
            to: session,
            game: game,
            modelContext: modelContext,
            projectBattingLines: projectBattingLines
        )
    }

    private static func addingLogicalPlayDeletion(
        _ stagedDeletion: CompletedPlayStagedDeletion,
        expectedTimeline: [GameEventRecordRevision],
        to session: GameEventCorrectionSession,
        game: Game,
        modelContext: ModelContext,
        projectBattingLines: LiveGameSnapshotLoader.ProjectBattingLines
    ) throws -> GameEventCorrectionSession {
        guard session.gameID == game.id else {
            throw GameEventCorrectionError.gameMismatch
        }
        let correctionContext = freshContext(from: modelContext)
        let records = try fetchRecords(gameID: game.id, modelContext: correctionContext)
        guard records.map(GameEventRecordRevision.init) == session.expectedTimeline,
              expectedTimeline == session.expectedTimeline else {
            throw GameEventCorrectionError.staleTimeline
        }
        guard !session.stagedLogicalPlayDeletions.contains(where: {
            $0.resultRecordID == stagedDeletion.resultRecordID
        }) else {
            throw GameEventCorrectionError.invalidCandidate
        }
        let originalSnapshot = try validatedSnapshot(
            game: game,
            records: records,
            projectBattingLines: projectBattingLines
        )
        let deletedRecordIDs = Set(stagedDeletion.recordIDs)
        let changes = session.stagedChanges.filter {
            !deletedRecordIDs.contains($0.recordID)
        }
        let offensivePitchChanges = session.stagedOffensivePitchChanges.filter {
            !deletedRecordIDs.contains($0.recordID)
        }
        let offensiveBaseRunningChanges = session.stagedOffensiveBaseRunningChanges.filter {
            !deletedRecordIDs.contains($0.recordID)
        }
        let offensivePlateAppearanceChanges = session.stagedOffensivePlateAppearanceChanges.filter {
            !deletedRecordIDs.contains($0.recordID)
        }
        let ballInPlayChanges = session.stagedBallInPlayChanges.filter {
            !deletedRecordIDs.contains($0.recordID)
        }
        let deletions = session.stagedLogicalPlayDeletions + [stagedDeletion]
        let candidateRecords = try applying(
            changes,
            offensivePitchChanges: offensivePitchChanges,
            offensiveBaseRunningChanges: offensiveBaseRunningChanges,
            offensivePlateAppearanceChanges: offensivePlateAppearanceChanges,
            ballInPlayChanges: ballInPlayChanges,
            pitchCountReconciliationChanges: session.stagedPitchCountReconciliationChanges,
            logicalPlayDeletions: deletions,
            to: records
        )
        let snapshot = try LiveGameSnapshotLoader.makeSnapshot(
            game: game,
            records: candidateRecords,
            projectBattingLines: projectBattingLines,
            validateEvent: terminalCountValidator(
                originalReplay: originalSnapshot.replay,
                ignoredRecordIDs: Set(offensivePlateAppearanceChanges.map(\.recordID))
            )
        )
        return GameEventCorrectionSession(
            gameID: game.id,
            stagedChanges: changes,
            stagedOffensivePitchChanges: offensivePitchChanges,
            stagedOffensiveBaseRunningChanges: offensiveBaseRunningChanges,
            stagedOffensivePlateAppearanceChanges: offensivePlateAppearanceChanges,
            stagedBallInPlayChanges: ballInPlayChanges,
            stagedPitchCountReconciliationChanges: session.stagedPitchCountReconciliationChanges,
            stagedLogicalPlayDeletions: deletions,
            snapshot: snapshot,
            firstInvalidRecord: firstCorrectionProblem(
                in: snapshot.replay,
                originalReplay: originalSnapshot.replay
            ),
            expectedTimeline: session.expectedTimeline
        )
    }

    static func saveOffensiveLogicalPlayDeletion(
        _ preview: OffensiveLogicalPlayDeletionPreview,
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
            offensiveBaseRunningChanges: session.stagedOffensiveBaseRunningChanges,
            offensivePlateAppearanceChanges: session.stagedOffensivePlateAppearanceChanges,
            ballInPlayChanges: [change],
            pitchCountReconciliationChanges: session.stagedPitchCountReconciliationChanges,
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
            stagedOffensiveBaseRunningChanges: session.stagedOffensiveBaseRunningChanges,
            stagedOffensivePlateAppearanceChanges: session.stagedOffensivePlateAppearanceChanges,
            stagedBallInPlayChanges: [change],
            stagedPitchCountReconciliationChanges: session.stagedPitchCountReconciliationChanges,
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
            offensiveBaseRunningChanges: session.stagedOffensiveBaseRunningChanges,
            offensivePlateAppearanceChanges: session.stagedOffensivePlateAppearanceChanges,
            ballInPlayChanges: session.stagedBallInPlayChanges,
            pitchCountReconciliationChanges: session.stagedPitchCountReconciliationChanges,
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
            offensiveBaseRunningChanges: session.stagedOffensiveBaseRunningChanges,
            offensivePlateAppearanceChanges: session.stagedOffensivePlateAppearanceChanges,
            ballInPlayChanges: ballInPlayChanges,
            pitchCountReconciliationChanges: session.stagedPitchCountReconciliationChanges,
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
            stagedOffensiveBaseRunningChanges: session.stagedOffensiveBaseRunningChanges,
            stagedOffensivePlateAppearanceChanges: session.stagedOffensivePlateAppearanceChanges,
            stagedBallInPlayChanges: ballInPlayChanges,
            stagedPitchCountReconciliationChanges: session.stagedPitchCountReconciliationChanges,
            stagedLogicalPlayDeletions: session.stagedLogicalPlayDeletions,
            snapshot: snapshot,
            firstInvalidRecord: firstCorrectionProblem(
                in: snapshot.replay,
                originalReplay: originalSnapshot.replay
            ),
            expectedTimeline: session.expectedTimeline
        )
    }

    static func stageOffensiveBaseRunningEdit(
        recordID: UUID,
        event: OffensiveBaseRunningEvent,
        in session: GameEventCorrectionSession,
        game: Game,
        modelContext: ModelContext,
        projectBattingLines: LiveGameSnapshotLoader.ProjectBattingLines = BattingStatProjector.project
    ) throws -> GameEventCorrectionSession {
        try stageOffensiveBaseRunningChange(
            recordID: recordID,
            action: .edit(event),
            in: session,
            game: game,
            modelContext: modelContext,
            projectBattingLines: projectBattingLines
        )
    }

    static func stageOffensiveBaseRunningDeletion(
        recordID: UUID,
        in session: GameEventCorrectionSession,
        game: Game,
        modelContext: ModelContext,
        projectBattingLines: LiveGameSnapshotLoader.ProjectBattingLines = BattingStatProjector.project
    ) throws -> GameEventCorrectionSession {
        try stageOffensiveBaseRunningChange(
            recordID: recordID,
            action: .delete,
            in: session,
            game: game,
            modelContext: modelContext,
            projectBattingLines: projectBattingLines
        )
    }

    private static func stageOffensiveBaseRunningChange(
        recordID: UUID,
        action: OffensiveBaseRunningStagedAction,
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
              case .offensiveBaseRunning(let persistedEvent) = try record.decoded().body,
              let homeAway = HomeAway(rawValue: game.homeAwayRawValue) else {
            throw GameEventCorrectionError.offensiveBaseRunningNotEditable
        }

        let originalSnapshot = try validatedSnapshot(
            game: game,
            records: records,
            projectBattingLines: projectBattingLines
        )
        guard let originalEntry = originalSnapshot.replay.entries.first(where: {
            $0.recordID == recordID
        }), OffensiveBaseRunningValidator.isValid(
            persistedEvent,
            state: originalEntry.stateBefore,
            trackedTeamHomeAway: homeAway
        ) else {
            throw GameEventCorrectionError.offensiveBaseRunningNotEditable
        }

        if case .edit(let event) = action {
            let currentRecords = try applying(
                session.stagedChanges,
                offensivePitchChanges: session.stagedOffensivePitchChanges,
                offensiveBaseRunningChanges: session.stagedOffensiveBaseRunningChanges,
                offensivePlateAppearanceChanges: session.stagedOffensivePlateAppearanceChanges,
                ballInPlayChanges: session.stagedBallInPlayChanges,
                pitchCountReconciliationChanges: session.stagedPitchCountReconciliationChanges,
                logicalPlayDeletions: session.stagedLogicalPlayDeletions,
                to: records
            )
            let currentSnapshot = try LiveGameSnapshotLoader.makeSnapshot(
                game: game,
                records: currentRecords,
                projectBattingLines: projectBattingLines
            )
            guard let referenceEntry = currentSnapshot.replay.entries.first(where: {
                $0.recordID == recordID
            }) ?? session.snapshot.replay.entries.first(where: { $0.recordID == recordID }),
                  OffensiveBaseRunningValidator.isValid(
                    event,
                    state: referenceEntry.stateBefore,
                    trackedTeamHomeAway: homeAway
                  ) else {
                throw GameEventCorrectionError.offensiveBaseRunningNotEditable
            }
        }

        let originalEvent = session.stagedOffensiveBaseRunningChanges.first(where: {
            $0.recordID == recordID
        })?.originalEvent ?? persistedEvent
        let change = OffensiveBaseRunningStagedChange(
            recordID: record.id,
            sequenceNumber: record.sequenceNumber,
            originalEvent: originalEvent,
            action: action
        )
        var baseRunningChanges = session.stagedOffensiveBaseRunningChanges
        if let index = baseRunningChanges.firstIndex(where: { $0.recordID == recordID }) {
            baseRunningChanges[index] = change
        } else {
            baseRunningChanges.append(change)
        }

        let candidateRecords = try applying(
            session.stagedChanges,
            offensivePitchChanges: session.stagedOffensivePitchChanges,
            offensiveBaseRunningChanges: baseRunningChanges,
            offensivePlateAppearanceChanges: session.stagedOffensivePlateAppearanceChanges,
            ballInPlayChanges: session.stagedBallInPlayChanges,
            pitchCountReconciliationChanges: session.stagedPitchCountReconciliationChanges,
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
            stagedOffensiveBaseRunningChanges: baseRunningChanges,
            stagedOffensivePlateAppearanceChanges: session.stagedOffensivePlateAppearanceChanges,
            stagedBallInPlayChanges: session.stagedBallInPlayChanges,
            stagedPitchCountReconciliationChanges: session.stagedPitchCountReconciliationChanges,
            stagedLogicalPlayDeletions: session.stagedLogicalPlayDeletions,
            snapshot: snapshot,
            firstInvalidRecord: firstCorrectionProblem(
                in: snapshot.replay,
                originalReplay: originalSnapshot.replay
            ),
            expectedTimeline: session.expectedTimeline
        )
    }

    static func stageOffensivePlateAppearanceEdit(
        recordID: UUID,
        plateAppearance: OffensivePlateAppearanceEvent,
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
              case .offensivePlateAppearance(let persistedPlateAppearance) = try record.decoded().body,
              let homeAway = HomeAway(rawValue: game.homeAwayRawValue) else {
            throw GameEventCorrectionError.offensivePlateAppearanceNotEditable
        }

        let originalSnapshot = try validatedSnapshot(
            game: game,
            records: records,
            projectBattingLines: projectBattingLines
        )
        guard let originalEntry = originalSnapshot.replay.entries.first(where: {
            $0.recordID == recordID
        }),
              isCorrectableOffensivePlateAppearance(
                persistedPlateAppearance,
                stateBefore: originalEntry.stateBefore,
                trackedTeamHomeAway: homeAway
              ) else {
            throw GameEventCorrectionError.offensivePlateAppearanceNotEditable
        }

        let currentRecords = try applying(
            session.stagedChanges,
            offensivePitchChanges: session.stagedOffensivePitchChanges,
            offensiveBaseRunningChanges: session.stagedOffensiveBaseRunningChanges,
            offensivePlateAppearanceChanges: session.stagedOffensivePlateAppearanceChanges,
            ballInPlayChanges: session.stagedBallInPlayChanges,
            pitchCountReconciliationChanges: session.stagedPitchCountReconciliationChanges,
            logicalPlayDeletions: session.stagedLogicalPlayDeletions,
            to: records
        )
        let existingChangedRecordIDs = Set(
            session.stagedOffensivePlateAppearanceChanges.map(\.recordID)
        )
        let currentSnapshot = try LiveGameSnapshotLoader.makeSnapshot(
            game: game,
            records: currentRecords,
            projectBattingLines: projectBattingLines,
            validateEvent: terminalCountValidator(
                originalReplay: originalSnapshot.replay,
                ignoredRecordIDs: existingChangedRecordIDs
            )
        )
        guard let referenceEntry = currentSnapshot.replay.entries.first(where: {
            $0.recordID == recordID
        }) ?? session.snapshot.replay.entries.first(where: { $0.recordID == recordID }),
              plateAppearance.batter == persistedPlateAppearance.batter,
              plateAppearance.battingOrderSize == persistedPlateAppearance.battingOrderSize,
              isCorrectableOffensivePlateAppearance(
                plateAppearance,
                stateBefore: referenceEntry.stateBefore,
                trackedTeamHomeAway: homeAway
              ) else {
            throw GameEventCorrectionError.offensivePlateAppearanceNotEditable
        }

        let originalPlateAppearance = session.stagedOffensivePlateAppearanceChanges
            .first(where: { $0.recordID == recordID })?.originalPlateAppearance
            ?? persistedPlateAppearance
        let change = OffensivePlateAppearanceStagedChange(
            recordID: record.id,
            sequenceNumber: record.sequenceNumber,
            originalPlateAppearance: originalPlateAppearance,
            proposedPlateAppearance: plateAppearance
        )
        var plateAppearanceChanges = session.stagedOffensivePlateAppearanceChanges
        if let index = plateAppearanceChanges.firstIndex(where: { $0.recordID == recordID }) {
            plateAppearanceChanges[index] = change
        } else {
            plateAppearanceChanges.append(change)
        }

        let candidateRecords = try applying(
            session.stagedChanges,
            offensivePitchChanges: session.stagedOffensivePitchChanges,
            offensiveBaseRunningChanges: session.stagedOffensiveBaseRunningChanges,
            offensivePlateAppearanceChanges: plateAppearanceChanges,
            ballInPlayChanges: session.stagedBallInPlayChanges,
            pitchCountReconciliationChanges: session.stagedPitchCountReconciliationChanges,
            logicalPlayDeletions: session.stagedLogicalPlayDeletions,
            to: records
        )
        let snapshot = try LiveGameSnapshotLoader.makeSnapshot(
            game: game,
            records: candidateRecords,
            projectBattingLines: projectBattingLines,
            validateEvent: terminalCountValidator(
                originalReplay: originalSnapshot.replay,
                ignoredRecordIDs: Set(plateAppearanceChanges.map(\.recordID))
            )
        )
        return GameEventCorrectionSession(
            gameID: game.id,
            stagedChanges: session.stagedChanges,
            stagedOffensivePitchChanges: session.stagedOffensivePitchChanges,
            stagedOffensiveBaseRunningChanges: session.stagedOffensiveBaseRunningChanges,
            stagedOffensivePlateAppearanceChanges: plateAppearanceChanges,
            stagedBallInPlayChanges: session.stagedBallInPlayChanges,
            stagedPitchCountReconciliationChanges: session.stagedPitchCountReconciliationChanges,
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
            offensiveBaseRunningChanges: session.stagedOffensiveBaseRunningChanges,
            offensivePlateAppearanceChanges: session.stagedOffensivePlateAppearanceChanges,
            ballInPlayChanges: session.stagedBallInPlayChanges,
            pitchCountReconciliationChanges: session.stagedPitchCountReconciliationChanges,
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
            offensiveBaseRunningChanges: session.stagedOffensiveBaseRunningChanges,
            offensivePlateAppearanceChanges: session.stagedOffensivePlateAppearanceChanges,
            ballInPlayChanges: session.stagedBallInPlayChanges,
            pitchCountReconciliationChanges: session.stagedPitchCountReconciliationChanges,
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
            stagedOffensiveBaseRunningChanges: session.stagedOffensiveBaseRunningChanges,
            stagedOffensivePlateAppearanceChanges: session.stagedOffensivePlateAppearanceChanges,
            stagedBallInPlayChanges: session.stagedBallInPlayChanges,
            stagedPitchCountReconciliationChanges: session.stagedPitchCountReconciliationChanges,
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
            offensiveBaseRunningChanges: session.stagedOffensiveBaseRunningChanges,
            offensivePlateAppearanceChanges: session.stagedOffensivePlateAppearanceChanges,
            ballInPlayChanges: session.stagedBallInPlayChanges,
            pitchCountReconciliationChanges: session.stagedPitchCountReconciliationChanges,
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
            offensiveBaseRunningChanges: session.stagedOffensiveBaseRunningChanges,
            offensivePlateAppearanceChanges: session.stagedOffensivePlateAppearanceChanges,
            ballInPlayChanges: session.stagedBallInPlayChanges,
            pitchCountReconciliationChanges: session.stagedPitchCountReconciliationChanges,
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
            stagedOffensiveBaseRunningChanges: session.stagedOffensiveBaseRunningChanges,
            stagedOffensivePlateAppearanceChanges: session.stagedOffensivePlateAppearanceChanges,
            stagedBallInPlayChanges: session.stagedBallInPlayChanges,
            stagedPitchCountReconciliationChanges: session.stagedPitchCountReconciliationChanges,
            stagedLogicalPlayDeletions: session.stagedLogicalPlayDeletions,
            snapshot: snapshot,
            firstInvalidRecord: firstCorrectionProblem(
                in: snapshot.replay,
                originalReplay: originalSnapshot.replay
            ),
            expectedTimeline: session.expectedTimeline
        )
    }

    private static func stagingPitchCountReconciliationChange(
        storedRecord: GameEventRecord,
        storedReconciliation: PitchCountReconciliationEvent,
        proposedReconciliation: PitchCountReconciliationEvent?,
        records: [GameEventRecord],
        originalSnapshot: LiveGameSnapshot,
        in session: GameEventCorrectionSession,
        game: Game,
        projectBattingLines: LiveGameSnapshotLoader.ProjectBattingLines
    ) throws -> GameEventCorrectionSession {
        var reconciliationChanges = session.stagedPitchCountReconciliationChanges.filter {
            $0.recordID != storedRecord.id
        }
        if proposedReconciliation != storedReconciliation {
            reconciliationChanges.append(PitchCountReconciliationStagedChange(
                recordID: storedRecord.id,
                sequenceNumber: storedRecord.sequenceNumber,
                originalReconciliation: storedReconciliation,
                proposedReconciliation: proposedReconciliation
            ))
            reconciliationChanges.sort { $0.sequenceNumber < $1.sequenceNumber }
        }
        let candidateRecords = try applying(
            session.stagedChanges,
            offensivePitchChanges: session.stagedOffensivePitchChanges,
            offensiveBaseRunningChanges: session.stagedOffensiveBaseRunningChanges,
            offensivePlateAppearanceChanges: session.stagedOffensivePlateAppearanceChanges,
            ballInPlayChanges: session.stagedBallInPlayChanges,
            pitchCountReconciliationChanges: reconciliationChanges,
            logicalPlayDeletions: session.stagedLogicalPlayDeletions,
            to: records
        )
        let snapshot = try LiveGameSnapshotLoader.makeSnapshot(
            game: game,
            records: candidateRecords,
            projectBattingLines: projectBattingLines,
            validateEvent: terminalCountValidator(
                originalReplay: originalSnapshot.replay,
                ignoredRecordIDs: Set(
                    session.stagedOffensivePlateAppearanceChanges.map(\.recordID)
                )
            )
        )
        return GameEventCorrectionSession(
            gameID: game.id,
            stagedChanges: session.stagedChanges,
            stagedOffensivePitchChanges: session.stagedOffensivePitchChanges,
            stagedOffensiveBaseRunningChanges: session.stagedOffensiveBaseRunningChanges,
            stagedOffensivePlateAppearanceChanges: session.stagedOffensivePlateAppearanceChanges,
            stagedBallInPlayChanges: session.stagedBallInPlayChanges,
            stagedPitchCountReconciliationChanges: reconciliationChanges,
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
        offensiveBaseRunningChanges: [OffensiveBaseRunningStagedChange],
        offensivePlateAppearanceChanges: [OffensivePlateAppearanceStagedChange],
        ballInPlayChanges: [DefensiveBallInPlayStagedChange],
        pitchCountReconciliationChanges: [PitchCountReconciliationStagedChange],
        logicalPlayDeletions: [CompletedPlayStagedDeletion] = [],
        problemRecordDeletions: [ProblemRecordStagedDeletion] = [],
        to records: [GameEventRecord]
    ) throws -> [GameEventRecord] {
        let changesByRecordID = Dictionary(uniqueKeysWithValues: changes.map { ($0.recordID, $0) })
        let offensivePitchChangesByRecordID = Dictionary(
            uniqueKeysWithValues: offensivePitchChanges.map { ($0.recordID, $0) }
        )
        let offensiveBaseRunningChangesByRecordID = Dictionary(
            uniqueKeysWithValues: offensiveBaseRunningChanges.map { ($0.recordID, $0) }
        )
        let offensivePlateAppearanceChangesByRecordID = Dictionary(
            uniqueKeysWithValues: offensivePlateAppearanceChanges.map { ($0.recordID, $0) }
        )
        let ballInPlayChangesByRecordID = Dictionary(
            uniqueKeysWithValues: ballInPlayChanges.map { ($0.recordID, $0) }
        )
        let pitchCountReconciliationChangesByRecordID = Dictionary(
            uniqueKeysWithValues: pitchCountReconciliationChanges.map { ($0.recordID, $0) }
        )
        let deletedLogicalPlayRecordIDs = Set(logicalPlayDeletions.flatMap {
            $0.recordIDs
        })
        let deletedProblemRecordIDs = Set(problemRecordDeletions.map(\.recordID))
        return try records.compactMap { record in
            guard !deletedLogicalPlayRecordIDs.contains(record.id),
                  !deletedProblemRecordIDs.contains(record.id) else { return nil }
            if let change = offensiveBaseRunningChangesByRecordID[record.id] {
                switch change.action {
                case .edit(let event):
                    return try GameEventRecord(
                        id: record.id,
                        gameID: record.gameID,
                        sequenceNumber: record.sequenceNumber,
                        timestamp: record.timestamp,
                        body: .offensiveBaseRunning(event)
                    )
                case .delete:
                    return nil
                }
            }
            if let change = ballInPlayChangesByRecordID[record.id] {
                return try GameEventRecord(
                    id: record.id,
                    gameID: record.gameID,
                    sequenceNumber: record.sequenceNumber,
                    timestamp: record.timestamp,
                    body: .ballInPlay(change.proposedPlay)
                )
            }
            if let change = offensivePlateAppearanceChangesByRecordID[record.id] {
                return try GameEventRecord(
                    id: record.id,
                    gameID: record.gameID,
                    sequenceNumber: record.sequenceNumber,
                    timestamp: record.timestamp,
                    body: .offensivePlateAppearance(change.proposedPlateAppearance)
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
            if let change = pitchCountReconciliationChangesByRecordID[record.id] {
                guard let proposedReconciliation = change.proposedReconciliation else {
                    return nil
                }
                return try GameEventRecord(
                    id: record.id,
                    gameID: record.gameID,
                    sequenceNumber: record.sequenceNumber,
                    timestamp: record.timestamp,
                    body: .pitchCountReconciliation(proposedReconciliation)
                )
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
        let canEditOffensiveBaseRunning: Bool
        let canEditOffensivePlateAppearance: Bool
        var canRepairPitchCountReconciliation = false
        var canDeletePitchCountReconciliation = false
        var relatedDefensivePlays: [RelatedDefensivePlayRepairOption] = []
        let canDeleteOffensiveBaseRunning = originalReplay.entries.contains(where: {
            guard $0.recordID == entry.recordID else { return false }
            if case .offensiveBaseRunning = $0.body { return true }
            return false
        })
        let logicalPlayDeletion = completedPlayRepairDeletion(
            containing: entry.recordID,
            in: originalReplay
        )
        let offensiveBaseRunningRunners: [OffensiveBaseRunningRunner]
        let offensiveRunnerIdentities: [TrackedBatterIdentity]
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
            canEditOffensiveBaseRunning = false
            canEditOffensivePlateAppearance = false
            offensiveBaseRunningRunners = []
            offensiveRunnerIdentities = []
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
            canEditOffensiveBaseRunning = false
            canEditOffensivePlateAppearance = false
            offensiveBaseRunningRunners = []
            offensiveRunnerIdentities = []
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
            canEditOffensiveBaseRunning = false
            canEditOffensivePlateAppearance = false
            offensiveBaseRunningRunners = []
            offensiveRunnerIdentities = []
        case .offensiveBaseRunning(let event):
            context = "\(entry.stateBefore.half.displayName) \(entry.stateBefore.inning) · "
                + "\(event.result.shortLabel) · \(event.source.baseLabel) to "
                + event.destination.label
            explanation = "Full replay rejected this tracked-team base-running entry at its "
                + "original chronological position. Choose a runner who occupied a base at "
                + "that event-time state and a legal SB or CS result."
            canEditPitch = false
            canEditOffensivePitch = false
            canDeleteOffensivePitch = false
            canDeletePitch = false
            canEditBallInPlay = false
            canEditOffensivePlateAppearance = false
            let resolvedRunners = replay.entries.firstIndex(where: {
                $0.recordID == entry.recordID
            }).flatMap { Self.offensiveBaseRunningRunners(at: $0, in: replay) }
            let originalWasBaseRunning = if let originalEntry = originalReplay.entries.first(where: {
                $0.recordID == entry.recordID && $0.rejection == nil
            }), case .offensiveBaseRunning = originalEntry.body {
                true
            } else {
                false
            }
            canEditOffensiveBaseRunning = resolvedRunners?.isEmpty == false
                && originalWasBaseRunning
            offensiveBaseRunningRunners = canEditOffensiveBaseRunning ? resolvedRunners ?? [] : []
            offensiveRunnerIdentities = []
        case .offensivePlateAppearance(let plateAppearance):
            context = "\(entry.stateBefore.half.displayName) \(entry.stateBefore.inning) · "
                + "\(plateAppearance.batter.displayName) · Batting slot "
                + "\(plateAppearance.batter.lineupSlot) of "
                + "\(plateAppearance.battingOrderSize) · \(plateAppearance.result.label)"
            explanation = if hasTerminalCountMismatch {
                "Full replay reached tracked batting slot "
                    + "\(entry.stateBefore.currentTrackedBatterSlot) with a "
                    + "\(entry.stateBefore.balls)–\(entry.stateBefore.strikes) count "
                    + "before rejecting this \(plateAppearance.result.label) for its saved count contract."
            } else {
                "Full replay rejected this completed tracked-team plate appearance at its original "
                    + "chronological position. Confirm the result and every event-time runner destination "
                    + "against the proposed game state."
            }
            canEditPitch = false
            canEditOffensivePitch = false
            canDeleteOffensivePitch = false
            canDeletePitch = false
            canEditBallInPlay = false
            canEditOffensiveBaseRunning = false
            offensiveBaseRunningRunners = []
            var resolvedRunnerIdentities = [plateAppearance.batter]
            var resolvedEveryRunner = true
            if let entryIndex = replay.entries.firstIndex(where: { $0.recordID == entry.recordID }) {
                for source in entry.stateBefore.occupiedTrackedRunnerSources where source != .batter {
                    guard let playerID = runnerPlayerID(in: entry.stateBefore, at: source),
                          let runner = trackedRunnerContext(
                            playerID: playerID,
                            source: source,
                            entries: replay.entries[..<entryIndex]
                          ) else {
                        resolvedEveryRunner = false
                        break
                    }
                    resolvedRunnerIdentities.append(runner.identity)
                }
            } else {
                resolvedEveryRunner = false
            }
            if let originalEntry = originalReplay.entries.first(where: {
                $0.recordID == entry.recordID
            }),
               case .offensivePlateAppearance(let originalPlateAppearance) = originalEntry.body {
                canEditOffensivePlateAppearance = OffensivePlateAppearanceValidator.supportsCorrection(
                    originalPlateAppearance,
                    stateBefore: originalEntry.stateBefore
                ) && OffensivePlateAppearanceValidator.supportsCorrection(
                    plateAppearance,
                    stateBefore: entry.stateBefore
                ) && resolvedEveryRunner
            } else {
                canEditOffensivePlateAppearance = false
            }
            offensiveRunnerIdentities = resolvedEveryRunner ? resolvedRunnerIdentities : []
        case .pitchCountReconciliation(let reconciliation):
            context = "\(entry.stateBefore.half.displayName) \(entry.stateBefore.inning) · "
                + "Pitch reconciliation "
                + signedPitchAdjustment(reconciliation.adjustment.total)
            let adjustmentRemainsValid = entry.stateBefore
                .pitchCount(for: reconciliation.pitcherID)
                .reconciling(reconciliation) != nil
            canRepairPitchCountReconciliation = adjustmentRemainsValid
                && reconciliation.relatedPlay != nil
            canDeletePitchCountReconciliation = originalReplay.entries.contains(where: {
                guard $0.recordID == entry.recordID, $0.rejection == nil else { return false }
                if case .pitchCountReconciliation = $0.body { return true }
                return false
            })
            explanation = if canRepairPitchCountReconciliation {
                "The saved related-play reference no longer matches a completed defensive "
                    + "play in this timeline. Re-associate it with an eligible play or "
                    + "explicitly remove the association."
            } else {
                "The reconciliation adjustment is no longer valid for the pitcher totals "
                    + "at this chronological position."
            }
            canEditPitch = false
            canEditOffensivePitch = false
            canDeleteOffensivePitch = false
            canDeletePitch = false
            canEditBallInPlay = false
            canEditOffensiveBaseRunning = false
            canEditOffensivePlateAppearance = false
            if canRepairPitchCountReconciliation {
                relatedDefensivePlays = completedDefensivePlayRepairOptions(
                    in: replay,
                    beforeSequenceNumber: entry.sequenceNumber
                )
            }
            offensiveBaseRunningRunners = []
            offensiveRunnerIdentities = []
        default:
            context = "\(entry.stateBefore.half.displayName) \(entry.stateBefore.inning) · Saved event"
            explanation = "Full replay rejected this record at its original chronological position."
            canEditPitch = false
            canEditOffensivePitch = false
            canDeleteOffensivePitch = false
            canDeletePitch = false
            canEditBallInPlay = false
            canEditOffensiveBaseRunning = false
            canEditOffensivePlateAppearance = false
            offensiveBaseRunningRunners = []
            offensiveRunnerIdentities = []
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
            canEditBallInPlay: canEditBallInPlay,
            canEditOffensiveBaseRunning: canEditOffensiveBaseRunning,
            canEditOffensivePlateAppearance: canEditOffensivePlateAppearance,
            canDeleteOffensiveBaseRunning: canDeleteOffensiveBaseRunning,
            canRepairPitchCountReconciliation: canRepairPitchCountReconciliation,
            canDeletePitchCountReconciliation: canDeletePitchCountReconciliation,
            relatedDefensivePlays: relatedDefensivePlays,
            logicalPlayDeletion: logicalPlayDeletion,
            offensiveBaseRunningRunners: offensiveBaseRunningRunners,
            offensiveRunnerIdentities: offensiveRunnerIdentities
        )
    }

    private static func terminalCountValidator(
        originalReplay: GameEventReplay.Result,
        ignoredRecordIDs: Set<UUID> = []
    ) -> GameEventReplay.ValidateEvent {
        { record, event, state in
            guard !ignoredRecordIDs.contains(record.id),
                  case .offensivePlateAppearance(let plateAppearance) = event.body,
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

    private static func isCorrectableOffensivePlateAppearance(
        _ plateAppearance: OffensivePlateAppearanceEvent,
        stateBefore: GameState,
        trackedTeamHomeAway: HomeAway
    ) -> Bool {
        return OffensivePlateAppearanceValidator.supportsCorrection(
            plateAppearance,
            stateBefore: stateBefore
        )
            && OffensivePlateAppearanceValidator.isValid(
                plateAppearance,
                state: stateBefore,
                trackedTeamHomeAway: trackedTeamHomeAway
            )
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

    private static func completedDefensivePlayRepairOptions(
        in replay: GameEventReplay.Result,
        beforeSequenceNumber: Int
    ) -> [RelatedDefensivePlayRepairOption] {
        replay.entries.compactMap { entry in
            guard entry.sequenceNumber < beforeSequenceNumber,
                  entry.rejection == nil,
                  let body = entry.body,
                  GameEventReplay.isCompletedDefensivePlay(
                      body,
                      stateBefore: entry.stateBefore
                  ) else {
                return nil
            }
            guard let (opponentBatterSlot, result) = completedDefensivePlayLabel(body) else {
                return nil
            }
            return RelatedDefensivePlayRepairOption(
                recordID: entry.recordID,
                sequenceNumber: entry.sequenceNumber,
                summary: "\(entry.stateBefore.half.displayName) \(entry.stateBefore.inning) · "
                    + "Opponent batter \(opponentBatterSlot) · Sequence "
                    + "\(entry.sequenceNumber) · \(result)"
            )
        }
    }

    private static func completedDefensivePlays(
        records: [GameEventRecord],
        replay: GameEventReplay.Result
    ) -> [CompletedDefensivePlayOption] {
        let recordsByID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        return replay.entries.compactMap { entry in
            guard entry.rejection == nil,
                  let body = entry.body,
                  GameEventReplay.isCompletedDefensivePlay(
                    body,
                    stateBefore: entry.stateBefore
                  ),
                  let record = recordsByID[entry.recordID] else {
                return nil
            }
            guard let (opponentBatterSlot, result) = completedDefensivePlayLabel(body) else {
                return nil
            }
            return CompletedDefensivePlayOption(
                recordID: entry.recordID,
                sequenceNumber: entry.sequenceNumber,
                inning: entry.stateBefore.inning,
                half: entry.stateBefore.half,
                opponentBatterSlot: opponentBatterSlot,
                summary: "\(entry.stateBefore.half.displayName) \(entry.stateBefore.inning) · "
                    + "Opponent batter \(opponentBatterSlot) · Sequence "
                    + "\(entry.sequenceNumber) · \(result)",
                reference: record.relatedDefensivePlayReference
            )
        }
    }

    private static func completedDefensivePlayLabel(
        _ body: GameEventBody
    ) -> (opponentBatterSlot: Int, result: String)? {
        switch body {
        case .pitch(let pitch):
            let result = switch pitch.result {
            case .ball: "Walk"
            case .calledStrike, .swingingStrike: "Strikeout"
            case .hitByPitch: "HBP"
            case .foul, .ballInPlay: pitch.result.label
            }
            return (pitch.opponentBatterSlot, result)
        case .ballInPlay(let play):
            return (play.opponentBatterSlot, play.outcome.label)
        case .pitchCountReconciliation, .offensivePitch,
             .offensiveBaseRunning, .offensivePlateAppearance:
            return nil
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

    private static func isDeletionOnlyRejection(
        _ rejection: GameEventReplay.Rejection?
    ) -> Bool {
        switch rejection {
        case .unknownKind, .malformedPayload: true
        case .invalidSequence, .semanticallyRejected, nil: false
        }
    }

    private static func completesPlateAppearance(
        _ result: PitchResult,
        stateBefore: GameState
    ) -> Bool {
        result.completesPlateAppearance(
            balls: stateBefore.balls,
            strikes: stateBefore.strikes
        )
    }

    private static func offensiveLogicalPlayEntries(
        endingAt resultIndex: Int,
        in replay: GameEventReplay.Result
    ) -> [GameEventReplay.Entry]? {
        guard replay.entries.indices.contains(resultIndex),
              case .offensivePlateAppearance(let plateAppearance) =
                replay.entries[resultIndex].body else {
            return nil
        }

        let resultEntry = replay.entries[resultIndex]
        var components = [resultEntry]
        var index = resultIndex
        scanEarlierEvents: while index > replay.entries.startIndex {
            index = replay.entries.index(before: index)
            let entry = replay.entries[index]
            guard entry.stateBefore.inning == resultEntry.stateBefore.inning,
                  entry.stateBefore.half == resultEntry.stateBefore.half else {
                break
            }
            switch entry.body {
            case .offensivePitch(let pitch)
                where pitch.batter == plateAppearance.batter
                    && pitch.battingOrderSize == plateAppearance.battingOrderSize:
                components.insert(entry, at: 0)
            case .offensiveBaseRunning:
                continue
            case .offensivePlateAppearance, .offensivePitch, .pitch,
                 .pitchCountReconciliation, .ballInPlay, nil:
                break scanEarlierEvents
            }
        }
        return components
    }

    private static func completedPlayRepairDeletion(
        containing recordID: UUID,
        in replay: GameEventReplay.Result
    ) -> CompletedPlayRepairDeletion? {
        for index in replay.entries.indices {
            guard case .offensivePlateAppearance(let plateAppearance) = replay.entries[index].body
            else { continue }
            guard let components = offensiveLogicalPlayEntries(endingAt: index, in: replay),
                  components.contains(where: { $0.recordID == recordID }) else {
                continue
            }
            let deletionComponents = components.compactMap { entry -> CompletedPlayDeletionComponent? in
                let summary: String
                switch entry.body {
                case .offensivePitch(let pitch): summary = "\(pitch.result.label) pitch"
                case .offensivePlateAppearance(let result):
                    summary = "\(result.result.label) result"
                default: return nil
                }
                return CompletedPlayDeletionComponent(
                    recordID: entry.recordID,
                    sequenceNumber: entry.sequenceNumber,
                    summary: summary
                )
            }
            guard deletionComponents.count == components.count,
                  let firstEntry = components.first else { return nil }
            return CompletedPlayRepairDeletion(
                kind: .offensive,
                resultRecordID: replay.entries[index].recordID,
                context: "\(firstEntry.stateBefore.half.displayName) "
                    + "\(firstEntry.stateBefore.inning), \(plateAppearance.batter.displayName), "
                    + "batting slot \(plateAppearance.batter.lineupSlot) of "
                    + "\(plateAppearance.battingOrderSize)",
                components: deletionComponents
            )
        }

        for index in replay.entries.indices where index > replay.entries.startIndex {
            guard case .ballInPlay(let play) = replay.entries[index].body,
                  case .pitch(let pitch) = replay.entries[index - 1].body,
                  pitch.result == .ballInPlay,
                  pitch.opponentBatterSlot == play.opponentBatterSlot,
                  [replay.entries[index - 1].recordID, replay.entries[index].recordID]
                    .contains(recordID) else {
                continue
            }
            let pitchEntry = replay.entries[index - 1]
            let resultEntry = replay.entries[index]
            return CompletedPlayRepairDeletion(
                kind: .defensive,
                resultRecordID: resultEntry.recordID,
                context: "\(pitchEntry.stateBefore.half.displayName) "
                    + "\(pitchEntry.stateBefore.inning), opponent batting slot "
                    + "\(play.opponentBatterSlot)",
                components: [
                    CompletedPlayDeletionComponent(
                        recordID: pitchEntry.recordID,
                        sequenceNumber: pitchEntry.sequenceNumber,
                        summary: "Ball In Play pitch"
                    ),
                    CompletedPlayDeletionComponent(
                        recordID: resultEntry.recordID,
                        sequenceNumber: resultEntry.sequenceNumber,
                        summary: "\(play.outcome.label) result"
                    )
                ]
            )
        }
        return nil
    }

    private static func offensiveBaseRunningRunners(
        at entryIndex: Int,
        in replay: GameEventReplay.Result
    ) -> [OffensiveBaseRunningRunner]? {
        let state = replay.entries[entryIndex].stateBefore
        var runners: [OffensiveBaseRunningRunner] = []
        for source in state.occupiedTrackedRunnerSources where source != .batter {
            guard let playerID = runnerPlayerID(in: state, at: source),
                  let runner = trackedRunnerContext(
                    playerID: playerID,
                    source: source,
                    entries: replay.entries[..<entryIndex]
                  ) else {
                return nil
            }
            runners.append(OffensiveBaseRunningRunner(
                identity: runner.identity,
                battingOrderSize: runner.battingOrderSize,
                source: source
            ))
        }
        return runners
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
