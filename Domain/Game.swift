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

enum GameFormat: String, CaseIterable, Identifiable {
    case innings = "Innings"
    case timeLimit = "Time Limit"

    var id: String { rawValue }
}

struct GameSetupValidation {
    static let timeLimitOptions = Array(stride(from: 30, through: 90, by: 5))
    static let defaultTimeLimitMinutes = 75

    static func canContinue(
        opponentName: String,
        seasonID: UUID?,
        format: GameFormat,
        timeLimitMinutes: Int
    ) -> Bool {
        guard !opponentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              seasonID != nil else {
            return false
        }

        return format != .timeLimit || timeLimitOptions.contains(timeLimitMinutes)
    }
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

    /// Positive values retain the shipped innings representation. Negative values encode a
    /// time limit in minutes without requiring a SwiftData schema migration for existing games.
    var format: GameFormat? {
        if regulationInnings > 0 { return .innings }
        if regulationInnings < 0, regulationInnings != .min { return .timeLimit }
        return nil
    }

    var timeLimitMinutes: Int? {
        guard format == .timeLimit else { return nil }
        return -regulationInnings
    }

    var formatDescription: String {
        guard let format else { return "Unreadable format" }
        switch format {
        case .innings:
            return "\(regulationInnings) innings"
        case .timeLimit:
            guard let timeLimitMinutes else { return "Unreadable format" }
            return "\(timeLimitMinutes) minute time limit"
        }
    }

    func timeStatus(at date: Date) -> String? {
        guard let timeLimitMinutes,
              timeLimitMinutes > 0,
              let startedAt else { return nil }

        let elapsed = date.timeIntervalSince(startedAt)
        let remaining = max(0, TimeInterval(timeLimitMinutes) * 60 - elapsed)
        guard remaining > 0 else { return "Time expired" }

        let wholeSeconds = ceil(remaining)
        return String(
            format: "%.0f:%02.0f remaining",
            floor(wholeSeconds / 60),
            wholeSeconds.truncatingRemainder(dividingBy: 60)
        )
    }

    init(
        id: UUID = UUID(),
        seasonID: UUID,
        opponentName: String,
        gameDate: Date = .now,
        homeAway: HomeAway = .away,
        regulationInnings: Int = 7,
        timeLimitMinutes: Int? = nil,
        status: GameStatus = .scheduled,
        startingPitcherID: UUID? = nil,
        startedAt: Date? = nil,
        finalizedAt: Date? = nil,
        createdAt: Date = .now
    ) {
        precondition(
            timeLimitMinutes.map { GameSetupValidation.timeLimitOptions.contains($0) } ?? (regulationInnings > 0),
            "A game requires a positive inning count or a supported time limit."
        )
        self.id = id
        self.seasonID = seasonID
        self.opponentName = opponentName
        self.gameDate = gameDate
        self.homeAwayRawValue = homeAway.rawValue
        self.regulationInnings = timeLimitMinutes.map { -$0 } ?? regulationInnings
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
    static let requiredDefenderCount = 9
    static let regulationDefensivePositions: [DefensivePosition] = [
        .pitcher, .catcher, .firstBase, .secondBase, .thirdBase,
        .shortstop, .leftField, .centerField, .rightField
    ]

    static func canStart(entries: [LineupDraftEntryValue], startingPitcherID: UUID?) -> Bool {
        guard entries.count >= requiredDefenderCount,
              Set(entries.map(\.playerID)).count == entries.count,
              let startingPitcherID,
              entries.contains(where: { $0.playerID == startingPitcherID && $0.position == .pitcher }) else {
            return false
        }

        let positions = entries.compactMap(\.position)
        return positions.count == requiredDefenderCount
            && Set(positions) == Set(regulationDefensivePositions)
    }
}

/// Value-only representation used to validate setup without coupling the domain rule to SwiftUI state.
struct LineupDraftEntryValue: Equatable {
    let playerID: UUID
    let position: DefensivePosition?
}

enum TrackedBattingOrder {
    static func resolve(
        gameID: UUID,
        lineupEntries: [LineupEntry],
        players: [Player]
    ) -> [TrackedBatterIdentity]? {
        let entries = lineupEntries
            .filter { $0.gameID == gameID && $0.isActive }
            .sorted { $0.battingOrder < $1.battingOrder }
        guard !entries.isEmpty,
              entries.map(\.battingOrder) == Array(1...entries.count),
              Set(entries.map(\.playerID)).count == entries.count else {
            return nil
        }

        let groupedPlayers = Dictionary(grouping: players, by: \.id)
        guard groupedPlayers.values.allSatisfy({ $0.count == 1 }) else { return nil }
        let playersByID = groupedPlayers.compactMapValues(\.first)
        var battingOrder: [TrackedBatterIdentity] = []
        for (index, entry) in entries.enumerated() {
            guard let player = playersByID[entry.playerID] else { return nil }
            battingOrder.append(TrackedBatterIdentity(
                playerID: player.id,
                lineupSlot: index + 1,
                displayName: player.displayName,
                jerseyNumber: player.jerseyNumber,
                position: entry.startingPosition
            ))
        }
        return battingOrder
    }
}
