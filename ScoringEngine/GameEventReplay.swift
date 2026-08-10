import Foundation

enum GameEventReplay {
    struct Result: Equatable {
        let state: GameState
        let rejectedRecordIDs: [UUID]
    }

    /// Decode and semantically validate persisted records in order. Invalid records are surfaced
    /// rather than crashing or silently changing score/state. New writes are blocked when any
    /// rejected record exists so corruption cannot compound unnoticed.
    static func replay(
        records: [GameEventRecord],
        homeAway: HomeAway,
        startingPitcherID: UUID?
    ) -> Result {
        var state = GameState()
        var rejected: [UUID] = []
        var seenSequenceNumbers = Set<Int>()

        let ordered = records.sorted { lhs, rhs in
            if lhs.sequenceNumber == rhs.sequenceNumber { return lhs.timestamp < rhs.timestamp }
            return lhs.sequenceNumber < rhs.sequenceNumber
        }

        for record in ordered {
            guard record.sequenceNumber > 0,
                  seenSequenceNumbers.insert(record.sequenceNumber).inserted else {
                rejected.append(record.id)
                continue
            }

            let decoded: DecodedGameEvent
            do {
                decoded = try record.decoded()
            } catch {
                rejected.append(record.id)
                continue
            }

            guard isSemanticallyValid(
                decoded,
                for: state,
                homeAway: homeAway,
                startingPitcherID: startingPitcherID
            ) else {
                rejected.append(record.id)
                continue
            }

            GameReducer.apply(decoded, to: &state, trackedTeamHomeAway: homeAway)
        }

        return Result(state: state, rejectedRecordIDs: rejected)
    }

    private static func isSemanticallyValid(
        _ event: DecodedGameEvent,
        for state: GameState,
        homeAway: HomeAway,
        startingPitcherID: UUID?
    ) -> Bool {
        switch event.body {
        case .pitch(let pitch):
            return startingPitcherID == pitch.pitcherID
                && state.isOpponentBatting(homeAway: homeAway)
                && !state.isAwaitingBallInPlayResult
                && pitch.opponentBatterSlot == state.currentOpponentBatterSlot

        case .ballInPlay(let play):
            return BallInPlayValidator.validate(
                play,
                state: state,
                trackedTeamHomeAway: homeAway
            ) == nil
        }
    }
}
