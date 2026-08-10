import Foundation
import SwiftData

enum GameEventKind: String, Codable, Sendable {
    case pitch
    case ballInPlay
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
        switch self {
        case .single: "Single"
        case .double: "Double"
        case .triple: "Triple"
        case .homeRun: "Home Run"
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
    case ballInPlay(BallInPlayEvent)

    var kind: GameEventKind {
        switch self {
        case .pitch: .pitch
        case .ballInPlay: .ballInPlay
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
        case .ballInPlay(let play):
            return (.ballInPlay, try encoder.encode(play))
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
            case .ballInPlay:
                return .ballInPlay(try decoder.decode(BallInPlayEvent.self, from: payload))
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
}
