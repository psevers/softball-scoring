import Foundation
import Observation
import SwiftData

struct LiveGameSnapshot {
    let records: [GameEventRecord]
    let replay: GameEventReplay.Result
    let battingLines: [UUID: BattingLine]
    let history: PlayHistory
}

enum LiveGameSnapshotError: LocalizedError {
    case invalidGameSide
    case gameMismatch

    var errorDescription: String? {
        switch self {
        case .invalidGameSide:
            "The saved home/away value is unreadable."
        case .gameMismatch:
            "The live-game session does not match this game."
        }
    }
}

@MainActor
enum LiveGameSnapshotLoader {
    typealias ProjectBattingLines = ([DecodedGameEvent]) throws -> [UUID: BattingLine]

    static func load(game: Game, modelContext: ModelContext) throws -> LiveGameSnapshot {
        let gameID = game.id
        let descriptor = FetchDescriptor<GameEventRecord>(
            predicate: #Predicate { $0.gameID == gameID },
            sortBy: [
                SortDescriptor(\GameEventRecord.sequenceNumber),
                SortDescriptor(\GameEventRecord.timestamp)
            ]
        )
        let records = try modelContext.fetch(descriptor)
        return try makeSnapshot(game: game, records: records)
    }

    static func makeSnapshot(
        game: Game,
        records: [GameEventRecord],
        projectBattingLines: ProjectBattingLines = BattingStatProjector.project,
        validateEvent: GameEventReplay.ValidateEvent = { _, _, _ in true }
    ) throws -> LiveGameSnapshot {
        guard records.allSatisfy({ $0.gameID == game.id }) else {
            throw LiveGameSnapshotError.gameMismatch
        }
        guard let homeAway = HomeAway(rawValue: game.homeAwayRawValue) else {
            throw LiveGameSnapshotError.invalidGameSide
        }
        let replay = GameEventReplay.replay(
            records: records,
            homeAway: homeAway,
            startingPitcherID: game.startingPitcherID,
            validateEvent: validateEvent
        )
        return LiveGameSnapshot(
            records: records,
            replay: replay,
            battingLines: try projectBattingLines(replay.acceptedEvents),
            history: PlayHistoryProjector.project(replay: replay)
        )
    }
}

@MainActor
@Observable
final class LiveGameSession {
    let gameID: UUID
    private(set) var snapshot: LiveGameSnapshot?
    private(set) var loadError: String?
    private(set) var undoCandidate: UndoLatestActionCandidate?

    init(gameID: UUID) {
        self.gameID = gameID
    }

    func refresh(game: Game, modelContext: ModelContext) {
        guard game.id == gameID else {
            snapshot = nil
            undoCandidate = nil
            loadError = LiveGameSnapshotError.gameMismatch.localizedDescription
            return
        }
        do {
            snapshot = try LiveGameSnapshotLoader.load(game: game, modelContext: modelContext)
            undoCandidate = try availableUndoCandidate(game: game, modelContext: modelContext)
            loadError = nil
        } catch {
            undoCandidate = nil
            loadError = error.localizedDescription
        }
    }

    func performRecording(
        game: Game,
        modelContext: ModelContext,
        action: () throws -> Void
    ) throws {
        guard game.id == gameID else { throw LiveGameSnapshotError.gameMismatch }
        try action()
        refresh(game: game, modelContext: modelContext)
    }

    func undoLatestAction(
        _ candidate: UndoLatestActionCandidate,
        game: Game,
        modelContext: ModelContext
    ) throws {
        guard game.id == gameID else { throw LiveGameSnapshotError.gameMismatch }
        snapshot = try GameEventCorrection.undoLatestAction(
            candidate,
            game: game,
            modelContext: modelContext
        )
        undoCandidate = try availableUndoCandidate(game: game, modelContext: modelContext)
        loadError = nil
    }

    func saveGameEventCorrection(
        _ correctionSession: GameEventCorrectionSession,
        game: Game,
        modelContext: ModelContext
    ) throws {
        guard game.id == gameID else { throw LiveGameSnapshotError.gameMismatch }
        snapshot = try GameEventCorrection.saveGameEventCorrection(
            correctionSession,
            game: game,
            modelContext: modelContext
        )
        undoCandidate = try availableUndoCandidate(game: game, modelContext: modelContext)
        loadError = nil
    }

    private func availableUndoCandidate(
        game: Game,
        modelContext: ModelContext
    ) throws -> UndoLatestActionCandidate? {
        do {
            return try GameEventCorrection.prepareUndoLatestAction(
                game: game,
                modelContext: modelContext
            )
        } catch GameEventCorrectionError.noUndoAvailable {
            return nil
        } catch GameEventCorrectionError.invalidTimeline {
            return nil
        }
    }
}
