import Foundation

enum GameEventReplay {
    typealias ValidateEvent = (GameEventRecord, DecodedGameEvent, GameState) -> Bool

    enum Rejection: Equatable {
        case invalidSequence
        case unknownKind
        case malformedPayload
        case semanticallyRejected
    }

    struct Entry: Equatable {
        let recordID: UUID
        let sequenceNumber: Int
        let timestamp: Date
        let body: GameEventBody?
        let stateBefore: GameState
        let stateAfter: GameState
        let rejection: Rejection?
    }

    struct Result: Equatable {
        let state: GameState
        let rejectedRecordIDs: [UUID]
        let entries: [Entry]

        var acceptedEvents: [DecodedGameEvent] {
            entries.compactMap { entry in
                guard entry.rejection == nil, let body = entry.body else { return nil }
                return DecodedGameEvent(
                    sequenceNumber: entry.sequenceNumber,
                    timestamp: entry.timestamp,
                    body: body
                )
            }
        }

        init(
            state: GameState,
            rejectedRecordIDs: [UUID],
            entries: [Entry] = []
        ) {
            self.state = state
            self.rejectedRecordIDs = rejectedRecordIDs
            self.entries = entries
        }
    }

    /// Decode and semantically validate persisted records in order. Invalid records are surfaced
    /// rather than crashing or silently changing score/state. New writes are blocked when any
    /// rejected record exists so corruption cannot compound unnoticed.
    static func replay(
        records: [GameEventRecord],
        homeAway: HomeAway,
        startingPitcherID: UUID?,
        validateEvent: ValidateEvent = { _, _, _ in true }
    ) -> Result {
        var state = GameState()
        var rejected: [UUID] = []
        var entries: [Entry] = []
        var seenSequenceNumbers = Set<Int>()

        let ordered = records.sorted { lhs, rhs in
            if lhs.sequenceNumber == rhs.sequenceNumber { return lhs.timestamp < rhs.timestamp }
            return lhs.sequenceNumber < rhs.sequenceNumber
        }

        for record in ordered {
            let stateBefore = state
            guard record.sequenceNumber > 0,
                  seenSequenceNumbers.insert(record.sequenceNumber).inserted else {
                rejected.append(record.id)
                entries.append(Entry(
                    recordID: record.id,
                    sequenceNumber: record.sequenceNumber,
                    timestamp: record.timestamp,
                    body: nil,
                    stateBefore: stateBefore,
                    stateAfter: state,
                    rejection: .invalidSequence
                ))
                continue
            }

            let decoded: DecodedGameEvent
            do {
                decoded = try record.decoded()
            } catch GameEventCodecError.unknownKind {
                rejected.append(record.id)
                entries.append(Entry(
                    recordID: record.id,
                    sequenceNumber: record.sequenceNumber,
                    timestamp: record.timestamp,
                    body: nil,
                    stateBefore: stateBefore,
                    stateAfter: state,
                    rejection: .unknownKind
                ))
                continue
            } catch {
                rejected.append(record.id)
                entries.append(Entry(
                    recordID: record.id,
                    sequenceNumber: record.sequenceNumber,
                    timestamp: record.timestamp,
                    body: nil,
                    stateBefore: stateBefore,
                    stateAfter: state,
                    rejection: .malformedPayload
                ))
                continue
            }

            guard isSemanticallyValid(
                decoded,
                for: state,
                homeAway: homeAway,
                startingPitcherID: startingPitcherID
            ), validateEvent(record, decoded, state) else {
                rejected.append(record.id)
                entries.append(Entry(
                    recordID: record.id,
                    sequenceNumber: record.sequenceNumber,
                    timestamp: record.timestamp,
                    body: decoded.body,
                    stateBefore: stateBefore,
                    stateAfter: state,
                    rejection: .semanticallyRejected
                ))
                continue
            }

            GameReducer.apply(
                decoded,
                to: &state,
                trackedTeamHomeAway: homeAway
            )
            entries.append(Entry(
                recordID: record.id,
                sequenceNumber: record.sequenceNumber,
                timestamp: record.timestamp,
                body: decoded.body,
                stateBefore: stateBefore,
                stateAfter: state,
                rejection: nil
            ))
        }

        return Result(state: state, rejectedRecordIDs: rejected, entries: entries)
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

        case .offensivePitch(let pitch):
            return OffensivePitchValidator.isValid(
                pitch,
                state: state,
                trackedTeamHomeAway: homeAway
            )

        case .offensiveBaseRunning(let event):
            return OffensiveBaseRunningValidator.isValid(
                event,
                state: state,
                trackedTeamHomeAway: homeAway
            )

        case .offensivePlateAppearance(let plateAppearance):
            return OffensivePlateAppearanceValidator.isValid(
                plateAppearance,
                state: state,
                trackedTeamHomeAway: homeAway
            )
        }
    }
}
