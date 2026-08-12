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

    var errorDescription: String? {
        switch self {
        case .invalidGameSide:
            "The saved home/away value is unreadable."
        }
    }
}

@MainActor
enum LiveGameSnapshotLoader {
    static func load(game: Game, modelContext: ModelContext) throws -> LiveGameSnapshot {
        guard let homeAway = HomeAway(rawValue: game.homeAwayRawValue) else {
            throw LiveGameSnapshotError.invalidGameSide
        }
        let gameID = game.id
        let descriptor = FetchDescriptor<GameEventRecord>(
            predicate: #Predicate { $0.gameID == gameID },
            sortBy: [
                SortDescriptor(\GameEventRecord.sequenceNumber),
                SortDescriptor(\GameEventRecord.timestamp)
            ]
        )
        let records = try modelContext.fetch(descriptor)
        let replay = GameEventReplay.replay(
            records: records,
            homeAway: homeAway,
            startingPitcherID: game.startingPitcherID
        )
        return LiveGameSnapshot(
            records: records,
            replay: replay,
            battingLines: BattingStatProjector.project(events: replay.acceptedEvents),
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

    init(gameID: UUID) {
        self.gameID = gameID
    }

    func refresh(game: Game, modelContext: ModelContext) {
        guard game.id == gameID else { return }
        do {
            snapshot = try LiveGameSnapshotLoader.load(game: game, modelContext: modelContext)
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }
}
