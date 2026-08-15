import CryptoKit
import Foundation
import SwiftData

enum GameEventKind: String, Codable, Sendable {
    case pitch
    case pitchCountReconciliation
    case ballInPlay
    case offensivePitch
    case offensiveBaseRunning
    case offensivePlateAppearance
}

enum PitchResult: String, CaseIterable, Codable, Identifiable, Sendable {
    case ball
    case calledStrike
    case swingingStrike
    case foul
    case ballInPlay
    case hitByPitch

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ball: "Ball"
        case .calledStrike: "Called Strike"
        case .swingingStrike: "Swinging Strike"
        case .foul: "Foul"
        case .ballInPlay: "Ball In Play"
        case .hitByPitch: "HBP"
        }
    }

    var shortLabel: String {
        switch self {
        case .ball: "Ball"
        case .calledStrike: "Strike"
        case .swingingStrike: "Swing"
        case .foul: "Foul"
        case .ballInPlay: "In Play"
        case .hitByPitch: "HBP"
        }
    }

    /// Pitch-stat classification. HBP is a pitch but is neither a ball nor a strike
    /// in the displayed ball/strike pitch breakdown.
    var pitchStatClassification: PitchStatClassification {
        switch self {
        case .ball: .ball
        case .calledStrike, .swingingStrike, .foul, .ballInPlay: .strike
        case .hitByPitch: .neither
        }
    }

    func completesPlateAppearance(balls: Int, strikes: Int) -> Bool {
        switch self {
        case .ball: balls == 3
        case .calledStrike, .swingingStrike: strikes == 2
        case .hitByPitch: true
        case .foul, .ballInPlay: false
        }
    }
}

enum PitchStatClassification: Sendable {
    case ball
    case strike
    case neither
}

struct PitchEvent: Codable, Equatable, Sendable {
    let result: PitchResult
    let pitcherID: UUID
    let opponentBatterSlot: Int
}

struct PitchCountAdjustment: Codable, Equatable, Sendable {
    var total = 0
    var balls = 0
    var strikes = 0

    var unclassified: Int {
        total - balls - strikes
    }

    var isEmpty: Bool {
        total == 0 && balls == 0 && strikes == 0
    }
}

struct RelatedDefensivePlayReference: Codable, Equatable, Sendable {
    let recordID: UUID
    let gameID: UUID
    let sequenceNumber: Int
    let kindRawValue: String
    let revisionDigest: Data
}

struct PitchCountReconciliationEvent: Codable, Equatable, Sendable {
    let pitcherID: UUID
    let adjustment: PitchCountAdjustment
    let relatedPlay: RelatedDefensivePlayReference?

    init(
        pitcherID: UUID,
        adjustment: PitchCountAdjustment,
        relatedPlay: RelatedDefensivePlayReference? = nil
    ) {
        self.pitcherID = pitcherID
        self.adjustment = adjustment
        self.relatedPlay = relatedPlay
    }
}

func signedPitchAdjustment(_ value: Int) -> String {
    value >= 0 ? "+\(value)" : "\(value)"
}

enum OffensivePitchResult: String, CaseIterable, Codable, Identifiable, Sendable {
    case ball
    case calledStrike
    case swingingStrike
    case foul

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ball: "Ball"
        case .calledStrike: "Called Strike"
        case .swingingStrike: "Swinging Strike"
        case .foul: "Foul"
        }
    }

    var shortLabel: String {
        switch self {
        case .ball: "Ball"
        case .calledStrike: "Strike"
        case .swingingStrike: "Swing"
        case .foul: "Foul"
        }
    }
}

struct OffensivePitchEvent: Codable, Equatable, Sendable {
    let batter: TrackedBatterIdentity
    let battingOrderSize: Int
    let result: OffensivePitchResult
}

enum OffensiveBaseRunningResult: String, CaseIterable, Codable, Identifiable, Sendable {
    case stolenBase
    case caughtStealing

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .stolenBase: "SB"
        case .caughtStealing: "CS"
        }
    }

    var confirmationName: String {
        switch self {
        case .stolenBase: "stolen base"
        case .caughtStealing: "caught stealing"
        }
    }
}

struct OffensiveBaseRunningEvent: Codable, Equatable, Sendable {
    let runnerID: UUID
    let source: RunnerSource
    let destination: RunnerDestination
    let result: OffensiveBaseRunningResult
}

enum BallInPlayOutcome: String, CaseIterable, Codable, Identifiable, Sendable {
    case single
    case double
    case triple
    case homeRun
    case reachedOnError
    case fieldersChoice
    case groundOut
    case flyOut
    case lineOut
    case popOut
    case sacrificeBunt
    case sacrificeFly
    case doublePlay

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .single: "1B"
        case .double: "2B"
        case .triple: "3B"
        case .homeRun: "HR"
        case .reachedOnError: "E"
        case .fieldersChoice: "FC"
        case .groundOut: "GO"
        case .flyOut: "FO"
        case .lineOut: "LO"
        case .popOut: "PO"
        case .sacrificeBunt: "SAC"
        case .sacrificeFly: "SF"
        case .doublePlay: "DP"
        }
    }

    var label: String {
        OffensivePlateAppearanceResult(ballInPlayOutcome: self).label
    }

    var suggestedBatterDestination: RunnerDestination {
        switch self {
        case .single, .reachedOnError, .fieldersChoice: .first
        case .double: .second
        case .triple: .third
        case .homeRun: .home
        case .groundOut, .flyOut, .lineOut, .popOut, .sacrificeBunt, .sacrificeFly, .doublePlay: .out
        }
    }

    var suggestedOuts: Int {
        switch self {
        case .groundOut, .flyOut, .lineOut, .popOut, .sacrificeBunt, .sacrificeFly: 1
        case .doublePlay: 2
        default: 0
        }
    }
}

enum RunnerSource: String, CaseIterable, Codable, Hashable, Sendable {
    case batter
    case first
    case second
    case third

    var label: String {
        switch self {
        case .batter: "Batter"
        case .first: "Runner on 1B"
        case .second: "Runner on 2B"
        case .third: "Runner on 3B"
        }
    }

    var baseLabel: String {
        switch self {
        case .batter: "Batter"
        case .first: "1B"
        case .second: "2B"
        case .third: "3B"
        }
    }
}

enum RunnerDestination: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case first
    case second
    case third
    case home
    case out

    var id: String { rawValue }

    var label: String {
        switch self {
        case .first: "1B"
        case .second: "2B"
        case .third: "3B"
        case .home: "Home"
        case .out: "Out"
        }
    }
}

struct RunnerMovementEvent: Codable, Equatable, Sendable {
    let source: RunnerSource
    let destination: RunnerDestination
}

struct TrackedBatterIdentity: Codable, Equatable, Sendable {
    let playerID: UUID
    let lineupSlot: Int
    let displayName: String
    let jerseyNumber: String
    let position: DefensivePosition?
}

enum OffensivePlateAppearanceResult: String, CaseIterable, Codable, Equatable, Sendable {
    case single
    case double
    case triple
    case homeRun
    case walk
    case hitByPitch
    case strikeout
    case reachedOnError
    case fieldersChoice
    case groundOut
    case flyOut
    case lineOut
    case popOut
    case sacrificeBunt
    case sacrificeFly
    case doublePlay

    var label: String {
        switch self {
        case .single: "Single"
        case .double: "Double"
        case .triple: "Triple"
        case .homeRun: "Home Run"
        case .walk: "Walk"
        case .hitByPitch: "HBP"
        case .strikeout: "Strikeout"
        case .reachedOnError: "Reached on Error"
        case .fieldersChoice: "Fielder's Choice"
        case .groundOut: "Ground Out"
        case .flyOut: "Fly Out"
        case .lineOut: "Line Out"
        case .popOut: "Pop Out"
        case .sacrificeBunt: "Sacrifice Bunt"
        case .sacrificeFly: "Sacrifice Fly"
        case .doublePlay: "Double Play"
        }
    }

    init(ballInPlayOutcome: BallInPlayOutcome) {
        switch ballInPlayOutcome {
        case .single: self = .single
        case .double: self = .double
        case .triple: self = .triple
        case .homeRun: self = .homeRun
        case .reachedOnError: self = .reachedOnError
        case .fieldersChoice: self = .fieldersChoice
        case .groundOut: self = .groundOut
        case .flyOut: self = .flyOut
        case .lineOut: self = .lineOut
        case .popOut: self = .popOut
        case .sacrificeBunt: self = .sacrificeBunt
        case .sacrificeFly: self = .sacrificeFly
        case .doublePlay: self = .doublePlay
        }
    }
}

struct OffensivePlateAppearanceEvent: Codable, Equatable, Sendable {
    let batter: TrackedBatterIdentity
    /// Number of batting-order slots when this plate appearance occurred.
    let battingOrderSize: Int
    let result: OffensivePlateAppearanceResult
    let movements: [RunnerMovementEvent]
    let rbi: Int
    /// Runner sources whose touches of home legally count. Identity is preserved for run attribution.
    let countedRunSources: [RunnerSource]
    let thirdOutClassification: ThirdOutClassification?
}

struct OffensivePlateAppearanceDraft: Equatable, Sendable {
    let result: OffensivePlateAppearanceResult
    let movements: [RunnerMovementEvent]
    let rbi: Int
    let countedRunSources: [RunnerSource]
    let thirdOutClassification: ThirdOutClassification?
}

enum ThirdOutClassification: String, CaseIterable, Codable, Equatable, Sendable {
    case forceOrBatterRunner
    case timingPlay
}

/// Completes a ball-in-play plate appearance. The event explicitly records the final
/// destination of the batter and every runner who existed when the play began.
struct BallInPlayEvent: Codable, Equatable, Sendable {
    let outcome: BallInPlayOutcome
    let opponentBatterSlot: Int
    let movements: [RunnerMovementEvent]
    let rbi: Int
    /// Required only when the play creates the third out and one or more runners touch home.
    /// This supports timing plays where some, but not all, apparent runs count.
    let thirdOutRunsCounted: Int?
    /// Required with `thirdOutRunsCounted`. Force and batter-runner third outs cannot score;
    /// timing plays may score only runs that touched home before the third out.
    let thirdOutClassification: ThirdOutClassification?

    init(
        outcome: BallInPlayOutcome,
        opponentBatterSlot: Int,
        movements: [RunnerMovementEvent],
        rbi: Int,
        thirdOutRunsCounted: Int?,
        thirdOutClassification: ThirdOutClassification? = nil
    ) {
        self.outcome = outcome
        self.opponentBatterSlot = opponentBatterSlot
        self.movements = movements
        self.rbi = rbi
        self.thirdOutRunsCounted = thirdOutRunsCounted
        self.thirdOutClassification = thirdOutClassification
    }
}

enum GameEventBody: Equatable, Sendable {
    case pitch(PitchEvent)
    case pitchCountReconciliation(PitchCountReconciliationEvent)
    case ballInPlay(BallInPlayEvent)
    case offensivePitch(OffensivePitchEvent)
    case offensiveBaseRunning(OffensiveBaseRunningEvent)
    case offensivePlateAppearance(OffensivePlateAppearanceEvent)

    var kind: GameEventKind {
        switch self {
        case .pitch: .pitch
        case .pitchCountReconciliation: .pitchCountReconciliation
        case .ballInPlay: .ballInPlay
        case .offensivePitch: .offensivePitch
        case .offensiveBaseRunning: .offensiveBaseRunning
        case .offensivePlateAppearance: .offensivePlateAppearance
        }
    }
}

struct DecodedGameEvent: Equatable, Sendable {
    let sequenceNumber: Int
    let timestamp: Date
    let body: GameEventBody
}

enum GameEventCodecError: Error, Equatable {
    case unknownKind(String)
    case invalidPayload(GameEventKind)
}

enum GameEventCodec {
    static func encode(_ body: GameEventBody) throws -> (kind: GameEventKind, payload: Data) {
        let encoder = JSONEncoder()
        switch body {
        case .pitch(let pitch):
            return (.pitch, try encoder.encode(pitch))
        case .pitchCountReconciliation(let reconciliation):
            return (.pitchCountReconciliation, try encoder.encode(reconciliation))
        case .ballInPlay(let play):
            return (.ballInPlay, try encoder.encode(play))
        case .offensivePitch(let pitch):
            return (.offensivePitch, try encoder.encode(pitch))
        case .offensiveBaseRunning(let event):
            return (.offensiveBaseRunning, try encoder.encode(event))
        case .offensivePlateAppearance(let plateAppearance):
            return (.offensivePlateAppearance, try encoder.encode(plateAppearance))
        }
    }

    static func decode(kindRawValue: String, payload: Data) throws -> GameEventBody {
        guard let kind = GameEventKind(rawValue: kindRawValue) else {
            throw GameEventCodecError.unknownKind(kindRawValue)
        }

        let decoder = JSONDecoder()
        do {
            switch kind {
            case .pitch:
                return .pitch(try decoder.decode(PitchEvent.self, from: payload))
            case .pitchCountReconciliation:
                return .pitchCountReconciliation(
                    try decoder.decode(PitchCountReconciliationEvent.self, from: payload)
                )
            case .ballInPlay:
                return .ballInPlay(try decoder.decode(BallInPlayEvent.self, from: payload))
            case .offensivePitch:
                return .offensivePitch(try decoder.decode(OffensivePitchEvent.self, from: payload))
            case .offensiveBaseRunning:
                return .offensiveBaseRunning(try decoder.decode(OffensiveBaseRunningEvent.self, from: payload))
            case .offensivePlateAppearance:
                return .offensivePlateAppearance(
                    try decoder.decode(OffensivePlateAppearanceEvent.self, from: payload)
                )
            }
        } catch {
            throw GameEventCodecError.invalidPayload(kind)
        }
    }
}

@Model
final class GameEventRecord {
    @Attribute(.unique) var id: UUID
    var gameID: UUID
    var sequenceNumber: Int
    var timestamp: Date
    var kindRawValue: String
    var payload: Data

    init(
        id: UUID = UUID(),
        gameID: UUID,
        sequenceNumber: Int,
        timestamp: Date = .now,
        body: GameEventBody
    ) throws {
        let encoded = try GameEventCodec.encode(body)
        self.id = id
        self.gameID = gameID
        self.sequenceNumber = sequenceNumber
        self.timestamp = timestamp
        self.kindRawValue = encoded.kind.rawValue
        self.payload = encoded.payload
    }

    func decoded() throws -> DecodedGameEvent {
        DecodedGameEvent(
            sequenceNumber: sequenceNumber,
            timestamp: timestamp,
            body: try GameEventCodec.decode(kindRawValue: kindRawValue, payload: payload)
        )
    }

    var relatedDefensivePlayReference: RelatedDefensivePlayReference {
        var revision = Data(kindRawValue.utf8)
        revision.append(0)
        if let object = try? JSONSerialization.jsonObject(with: payload),
           let canonicalPayload = try? JSONSerialization.data(
               withJSONObject: object,
               options: [.sortedKeys]
           ) {
            revision.append(canonicalPayload)
        } else {
            revision.append(payload)
        }
        return RelatedDefensivePlayReference(
            recordID: id,
            gameID: gameID,
            sequenceNumber: sequenceNumber,
            kindRawValue: kindRawValue,
            revisionDigest: Data(SHA256.hash(data: revision))
        )
    }
}
