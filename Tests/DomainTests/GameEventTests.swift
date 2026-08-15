import Foundation
import Testing
@testable import SoftballScoring

struct GameEventTests {
    @Test func pitchCountReconciliationRoundTripsSignedAdjustments() throws {
        let relatedPlay = RelatedDefensivePlayReference(
            recordID: UUID(),
            gameID: UUID(),
            sequenceNumber: 12,
            kindRawValue: GameEventKind.ballInPlay.rawValue,
            revisionDigest: Data([1, 2, 3, 4])
        )
        let reconciliation = PitchCountReconciliationEvent(
            pitcherID: UUID(),
            adjustment: .init(total: -2, balls: -1, strikes: -1),
            relatedPlay: relatedPlay
        )

        let encoded = try GameEventCodec.encode(.pitchCountReconciliation(reconciliation))
        let decoded = try GameEventCodec.decode(
            kindRawValue: encoded.kind.rawValue,
            payload: encoded.payload
        )

        #expect(encoded.kind == .pitchCountReconciliation)
        #expect(decoded == .pitchCountReconciliation(reconciliation))
    }

    @Test func legacyPitchCountReconciliationDecodesWithoutRelatedPlay() throws {
        struct LegacyReconciliation: Encodable {
            let pitcherID: UUID
            let adjustment: PitchCountAdjustment
        }
        let pitcherID = UUID()
        let adjustment = PitchCountAdjustment(total: 2, balls: 1, strikes: 0)
        let payload = try JSONEncoder().encode(LegacyReconciliation(
            pitcherID: pitcherID,
            adjustment: adjustment
        ))

        let decoded = try GameEventCodec.decode(
            kindRawValue: GameEventKind.pitchCountReconciliation.rawValue,
            payload: payload
        )

        #expect(decoded == .pitchCountReconciliation(.init(
            pitcherID: pitcherID,
            adjustment: adjustment,
            relatedPlay: nil
        )))
    }

    @Test func offensivePlateAppearanceRoundTripsPlayerIdentity() throws {
        let batter = TrackedBatterIdentity(
            playerID: UUID(),
            lineupSlot: 13,
            displayName: "M. Wilson",
            jerseyNumber: "8",
            position: .leftField
        )
        let event = OffensivePlateAppearanceEvent(
            batter: batter,
            battingOrderSize: 13,
            result: .walk,
            movements: [RunnerMovementEvent(source: .batter, destination: .first)],
            rbi: 0,
            countedRunSources: [],
            thirdOutClassification: nil
        )

        let encoded = try GameEventCodec.encode(.offensivePlateAppearance(event))
        let decoded = try GameEventCodec.decode(kindRawValue: encoded.kind.rawValue, payload: encoded.payload)

        #expect(encoded.kind == .offensivePlateAppearance)
        #expect(decoded == .offensivePlateAppearance(event))
    }

    @Test func pitchEventCodecRoundTrips() throws {
        let pitch = PitchEvent(result: .swingingStrike, pitcherID: UUID(), opponentBatterSlot: 6)
        let body = GameEventBody.pitch(pitch)

        let encoded = try GameEventCodec.encode(body)
        let decoded = try GameEventCodec.decode(kindRawValue: encoded.kind.rawValue, payload: encoded.payload)

        #expect(decoded == body)
    }

    @Test func offensivePitchEventCodecRoundTripsBatterAndLineupContext() throws {
        let body = GameEventBody.offensivePitch(OffensivePitchEvent(
            batter: TrackedBatterIdentity(
                playerID: UUID(),
                lineupSlot: 7,
                displayName: "M. Wilson",
                jerseyNumber: "8",
                position: .leftField
            ),
            battingOrderSize: 13,
            result: .swingingStrike
        ))

        let encoded = try GameEventCodec.encode(body)
        let decoded = try GameEventCodec.decode(kindRawValue: encoded.kind.rawValue, payload: encoded.payload)

        #expect(encoded.kind == .offensivePitch)
        #expect(decoded == body)
    }

    @Test func ballInPlayEventCodecRoundTrips() throws {
        let play = BallInPlayEvent(
            outcome: .double,
            opponentBatterSlot: 4,
            movements: [
                .init(source: .batter, destination: .second),
                .init(source: .first, destination: .home)
            ],
            rbi: 1,
            thirdOutRunsCounted: nil
        )
        let body = GameEventBody.ballInPlay(play)

        let encoded = try GameEventCodec.encode(body)
        let decoded = try GameEventCodec.decode(kindRawValue: encoded.kind.rawValue, payload: encoded.payload)

        #expect(decoded == body)
    }

    @Test func unknownEventKindIsRejected() {
        #expect(throws: GameEventCodecError.unknownKind("future-event")) {
            _ = try GameEventCodec.decode(kindRawValue: "future-event", payload: Data())
        }
    }

    @Test func invalidPitchPayloadIsRejected() {
        #expect(throws: GameEventCodecError.invalidPayload(.pitch)) {
            _ = try GameEventCodec.decode(kindRawValue: GameEventKind.pitch.rawValue, payload: Data("not json".utf8))
        }
    }
}
