import Foundation
import SwiftData

enum HomeAway: String, CaseIterable, Codable, Identifiable {
    case home = "Home"
    case away = "Away"

    var id: String { rawValue }
}

enum GameStatus: String, CaseIterable, Codable {
    case scheduled
    case inProgress
    case final
}

@Model
final class Game {
    @Attribute(.unique) var id: UUID
    var seasonID: UUID
    var opponentName: String
    var gameDate: Date
    var homeAwayRawValue: String
    var regulationInnings: Int
    var statusRawValue: String
    var startingPitcherID: UUID?
    var startedAt: Date?
    var finalizedAt: Date?
    var createdAt: Date

    var homeAway: HomeAway {
        get { HomeAway(rawValue: homeAwayRawValue) ?? .away }
        set { homeAwayRawValue = newValue.rawValue }
    }

    var status: GameStatus? {
        GameStatus(rawValue: statusRawValue)
    }

    init(
        id: UUID = UUID(),
        seasonID: UUID,
        opponentName: String,
        gameDate: Date = .now,
        homeAway: HomeAway = .away,
        regulationInnings: Int = 7,
        status: GameStatus = .scheduled,
        startingPitcherID: UUID? = nil,
        startedAt: Date? = nil,
        finalizedAt: Date? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.seasonID = seasonID
        self.opponentName = opponentName
        self.gameDate = gameDate
        self.homeAwayRawValue = homeAway.rawValue
        self.regulationInnings = regulationInnings
        self.statusRawValue = status.rawValue
        self.startingPitcherID = startingPitcherID
        self.startedAt = startedAt
        self.finalizedAt = finalizedAt
        self.createdAt = createdAt
    }
}

@Model
final class LineupEntry {
    @Attribute(.unique) var id: UUID
    var playerID: UUID
    var battingOrder: Int
    var startingPositionRawValue: String
    var currentPositionRawValue: String
    var isActive: Bool
    var gameID: UUID

    var startingPosition: DefensivePosition? {
        get { DefensivePosition(rawValue: startingPositionRawValue) }
        set { startingPositionRawValue = newValue?.rawValue ?? "" }
    }

    var currentPosition: DefensivePosition? {
        get { DefensivePosition(rawValue: currentPositionRawValue) }
        set { currentPositionRawValue = newValue?.rawValue ?? "" }
    }

    init(
        id: UUID = UUID(),
        playerID: UUID,
        battingOrder: Int,
        startingPosition: DefensivePosition? = nil,
        currentPosition: DefensivePosition? = nil,
        isActive: Bool = true,
        gameID: UUID
    ) {
        self.id = id
        self.playerID = playerID
        self.battingOrder = battingOrder
        self.startingPositionRawValue = startingPosition?.rawValue ?? ""
        self.currentPositionRawValue = (currentPosition ?? startingPosition)?.rawValue ?? ""
        self.isActive = isActive
        self.gameID = gameID
    }
}

struct LineupValidation {
    static let requiredStarterCount = 9
    static let regulationDefensivePositions: [DefensivePosition] = [
        .pitcher, .catcher, .firstBase, .secondBase, .thirdBase,
        .shortstop, .leftField, .centerField, .rightField
    ]

    static func canStart(entries: [LineupDraftEntryValue], startingPitcherID: UUID?) -> Bool {
        guard entries.count == requiredStarterCount,
              Set(entries.map(\.playerID)).count == requiredStarterCount,
              let startingPitcherID,
              entries.contains(where: { $0.playerID == startingPitcherID && $0.position == .pitcher }) else {
            return false
        }

        let positions = entries.compactMap(\.position)
        return positions.count == requiredStarterCount
            && Set(positions) == Set(regulationDefensivePositions)
    }
}

/// Value-only representation used to validate setup without coupling the domain rule to SwiftUI state.
struct LineupDraftEntryValue: Equatable {
    let playerID: UUID
    let position: DefensivePosition?
}
